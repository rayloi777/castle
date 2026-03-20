package js.node.webkit;

import js.jquery.Event;

@:expose
class Window {
	public var window: js.html.Window;
	public var x: Int;
	public var y: Int;
	public var width: Int;
	public var height: Int;
	public var title: String;
	public var isFullScreen: Bool;
	public var isKioskMode: Bool;
	public var zoomLevel: Int;
	public var menu: Menu;

	var onFocusCallbacks: Array<Event -> Void> = [];

	public function new() {
		window = js.Browser.window;
	}

	public function moveTo(x: Int, y: Int): Void {}
	public function moveBy(x: Int, y: Int): Void {}
	public function resizeTo(w: Int, h: Int): Void {}
	public function resizeBy(w: Int, h: Int): Void {}
	public function focus(): Void {}
	public function blur(): Void {}
	public function show(): Void {}
	public function hide(): Void {}
	public function close(?force: Bool): Void {}
	public function reload(): Void {}
	public function reloadIgnoringCache(): Void {}
	public function maximize(): Void {}
	public function unmaximize(): Void {}
	public function minimize(): Void {}
	public function restore(): Void {}
	public function enterFullscreen(): Void {}
	public function leaveFullscreen(): Void {}
	public function showDevTools(?id: String, ?headless: Bool): Void {}
	public function closeDevTools(): Void {}

	public function on(event: String, callb: Event -> Void): Void {
		if (event == "focus") {
			onFocusCallbacks.push(callb);
			js.Browser.window.addEventListener("focus", function(e) {
				for (cb in onFocusCallbacks) {
					cb(cast e);
				}
			});
		}
	}

	public static function get(): Window {
		if (_instance == null) {
			_instance = new Window();
		}
		return _instance;
	}

	public static function open(url: String, ?options: Dynamic): Window {
		js.Browser.window.open(url, "_blank");
		return get();
	}

	static var _instance: Window;
}
