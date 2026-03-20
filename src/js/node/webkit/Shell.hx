package js.node.webkit;

@:expose
class Shell {
	public static function openExternal(url: String): Void {
		js.Browser.window.open(url, "_blank");
	}

	public static function openItem(filePath: String): Void {
		// In browser, files are opened via the file input dialog
		// This is handled by the file browser API
	}

	public static function showItemInFolder(filePath: String): Void {
		// Cannot show item in folder in browser
	}
}
