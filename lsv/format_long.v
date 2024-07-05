import arrays
import os
import time
import v.mathutil { max }

const inode_title = 'inode'
const permissions_title = 'Permissions'
const mask_title = 'Mask'
const links_title = 'Links'
const owner_title = 'Owner'
const group_title = 'Group'
const size_title = 'Size'
const date_modified_title = 'Modified'
const date_accessed_title = 'Accessed'
const date_status_title = 'Status Change'
const name_title = 'Name'
const unknown = '?'
const block_size = 5
const space = ' '
const date_format = 'MMM DD YYYY HH:MM:ss'
const date_iso_format = 'YYYY-MM-DD HH:MM:ss'
const date_compact_format = "DD MMM'YY HH:MM"

struct Longest {
	inode      int
	nlink      int
	owner_name int
	group_name int
	size       int
	checksum   int
	file       int
}

enum StatTime {
	accessed
	changed
	modified
}

fn format_long_listing(entries []Entry, args Args) {
	longest := longest_entries(entries, args)
	header, cols := format_header(args, longest)
	header_len := real_length(header)

	print_header(header, args, header_len, cols)
	print_header_border(args, header_len, cols)

	dim := if args.no_dim { no_style } else { dim_style }

	for idx, entry in entries {
		// emit blank row every 5th row
		if args.blocked_output {
			if idx % block_size == 0 && idx != 0 {
				if args.table_format {
					print(border_row_middle(header_len, cols))
				} else {
					print('\n')
				}
			}
		}

		// left table border
		if args.table_format {
			print(table_border_pad_left)
		}

		// inode
		if args.inode {
			content := if entry.invalid { unknown } else { entry.stat.inode.str() }
			print(format_cell(content, longest.inode, Align.right, no_style, args))
			print(space)
		}

		// checksum
		if args.checksum != '' {
			checksum := format_cell(entry.checksum, longest.checksum, .left, dim, args)
			print(checksum)
			print(space)
		}

		// permissions
		if !args.no_permissions {
			flag := file_flag(entry, args)
			print(format_cell(flag, 1, .left, no_style, args))
			print(space)

			content := permissions(entry, args)
			print(format_cell(content, permissions_title.len, .right, no_style, args))
			print(space)
		}

		// octal permissions
		if args.octal_permissions {
			content := format_octal_permissions(entry, args)
			print(format_cell(content, 4, .left, dim, args))
			print(space)
		}

		// hard links
		if !args.no_hard_links {
			content := if entry.invalid { unknown } else { '${entry.stat.nlink}' }
			print(format_cell(content, longest.nlink, .right, dim, args))
			print(space)
		}

		// owner name
		if !args.no_owner_name {
			content := if entry.invalid { unknown } else { get_owner_name(entry.stat.uid) }
			print(format_cell(content, longest.owner_name, .right, dim, args))
			print(space)
		}

		// group name
		if !args.no_group_name {
			content := if entry.invalid { unknown } else { get_group_name(entry.stat.gid) }
			print(format_cell(content, longest.group_name, .right, dim, args))
			print(space)
		}

		// size
		if !args.no_size {
			content := match true {
				entry.invalid { unknown }
				entry.dir || entry.socket || entry.fifo { '-' }
				args.size_ki && args.size_ki && !args.size_kb { entry.size_ki }
				args.size_kb && args.size_kb { entry.size_kb }
				else { entry.size.str() }
			}
			size_style := match entry.link_stat.size > 0 {
				true { get_style_for_link(entry, args) }
				else { get_style_for(entry, args) }
			}
			size := format_cell(content, longest.size, .right, size_style, args)
			print(size)
			print(space)
		}

		// date/time(modified)
		if !args.no_date {
			print(format_time(entry, .modified, args))
			print(space)
		}

		// date/time (accessed)
		if args.accessed_date {
			print(format_time(entry, .accessed, args))
			print(space)
		}

		// date/time (status change)
		if args.changed_date {
			print(format_time(entry, .changed, args))
			print(space)
		}

		// file name
		file_name := format_entry_name(entry, args)
		file_style := get_style_for(entry, args)
		println(format_cell(file_name, longest.file, .left, file_style, args))
	}

	// bottom border
	print_bottom_border(args, header_len, cols)

	// stats
	if !args.no_count {
		statistics(entries, header_len, args)
	}
}

fn longest_entries(entries []Entry, args Args) Longest {
	return Longest{
		inode: longest_inode_len(entries, inode_title, args)
		nlink: longest_nlink_len(entries, links_title, args)
		owner_name: longest_owner_name_len(entries, owner_title, args)
		group_name: longest_group_name_len(entries, group_title, args)
		size: longest_size_len(entries, size_title, args)
		checksum: longest_checksum_len(entries, args.checksum, args)
		file: longest_file_name_len(entries, name_title, args)
	}
}

fn print_header(header string, args Args, len int, cols []int) {
	if args.header {
		if args.table_format {
			print(border_row_top(len, cols))
		}
		println(header)
	}
}

fn format_header(args Args, longest Longest) (string, []int) {
	mut buffer := ''
	mut cols := []int{}
	dim := if args.no_dim || args.table_format { no_style } else { dim_style }
	table_pad := if args.table_format { table_border_pad_left } else { '' }

	if args.table_format {
		buffer += table_border_pad_left
	}
	if args.inode {
		title := if args.header { inode_title } else { '' }
		buffer += left_pad(title, longest.inode) + table_pad
		cols << real_length(buffer) - 1
	}
	if args.checksum != '' {
		title := if args.header { args.checksum.capitalize() } else { '' }
		width := longest.checksum
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_permissions {
		buffer += 'T ${table_pad}'
		cols << real_length(buffer) - 1
		buffer += left_pad(permissions_title, permissions_title.len) + table_pad
		cols << real_length(buffer) - 1
	}
	if args.octal_permissions {
		buffer += left_pad(mask_title, mask_title.len) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_hard_links {
		title := if args.header { links_title } else { '' }
		buffer += left_pad(title, longest.nlink) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_owner_name {
		title := if args.header { owner_title } else { '' }
		buffer += left_pad(title, longest.owner_name) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_group_name {
		title := if args.header { group_title } else { '' }
		buffer += left_pad(title, longest.group_name) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_size {
		title := if args.header { size_title } else { '' }
		buffer += left_pad(title, longest.size) + table_pad
		cols << real_length(buffer) - 1
	}
	if !args.no_date {
		title := if args.header { date_modified_title } else { '' }
		width := time_format(args).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if args.accessed_date {
		title := if args.header { date_accessed_title } else { '' }
		width := time_format(args).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if args.changed_date {
		title := if args.header { date_status_title } else { '' }
		width := time_format(args).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}

	buffer += right_pad_end(if args.header { name_title } else { '' }, longest.file) // drop last space
	header := format_cell(buffer, 0, .left, dim, args)
	return header, cols
}

fn time_format(args Args) string {
	return if args.time_iso {
		date_iso_format
	} else if args.time_compact {
		date_compact_format
	} else {
		date_format
	}
}

fn left_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { space.repeat(pad) + s + space } else { s + space }
}

fn right_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { s + space.repeat(pad) + space } else { s + space }
}

fn right_pad_end(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { s + space.repeat(pad) } else { s }
}

fn statistics(entries []Entry, len int, args Args) {
	file_count := entries.filter(it.file).len
	total := arrays.sum(entries.map(if it.file || it.exe { it.stat.size } else { 0 })) or { 0 }
	dir_count := entries.filter(it.dir).len
	link_count := entries.filter(it.link).len
	mut stats := ''

	dim := if args.no_dim { no_style } else { dim_style }
	file_count_styled := style_string(file_count.str(), args.style_fi, args)

	file := if file_count == 1 { 'file' } else { 'files' }
	files := style_string(file, dim, args)
	dir_count_styled := style_string(dir_count.str(), args.style_di, args)

	dir := if dir_count == 1 { 'directory' } else { 'directories' }
	dirs := style_string(dir, dim, args)

	size := match true {
		args.size_ki { readable_size(total, true) }
		args.size_kb { readable_size(total, false) }
		else { total.str() }
	}

	totals := style_string(size, args.style_fi, args)
	stats = '${dir_count_styled} ${dirs} | ${file_count_styled} ${files} [${totals}]'

	if link_count > 0 {
		link_count_styled := style_string(link_count.str(), args.style_ln, args)
		links := style_string('links', dim, args)
		stats += ' | ${link_count_styled} ${links}'
	}
	println(stats)
}

fn file_flag(entry Entry, args Args) string {
	return match true {
		entry.invalid { unknown }
		entry.link { style_string('l', args.style_ln, args) }
		entry.dir { style_string('d', args.style_di, args) }
		entry.exe { style_string('x', args.style_ex, args) }
		entry.fifo { style_string('p', args.style_pi, args) }
		entry.block { style_string('b', args.style_bd, args) }
		entry.character { style_string('c', args.style_cd, args) }
		entry.socket { style_string('s', args.style_so, args) }
		entry.file { style_string('f', args.style_fi, args) }
		else { ' ' }
	}
}

fn format_octal_permissions(entry Entry, args Args) string {
	mode := entry.stat.get_mode()
	return '0${mode.owner.bitmask()}${mode.group.bitmask()}${mode.others.bitmask()}'
}

fn permissions(entry Entry, args Args) string {
	mode := entry.stat.get_mode()
	owner := file_permission(mode.owner, args)
	group := file_permission(mode.group, args)
	other := file_permission(mode.others, args)
	return '${owner} ${group} ${other}'
}

fn file_permission(file_permission os.FilePermission, args Args) string {
	dim := if args.no_dim { no_style } else { dim_style }
	dash := style_string('-', dim, args)
	r := if file_permission.read { style_string('r', args.style_ln, args) } else { dash }
	w := if file_permission.write { style_string('w', args.style_fi, args) } else { dash }
	x := if file_permission.execute { style_string('x', args.style_ex, args) } else { dash }
	return '${r}${w}${x}'
}

fn format_time(entry Entry, stat_time StatTime, args Args) string {
	entry_time := match stat_time {
		.accessed { entry.stat.atime }
		.changed { entry.stat.ctime }
		.modified { entry.stat.mtime }
	}

	date := time.unix(entry_time)
		.local()
		.custom_format(time_format(args))

	dim := if args.no_dim { no_style } else { dim_style }
	content := if entry.invalid { '?' + space.repeat(date.len - 1) } else { date }
	return format_cell(content, date.len, .left, dim, args)
}

fn longest_nlink_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(it.stat.nlink.str().len)
	max := arrays.max(lengths) or { 0 }
	return if args.no_hard_links || !args.header { max } else { max(max, title.len) }
}

fn longest_owner_name_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(get_owner_name(it.stat.uid).len)
	max := arrays.max(lengths) or { 0 }
	return if args.no_owner_name || !args.header { max } else { max(max, title.len) }
}

fn longest_group_name_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(get_group_name(it.stat.gid).len)
	max := arrays.max(lengths) or { 0 }
	return if args.no_group_name || !args.header { max } else { max(max, title.len) }
}

fn longest_size_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(match true {
		it.dir { 1 }
		args.size_ki && !args.size_kb { it.size_ki.len }
		args.size_kb { it.size_kb.len }
		else { it.size.str().len }
	})
	max := arrays.max(lengths) or { 0 }
	return if args.no_size || !args.header { max } else { max(max, title.len) }
}

fn longest_inode_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(it.stat.inode.str().len)
	max := arrays.max(lengths) or { 0 }
	return if !args.inode || !args.header { max } else { max(max, title.len) }
}

fn longest_file_name_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(real_length(format_entry_name(it, args)))
	max := arrays.max(lengths) or { 0 }
	return if !args.header { max } else { max(max, title.len) }
}

fn longest_checksum_len(entries []Entry, title string, args Args) int {
	lengths := entries.map(it.checksum.len)
	max := arrays.max(lengths) or { 0 }
	return if !args.header { max } else { max(max, title.len) }
}
