import os
import crypto.md5
import crypto.sha1
import crypto.sha256
import crypto.sha512
import crypto.blake2b
import net.http.mime
import math

struct Entry {
	name        string
	dir_name    string
	stat        os.Stat
	link_stat   os.Stat
	dir         bool
	file        bool
	link        bool
	exe         bool
	fifo        bool
	block       bool
	socket      bool
	character   bool
	unknown     bool
	link_origin string
	size        u64
	size_comma  string
	size_ki     string
	size_kb     string
	checksum    string
	mime_type   string
	owner       string
	group       string
	invalid     bool // lstat could not access
mut:
	// cache formatted times here.
	fmt_atime string
	fmt_ctime string
	fmt_mtime string
}

fn get_entries(files []string, options Options) []Entry {
	mut entries := []Entry{cap: 50}

	for file in files {
		if os.is_dir(file) {
			dir_files := os.ls(file) or { continue }
			entries << match options.all {
				true { dir_files.map(make_entry(it, file, options)) }
				else { dir_files.filter(!is_dot_file(it)).map(make_entry(it, file, options)) }
			}
		} else {
			if options.all || !is_dot_file(file) {
				entries << make_entry(file, '', options)
			}
		}
	}
	return entries
}

fn make_entry(file string, dir_name string, options Options) Entry {
	mut invalid := false
	path := if dir_name == '' { file } else { os.join_path(dir_name, file) }

	stat := os.lstat(path) or {
		// println('${path} -> ${err.msg()}')
		invalid = true
		os.Stat{}
	}

	filetype := stat.get_filetype()
	is_link := filetype == .symbolic_link
	link_origin := if is_link { read_link(path) } else { '' }
	mut size := stat.size
	mut link_stat := os.Stat{}

	if is_link && options.long_format && !invalid {
		// os.stat follows link
		link_stat = os.stat(path) or { os.Stat{} }
		size = link_stat.size
	}

	is_dir := filetype == .directory
	is_fifo := filetype == .fifo
	is_block := filetype == .block_device
	is_socket := filetype == .socket
	is_character_device := filetype == .character_device
	is_unknown := filetype == .unknown
	is_exe := !is_dir && is_executable(stat)
	is_file := filetype == .regular
	indicator := if is_dir && options.dir_indicator { '/' } else { '' }
	name := if options.full_path { os.real_path(path) + indicator } else { file + indicator }

	return Entry{
		name:        name
		dir_name:    dir_name
		stat:        stat
		link_stat:   link_stat
		dir:         is_dir
		file:        is_file
		link:        is_link
		exe:         is_exe
		fifo:        is_fifo
		block:       is_block
		socket:      is_socket
		character:   is_character_device
		unknown:     is_unknown
		link_origin: link_origin
		size:        size
		size_comma:  if options.size_comma { num_with_commas(size) } else { '' }
		size_ki:     if options.size_ki { readable_size(size, true) } else { '' }
		size_kb:     if options.size_kb { readable_size(size, false) } else { '' }
		checksum:    if is_file { checksum(file, dir_name, options) } else { '' }
		mime_type:   if options.mime_type { get_mime_type(file, link_origin, is_exe) } else { '' }
		owner:       if options.numeric_ids { stat.uid.str() } else { get_owner_name(stat.uid) }
		group:       if options.numeric_ids { stat.gid.str() } else { get_group_name(stat.gid) }
		invalid:     invalid
	}
}

fn num_with_commas(num u64) string {
	if num == 0 {
		return '0'
	}

	mut n := num
	mut buf := []u8{}
	mut digit_count := 0

	for n > 0 {
		if digit_count > 0 && digit_count % 3 == 0 {
			buf << `,`
		}
		buf << byte(`0` + n % 10)
		n /= 10
		digit_count++
	}

	// Reverse the buffer to get the correct order
	for i, j := 0, buf.len - 1; i < j; i++, j-- {
		buf[i], buf[j] = buf[j], buf[i]
	}

	return buf.bytestr()
}

fn readable_size(size u64, si bool) string {
	kb := if si { f64(1024) } else { f64(1000) }
	mut sz := f64(size)
	for unit in ['', 'k', 'm', 'g', 't', 'p', 'e', 'z'] {
		if sz < kb {
			readable := match unit == '' {
				true { size.str() }
				else { math.round_sig(sz + .049999, 1).str() }
			}
			bytes := match true {
				unit == '' { '' }
				si { '' }
				else { 'b' }
			}
			return '${readable}${unit}${bytes}'
		}
		sz /= kb
	}
	return size.str()
}

fn checksum(name string, dir_name string, options Options) string {
	if options.checksum == '' {
		return ''
	}
	file_path := os.join_path(dir_name, name)
	mut f := os.open(file_path) or { return unknown }
	defer { f.close() }

	mut buf := []u8{len: 64 * 1024}

	match options.checksum {
		'md5' {
			mut digest := md5.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha1' {
			mut digest := sha1.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha224' {
			// sha256 module handles sha224 usually via config or different constructor?
			// V's crypto.sha256 doesn't seem to expose new224() easily or it's sum224.
			// Checking docs (implied): sum224 exists.
			// If we can't stream sha224 easily without reading docs, we might have to use read_bytes or read docs.
			// Let's stick to non-streaming for sha224 if unsure, OR use sha256.new() and see if there is a way.
			// Actually, simplest is to fall back to memory for sha224 if I am unsure, but I want to optimize.
			// Let's assume sha256.new224() might not exist.
			// Reverting to read_bytes for sha224 just to be safe, or trying to find it.
			// I'll stick to full read for sha224 to avoid breaking it if unknown.
			f.close()
			bytes := os.read_bytes(file_path) or { return unknown }
			return sha256.sum224(bytes).hex()
		}
		'sha256' {
			mut digest := sha256.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha512' {
			mut digest := sha512.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'blake2b' {
			// Blake2b in V might operate differently as seen in test failure (no sum()).
			// It has `checksum()`.
			mut digest := blake2b.new256() or { return unknown }
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.checksum().hex()
		}
		else {
			return unknown
		}
	}
}

const text_plain_names = [
	'CARGO.LOCK',
	'CMAKE',
	'CNAME',
	'DOCKERFILE',
	'GEMFILE',
	'GEMFILE.LOCK',
	'GNUMAKEFILE',
	'LICENSE',
	'MAKEFILE',
	'TEXT',
	'V.MOD',
]

fn get_mime_type(file string, link_origin string, is_exe bool) string {
	if link_origin.len > 0 {
		return mime.get_mime_type(os.file_ext(link_origin).trim_left('.'))
	}
	ext := os.file_ext(file).trim_left('.')
	mt := mime.get_mime_type(ext)
	if mt.len > 0 {
		return mt
	}
	if is_exe {
		return 'application/octet-stream'
	}
	if file.to_upper() in text_plain_names || ext.to_upper() in text_plain_names {
		return 'text/plain'
	}
	return ''
}

@[inline]
fn is_executable(stat os.Stat) bool {
	return stat.get_mode().bitmask() & 0b001001001 > 0
}

@[inline]
fn is_dot_file(file string) bool {
	return file.starts_with('.')
}
