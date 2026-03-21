package js.node.webkit;

import js.jquery.Event;

@:expose
class Menu {
	public var items(default, null): Array<MenuItem> = [];
	var _menuElement: Dynamic;
	var _isVisible: Bool = false;

	public function new(?t: Dynamic): Void {
		createMenuElement();
	}

	function createMenuElement(): Void {
		untyped {
			_menuElement = js.Browser.document.createElement("ul");
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

			js.Browser.document.addEventListener("click", function(e) {
				if (_isVisible) {
					this.hide();
				}
			});
		}
	}

	public function append(it: MenuItem): Void {
		items.push(it);
		rebuildMenu();
	}

	public function remove(it: MenuItem): Void {
		items.remove(it);
		rebuildMenu();
	}

	function rebuildMenu(): Void {
		untyped {
			_menuElement.innerHTML = "";
			for (i in 0...items.length) {
				var item = items[i];
				var li = js.Browser.document.createElement("li");
				li.style.padding = "8px 12px";
				li.style.cursor = item.type == "separator" ? "default" : "pointer";
				li.style.borderBottom = "1px solid #eee";
				li.style.background = "";

				if (item.type == "separator") {
					li.style.height = "1px";
					li.style.background = "#ccc";
					li.style.padding = "0";
					li.style.borderBottom = "none";
				} else {
					li.textContent = item.label;
					var capturedItem = item;
					li.addEventListener("click", function(e) {
						e.stopPropagation();
						if (capturedItem.click != null) {
							capturedItem.click(cast e);
						}
						this.hide();
					});
					li.addEventListener("mouseenter", function(e) {
						if (capturedItem.enabled != false) {
							li.style.background = "#f0f0f0";
						}
					});
					li.addEventListener("mouseleave", function(e) {
						li.style.background = "";
					});
					if (capturedItem.checked != null && capturedItem.checked) {
						li.style.fontWeight = "bold";
					}
					if (capturedItem.enabled == false) {
						li.style.color = "#999";
						li.style.cursor = "default";
					}
				}
				_menuElement.appendChild(li);
			}
		}
	}

	public function popup(x: Int, y: Int): Void {
		untyped {
			_menuElement.style.left = x + "px";
			_menuElement.style.top = y + "px";
			_menuElement.style.display = "block";
		}
		_isVisible = true;
	}

	public function hide(): Void {
		untyped {
			_menuElement.style.display = "none";
		}
		_isVisible = false;
	}

	public function removeAt(pos: Int): Void {
		if (pos >= 0 && pos < items.length) {
			items.splice(pos, 1);
			rebuildMenu();
		}
	}

	public function insert(it: MenuItem, pos: Int): Void {
		items.insert(pos, it);
		rebuildMenu();
	}

	public static inline function createWindowMenu(): Menu {
		return new Menu({ type: "menubar" });
	}

	public function createMacBuiltin(name: String, ?opts: Dynamic): Void {
	#if !nwjs
		throw "createMacBuiltin is only available in NW.js";
	#end
	}
}
