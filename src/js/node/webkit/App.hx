package js.node.webkit;

@:expose
class App {
	static var argv: Array<String> = [];
	static var fullArgv: Array<String> = [];
	static var dataPath: String = "";
	static var manifest: Dynamic = {};

	public static function quit(): Void {
		// Cannot quit browser
	}

	public static function clearCache(): Void {
		// No-op in browser
	}

	public static function closeAllWindows(): Void {
		// No-op in browser
	}

	public static function crashBrowser(): Void {
		throw "Cannot crash browser";
	}

	public static function crashRenderer(): Void {
		throw "Cannot crash renderer";
	}

	public static function getProxyForURL(url: String): String {
		return "";
	}

	public static function setProxyConfig(config: String): Void {}

	public static function on(event: String, callb: Dynamic -> Void): Void {
		// No-op in browser
	}
}
