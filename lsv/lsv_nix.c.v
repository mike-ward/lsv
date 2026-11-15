import os

#include <pwd.h>
#include <grp.h>
#include <unistd.h>

struct Passwd {
	pw_name  &char
	pw_uid   u32
	pw_gid   u32
	pw_dir   &char
	pw_shell &char
}

struct Group {
	gr_name &char
	gr_gid  u32
	gr_mem  &&char
}

fn C.getpwuid(uid u32) &Passwd
fn C.getgrgid(uid u32) &Group
fn C.readlink(pathname &char, buf &char, bufsiz u32) i32

fn get_owner_name(uid u32) string {
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

fn get_group_name(uid u32) string {
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
	len := C.readlink(file.str, buf.str, u32(buf_size))
	if len == -1 {
		return os.error_posix().msg()
	}
	return buf.substr(0, len)
}
