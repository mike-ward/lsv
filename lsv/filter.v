fn filter(entries []Entry, args Args) []Entry {
	mut filtered := entries.clone()

	if !args.all {
		filtered = entries.filter(it.name.starts_with('../') || !it.name.starts_with('.'))
	}

	if args.only_dirs {
		filtered = filtered.filter(it.dir)
	}

	if args.only_files {
		filtered = filtered.filter(it.file)
	}

	return filtered
}
