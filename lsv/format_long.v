import arrays
import os
import term
import time
import crypto.md5
import crypto.sha1
import crypto.sha256
import crypto.sha512
import crypto.blake2b
import net.http.mime

const block_size = 5
const date_accessed_title = 'Accessed'
const date_compact_format = "DD.MMM'YY HH:mm"
const date_compact_format_with_day = "ddd DD MMM'YY HH:mm"
const date_format = 'MMM DD YYYY HH:mm:ss'
const date_iso_format = 'YYYY-MM-DD HH:mm:ss'
const date_modified_title = 'Modified'
const date_status_title = 'Status Change'
const group_title = 'Group'
const index_title = '#'
const inode_title = 'inode'
const links_title = 'Links'
const mask_title = 'Mask'
const mime_type_title = 'Mime Type'
const name_title = 'Name'
const owner_title = 'Owner'
const permissions_title = 'Permissions'
const size_title = 'Size'
const space = ' '
const unknown = '?'

struct Longest {
	atime      int
	checksum   int
	ctime      int
	file       int
	group_name int
	index      int
	inode      int
	mime_type  int
	mtime      int
	nlink      int
	owner_name int
	size       int
}

struct DisplayCache {
mut:
	checksum   string
	mime_type  string
	owner      string
	group      string
	fmt_atime  string
	fmt_ctime  string
	fmt_mtime  string
}

enum StatTime {
	accessed
	changed
	modified
}

fn format_long_listing(mut entries []&Entry, options Options) {
	longest, cache := longest_entries(mut entries, options)
	header, cols := format_header(options, longest)
	header_len := visible_length(header)
	term_cols, _ := term.get_terminal_size()

	print_header(header, options, header_len, cols)
	print_header_border(options, header_len, cols)

	dim := if options.no_dim { no_style } else { dim_style }
	time_style := Style{
		...options.style_so
		dim: !options.no_dim
	}

	for idx, entry in entries {
		c_entry := cache[idx]
		// emit blank row every 5th row
		if options.blocked_output {
			if idx % block_size == 0 && idx != 0 {
				match options.table_format {
					true { print(border_row_middle(header_len, cols)) }
					else { print_newline() }
				}
			}
		}

		// left table border
		if options.table_format {
			print(table_border_pad_left)
		}

		// index
		if options.index {
			print(format_cell(idx.str(), longest.index, .left, dim, options))
			print_space()
		}

		// mime type
		if options.mime_type {
			print(format_cell(c_entry.mime_type, longest.mime_type, .right, no_style, options))
			print_space()
		}

		// inode
		if options.inode {
			content := if entry.invalid { unknown } else { entry.stat.inode.str() }
			print(format_cell(content, longest.inode, .right, no_style, options))
			print_space()
		}

		// checksum
		if options.checksum != '' {
			checksum := format_cell(c_entry.checksum, longest.checksum, .left, dim, options)
			print(checksum)
			print_space()
		}

		// permissions
		if !options.no_permissions {
			flag := file_flag(entry, options)
			print(format_cell(flag, 1, .left, no_style, options))
			print_space()

			content := permissions(entry, options)
			print(format_cell(content, visible_length(permissions_title), .right, no_style,
				options))
			print_space()
		}

		// octal permissions
		if options.octal_permissions {
			content := format_octal_permissions(entry, options)
			print(format_cell(content, 4, .left, dim, options))
			print_space()
		}

		// hard links
		if !options.no_hard_links {
			content := if entry.invalid { unknown } else { '${entry.stat.nlink}' }
			print(format_cell(content, longest.nlink, .right, dim, options))
			print_space()
		}

		// owner name
		if !options.no_owner_name {
			content := if entry.invalid { unknown } else { c_entry.owner }
			print(format_cell(content, longest.owner_name, .right, dim, options))
			print_space()
		}

		// group name
		if !options.no_group_name {
			content := if entry.invalid { unknown } else { c_entry.group }
			print(format_cell(content, longest.group_name, .right, dim, options))
			print_space()
		}

		// size
		if !options.no_size {
			content := match true {
				entry.invalid { unknown }
				entry.dir || entry.socket || entry.fifo { '-' }
				options.size_ki && !options.size_kb { readable_size(entry.size, true) }
				options.size_kb { readable_size(entry.size, false) }
				options.size_comma { num_with_commas(entry.size) }
				else { entry.size.str() }
			}
			size_style := match entry.link_stat.size > 0 {
				true { get_style_for_link(entry, options) }
				else { get_style_for(entry, options) }
			}
			size := format_cell(content, longest.size, .right, size_style, options)
			print(size)
			print_space()
		}

		// date/time(modified)
		if !options.no_date {
			ftime := c_entry.fmt_mtime // format_time(&entry, .modified, options)
			fcell := format_cell(ftime, longest.mtime, .right, time_style, options)
			print(fcell)
			print_space()
		}

		// date/time (accessed)
		if options.accessed_date {
			ftime := c_entry.fmt_atime // format_time(&entry, .modified, options)
			fcell := format_cell(ftime, longest.atime, .right, time_style, options)
			print(fcell)
			print_space()
		}

		// date/time (status change)
		if options.changed_date {
			ftime := c_entry.fmt_ctime // format_time(&entry, .modified, options)
			fcell := format_cell(ftime, longest.ctime, .right, time_style, options)
			print(fcell)
			print_space()
		}

		// file name
		file_name := format_entry_name(entry, options)
		file_style := get_style_for(entry, options)
		match options.table_format {
			true { print(format_cell(file_name, longest.file, .left, file_style, options)) }
			else { print(format_cell(file_name, 0, .left, file_style, options)) }
		}

		// line too long? Print a '≈' in the last column
		if options.no_wrap {
			mut coord := term.get_cursor_position() or { term.Coord{} }
			if coord.x >= term_cols {
				coord.x = term_cols
				term.set_cursor_position(coord)
				print('≈')
			}
		}

		match true {
			options.null_terminate { print('\0') }
			else { print_newline() }
		}
	}

	// bottom border
	print_bottom_border(options, header_len, cols)

	// stats
	if !options.no_count {
		statistics(entries, header_len, options)
	}
}

fn longest_entries(mut entries []&Entry, options Options) (Longest, []DisplayCache) {
	mut max_atime := 0
	mut max_checksum := 0
	mut max_ctime := 0
	mut max_file := 0
	mut max_group_name := 0
	mut max_index := 0
	mut max_inode := 0
	mut max_mime_type := 0
	mut max_mtime := 0
	mut max_nlink := 0
	mut max_owner_name := 0
	mut max_size := 0
	mut cache := []DisplayCache{cap: entries.len}

	for mut entry in entries {
		mut d_cache := DisplayCache{}

		// Calculate time formatting once and cache it in the entry
		if !options.no_date {
			d_cache.fmt_mtime = format_time(entry, .modified, options)
			max_mtime = int_max(max_mtime, d_cache.fmt_mtime.len)
		}
		if options.accessed_date {
			d_cache.fmt_atime = format_time(entry, .accessed, options)
			max_atime = int_max(max_atime, d_cache.fmt_atime.len)
		}
		if options.changed_date {
			d_cache.fmt_ctime = format_time(entry, .changed, options)
			max_ctime = int_max(max_ctime, d_cache.fmt_ctime.len)
		}

		// Calculate other lengths
		if options.checksum.len > 0 {
			if entry.file {
				d_cache.checksum = checksum(entry.name, entry.dir_name, options)
			}
			max_checksum = int_max(max_checksum, d_cache.checksum.len)
		}

		max_file = int_max(max_file, visible_length(format_entry_name(entry, options)))

		if !options.no_group_name {
			if options.numeric_ids {
				d_cache.group = entry.stat.gid.str()
			} else {
				d_cache.group = get_group_name(entry.stat.gid)
			}
			max_group_name = int_max(max_group_name, visible_length(d_cache.group))
		}

		if options.index {
			// index is dynamic based on array position, max width is len of total count
			max_index = int_max(max_index, entries.len.str().len)
		}

		if options.inode {
			max_inode = int_max(max_inode, entry.stat.inode.str().len)
		}

		if options.mime_type {
			d_cache.mime_type = get_mime_type(entry.name, entry.link_origin, entry.exe)
			max_mime_type = int_max(max_mime_type, d_cache.mime_type.len)
		}

		if !options.no_hard_links {
			max_nlink = int_max(max_nlink, entry.stat.nlink.str().len)
		}

		if !options.no_owner_name {
			if options.numeric_ids {
				d_cache.owner = entry.stat.uid.str()
			} else {
				d_cache.owner = get_owner_name(entry.stat.uid)
			}
			max_owner_name = int_max(max_owner_name, visible_length(d_cache.owner))
		}

		if !options.no_size {
			size_len := match true {
				entry.dir { 1 } // '-'
				options.size_ki && !options.size_kb { readable_size(entry.size, true).len }
				options.size_kb { readable_size(entry.size, false).len }
				options.size_comma { num_with_commas(entry.size).len }
				else { entry.size.str().len }
			}
			max_size = int_max(max_size, size_len)
		}
		cache << d_cache
	}

	// Adjust for headers if necessary
	if options.header {
		max_atime = int_max(max_atime, visible_length(date_accessed_title))
		max_checksum = int_max(max_checksum, visible_length(options.checksum.capitalize()))
		max_ctime = int_max(max_ctime, visible_length(date_status_title))
		max_file = int_max(max_file, visible_length(name_title))
		max_group_name = int_max(max_group_name, visible_length(group_title))
		max_index = int_max(max_index, visible_length(index_title))
		max_inode = int_max(max_inode, visible_length(inode_title))
		max_mime_type = int_max(max_mime_type, visible_length(mime_type_title))
		max_mtime = int_max(max_mtime, visible_length(date_modified_title))
		max_nlink = int_max(max_nlink, visible_length(links_title))
		max_owner_name = int_max(max_owner_name, visible_length(owner_title))
		max_size = int_max(max_size, visible_length(size_title))
	}

	longest := Longest{
		atime:      max_atime
		checksum:   max_checksum
		ctime:      max_ctime
		file:       max_file
		group_name: max_group_name
		index:      max_index
		inode:      max_inode
		mime_type:  max_mime_type
		mtime:      max_mtime
		nlink:      max_nlink
		owner_name: max_owner_name
		size:       max_size
	}
	return longest, cache
}

fn print_header(header string, options Options, len int, cols []int) {
	if options.header {
		if options.table_format {
			print(border_row_top(len, cols))
		}
		println(header)
	}
}

fn format_header(options Options, longest Longest) (string, []int) {
	mut buffer := ''
	mut cols := []int{}
	dim := if options.no_dim || options.table_format { no_style } else { dim_style }
	table_pad := if options.table_format { table_border_pad_left } else { '' }

	if options.table_format {
		buffer += table_border_pad_left
	}
	if options.index {
		title := if options.header { index_title } else { '' }
		buffer += right_pad(title, longest.index) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.mime_type {
		title := if options.header { mime_type_title } else { '' }
		buffer += right_pad(title, longest.mime_type) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.inode {
		title := if options.header { inode_title } else { '' }
		buffer += left_pad(title, longest.inode) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.checksum != '' {
		title := if options.header { options.checksum.capitalize() } else { '' }
		width := longest.checksum
		buffer += right_pad(title, width) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_permissions {
		buffer += 'T ${table_pad}'
		cols << visible_length(buffer) - 1
		buffer += left_pad(permissions_title, visible_length(permissions_title)) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.octal_permissions {
		buffer += left_pad(mask_title, visible_length(mask_title)) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_hard_links {
		title := if options.header { links_title } else { '' }
		buffer += left_pad(title, longest.nlink) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_owner_name {
		title := if options.header { owner_title } else { '' }
		buffer += left_pad(title, longest.owner_name) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_group_name {
		title := if options.header { group_title } else { '' }
		buffer += left_pad(title, longest.group_name) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_size {
		title := if options.header { size_title } else { '' }
		buffer += left_pad(title, longest.size) + table_pad
		cols << visible_length(buffer) - 1
	}
	if !options.no_date {
		title := if options.header { date_modified_title } else { '' }
		buffer += right_pad(title, longest.mtime) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.accessed_date {
		title := if options.header { date_accessed_title } else { '' }
		buffer += right_pad(title, longest.atime) + table_pad
		cols << visible_length(buffer) - 1
	}
	if options.changed_date {
		title := if options.header { date_status_title } else { '' }
		buffer += right_pad(title, longest.ctime) + table_pad
		cols << visible_length(buffer) - 1
	}

	buffer += right_pad_end(if options.header { name_title } else { '' }, longest.file) // drop last space
	header := format_cell(buffer, 0, .left, dim, options)
	return header, cols
}

fn time_format(options Options) string {
	return match true {
		options.time_iso { date_iso_format }
		options.time_compact { date_compact_format }
		options.time_compact_with_day { date_compact_format_with_day }
		else { date_format }
	}
}

fn left_pad(s string, width int) string {
	pad := width - visible_length(s)
	return if pad > 0 { space.repeat(pad) + s + space } else { s + space }
}

fn right_pad(s string, width int) string {
	pad := width - visible_length(s)
	return if pad > 0 { s + space.repeat(pad) + space } else { s + space }
}

fn right_pad_end(s string, width int) string {
	pad := width - visible_length(s)
	return if pad > 0 { s + space.repeat(pad) } else { s }
}

fn statistics(entries []&Entry, len int, options Options) {
	file_count := entries.filter(it.file).len
	total := arrays.sum(entries.map(if it.file || it.exe { it.stat.size } else { 0 })) or { 0 }
	dir_count := entries.filter(it.dir).len
	link_count := entries.filter(it.link).len
	mut stats := ''

	dim := if options.no_dim { no_style } else { dim_style }
	file_count_styled := style_string(file_count.str(), options.style_fi, options)

	file := if file_count == 1 { 'file' } else { 'files' }
	files := style_string(file, dim, options)
	dir_count_styled := style_string(dir_count.str(), options.style_di, options)

	dir := if dir_count == 1 { 'directory' } else { 'directories' }
	dirs := style_string(dir, dim, options)

	size := match true {
		options.size_comma { num_with_commas(total) }
		options.size_ki { readable_size(total, true) }
		options.size_kb { readable_size(total, false) }
		else { total.str() }
	}

	totals := style_string(size, options.style_fi, options)
	totals_units := if !options.size_ki && !options.size_kb {
		style_string('bytes', dim, options)
	} else {
		''
	}
	stats = '${dir_count_styled} ${dirs} | ${file_count_styled} ${files} | ${totals} ${totals_units}'

	if link_count > 0 {
		link_count_styled := style_string(link_count.str(), options.style_ln, options)
		label := if link_count == 1 { 'link' } else { 'links' }
		links := style_string(label, dim, options)
		stats += ' | ${link_count_styled} ${links}'
	}
	println(stats)
}

fn file_flag(entry &Entry, options Options) string {
	return match true {
		entry.invalid { unknown }
		entry.link { style_string('l', options.style_ln, options) }
		entry.dir { style_string('d', options.style_di, options) }
		entry.exe { style_string('x', options.style_ex, options) }
		entry.fifo { style_string('p', options.style_pi, options) }
		entry.block { style_string('b', options.style_bd, options) }
		entry.character { style_string('c', options.style_cd, options) }
		entry.socket { style_string('s', options.style_so, options) }
		entry.file { style_string('f', options.style_fi, options) }
		else { ' ' }
	}
}

fn format_octal_permissions(entry &Entry, options Options) string {
	mode := entry.stat.get_mode()
	return '0${mode.owner.bitmask()}${mode.group.bitmask()}${mode.others.bitmask()}'
}

fn permissions(entry &Entry, options Options) string {
	mode := entry.stat.get_mode()
	owner := file_permission(mode.owner, options)
	group := file_permission(mode.group, options)
	other := file_permission(mode.others, options)
	return '${owner} ${group} ${other}'
}

fn file_permission(file_permission os.FilePermission, options Options) string {
	dim := if options.no_dim { no_style } else { dim_style }
	dash := style_string('-', dim, options)
	r := if file_permission.read { style_string('r', options.style_ln, options) } else { dash }
	w := if file_permission.write { style_string('w', options.style_fi, options) } else { dash }
	x := if file_permission.execute { style_string('x', options.style_ex, options) } else { dash }
	return '${r}${w}${x}'
}

fn format_time(entry &Entry, stat_time StatTime, options Options) string {
	entry_time := match stat_time {
		.accessed { entry.stat.atime }
		.changed { entry.stat.ctime }
		.modified { entry.stat.mtime }
	}

	local := time.unix(entry_time).local()
	date := if options.time_relative {
		local.relative_short()
	} else {
		dt := local.custom_format(time_format(options))
		if dt.starts_with('0') {
			' ' + dt[1..]
		} else {
			dt
		}
	}

	content := if entry.invalid { '?' + space.repeat(visible_length(date) - 1) } else { date }
	return content
}
fn checksum(name string, dir_name string, options Options) string {
	if options.checksum == '' {
		return ''
	}
	file_path := os.join_path(dir_name, name)
	mut f := os.open(file_path) or { return unknown }
	defer { f.close() }

	mut buf := []u8{len: 64 * 1024}

	match options.checksum {
		'md5' {
			mut digest := md5.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha1' {
			mut digest := sha1.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha224' {
			f.close()
			bytes := os.read_bytes(file_path) or { return unknown }
			return sha256.sum224(bytes).hex()
		}
		'sha256' {
			mut digest := sha256.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'sha512' {
			mut digest := sha512.new()
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.sum([]).hex()
		}
		'blake2b' {
			// Blake2b in V might operate differently as seen in test failure (no sum()).
			// It has `checksum()`.
			mut digest := blake2b.new256() or { return unknown }
			for {
				n := f.read(mut buf) or { break }
				if n == 0 {
					break
				}
				digest.write(buf[..n]) or { return unknown }
			}
			return digest.checksum().hex()
		}
		else {
			return unknown
		}
	}
}

const text_plain_names = [
	'CARGO.LOCK',
	'CMAKE',
	'CNAME',
	'DOCKERFILE',
	'GEMFILE',
	'GEMFILE.LOCK',
	'GNUMAKEFILE',
	'LICENSE',
	'MAKEFILE',
	'TEXT',
	'V.MOD',
]

fn get_mime_type(file string, link_origin string, is_exe bool) string {
	if link_origin.len > 0 {
		return mime.get_mime_type(os.file_ext(link_origin).trim_left('.'))
	}
	ext := os.file_ext(file).trim_left('.')
	mt := mime.get_mime_type(ext)
	if mt.len > 0 {
		return mt
	}
	if is_exe {
		return 'application/octet-stream'
	}
	if file.to_upper() in text_plain_names || ext.to_upper() in text_plain_names {
		return 'text/plain'
	}
	return ''
}
