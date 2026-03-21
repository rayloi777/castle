/*
 * CastleDB Browser Application Entry Point
 */

class MainBrowser {
	static function main() {
		untyped window.CastleDBApp = CastleDBApp;
		untyped window.openImagePicker = CastleDBApp.openImagePicker;
		js.Browser.window.onload = function() {
			CastleDBApp.init();
		};
	}
}
