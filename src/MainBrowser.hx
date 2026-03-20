/*
 * CastleDB Browser Application Entry Point
 */

class MainBrowser {
	static function main() {
		js.Browser.window.onload = function() {
			CastleDBApp.init();
		};
	}
}
