module main

import flag
import term

const app_name = 'lsv'
const current_dir = ['.']

struct Args {
	// display options
	long_format              bool
	list_by_lines            bool
	one_per_line             bool
	dir_indicator            bool
	with_commas              bool
	colorize                 bool
	width_in_cols            int
	blocked_output           bool
	no_dim                   bool
	relative_path            bool
	quote                    bool
	can_show_color_on_stdout bool
	//
	// filter, group and sorting options
	all             bool
	dirs_first      bool
	only_dirs       bool
	only_files      bool
	sort_none       bool
	sort_size       bool
	sort_time       bool
	sort_natural    bool
	sort_ext        bool
	sort_width      bool
	sort_reverse    bool
	recursive       bool
	recursion_depth int
	//
	// long view options
	accessed_date     bool
	changed_date      bool
	header            bool
	inode             bool
	time_iso          bool
	size_ki           bool
	size_kb           bool
	no_permissions    bool
	no_hard_links     bool
	no_owner_name     bool
	no_group_name     bool
	no_size           bool
	no_date           bool
	no_count          bool
	link_origin       bool
	octal_permissions bool
	//
	// from ls colors
	style_di Style
	style_fi Style
	style_ln Style
	style_ex Style
	style_pi Style
	style_bd Style
	style_cd Style
	style_so Style
	//
	// file arguments
	files []string
}

fn parse_args(args []string) Args {
	mut fp := flag.new_flag_parser(args)

	fp.application(app_name)
	fp.version('2024.1.beta')
	fp.skip_executable()
	fp.description('List information about FILES')
	fp.arguments_description('[FILES]')

	all := fp.bool('', `a`, false, 'include files starting with .')
	colorize := fp.bool('', `c`, false, 'color the listing')
	dir_indicator := fp.bool('', `D`, false, 'append / to directories')
	with_commas := fp.bool('', `m`, false, 'list of files separated by commas')
	quote := fp.bool('', `q`, false, 'enclose files in quotes')
	recursive := fp.bool('', `R`, false, 'list subdirectories recursively')
	recursion_depth := fp.int('depth', ` `, max_int, 'limit depth of recursion')
	list_by_lines := fp.bool('', `X`, false, 'list files by lines instead of by columns')
	one_per_line := fp.bool('', `1`, false, 'list one file per line')
	width_in_cols := fp.int('width', ` `, 0, 'set output width to <int>\n\nFiltering and Sorting Options:')

	only_dirs := fp.bool('', `d`, false, 'list only directories')
	only_files := fp.bool('', `f`, false, 'list only files')
	dirs_first := fp.bool('', `g`, false, 'group directories before files')
	sort_reverse := fp.bool('', `r`, false, 'reverse the listing order')
	sort_size := fp.bool('', `s`, false, 'sort by file size, largest first')
	sort_time := fp.bool('', `t`, false, 'sort by time, newest first')
	sort_natural := fp.bool('', `v`, false, 'sort digits within text as numbers')
	sort_width := fp.bool('', `w`, false, 'sort by width, shortest first')
	sort_ext := fp.bool('', `x`, false, 'sort by file extension')
	sort_none := fp.bool('', `u`, false, 'no sorting\n\nLong Listing Options:')

	blocked_output := fp.bool('', `b`, false, 'blank line every 5 rows')
	size_ki := fp.bool('', `k`, false, 'sizes in kibibytes (1024) (e.g. 1k 234m 2g)')
	size_kb := fp.bool('', `K`, false, 'sizes in Kilobytes (1000) (e.g. 1kb 234mb 2gb)')
	long_format := fp.bool('', `l`, false, 'show long listing format')
	link_origin := fp.bool('', `L`, false, "show link's origin information")
	octal_permissions := fp.bool('', `o`, false, 'show octal permissions')
	relative_path := fp.bool('', `p`, false, 'show relative path')

	accessed_date := fp.bool('accessed', ` `, false, 'show last accessed date')
	changed_date := fp.bool('changed', ` `, false, 'show last status changed date')
	header := fp.bool('header', ` `, false, 'show column headers')
	inode := fp.bool('inode', ` `, false, 'show inodes')
	time_iso := fp.bool('iso', ` `, false, 'show time in iso format\n')
	no_count := fp.bool('no-counts', ` `, false, 'hide file/dir counts')
	no_date := fp.bool('no-date', ` `, false, 'hide date (modified)')
	no_dim := fp.bool('no-dim', ` `, false, 'hide shading; useful for light backgrounds')
	no_group_name := fp.bool('no-group', ` `, false, 'hide group name')
	no_hard_links := fp.bool('no-hard-links', ` `, false, 'hide hard links count')
	no_owner_name := fp.bool('no-owner', ` `, false, 'hide owner name')
	no_permissions := fp.bool('no-permissions', ` `, false, 'hide permissions')
	no_size := fp.bool('no-size', ` `, false, 'hide file size\n')

	fp.footer('

		The -c option emits color codes when standard output is
		connected to a terminal. Colors are defined in the LS_COLORS 
		environment variable.'.trim_indent())

	files := fp.finalize() or { exit_error(err.msg()) }
	style_map := make_style_map()

	return Args{
		all: all
		accessed_date: accessed_date
		blocked_output: blocked_output
		can_show_color_on_stdout: term.can_show_color_on_stdout()
		changed_date: changed_date
		colorize: colorize
		dir_indicator: dir_indicator
		dirs_first: dirs_first
		files: if files == [] { current_dir } else { files }
		header: header
		inode: inode
		link_origin: link_origin
		list_by_lines: list_by_lines
		long_format: long_format
		no_count: no_count
		no_date: no_date
		no_dim: no_dim
		no_group_name: no_group_name
		no_hard_links: no_hard_links
		no_owner_name: no_owner_name
		no_permissions: no_permissions
		no_size: no_size
		octal_permissions: octal_permissions
		one_per_line: one_per_line
		only_dirs: only_dirs
		only_files: only_files
		quote: quote
		recursion_depth: recursion_depth
		recursive: recursive
		relative_path: relative_path
		size_kb: size_kb
		size_ki: size_ki
		sort_ext: sort_ext
		sort_natural: sort_natural
		sort_none: sort_none
		sort_reverse: sort_reverse
		sort_size: sort_size
		sort_time: sort_time
		sort_width: sort_width
		style_bd: style_map['bd']
		style_cd: style_map['cd']
		style_di: style_map['di']
		style_ex: style_map['ex']
		style_fi: style_map['fi']
		style_ln: style_map['ln']
		style_pi: style_map['pi']
		style_so: style_map['so']
		time_iso: time_iso
		width_in_cols: width_in_cols
		with_commas: with_commas
	}
}

@[noreturn]
fn exit_error(msg string) {
	if msg.len > 0 {
		eprintln('${app_name}: ${error}')
	}
	eprintln("Try '${app_name} --help' for more information.")
	exit(1)
}
