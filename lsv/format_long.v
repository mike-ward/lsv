import arrays
import os
import strings
import term
import time
import v.mathutil { max }

const inode_title = 'inode'
const permissions_title = 'Permissions'
const mask_title = 'Mask'
const links_title = 'Links'
const owner_title = 'Owner'
const group_title = 'Group'
const size_title = 'Size'
const date_modified_title = 'Date (modified)'
const date_accessed_title = 'Date (accessed)'
const date_status_title = 'Date (status change)'
const name_title = 'Name'
const unknown = '?'
const block_size = 5
const space = ' '
const date_format = 'MMM DD YYYY HH:MM:ss'
const date_iso_format = 'YYYY-MM-DD HH:MM:ss'

fn format_long_listing(entries []Entry, args Args) {
	longest_inode := longest_inode_len(entries, inode_title, args)
	longest_nlink := longest_nlink_len(entries, links_title, args)
	longest_owner_name := longest_owner_name_len(entries, owner_title, args)
	longest_group_name := longest_group_name_len(entries, group_title, args)
	longest_size := longest_size_len(entries, size_title, args)
	longest_file := longest_file_name_len(entries, name_title, args)
	dim := if args.no_dim { no_style } else { dim_style }

	if args.header {
		print_header(args, longest_inode, longest_nlink, longest_owner_name, longest_group_name,
			longest_size, longest_file)
	}

	mut line := strings.new_builder(300)

	for idx, entry in entries {
		// spacer row
		if args.blocked_output {
			if idx % block_size == 0 && idx != 0 {
				line.write_string('\n')
			}
		}

		// inode
		if args.inode {
			content := if entry.invalid { unknown } else { entry.stat.inode.str() }
			line.write_string(format_cell(content, longest_inode, Align.right, no_style, args) +
				space)
		}

		// permissions
		if !args.no_permissions {
			flag := file_flag(entry, args)
			line.write_string(format_cell(flag, 1, .left, no_style, args) + space)

			content := permissions(entry, args)
			line.write_string(format_cell(content, permissions_title.len, .right, no_style, args) +
				space)
		}

		// octal permissions
		if args.octal_permissions {
			content := print_octal_permissions(entry, args)
			line.write_string(format_cell(content, 4, .left, dim, args) + space)
		}

		// hard links
		if !args.no_hard_links {
			content := if entry.invalid { unknown } else { '${entry.stat.nlink}' }
			line.write_string(format_cell(content, longest_nlink, .right, dim, args) + space)
		}

		// owner name
		if !args.no_owner_name {
			content := if entry.invalid { unknown } else { get_owner_name(entry.stat.uid) }
			line.write_string(format_cell(content, longest_owner_name, .right, dim, args) + space)
		}

		// group name
		if !args.no_group_name {
			content := if entry.invalid { unknown } else { get_group_name(entry.stat.gid) }
			line.write_string(format_cell(content, longest_group_name, .right, dim, args) + space)
		}

		// size
		if !args.no_size {
			content := match true {
				entry.invalid { unknown }
				entry.dir || entry.link || entry.socket || entry.fifo { '-' }
				args.size_ki && args.size_ki && !args.size_kb { entry.size_ki }
				args.size_kb && args.size_kb { entry.size_kb }
				else { entry.stat.size.str() }
			}
			line.write_string(
				format_cell(content, longest_size, .right, get_style_for(entry, args), args) + space)
		}

		// date/time(modified)
		if !args.no_date {
			line.write_string(format_time(entry, .modified, args))
			line.write_string(space)
		}

		// date/time (accessed)
		if args.accessed_date {
			line.write_string(format_time(entry, .accessed, args))
			line.write_string(space)
		}

		// date/time (status change)
		if args.changed_date {
			line.write_string(format_time(entry, .changed, args))
			line.write_string(space)
		}

		line.write_string(space)

		// file name
		line.write_string(format_cell(format_entry_name(entry, args), longest_file, .left,
			get_style_for(entry, args), args))

		println(line)
	}

	if !args.no_count {
		statistics(entries, args)
	}
}

fn print_header(args Args, longest_inode int, longest_nlink int, longest_owner_name int, longest_group_name int, longest_size int, longest_file int) {
	if !args.header {
		return
	}

	mut buffer := ''
	dim := if args.no_dim { no_style } else { dim_style }

	if args.inode {
		buffer += left_pad(inode_title, longest_inode)
	}
	if !args.no_permissions {
		buffer += left_pad('T ${permissions_title}', 0)
	}
	if args.octal_permissions {
		buffer += left_pad(mask_title, mask_title.len)
	}
	if !args.no_hard_links {
		buffer += left_pad(links_title, longest_nlink)
	}
	if !args.no_owner_name {
		buffer += left_pad(owner_title, longest_owner_name)
	}
	if !args.no_group_name {
		buffer += left_pad(group_title, longest_group_name)
	}
	if !args.no_size {
		buffer += left_pad(size_title, longest_size)
	}
	if !args.no_date {
		width := if args.time_iso { date_iso_format.len } else { date_format.len }
		buffer += right_pad(date_modified_title, width)
	}
	if args.accessed_date {
		width := if args.time_iso { date_iso_format.len } else { date_format.len }
		buffer += right_pad(date_accessed_title, width)
	}
	if args.changed_date {
		width := if args.time_iso { date_iso_format.len } else { date_format.len }
		buffer += right_pad(date_status_title, width)
	}

	buffer += space + name_title
	println(format_cell(buffer, 0, .left, dim, args))

	div_len := term.strip_ansi(buffer).len + longest_file - name_title.len
	divider := '┈'.repeat(div_len)
	println(format_cell(divider, 0, .left, dim, args))
}

fn left_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { space.repeat(pad) + s + space } else { s + space }
}

fn right_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { s + space.repeat(pad) + space } else { s + space }
}

fn statistics(entries []Entry, args Args) {
	file_count := entries.filter(it.file).len
	dir_count := entries.filter(it.dir).len
	link_count := entries.filter(it.link).len
	mut stats := ''

	dim := if args.no_dim { no_style } else { dim_style }
	file_count_styled := style_string(file_count.str(), args.style_fi, args)

	files := style_string('files', dim, args)
	dir_count_styled := style_string(dir_count.str(), args.style_di, args)

	dirs := style_string('dirs', dim, args)
	stats = '${file_count_styled} ${files} ${dir_count_styled} ${dirs}'

	if link_count > 0 {
		link_count_styled := style_string(link_count.str(), args.style_ln, args)
		links := style_string('links', dim, args)
		stats += ' ${link_count_styled} ${links}'
	}

	println(stats)
}

fn format_entry_name(entry Entry, args Args) string {
	name := if args.relative_path {
		os.join_path(entry.dir_name, entry.name)
	} else {
		entry.name
	}

	return match true {
		entry.link { '${name} -> ${entry.link_origin}' }
		args.quote { '"${name}"' }
		else { name }
	}
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

fn print_octal_permissions(entry Entry, args Args) string {
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

enum StatTime {
	accessed
	changed
	modified
}

fn format_time(entry Entry, stat_time StatTime, args Args) string {
	unix_time := match stat_time {
		.accessed {entry.stat.atime} 
		.changed { entry.stat.ctime}
		.modified {entry.stat.mtime}
	}

	date := time.unix(unix_time)
		.local()
		.custom_format(if args.time_iso { date_iso_format } else { date_format })

	dim := if args.no_dim { no_style } else { dim_style }
	content := if entry.invalid { '?'.repeat(date.len) } else { date }
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
		else { it.stat.size.str().len }
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
	lengths := entries.map(it.name.len + it.link_origin.len +
		if it.link_origin.len > 0 { 4 } else { 0 })
	max := arrays.max(lengths) or { 0 }
	return if !args.header { max } else { max(max, title.len) }
}
