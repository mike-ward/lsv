import arrays
import os

fn sort(entries []Entry, args Args) []Entry {
	cmp := match true {
		args.sort_none {
			fn (a &Entry, b &Entry) int {
				return 0
			}
		}
		args.sort_size {
			fn (a &Entry, b &Entry) int {
				return match true {
					a.stat.size < b.stat.size { 1 }
					a.stat.size > b.stat.size { -1 }
					else { compare_strings(a.name, b.name) }
				}
			}
		}
		args.sort_time {
			fn (a &Entry, b &Entry) int {
				return match true {
					a.stat.ctime < b.stat.ctime { 1 }
					a.stat.ctime > b.stat.ctime { -1 }
					else { compare_strings(a.name, b.name) }
				}
			}
		}
		args.sort_width {
			fn (a &Entry, b &Entry) int {
				a_len := a.name.len + a.link_origin.len + if a.link_origin.len > 0 { 4 } else { 0 }
				b_len := b.name.len + b.link_origin.len + if b.link_origin.len > 0 { 4 } else { 0 }
				result := a_len - b_len
				return if result != 0 { result } else { compare_strings(a.name, b.name) }
			}
		}
		args.sort_natural {
			fn (a &Entry, b &Entry) int {
				return natural_compare(a.name, b.name)
			}
		}
		args.sort_ext {
			fn (a &Entry, b &Entry) int {
				result := compare_strings(os.file_ext(a.name), os.file_ext(b.name))
				return if result != 0 { result } else { compare_strings(a.name, b.name) }
			}
		}
		else {
			fn (a &Entry, b &Entry) int {
				return compare_strings(a.name, b.name)
			}
		}
	}

	// if directories first option, group entries into dirs and files
	// The 'dir' and 'file' labels are discriptive. The only thing that
	// matters is that the 'dir' key collates before the 'file' key
	groups := arrays.group_by[string, Entry](entries, fn [args] (e Entry) string {
		return if args.dirs_first && e.dir { 'dir' } else { 'file' }
	})

	mut sorted := []Entry{}
	for key in groups.keys().sorted() {
		sorted << groups[key].sorted_with_compare(cmp)
	}

	return if args.sort_reverse { sorted.reverse() } else { sorted }
}
