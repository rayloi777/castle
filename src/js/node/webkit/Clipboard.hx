package js.node.webkit;

@:expose
class Clipboard {
	var _instance: Clipboard;

	public function new() {}

	public static inline function getInstance(): Clipboard {
		if (untyped window._castleClipboard == null) {
			untyped window._castleClipboard = new Clipboard();
		}
		return untyped window._castleClipboard;
	}

	public function get(?type: String): Dynamic {
		#if js
		try {
			return untyped __js__('navigator.clipboard.readText()');
		} catch(e: Dynamic) {
			return "";
		}
		#else
		return null;
		#end
	}

	public function set(data: Dynamic, ?type: String): Void {
		#if js
		untyped __js__('navigator.clipboard.writeText({0})', Std.string(data));
		#end
	}

	public function clear(): Void {
		#if js
		untyped __js__('navigator.clipboard.writeText("")');
		#end
	}
}
