module main

import flag
import term

const app_name = 'lsv'
const current_dir = ['.']

struct Options {
	// display options
	blocked_output bool
	colorize       bool
	dir_indicator  bool
	full_path      bool
	list_by_lines  bool
	long_format    bool
	no_dim         bool
	one_per_line   bool
	quote          bool
	relative_path  bool
	table_format   bool
	width_in_cols  int
	with_commas    bool
	icons          bool
	no_wrap        bool
	//
	// filter, group and sorting options
	all              bool
	almost_all       bool
	dirs_first       bool
	only_dirs        bool
	only_files       bool
	recursion_depth  int
	recursive        bool
	sort_ext         bool
	sort_ignore_case bool
	sort_natural     bool
	sort_none        bool
	sort_reverse     bool
	sort_size        bool
	sort_time        bool
	sort_width       bool
	//
	// long view options
	accessed_date         bool
	changed_date          bool
	header                bool
	inode                 bool
	no_count              bool
	no_date               bool
	no_group_name         bool
	no_hard_links         bool
	no_owner_name         bool
	no_permissions        bool
	no_size               bool
	octal_permissions     bool
	size_comma            bool
	size_kb               bool
	size_ki               bool
	time_iso              bool
	time_compact          bool
	time_compact_with_day bool
	time_relative         bool
	mime_type             bool
	checksum              string
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

fn parse_args(args []string) Options {
	mut fp := flag.new_flag_parser(args)

	fp.application(app_name)
	fp.version('2024.6')
	fp.skip_executable()
	fp.description('List information about FILES')
	fp.arguments_description('[FILES]')

	all := fp.bool('', `a`, false, 'include files starting with .')
	almost_all := fp.bool('', `A`, false, 'do not list implied . and ..')
	colorize := fp.bool('', `c`, false, 'color the listing')
	dir_indicator := fp.bool('', `D`, false, 'append / to directories')
	full_path := fp.bool('', `F`, false, 'show full path')
	icons := fp.bool('', `i`, false, 'show file icon (requires nerd fonts)')
	long_format := fp.bool('', `l`, false, 'long listing format (see Long Listing Options)')
	with_commas := fp.bool('', `m`, false, 'list of files separated by commas')
	quote := fp.bool('', `q`, false, 'enclose files in quotes')
	recursive := fp.bool('', `R`, false, 'list subdirectories recursively')
	list_by_lines := fp.bool('', `X`, false, 'list files by lines instead of by columns')
	one_per_line := fp.bool('', `1`, false, 'list one file per line\n')
	recursion_depth := fp.int('depth', 0, max_int, 'limit depth of recursion')

	width_in_cols := fp.int('width', 0, 0, 'set output width to <int>\n\nFiltering and Sorting Options:')
	only_dirs := fp.bool('', `d`, false, 'list only directories')
	only_files := fp.bool('', `f`, false, 'list only files')
	dirs_first := fp.bool('', `g`, false, 'group directories before files')
	sort_reverse := fp.bool('', `r`, false, 'reverse the listing order')
	sort_size := fp.bool('', `s`, false, 'sort by file size, largest first')
	sort_time := fp.bool('', `t`, false, 'sort by time, newest first')
	sort_natural := fp.bool('', `v`, false, 'sort digits within text as numbers')
	sort_width := fp.bool('', `w`, false, 'sort by width, shortest first')
	sort_ext := fp.bool('', `x`, false, 'sort by file extension')
	sort_none := fp.bool('', `u`, false, 'no sorting\n')
	sort_ignore_case := fp.bool('ignore-case', 0, false, 'ignore case when sorting\n\nLong Listing Options:')

	blocked_output := fp.bool('', `b`, false, 'blank line every 5 rows')
	table_format := fp.bool('', `B`, false, 'add borders to long listing format')
	size_comma := fp.bool('', `,`, false, 'sizes comma separated by thousands')
	size_ki := fp.bool('', `k`, false, 'sizes in kibibytes (1024) (e.g. 1k 234m 2g)')
	size_kb := fp.bool('', `K`, false, 'sizes in Kilobytes (1000) (e.g. 1kb 234mb 2gb)')
	octal_permissions := fp.bool('', `o`, false, 'show octal permissions')
	relative_path := fp.bool('', `p`, false, 'show relative path')
	changed_date := fp.bool('', `C`, false, 'show last status changed date')
	accessed_date := fp.bool('', `E`, false, 'show last accessed date')
	header := fp.bool('', `H`, false, 'show column headers')
	time_iso := fp.bool('', `I`, false, 'show time in iso format')
	time_compact := fp.bool('', `J`, false, 'show time in compact format')
	time_compact_with_day := fp.bool('', `L`, false, 'show time in compact format with week day')
	time_relative := fp.bool('', `T`, false, 'show relative time')
	mime_type := fp.bool('', `M`, false, 'show mime type')
	inode := fp.bool('', `N`, false, 'show inodes')
	no_wrap := fp.bool('', `Z`, false, 'do not wrap long lines\n')

	checksum := fp.string('cs', 0, '', 'show file checksum\n${flag.space}(md5, sha1, sha224, sha256, sha512, blake2b)')
	no_count := fp.bool('no-counts', 0, false, 'hide file/dir counts')
	no_date := fp.bool('no-date', 0, false, 'hide date (modified)')
	no_dim := fp.bool('no-dim', 0, false, 'hide shading; useful for light backgrounds')
	no_group_name := fp.bool('no-group', 0, false, 'hide group name')
	no_hard_links := fp.bool('no-hard-links', 0, false, 'hide hard links count')
	no_owner_name := fp.bool('no-owner', 0, false, 'hide owner name')
	no_permissions := fp.bool('no-permissions', 0, false, 'hide permissions')
	no_size := fp.bool('no-size', 0, false, 'hide file size\n')

	fp.footer('\n
		The -c option emits color codes when standard output is
		connected to a terminal. Colors are defined in the LS_COLORS
		environment variable.'.trim_indent())
	files := fp.finalize() or { exit_error(err.msg()) }

	style_map := make_style_map()
	can_show_color_on_stdout := term.can_show_color_on_stdout()

	return Options{
		all:                   all
		almost_all:            almost_all
		accessed_date:         accessed_date
		blocked_output:        blocked_output
		changed_date:          changed_date
		checksum:              checksum
		colorize:              colorize && can_show_color_on_stdout
		dir_indicator:         dir_indicator
		dirs_first:            dirs_first
		files:                 if files == [] { current_dir } else { files }
		full_path:             full_path
		header:                header
		icons:                 icons
		inode:                 inode
		list_by_lines:         list_by_lines
		long_format:           long_format
		mime_type:             mime_type
		no_count:              no_count
		no_date:               no_date
		no_dim:                no_dim
		no_group_name:         no_group_name
		no_hard_links:         no_hard_links
		no_owner_name:         no_owner_name
		no_permissions:        no_permissions
		no_size:               no_size
		no_wrap:               no_wrap
		octal_permissions:     octal_permissions
		one_per_line:          one_per_line
		only_dirs:             only_dirs
		only_files:            only_files
		quote:                 quote
		recursion_depth:       recursion_depth
		recursive:             recursive
		relative_path:         relative_path
		size_comma:            size_comma
		size_kb:               size_kb
		size_ki:               size_ki
		sort_ext:              sort_ext
		sort_ignore_case:      sort_ignore_case
		sort_natural:          sort_natural
		sort_none:             sort_none
		sort_reverse:          sort_reverse
		sort_size:             sort_size
		sort_time:             sort_time
		sort_width:            sort_width
		style_bd:              style_map['bd']
		style_cd:              style_map['cd']
		style_di:              style_map['di']
		style_ex:              style_map['ex']
		style_fi:              style_map['fi']
		style_ln:              style_map['ln']
		style_pi:              style_map['pi']
		style_so:              style_map['so']
		table_format:          table_format && long_format
		time_compact:          time_compact
		time_compact_with_day: time_compact_with_day
		time_iso:              time_iso
		time_relative:         time_relative
		width_in_cols:         width_in_cols
		with_commas:           with_commas
	}
}

@[noreturn]
fn exit_error(msg string) {
	if msg.len > 0 {
		eprintln('${app_name}: ${msg}')
	}
	eprintln("Try '${app_name} --help' for more information.")
	exit(1)
}
