import os
import math

struct Entry {
	name        string
	dir_name    string
	stat        os.Stat
	dir         bool
	file        bool
	link        bool
	exe         bool
	fifo        bool
	block       bool
	socket      bool
	character   bool
	link_origin string
	size_ki     string
	size_kb     string
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
	path := os.join_path(dir_name, file)

	stat := os.lstat(path) or {
		invalid = true
		os.Stat{}
	}

	filetype := stat.get_filetype()
	is_link := filetype == os.FileType.symbolic_link
	link_origin := if is_link { read_link(path) } else { '' }
	follow_link := is_link && args.link_origin && args.long_format

	if follow_link && !invalid {
		return make_entry(link_origin, dir_name, args)
	}

	is_dir := filetype == os.FileType.directory
	is_file := !is_dir && !invalid
	is_exe := stat.get_mode().bitmask() & 0b001001001 > 0
	indicator := if is_dir && args.dir_indicator { '/' } else { '' }

	return Entry{
		name: file + indicator
		dir_name: dir_name
		stat: stat
		dir: is_dir
		file: is_file
		link: is_link
		exe: is_exe
		fifo: filetype == .fifo
		block: filetype == .block_device
		socket: filetype == .socket
		character: filetype == .character_device
		link_origin: link_origin
		size_ki: if args.size_ki { readable_size(stat.size, true) } else { '' }
		size_kb: if args.size_kb { readable_size(stat.size, false) } else { '' }
		invalid: invalid
	}
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
