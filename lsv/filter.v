import arrays
import time

enum ByTime {
	before_modified
	before_accessed
	before_changed
	after_modified
	after_accessed
	after_changed
}

fn filter(entries []Entry, options Options) []Entry {
	mut filtered := entries.clone()

	if options.only_dirs {
		filtered = filtered.filter(it.dir)
	}

	if options.only_files {
		filtered = filtered.filter(it.file)
	}

	if options.glob_ignore.len > 0 {
		for glob in options.glob_ignore.split('|') {
			filtered = filtered.filter(!it.name.match_glob(glob))
		}
	}

	if options.glob_match.len > 0 {
		mut matched := []Entry{}
		for glob in options.glob_match.split('|') {
			matched << filtered.filter(it.name.match_glob(glob))
		}
		filtered = arrays.distinct(matched)
	}

	filtered = filter_time(filtered, options.time_before_modified, .before_modified)
	filtered = filter_time(filtered, options.time_before_modified, .before_accessed)
	filtered = filter_time(filtered, options.time_before_modified, .before_changed)

	filtered = filter_time(filtered, options.time_after_modified, .after_modified)
	filtered = filter_time(filtered, options.time_after_accessed, .after_accessed)
	filtered = filter_time(filtered, options.time_after_changed, .after_changed)

	return filtered
}

fn filter_time(entries []Entry, time_str string, by ByTime) []Entry {
	if time_str.len == 0 {
		return entries
	}

	target_time := time.parse_iso8601(time_str) or { exit_error(err.msg()) }

	return match by {
		.before_modified { entries.filter(time.unix(it.stat.mtime) < target_time) }
		.before_accessed { entries.filter(time.unix(it.stat.atime) < target_time) }
		.before_changed { entries.filter(time.unix(it.stat.ctime) < target_time) }
		.after_modified { entries.filter(time.unix(it.stat.mtime) > target_time) }
		.after_accessed { entries.filter(time.unix(it.stat.atime) > target_time) }
		.after_changed { entries.filter(time.unix(it.stat.ctime) > target_time) }
	}
}
