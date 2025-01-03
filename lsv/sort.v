import arrays
import os

fn sort(entries []Entry, options Options) []Entry {
	cmp := match true {
		options.sort_none {
			fn (a &Entry, b &Entry) int {
				return 0
			}
		}
		options.sort_size {
			fn [options] (a &Entry, b &Entry) int {
				return match true {
					// vfmt off
					a.size < b.size { 1 }
					a.size > b.size { -1 }
					else            { string_compare(a.name, b.name, options.sort_ignore_case) }
					// vfmt on
				}
			}
		}
		options.sort_time {
			fn [options] (a &Entry, b &Entry) int {
				return match true {
					// vfmt off
					a.stat.mtime < b.stat.mtime { 1 }
					a.stat.mtime > b.stat.mtime { -1 }
					else                        { string_compare(a.name, b.name, options.sort_ignore_case) }
					// vfmt on
				}
			}
		}
		options.sort_width {
			fn [options] (a &Entry, b &Entry) int {
				a_len := a.name.len + a.link_origin.len + if a.link_origin.len > 0 { 4 } else { 0 }
				b_len := b.name.len + b.link_origin.len + if b.link_origin.len > 0 { 4 } else { 0 }
				result := a_len - b_len
				return if result != 0 {
					result
				} else {
					string_compare(a.name, b.name, options.sort_ignore_case)
				}
			}
		}
		options.sort_natural {
			fn [options] (a &Entry, b &Entry) int {
				return natural_compare(a.name, b.name, options.sort_ignore_case)
			}
		}
		options.sort_ext {
			fn [options] (a &Entry, b &Entry) int {
				result := string_compare(os.file_ext(a.name), os.file_ext(b.name), options.sort_ignore_case)
				return if result != 0 {
					result
				} else {
					string_compare(a.name, b.name, options.sort_ignore_case)
				}
			}
		}
		else {
			fn [options] (a &Entry, b &Entry) int {
				return string_compare(a.name, b.name, options.sort_ignore_case)
			}
		}
	}

	// if directories first option, group entries into dirs and files
	// The 'dir' and 'file' labels are discriptive. The only thing that
	// matters is that the 'dir' key collates before the 'file' key
	groups := arrays.group_by[string, Entry](entries, fn [options] (e Entry) string {
		return if options.dirs_first && e.dir { 'dir' } else { 'file' }
	})

	mut sorted := []Entry{}
	for key in groups.keys().sorted() {
		sorted << groups[key].sorted_with_compare(cmp)
	}

	return if options.sort_reverse { sorted.reverse() } else { sorted }
}

fn string_compare(a &string, b &string, ignore_case bool) int {
	return match ignore_case {
		true { compare_strings(a.to_lower(), b.to_lower()) }
		else { compare_strings(a, b) }
	}
}
