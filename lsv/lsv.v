import arrays { group_by }
import datatypes { Set }
import os

fn main() {
	args := parse_args(os.args)
	entries := get_entries(args.files, args)
	mut cyclic := Set[string]{}
	lsv(entries, args, mut cyclic)
}

fn lsv(entries []Entry, args Args, mut cyclic Set[string]) {
	group_by_dirs := group_by[string, Entry](entries, fn (e Entry) string {
		return e.dir_name
	})
	sorted_dirs := group_by_dirs.keys().sorted()

	for dir in sorted_dirs {
		dirs := group_by_dirs[dir]
		filtered := filter(dirs, args)
		sorted := sort(filtered, args)
		if group_by_dirs.len > 1 || args.recursive {
			print_dir_name(dir, args)
		}
		format(sorted, args)

		if args.recursive {
			for entry in sorted {
				entry_path := os.join_path(entry.dir_name, entry.name)
				if entry.dir {
					if cyclic.exists(entry_path) {
						println('===> cyclic reference detected <===')
						continue
					}
					cyclic.add(entry_path)
					dir_entries := get_entries([entry_path], args)
					lsv(dir_entries, args, mut cyclic)
					cyclic.remove(entry_path)
				}
			}
		}
	}
}
