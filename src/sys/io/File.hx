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
package sys.io;

#if !nodejs
import js.browser.BrowserFile;

@:expose
class File {
	public static function getContent(path: String): String {
		throw "sys.io.File.getContent is not available in browser. Use BrowserFile.openFile instead.";
	}

	public static function saveContent(path: String, content: String): Void {
		BrowserFile.saveFile(content, path);
	}

	public static function getBytes(path: String): haxe.io.Bytes {
		throw "sys.io.File.getBytes is not available in browser.";
	}

	public static function saveBytes(path: String, bytes: haxe.io.Bytes): Void {
		BrowserFile.saveBytes(bytes, path);
	}

	public static function read(path: String, binary: Bool = true): FileInput {
		throw "sys.io.File.read is not available in browser.";
	}

	public static function write(path: String, binary: Bool = true): FileOutput {
		throw "sys.io.File.write is not available in browser.";
	}

	public static function append(path: String, binary: Bool = true): FileOutput {
		throw "sys.io.File.append is not available in browser.";
	}

	public static function update(path: String, binary: Bool = true): FileOutput {
		throw "sys.io.File.update is not available in browser.";
	}

	public static function copy(srcPath: String, dstPath: String): Void {
		throw "sys.io.File.copy is not available in browser.";
	}
}

@:expose
class FileInput {
	public function close(): Void {}
	public function readByte(): Int { return 0; }
	public function readBytes(s: haxe.io.Bytes, pos: Int, len: Int): Int { return 0; }
}

@:expose
class FileOutput {
	public function close(): Void {}
	public function writeByte(c: Int): Void {}
	public function writeBytes(s: haxe.io.Bytes, pos: Int, len: Int): Int { return 0; }
	public function flush(): Void {}
}
#end
