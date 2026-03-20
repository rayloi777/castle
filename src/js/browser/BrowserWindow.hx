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

import js.jquery.Event;

@:expose
class BrowserWindow {
	public var onFocusCallbacks: Array<Void -> Void> = [];

	public function new() {
		var self = this;
		js.Browser.window.addEventListener("focus", function(e) {
			for (cb in self.onFocusCallbacks) {
				cb();
			}
		});
	}

	public function on(event: String, callback: Event -> Void): Void {
		if (event == "focus") {
			onFocusCallbacks.push(cast callback);
		}
	}

	static function get(): BrowserWindow {
		return _instance;
	}

	static var _instance: BrowserWindow;

	static function init() {
		if (_instance == null) {
			_instance = new BrowserWindow();
		}
		return _instance;
	}

	public function clearCache(): Void {
		// No-op in browser - cannot clear cache programmatically
	}
}

@:expose
class BrowserApp {
	public static function clearCache(): Void {
		// No-op in browser
	}
}

@:expose
class BrowserShell {
	public static function openExternal(url: String): Void {
		js.Browser.window.open(url, "_blank");
	}

	public static function openItem(filePath: String): Void {
		// In browser, this would download the file
		// The actual file opening is handled by BrowserFile
	}

	public static function showItemInFolder(filePath: String): Void {
		// Cannot show item in folder in browser
	}
}

@:expose
class BrowserMenu {
	public var items(default, null): Array<Dynamic> = [];
	var _menuElement: js.html.UListElement;
	var _isVisible: Bool = false;

	public function new(?t: Dynamic): Void {
		createMenuElement();
	}

	function createMenuElement(): Void {
		_menuElement = cast js.Browser.document.createElement("ul");
		_menuElement.className = "browser-context-menu";
		_menuElement.style.position = "absolute";
		_menuElement.style.zIndex = "10000";
		_menuElement.style.background = "#fff";
		_menuElement.style.border = "1px solid #ccc";
		_menuElement.style.boxShadow = "2px 2px 5px rgba(0,0,0,0.2)";
		_menuElement.style.padding = "0";
		_menuElement.style.margin = "0";
		_menuElement.style.listStyle = "none";
		_menuElement.style.display = "none";
		_menuElement.style.minWidth = "150px";
		js.Browser.document.body.appendChild(_menuElement);

		// Hide menu when clicking elsewhere
		js.Browser.document.addEventListener("click", function(e) {
			if (_isVisible) {
				hide();
			}
		});
	}

	public function append(item: Dynamic): Void {
		items.push(item);
		var li = cast js.Browser.document.createElement("li");
		li.style.padding = "8px 12px";
		li.style.cursor = "pointer";
		li.style.borderBottom = "1px solid #eee";

		if (Std.isOfType(item, BrowserMenuItem)) {
			var menuItem: BrowserMenuItem = cast item;
			li.textContent = menuItem.label;
			if (menuItem.type == "separator") {
				li.style.height = "1px";
				li.style.background = "#ccc";
				li.style.padding = "0";
				li.style.borderBottom = "none";
			} else {
				li.addEventListener("click", function(e) {
					e.stopPropagation();
					if (menuItem.click != null) {
						menuItem.click(cast e);
					}
					hide();
				});
				li.addEventListener("mouseenter", function(e) {
					li.style.background = "#f0f0f0";
				});
				li.addEventListener("mouseleave", function(e) {
					li.style.background = "";
				});
				if (menuItem.checked != null) {
					li.style.fontWeight = menuItem.checked ? "bold" : "normal";
				}
				if (menuItem.enabled == false) {
					li.style.color = "#999";
					li.style.cursor = "default";
					li.removeEventListener("click", null);
				}
			}
		}
		_menuElement.appendChild(li);
	}

	public function remove(item: Dynamic): Void {
		items.remove(item);
		rebuildMenu();
	}

	function rebuildMenu(): Void {
		_menuElement.innerHTML = "";
		for (item in items) {
			append(item);
		}
	}

	public function popup(x: Int, y: Int): Void {
		_menuElement.style.left = x + "px";
		_menuElement.style.top = y + "px";
		_menuElement.style.display = "block";
		_isVisible = true;
	}

	public function hide(): Void {
		_menuElement.style.display = "none";
		_isVisible = false;
	}

	public function removeAt(pos: Int): Void {
		if (pos >= 0 && pos < items.length) {
			items.splice(pos, 1);
			rebuildMenu();
		}
	}

	public function insert(item: Dynamic, pos: Int): Void {
		items.insert(pos, item);
		rebuildMenu();
	}

	static function createWindowMenu(): BrowserMenu {
		return new BrowserMenu({ type: "menubar" });
	}
}

@:expose
class BrowserMenuItem {
	public var label: String;
	public var type: String;
	public var click: Event -> Void;
	public var checked: Bool;
	public var enabled: Bool;

	public function new(opts: Dynamic): Void {
		label = opts.label;
		type = opts.type;
		click = opts.click;
		checked = opts.checked;
		enabled = opts.enabled;
	}
}

@:expose
class BrowserMenuItemType {
	public static var normal: String = "normal";
	public static var separator: String = "separator";
	public static var checkbox: String = "checkbox";
}
