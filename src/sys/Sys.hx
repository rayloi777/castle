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
 * WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
 * ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
package sys;

@:expose
class Sys {
	public static function print(v: Dynamic): Void {
		#if !macro js.Syntax.code("console.log(String({0}))", Std.string(v)); #end
	}

	public static function println(v: Dynamic): Void {
		#if !macro js.Syntax.code("console.log(String({0}))", Std.string(v)); #end
	}

	public static function args(): Array<String> {
		return [];
	}

	public static function getEnv(s: String): String {
		#if !macro return js.Syntax.code("process.env[{0}]", s); #else return ""; #end
	}

	public static function putEnv(s: String, v: Null<String>): Void {
	}

	public static function systemName(): String {
		#if !macro
		var platform: String = js.Syntax.code("navigator.platform");
		if (platform.indexOf("Mac") >= 0) return "Mac";
		if (platform.indexOf("Win") >= 0) return "Windows";
		if (platform.indexOf("Linux") >= 0) return "Linux";
		return platform;
		#else
		return "Unknown";
		#end
	}

	public static function exit(code: Int): Void {
		throw "Cannot exit in browser";
	}

	public static function time(): Float {
		return Date.now().getTime() / 1000;
	}

	public static function cpuTime(): Float {
		return 0;
	}

	public static function getCwd(): String {
		return "/";
	}

	public static function setCwd(s: String): Void {
	}

	public static function setTimeLocale(loc: String): Bool {
		return false;
	}

	public static function getChar(echo: Bool): Int {
		return 0;
	}

	public static function sleep(seconds: Float): Void {
	}

	public static function stdin(): haxe.io.Input {
		return null;
	}

	public static function stdout(): haxe.io.Output {
		return null;
	}

	public static function stderr(): haxe.io.Output {
		return null;
	}

	public static function executablePath(): String {
		return "";
	}

	public static function programPath(): String {
		#if !macro return js.Syntax.code("window.location.href"); #else return ""; #end
	}

	public static function environment(): Map<String, String> {
		return new Map();
	}

	public static function command(cmd: String, ?args: Array<String>): Int {
		return 0;
	}
}
