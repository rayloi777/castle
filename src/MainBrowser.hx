/*
 * CastleDB Browser Application Entry Point
 */

class MainBrowser {
	static function main() {
		untyped window.CastleDBApp = CastleDBApp;
		js.Browser.window.onload = function() {
			CastleDBApp.init();
		};
	}
}
