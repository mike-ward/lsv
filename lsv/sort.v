import os

fn sort(mut entries []Entry, options Options) {
	if options.sort_none {
		return
	}

	entries.sort_with_compare(fn [options] (a &Entry, b &Entry) int {
		// Handle directories first
		if options.dirs_first {
			if a.dir && !b.dir {
				return -1
			}
			if !a.dir && b.dir {
				return 1
			}
		}

		// Primary Sort
		result := match true {
			options.sort_size {
				if a.size < b.size {
					1
				} else if a.size > b.size {
					-1
				} else {
					0
				}
			}
			options.sort_time {
				if a.stat.mtime < b.stat.mtime {
					1
				} else if a.stat.mtime > b.stat.mtime {
					-1
				} else {
					0
				}
			}
			options.sort_width {
				// Calculate lengths (expensive but needed for accuracy if sorting by width)
				// Optimization: We could cache this if we sorted primarily by width often, but usually rare.
				a_len := a.name.len + a.link_origin.len + if a.link_origin.len > 0 { 4 } else { 0 }
				b_len := b.name.len + b.link_origin.len + if b.link_origin.len > 0 { 4 } else { 0 }
				a_len - b_len
			}
			options.sort_ext {
				// Optimization: avoid re-calculating ext multiple times if possible,
				// but here we just optimize the calling pattern.
				// For truly high perf, we'd store ext in Entry, but that increases memory.
				// Given V's os.file_ext is fast (string slicing), this might be acceptable.
				compare_strings(os.file_ext(a.name), os.file_ext(b.name))
			}
			options.sort_natural {
				natural_compare(a.name, b.name, options.sort_ignore_case)
			}
			else {
				0
			}
		}

		if result != 0 {
			return if options.sort_reverse { -result } else { result }
		}

		// Fallback to name sort (always consistent)
		name_cmp := string_compare(a.name, b.name, options.sort_ignore_case)
		return if options.sort_reverse { -name_cmp } else { name_cmp }
	})
}

fn string_compare(a string, b string, ignore_case bool) int {
	return match ignore_case {
		true { compare_strings(a.to_lower(), b.to_lower()) }
		else { compare_strings(a, b) }
	}
}
