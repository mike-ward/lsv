import arrays { group_by }
import datatypes { Set }
import os

fn main() {
	options := parse_args(os.args)
	set_auto_wrap(options)
	entries := get_entries(options.files, options)
	mut cyclic := Set[string]{}
	lsv(entries, options, mut cyclic)
}

fn lsv(entries []Entry, options Options, mut cyclic Set[string]) {
	group_by_dirs := group_by[string, Entry](entries, fn (e Entry) string {
		return e.dir_name
	})
	sorted_dirs := group_by_dirs.keys().sorted()

	for dir in sorted_dirs {
		files := group_by_dirs[dir]
		filtered := filter(files, options)
		sorted := sort(filtered, options)
		if group_by_dirs.len > 1 || options.recursive {
			print_dir_name(dir, options)
		}
		print_files(sorted, options)

		if options.recursive {
			for entry in sorted {
				if entry.dir {
					entry_path := os.join_path(entry.dir_name, entry.name)
					if cyclic.exists(entry_path) {
						println('===> cyclic reference detected <===')
						continue
					}
					cyclic.add(entry_path)
					dir_entries := get_entries([entry_path], options)
					lsv(dir_entries, options, mut cyclic)
					cyclic.remove(entry_path)
				}
			}
		}
	}
}

fn set_auto_wrap(options Options) {
	if options.no_wrap {
		wrap_off := '\e[?7l'
		wrap_reset := '\e[?7h'
		println(wrap_off)

		at_exit(fn [wrap_reset] () {
			println(wrap_reset)
		}) or {}

		// Ctrl-C handler
		os.signal_opt(os.Signal.int, fn (sig os.Signal) {
			println('\e[?7h') // until compile bug fixed
			exit(0)
		}) or {}
	}
}
