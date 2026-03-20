/*
 * Copyright (c) 2026, CastleDB Contributors
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package sys;

@:expose
class FileSystem {
	public static function exists(path: String): Bool {
		// In browser, we don't have real file system access
		// Return false to indicate the file doesn't exist
		return false;
	}

	public static function isDirectory(path: String): Bool {
		return false;
	}

	public static function readDirectory(path: String): Array<String> {
		return [];
	}

	public static function createDirectory(path: String): Void {
		// Cannot create directories in browser
	}

	public static function deleteFile(path: String): Void {
		// Cannot delete files in browser
	}

	public static function deleteDirectory(path: String): Void {
		// Cannot delete directories in browser
	}

	public static function rename(path: String, newPath: String): Void {
		// Cannot rename files in browser
	}

	public static function stat(path: String): FileStat {
		return null;
	}

	public static function fullPath(path: String): String {
		return path;
	}
}

typedef FileStat = {
	var size: Int;
	var mtime: Date;
	var isDirectory: Bool;
}
