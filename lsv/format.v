import arrays
import os
import strings
import term

const cell_max = 12 // limit on wide displays
const cell_spacing = 3 // space between cells

enum Align {
	left
	right
}

struct FormattedEntry {
	entry          &Entry
	formatted_name string
	visible_len    int
	style          Style
}

fn print_files(mut entries_arg []Entry, options Options) {
	mut entries := match true {
		options.all && !options.almost_all {
			dot := make_entry('.', '.', options)
			dot_dot := make_entry('..', '.', options)
			arrays.append([dot, dot_dot], entries_arg)
		}
		else {
			*entries_arg
		}
	}

	w, _ := term.get_terminal_size()
	options_width_ok := options.width_in_cols > 0 && options.width_in_cols < 1000
	width := if options_width_ok { options.width_in_cols } else { w }

	// Phase 4 Optimization: Pre-calculate formatted strings for short views
	// This avoids double formatting (once for width calc, once for print)
	// Only apply for short views that need it. Long view handles its own logic.
	if options.long_format {
		format_long_listing(mut entries, options)
		return
	}

	// Prepare formatted entries for short views
	formatted_entries := prepare_formatted_entries(entries, options)

	match true {
		options.list_by_lines { format_by_lines(formatted_entries, width, options) }
		options.with_commas { format_with_commas(formatted_entries, options) }
		options.one_per_line { format_one_per_line(formatted_entries, options) }
		else { format_by_cells(formatted_entries, width, options) }
	}
}

fn prepare_formatted_entries(entries []Entry, options Options) []FormattedEntry {
	mut formatted := []FormattedEntry{cap: entries.len}
	for i in 0 .. entries.len {
		entry := &entries[i]
		name := format_entry_name(entry, options)
		formatted << FormattedEntry{
			entry:          entry
			formatted_name: name
			visible_len:    utf8_str_visible_length(name)
			style:          get_style_for(entry, options)
		}
	}
	return formatted
}

fn format_by_cells(entries []FormattedEntry, width int, options Options) {
	if entries.len == 0 {
		return
	}

	// Calc max len from cached values
	mut max_len := 0
	for e in entries {
		if e.visible_len > max_len {
			max_len = e.visible_len
		}
	}
	cell_len := max_len + cell_spacing

	cols := int_min(width / cell_len, cell_max)
	max_cols := int_max(cols, 1)
	partial_row := entries.len % max_cols != 0
	rows := entries.len / max_cols + if partial_row { 1 } else { 0 }
	max_rows := int_max(1, rows)

	mut sb := strings.new_builder(1024 * 16)

	for r := 0; r < max_rows; r += 1 {
		for c := 0; c < max_cols; c += 1 {
			idx := r + c * max_rows
			if idx < entries.len {
				entry := entries[idx]
				write_cell(mut sb, entry.formatted_name, entry.visible_len, cell_len,
					.left, entry.style, options)
			}
		}
		sb.write_u8(`\n`)
	}
	print(sb.str())
}

fn format_by_lines(entries []FormattedEntry, width int, options Options) {
	if entries.len == 0 {
		return
	}

	mut max_len := 0
	for e in entries {
		if e.visible_len > max_len {
			max_len = e.visible_len
		}
	}
	cell_len := max_len + cell_spacing

	cols := int_min(width / cell_len, cell_max)
	max_cols := int_max(cols, 1)

	mut sb := strings.new_builder(1024 * 16)

	for i, entry in entries {
		if i % max_cols == 0 && i != 0 {
			sb.write_u8(`\n`)
		}
		write_cell(mut sb, entry.formatted_name, entry.visible_len, cell_len, .left, entry.style,
			options)
	}
	sb.write_u8(`\n`)
	print(sb.str())
}

fn format_one_per_line(entries []FormattedEntry, options Options) {
	mut sb := strings.new_builder(1024 * 16)
	for entry in entries {
		write_cell(mut sb, entry.formatted_name, entry.visible_len, 0, .left, entry.style,
			options)
		sb.write_u8(`\n`)
	}
	print(sb.str())
}

fn format_with_commas(entries []FormattedEntry, options Options) {
	mut sb := strings.new_builder(1024 * 16)
	last := entries.len - 1
	for i, entry in entries {
		if i < last {
			// Reuse formatted name but append comma.
			// Tricky if we rely on write_cell for styling.
			// write_cell applies style to the string passed.
			// If we pass "name, ", style applies to comma too? Usually fine.
			// Or we write name styled, then comma unstyled.
			write_cell_content(mut sb, entry.formatted_name, entry.visible_len, 0, .left,
				entry.style, options)
			sb.write_string(', ')
		} else {
			write_cell_content(mut sb, entry.formatted_name, entry.visible_len, 0, .left,
				entry.style, options)
		}
	}
	sb.write_u8(`\n`)
	print(sb.str())
}

fn write_cell(mut sb strings.Builder, s string, s_len int, width int, align Align, style Style, options Options) {
	match options.table_format {
		true { write_table_cell(mut sb, s, s_len, width, align, style, options) }
		else { write_cell_content(mut sb, s, s_len, width, align, style, options) }
	}
}

fn write_cell_content(mut sb strings.Builder, s string, s_len int, width int, align Align, style Style, options Options) {
	pad := width - s_len

	if align == .right && pad > 0 {
		sb.write_string(space.repeat(pad))
	}

	match options.colorize {
		true { sb.write_string(style_string(s, style, options)) }
		else { sb.write_string(s) }
	}

	if align == .left && pad > 0 {
		sb.write_string(space.repeat(pad))
	}
}

fn write_table_cell(mut sb strings.Builder, s string, s_len int, width int, align Align, style Style, options Options) {
	write_cell_content(mut sb, s, s_len, width, align, style, options)
	sb.write_string(table_border_pad_right)
}

fn format_cell(s string, width int, align Align, style Style, options Options) string {
	// Legacy support for callers that need string (like format_long.v)
	// We can wrap the builder version.
	mut sb := strings.new_builder(128)
	write_cell(mut sb, s, visible_length(s), width, align, style, options)
	return sb.str()
}

fn print_dir_name(name string, options Options) {
	if name.len > 0 {
		print_newline()
		nm := if options.colorize { style_string(name, options.style_di, options) } else { name }
		println('${nm}:')
	}
}

// Deprecated: use FormattedEntry logic instead for batch operations
fn (entries []Entry) max_name_len(options Options) int {
	return 0 // Unused in new logic but kept for interface compact if needed
}

fn get_style_for(entry &Entry, options Options) Style {
	return match true {
		entry.link { options.style_ln }
		entry.dir { options.style_di }
		entry.exe { options.style_ex }
		entry.fifo { options.style_pi }
		entry.block { options.style_bd }
		entry.character { options.style_cd }
		entry.socket { options.style_so }
		entry.file { options.style_fi }
		else { no_style }
	}
}

fn get_style_for_link(entry Entry, options Options) Style {
	if entry.link_stat.size == 0 {
		return unknown_style
	}

	filetype := entry.link_stat.get_filetype()
	is_dir := filetype == os.FileType.directory
	is_fifo := filetype == .fifo
	is_block := filetype == .block_device
	is_socket := filetype == .socket
	is_character_device := filetype == .character_device
	is_unknown := filetype == .unknown
	is_exe := !is_dir && is_executable(entry.link_stat)
	is_file := !is_dir && !is_fifo && !is_block && !is_socket && !is_character_device && !is_unknown
		&& !is_exe

	return match true {
		is_dir { options.style_di }
		is_exe { options.style_ex }
		is_fifo { options.style_pi }
		is_block { options.style_bd }
		is_character_device { options.style_cd }
		is_socket { options.style_so }
		is_unknown { unknown_style }
		is_file { options.style_fi }
		else { no_style }
	}
}

fn format_entry_name(entry &Entry, options Options) string {
	name := match options.relative_path {
		true { os.join_path(entry.dir_name, entry.name) }
		else { entry.name }
	}

	icon := get_icon_for_entry(*entry, options)
	prefix := if icon != '' { '${icon} ' } else { '' }

	return match true {
		entry.link {
			link_style := get_style_for_link(*entry, options)
			missing := if link_style == unknown_style { ' (not found)' } else { '' }
			link := style_string(entry.link_origin, link_style, options)
			'${prefix}${name} -> ${link}${missing}'
		}
		options.quote {
			'${prefix}"${name}"'
		}
		else {
			'${prefix}${name}'
		}
	}
}

fn visible_length(s string) int {
	return utf8_str_visible_length(s)
}

@[inline]
fn print_space() {
	print_character(` `)
}

@[inline]
fn print_newline() {
	print_character(`\n`)
}
