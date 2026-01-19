import os

fn get_icon_for_entry(entry Entry, options Options) string {
	if !options.icons {
		return ''
	}
	ext := os.file_ext(entry.name)
	name := os.file_name(entry.name)
	return match entry.dir {
		true { get_icon_for_folder(name) }
		else { get_icon_for_file(name, ext, entry) }
	}
}

fn get_icon_for_file(name string, ext string, entry Entry) string {
	// default icon
	mut icon := icons_map['file']

	// Extension lookup
	// Optimization: Try exact match first to avoid allocation of to_lower()
	// Most extensions are already lowercase.
	mut ext_key := ext
	if ext.starts_with('.') {
		ext_key = ext_key[1..]
	}

	// Check aliases first (assuming aliases key are lowercase, so this might be tricky if we don't lower)
	// Actually aliases map keys are lowercase.
	// So if ext is "PNG", alias lookup "PNG" fails.
	// But direct icon lookup "PNG" might fail if map keys are lowercase.
	// The maps are all lowercase keys.
	// So we MUST lower if the input is mixed/upper.
	// But if input is already lower, `to_lower` might optimize?
	// V's `to_lower` returns a new string.
	// Check if string is all lower?
	// `is_lower` loop vs allocation? Allocation is expensive.
	// Simple optimization: check if `icons_map[ext_key]` exists (if map has exact keys? Map keys are lc).
	// So if ext_key is "png", it works.

	// Resolve alias
	// We need lower case for alias lookup usually.
	mut lower_ext_key := '' // Lazy init

	// Try exact match on icons_map first (if user has exact case config? No, internal map is lower).
	// So if ext_key is "png", icons_map['png'] works.
	// If ext_key is "PNG", icons_map['PNG'] fails.

	mut better_icon := icons_map[ext_key]
	if better_icon == '' {
		// Not found exact, try lower case
		lower_ext_key = ext_key.to_lower()

		// Try alias with lower
		alias := aliases_map[lower_ext_key]
		if alias != '' {
			better_icon = icons_map[alias]
		} else {
			better_icon = icons_map[lower_ext_key]
		}
	} else {
		// Found exact match, but check if it's an alias?
		// Aliases are in aliases_map. "h++" -> "h".
		// If "h++" is in icons_map? No.
		// So strict order: Alias check -> Icon check?
		// Original code:
		/*
        	mut ext_key := ext.to_lower()
            // ... strip dot
            alias := aliases_map[ext_key]
            if alias != '' { ext_key = alias }
            better_icon := icons_map[ext_key]
        */
		// If we want to optimize:
		// 1. Try `aliases_map[ext_key]` (exact). If found, use result as key for icons.
		// 2. If not, try `icons_map[ext_key]` (exact).
		// 3. If neither, `to_lower` and repeat.

		// Aliases map keys: 'apk', 'gradle' (lowercase).
		// If file is 'file.APK', ext is 'APK'. `aliases_map['APK']` will fail.
		// So for "APK", we must lower.
		// If file is 'file.apk', ext is 'apk'. `aliases_map['apk']` succeeds.

		alias := aliases_map[ext_key]
		if alias != '' {
			better_icon = icons_map[alias]
		} else {
			// No exact alias. Try exact icon.
			better_icon = icons_map[ext_key]
		}

		if better_icon == '' {
			// Try lower case
			lower_ext_key = ext_key.to_lower()
			if lower_ext_key != ext_key { // Only if different
				alias_lower := aliases_map[lower_ext_key]
				if alias_lower != '' {
					better_icon = icons_map[alias_lower]
				} else {
					better_icon = icons_map[lower_ext_key]
				}
			}
		}
	}

	if better_icon != '' {
		icon = better_icon
	}

	// now look for icons based on full names (like "Makefile")
	// Map keys are: 'gruntfile.js' (lower).
	// Input Name: "Makefile".
	// Exact lookup: folders_map["Makefile"] -> fail.
	// to_lower -> "makefile". folders_map["makefile"] -> success.
	// Optimization: Check exact, if fail, lower.

	mut best_icon := icons_map[name]
	if best_icon == '' {
		lower_name := name.to_lower()
		if lower_name != name {
			// Check alias for full name
			full_alias := aliases_map[lower_name]
			if full_alias != '' {
				best_icon = icons_map[full_alias]
			} else {
				best_icon = icons_map[lower_name]
			}
		}
	}

	if best_icon != '' {
		icon = best_icon
	}

	// look at file type
	if icon == icons_map['file'] {
		icon = match true {
			entry.socket { other_icons_map['socket'] }
			entry.link { other_icons_map['link'] }
			entry.exe { other_icons_map['exe'] }
			else { icons_map['file'] }
		}
	}
	return icon
}

fn get_icon_for_folder(name string) string {
	mut icon := folders_map['folder']
	mut better_icon := folders_map[name]
	if better_icon == '' {
		better_icon = folders_map[name.to_lower()]
	}
	if better_icon != '' {
		icon = better_icon
	}
	return icon
}

const icons_map = {
	'ai':           '\ue7b4'
	'android':      '\ue70e'
	'apple':        '\uf179'
	'as':           '\ue60b'
	'asm':          '󰘚'
	'audio':        '\uf1c7'
	'avro':         '\ue60b'
	'bf':           '\uf067'
	'binary':       '\uf471'
	'bzl':          '\ue63a'
	'c':            '\ue61e'
	'cfg':          '\uf423'
	'clj':          '\ue768'
	'conduct':      '\uf4ae'
	'coffee':       '\ue751'
	'conf':         '\ue615'
	'cpp':          '\ue61d'
	'cfm':          '\ue645'
	'cr':           '\ue62f'
	'cs':           '\ue648'
	'cson':         '\ue601'
	'css':          '\ue749'
	'cu':           '\ue64b'
	'd':            '\ue7af'
	'dart':         '\ue64c'
	'db':           '\uf1c0'
	'deb':          '\uf306'
	'diff':         '\uf440'
	'doc':          '\uf1c2'
	'dockerfile':   '\ue650'
	'dpkg':         '\uf17c'
	'ebook':        '\uf02d'
	'elm':          '\ue62c'
	'env':          '\uf462'
	'erl':          '\ue7b1'
	'ex':           '\ue62d'
	'f':            '󱈚'
	'file':         '\uea7b'
	'font':         '\uf031'
	'fs':           '\ue7a7'
	'gb':           '\ue272'
	'gform':        '\uf298'
	'git':          '\ue702'
	'go':           '\ue724'
	'graphql':      '\ue662'
	'glp':          '󰆧'
	'groovy':       '\ue775'
	'gruntfile.js': '\ue74c'
	'gulpfile.js':  '\ue610'
	'gv':           '\ue225'
	'h':            '\uf0fd'
	'haml':         '\ue664'
	'hs':           '\ue777'
	'html':         '\uf13b'
	'hx':           '\ue666'
	'ics':          '\uf073'
	'image':        '\uf1c5'
	'iml':          '\ue7b5'
	'ini':          '󰅪'
	'ino':          '\ue255'
	'iso':          '󰋊'
	'jade':         '\ue66c'
	'java':         '\ue738'
	'jenkinsfile':  '\ue767'
	'jl':           '\ue624'
	'js':           '\ue781'
	'json':         '\ue60b'
	'jsx':          '\ue7ba'
	'key':          '\uf43d'
	'ko':           '\uebc6'
	'kt':           '\ue634'
	'law':          '\uf495'
	'less':         '\ue758'
	'lock':         '\uf023'
	'log':          '\uf18d'
	'lua':          '\ue620'
	'maintainers':  '\uf0c0'
	'makefile':     '\ue673'
	'md':           '\uf48a'
	'mjs':          '\ue718'
	'ml':           '󰘧'
	'mustache':     '\ue60f'
	'nc':           '󰋁'
	'nim':          '\ue677'
	'nix':          '\uf313'
	'npmignore':    '\ue71e'
	'package':      '󰏗'
	'passwd':       '\uf023'
	'patch':        '\uf440'
	'pdf':          '\uf1c1'
	'php':          '\ue608'
	'pl':           '\ue7a1'
	'prisma':       '\ue684'
	'ppt':          '\uf1c4'
	'psd':          '\ue7b8'
	'py':           '\ue606'
	'r':            '\ue68a'
	'rb':           '\ue21e'
	'rdb':          '\ue76d'
	'readme':       '\ueda4'
	'rpm':          '\uf17c'
	'rs':           '\ue7a8'
	'rss':          '\uf09e'
	'rst':          '󰅫'
	'rubydoc':      '\ue73b'
	'sass':         '\ue603'
	'scala':        '\ue737'
	'shell':        '\uf489'
	'shp':          '󰙞'
	'sol':          '󰡪'
	'sqlite':       '\ue7c4'
	'styl':         '\ue600'
	'svelte':       '\ue697'
	'swift':        '\ue755'
	'tex':          '\u222b'
	'tf':           '\ue69a'
	'toml':         '󰅪'
	'ts':           '󰛦'
	'twig':         '\ue61c'
	'txt':          '\uf15c'
	'v':            '\ue6ac'
	'vagrantfile':  '\ue21e'
	'video':        '\uf03d'
	'vim':          '\ue62b'
	'vue':          '\ue6a0'
	'windows':      '\uf17a'
	'xls':          '\uf1c3'
	'xml':          '\ue796'
	'yml':          '\ue601'
	'zig':          '\ue6a9'
	'zip':          '\uf410'
}

const aliases_map = {
	'apk':                'android'
	'gradle':             'android'
	'ds_store':           'apple'
	'localized':          'apple'
	'm':                  'apple'
	'mm':                 'apple'
	's':                  'asm'
	'aac':                'audio'
	'alac':               'audio'
	'flac':               'audio'
	'm4a':                'audio'
	'mka':                'audio'
	'mp3':                'audio'
	'ogg':                'audio'
	'opus':               'audio'
	'wav':                'audio'
	'wma':                'audio'
	'b':                  'bf'
	'bson':               'binary'
	'feather':            'binary'
	'mat':                'binary'
	'o':                  'binary'
	'pb':                 'binary'
	'pickle':             'binary'
	'pkl':                'binary'
	'tfrecord':           'binary'
	'code_of_conduct.md': 'conduct'
	'conf':               'cfg'
	'config':             'cfg'
	'contributing':       'maintainers'
	'contributing.md':    'maintainers'
	'cljc':               'clj'
	'cljs':               'clj'
	'editorconfig':       'conf'
	'rc':                 'conf'
	'c++':                'cpp'
	'cc':                 'cpp'
	'cxx':                'cpp'
	'scss':               'css'
	'sql':                'db'
	'docx':               'doc'
	'gdoc':               'doc'
	'dockerignore':       'dockerfile'
	'epub':               'ebook'
	'ipynb':              'ebook'
	'mobi':               'ebook'
	'f03':                'f'
	'f77':                'f'
	'f90':                'f'
	'f95':                'f'
	'for':                'f'
	'fpp':                'f'
	'ftn':                'f'
	'eot':                'font'
	'otf':                'font'
	'ttf':                'font'
	'woff':               'font'
	'woff2':              'font'
	'fsi':                'fs'
	'fsscript':           'fs'
	'fsx':                'fs'
	'dna':                'gb'
	'gitattributes':      'git'
	'gitconfig':          'git'
	'gitignore':          'git'
	'gitignore_global':   'git'
	'gitmirrorall':       'git'
	'gitmodules':         'git'
	'gltf':               'glp'
	'gsh':                'groovy'
	'gvy':                'groovy'
	'gy':                 'groovy'
	'h++':                'h'
	'hh':                 'h'
	'hpp':                'h'
	'hxx':                'h'
	'lhs':                'hs'
	'htm':                'html'
	'xhtml':              'html'
	'bmp':                'image'
	'cbr':                'image'
	'cbz':                'image'
	'dvi':                'image'
	'eps':                'image'
	'gif':                'image'
	'ico':                'image'
	'jpeg':               'image'
	'jpg':                'image'
	'nef':                'image'
	'orf':                'image'
	'pbm':                'image'
	'pgm':                'image'
	'png':                'image'
	'pnm':                'image'
	'ppm':                'image'
	'pxm':                'image'
	'sixel':              'image'
	'stl':                'image'
	'svg':                'image'
	'tif':                'image'
	'tiff':               'image'
	'webp':               'image'
	'xpm':                'image'
	'disk':               'iso'
	'dmg':                'iso'
	'img':                'iso'
	'ipsw':               'iso'
	'smi':                'iso'
	'vhd':                'iso'
	'vhdx':               'iso'
	'vmdk':               'iso'
	'jar':                'java'
	'cjs':                'js'
	'properties':         'json'
	'webmanifest':        'json'
	'tsx':                'jsx'
	'cjsx':               'jsx'
	'cer':                'key'
	'crt':                'key'
	'der':                'key'
	'gpg':                'key'
	'p7b':                'key'
	'pem':                'key'
	'pfx':                'key'
	'pgp':                'key'
	'license':            'law'
	'license.md':         'law'
	'changelog.md':       'log'
	'codeowners':         'maintainers'
	'credits':            'maintainers'
	'cmake':              'makefile'
	'justfile':           'makefile'
	'markdown':           'md'
	'mkd':                'md'
	'rdoc':               'md'
	'readme':             'readme'
	'readme.md':          'readme'
	'readme.package.md':  'readme'
	'mli':                'ml'
	'sml':                'ml'
	'netcdf':             'nc'
	'brewfile':           'package'
	'cargo.toml':         'package'
	'cargo.lock':         'package'
	'go.mod':             'package'
	'go.sum':             'package'
	'pyproject.toml':     'package'
	'poetry.lock':        'package'
	'package.json':       'package'
	'pipfile':            'package'
	'pipfile.lock':       'package'
	'php3':               'php'
	'php4':               'php'
	'php5':               'php'
	'phpt':               'php'
	'phtml':              'php'
	'gslides':            'ppt'
	'pptx':               'ppt'
	'pxd':                'py'
	'pyc':                'py'
	'pyx':                'py'
	'whl':                'py'
	'rdata':              'r'
	'rds':                'r'
	'rmd':                'r'
	'gemfile':            'rb'
	'gemspec':            'rb'
	'guardfile':          'rb'
	'procfile':           'rb'
	'rakefile':           'rb'
	'rspec':              'rb'
	'rspec_parallel':     'rb'
	'rspec_status':       'rb'
	'ru':                 'rb'
	'erb':                'rubydoc'
	'slim':               'rubydoc'
	'awk':                'shell'
	'bash':               'shell'
	'bash_history':       'shell'
	'bash_profile':       'shell'
	'bashrc':             'shell'
	'csh':                'shell'
	'fish':               'shell'
	'ksh':                'shell'
	'ps1':                'shell'
	'sh':                 'shell'
	'zsh':                'shell'
	'zsh-theme':          'shell'
	'zshrc':              'shell'
	'plpgsql':            'sql'
	'plsql':              'sql'
	'psql':               'sql'
	'tsql':               'sql'
	'sl3':                'sqlite'
	'sqlite3':            'sqlite'
	'stylus':             'styl'
	'cls':                'tex'
	'avi':                'video'
	'flv':                'video'
	'm2v':                'video'
	'mkv':                'video'
	'mov':                'video'
	'mp4':                'video'
	'mpeg':               'video'
	'mpg':                'video'
	'ogm':                'video'
	'ogv':                'video'
	'vob':                'video'
	'webm':               'video'
	'vimrc':              'vim'
	'bat':                'windows'
	'cmd':                'windows'
	'exe':                'windows'
	'csv':                'xls'
	'gsheet':             'xls'
	'xlsx':               'xls'
	'plist':              'xml'
	'xul':                'xml'
	'yaml':               'yml'
	'7z':                 'zip'
	'Z':                  'zip'
	'bz2':                'zip'
	'gz':                 'zip'
	'lzma':               'zip'
	'par':                'zip'
	'rar':                'zip'
	'tar':                'zip'
	'tc':                 'zip'
	'tgz':                'zip'
	'txz':                'zip'
	'xz':                 'zip'
	'z':                  'zip'
}

const folders_map = {
	'.android':              '\ue70e'
	'.aspnet':               '\ue77f'
	'.atom':                 '\ue764'
	'.aws':                  '\ue7ad'
	'.config':               '\ue615'
	'.docker':               '\ue7b0'
	'.dotnet':               '\ue77f'
	'.gem':                  '\ue21e'
	'.git':                  '\ue5fb'
	'.git-credential-cache': '\ue5fb'
	'.github':               '\ue5fd'
	'.gradle':               '\ue7f2'
	'.javacpp':              '\ue738'
	'.net':                  '\ue77f'
	'.npm':                  '\ue5fa'
	'.nvm':                  '\ue718'
	'.rvm':                  '\ue21e'
	'.trash':                '\uf014'
	'.vscode':               '\ue70c'
	'.vim':                  '\ue62b'
	'androidstudioprojects': '\ue70e'
	'applications':          '\ueb44'
	'bin':                   '\uf085'
	'sbin':                  '\uf085'
	'config':                '\ue5fc'
	'desktop':               '\uf108'
	'documents':             '\uef0d'
	'downloads':             '\uf409'
	'folder':                '\uea83'
	'github':                '\uea84'
	'go':                    '\ue65e'
	'hidden':                '\uf023'
	'lib':                   '\ueac4'
	'library':               '\ueac4'
	'log':                   '\uf18d'
	'mail':                  '\ueb1c'
	'movies':                '\uf008'
	'music':                 '\uf025'
	'node_modules':          '\ue5fa'
	'pictures':              '\uf03e'
	'screenshots':           '󰹑'
	'screen-shots':          '󰹑'
	'screen_shots':          '󰹑'
	'swift':                 '\ue699'
	'users':                 '\uf0c0'
}

const other_icons_map = {
	'link':       '\uf0c1'
	'linkDir':    '\uf0c1'
	'brokenLink': '\uf127'
	'device':     '\uf0a0'
	'socket':     '\uf1e6'
	'pipe':       '\ufce3'
	'exe':        '\uf085'
}
