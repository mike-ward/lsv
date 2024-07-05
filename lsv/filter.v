fn filter(entries []Entry, options Options) []Entry {
	mut filtered := entries.clone()

	if !options.all {
		filtered = entries.filter(it.name.starts_with('../') || !it.name.starts_with('.'))
	}

	if options.only_dirs {
		filtered = filtered.filter(it.dir)
	}

	if options.only_files {
		filtered = filtered.filter(it.file)
	}

	return filtered
}
