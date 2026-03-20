package js.node.webkit;

@:expose
class Clipboard {
	var _instance: Clipboard;

	public function new() {}

	public static inline function getInstance(): Clipboard {
		if (js.Syntax.code("window._castleClipboard") == null) {
			js.Syntax.code("window._castleClipboard = {0}", new Clipboard());
		}
		return js.Syntax.code("window._castleClipboard");
	}

	public function get(?type: String): Dynamic {
		#if js
		try {
			return js.Syntax.code("navigator.clipboard.readText()");
		} catch(e: Dynamic) {
			return "";
		}
		#else
		return null;
		#end
	}

	public function set(data: Dynamic, ?type: String): Void {
		#if js
		js.Syntax.code("navigator.clipboard.writeText({0})", Std.string(data));
		#end
	}

	public function clear(): Void {
		#if js
		js.Syntax.code("navigator.clipboard.writeText(\"\")");
		#end
	}
}
