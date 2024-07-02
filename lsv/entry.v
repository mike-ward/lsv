import os
import crypto.md5
import crypto.sha1
import crypto.sha256
import crypto.sha512
import crypto.blake2b
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
	size_ki     string
	size_kb     string
	checksum    string
	invalid     bool // lstat could not access
}

fn get_entries(files []string, args Args) []Entry {
	mut entries := []Entry{}

	for file in files {
		if os.is_dir(file) {
			other_files := os.ls(file) or { continue }
			entries << other_files.map(make_entry(it, file, args))
			continue
		}
		entries << make_entry(file, '', args)
	}
	return entries
}

fn make_entry(file string, dir_name string, args Args) Entry {
	mut invalid := false
	path := if dir_name == '' { file } else { os.join_path(dir_name, file) }

	stat := os.lstat(path) or {
		// println('${path} -> ${err.msg()}')
		invalid = true
		os.Stat{}
	}

	filetype := stat.get_filetype()
	is_link := filetype == os.FileType.symbolic_link
	link_origin := if is_link { read_link(path) } else { '' }
	mut size := stat.size
	mut link_stat := os.Stat{}

	if is_link && args.long_format && !invalid {
		// os.stat follows link
		link_stat = os.stat(path) or {
			size = 0
			os.Stat{}
		}
		size = link_stat.size
	}

	is_dir := filetype == os.FileType.directory
	is_fifo := filetype == .fifo
	is_block := filetype == .block_device
	is_socket := filetype == .socket
	is_character_device := filetype == .character_device
	is_unknown := filetype == .unknown
	is_exe := !is_dir && is_executable(stat)
	is_file := !is_dir && !is_fifo && !is_block && !is_socket && !is_character_device && !is_unknown
		&& !is_exe && !invalid
	indicator := if is_dir && args.dir_indicator { '/' } else { '' }

	return Entry{
		name: file + indicator
		dir_name: dir_name
		stat: stat
		link_stat: link_stat
		dir: is_dir
		file: is_file
		link: is_link
		exe: is_exe
		fifo: is_fifo
		block: is_block
		socket: is_socket
		character: is_character_device
		unknown: is_unknown
		link_origin: link_origin
		size: size
		size_ki: if args.size_ki { readable_size(size, true) } else { '' }
		size_kb: if args.size_kb { readable_size(size, false) } else { '' }
		checksum: if is_file { checksum(file, dir_name, args) } else { '' }
		invalid: invalid
	}
}

fn is_executable(stat os.Stat) bool {
	return stat.get_mode().bitmask() & 0b001001001 > 0
}

fn readable_size(size u64, si bool) string {
	kb := if si { f64(1024) } else { f64(1000) }
	mut sz := f64(size)
	for unit in ['', 'k', 'm', 'g', 't', 'p', 'e', 'z'] {
		if sz < kb {
			readable := if unit == '' {
				size.str()
			} else {
				math.round_sig(sz + .049999, 1).str()
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

fn checksum(name string, dir_name string, args Args) string {
	if args.checksum == '' {
		return ''
	}
	file := os.join_path(dir_name, name)
	bytes := os.read_bytes(file) or { return unknown }

	return match args.checksum {
		'md5' { md5.sum(bytes).hex() }
		'sha1' { sha1.sum(bytes).hex() }
		'sha224' { sha256.sum224(bytes).hex() }
		'sha256' { sha256.sum256(bytes).hex() }
		'sha512' { sha512.sum512(bytes).hex() }
		'blake2b' { blake2b.sum256(bytes).hex() }
		else { unknown }
	}
}
