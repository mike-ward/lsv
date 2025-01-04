# Changelog

All notable changes to this project will be documented in this file.

## [2025.1 (pending)]
### Added
- implied . and .. folders to -a option
- almost all option (-A)
- full path option (-F)
- relative time option (-T)
- mime type (-M)
- entry number (-#)

## [2024.6]
### Added
- , (comma) flag to print file sizes grouped and separated by thousands.
- --ignore-case option

### Updated
- updated icons

## [2024.5]
### Added
- compact date with week day (e.g. Thu 18 Jul'24 09:03)
- fix printing of error message for command line flags

### Updated
- tweaked the help layout
- removed the last vestiages of line buffering
- remove leading 0 in compact date format

## [2024.4] - 2024-07-07
### Added
- Optionally (-Z) truncate lines if too long. Show `≈` to indicate truncation
- Minor performnce tweaks

### Fixed
- remove end-of-line padding when no borders specfied #1
- fix date minute formatting error

## [2024.3] - 2024-07-05
### Added
- file icons

### Fixed
- don't include excutable dirs in file byte count

## [2024.2]
### Added
- Always follow links. Color link and link origin separately
- Highlight broken links
- Change format of statistics
- Add total size of files to statistics

### Fixed
- Resolve full paths and links bug

## [2024.1] - 2024-22-19

### Added
- Compact date format option
- Borders around long formatted listings
- Checksum (md5, sha1, sha224, sha256, sha512, blake2b)

## [2024.1.beta.1] - 2024-06-19

- First beta release. Let the games begin!
