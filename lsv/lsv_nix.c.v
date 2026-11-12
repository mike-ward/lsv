import os

#include <pwd.h>
#include <grp.h>
#include <unistd.h>

struct Passwd {
	pw_name  &char
	pw_uid   uint
	pw_gid   uint
	pw_dir   &char
	pw_shell &char
}

struct Group {
	gr_name &char
	gr_gid  uint
	gr_mem  &&char
}

fn C.getpwuid(uid uint) &Passwd
fn C.getgrgid(uid uint) &Group
fn C.readlink(pathname &char, buf &char, bufsiz uint) i32

fn get_owner_name(uid uint) string {
	pwd := C.getpwuid(uid)
	unsafe {
		if isnil(pwd) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix().msg()
		}
		return cstring_to_vstring(pwd.pw_name)
	}
}

fn get_group_name(uid uint) string {
	grp := C.getgrgid(uid)
	unsafe {
		if isnil(grp) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix().msg()
		}
		return cstring_to_vstring(grp.gr_name)
	}
}

fn read_link(file string) string {
	buf_size := 2048
	buf := '\0'.repeat(buf_size)
	len := C.readlink(file.str, buf.str, uint(buf_size))
	if len == -1 {
		return os.error_posix().msg()
	}
	return buf.substr(0, len)
}
