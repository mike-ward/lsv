import arrays
import strings
import term
import v.mathutil
import os

const cell_max = 12 // limit on wide displays
const cell_spacing = 3 // space between cells

enum Align {
	left
	right
}

fn format(entries []Entry, args Args) {
	w, _ := term.get_terminal_size()
	args_width_ok := args.width_in_cols > 0 && args.width_in_cols < 1000
	width := if args_width_ok { args.width_in_cols } else { w }

	match true {
		args.long_format { format_long_listing(entries, args) }
		args.list_by_lines { format_by_lines(entries, width, args) }
		args.with_commas { format_with_commas(entries, args) }
		args.one_per_line { format_one_per_line(entries, args) }
		else { format_by_cells(entries, width, args) }
	}
}

fn format_by_cells(entries []Entry, width int, args Args) {
	len := entries.max_name_len(args) + cell_spacing
	cols := mathutil.min(width / len, cell_max)
	max_cols := mathutil.max(cols, 1)
	partial_row := entries.len % max_cols != 0
	rows := entries.len / max_cols + if partial_row { 1 } else { 0 }
	max_rows := mathutil.max(1, rows)
	mut line := strings.new_builder(200)

	for r := 0; r < max_rows; r += 1 {
		for c := 0; c < max_cols; c += 1 {
			idx := r + c * max_rows
			if idx < entries.len {
				entry := entries[idx]
				name := format_entry_name(entry, args)
				cell := format_cell(name, len, .left, get_style_for(entry, args), args)
				line.write_string(cell)
			}
		}
		println(line)
	}
}

fn format_by_lines(entries []Entry, width int, args Args) {
	len := entries.max_name_len(args) + cell_spacing
	cols := mathutil.min(width / len, cell_max)
	max_cols := mathutil.max(cols, 1)
	mut line := strings.new_builder(200)

	for i, entry in entries {
		if i % max_cols == 0 && i != 0 {
			println(line)
		}
		name := format_entry_name(entry, args)
		cell := format_cell(name, len, .left, get_style_for(entry, args), args)
		line.write_string(cell)
	}
	if entries.len % max_cols != 0 {
		println(line)
	}
}

fn format_one_per_line(entries []Entry, args Args) {
	for entry in entries {
		println(format_cell(entry.name, 0, .left, get_style_for(entry, args), args))
	}
}

fn format_with_commas(entries []Entry, args Args) {
	mut line := strings.new_builder(200)
	last := entries.len - 1
	for i, entry in entries {
		content := if i < last { '${entry.name}, ' } else { entry.name }
		line.write_string(format_cell(content, 0, .left, no_style, args))
	}
	println(line)
}

fn format_cell(s string, width int, align Align, style Style, args Args) string {
	return match args.table_format {
		true { format_table_cell(s, width, align, style, args) }
		else { format_cell_content(s, width, align, style, args) }
	}
}

fn format_cell_content(s string, width int, align Align, style Style, args Args) string {
	mut cell := ''
	no_ansi_s := term.strip_ansi(s)
	pad := width - no_ansi_s.runes().len

	if align == .right && pad > 0 {
		cell += space.repeat(pad)
	}

	cell += if args.colorize {
		style_string(s, style, args)
	} else {
		no_ansi_s
	}

	if align == .left && pad > 0 {
		cell += space.repeat(pad)
	}

	return cell
}

fn format_table_cell(s string, width int, align Align, style Style, args Args) string {
	cell := format_cell_content(s, width, align, style, args)
	return '${cell}${table_border_pad_right}'
}

// surrounds a cell with table borders
fn print_dir_name(name string, args Args) {
	if name.len > 0 {
		print('\n')
		nm := if args.colorize { style_string(name, args.style_di, args) } else { name }
		println('${nm}:')
	}
}

fn (entries []Entry) max_name_len(args Args) int {
	lengths := entries.map(format_entry_name(it, args).len)
	return arrays.max(lengths) or { 0 }
}

fn get_style_for(entry Entry, args Args) Style {
	return match true {
		entry.link { args.style_ln }
		entry.dir { args.style_di }
		entry.exe { args.style_ex }
		entry.fifo { args.style_pi }
		entry.block { args.style_bd }
		entry.character { args.style_cd }
		entry.socket { args.style_so }
		entry.file { args.style_fi }
		else { no_style }
	}
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
