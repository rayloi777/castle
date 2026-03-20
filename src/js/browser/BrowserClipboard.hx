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
package js.browser;

@:expose
class BrowserClipboard {
	static var _instance: BrowserClipboard;

	public static function getInstance(): BrowserClipboard {
		if (_instance == null) {
			_instance = new BrowserClipboard();
		}
		return _instance;
	}

	public function new() {}

	public function get(format: String): String {
		#if js
		var text: Dynamic = untyped __js__('navigator.clipboard.readText()');
		return text;
		#else
		return null;
		#end
	}

	public function set(text: String, format: String): Void {
		#if js
		untyped __js__('navigator.clipboard.writeText({0})', text);
		#end
	}
}
