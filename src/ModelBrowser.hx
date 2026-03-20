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
import cdb.Data;
import js.browser.BrowserFile;

typedef Prefs = {
	windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool },
	curFile : String,
	curSheet : Int,
	recent : Array<String>,
}

typedef HistoryElement = { d : String, o : String };

class Model {

	public var base : cdb.Database;
	var prefs : Prefs;
	var imageBank : Dynamic<String>;
	var openedList : Map<String,Bool>;
	var existsCache : Map<String,{ t : Float, r : Bool }>;

	var curSavedData : HistoryElement;
	var history : Array<HistoryElement>;
	var redo : Array<HistoryElement>;

	public var onSaveCallback: Void -> Void;
	public var onLoadCallback: Void -> Void;

	function new() {
		openedList = new Map();
		prefs = {
			windowPos : { x : 50, y : 50, w : 800, h : 600, max : false },
			curFile : null,
			curSheet : 0,
			recent : [],
		};
		existsCache = new Map();
		loadPrefs();
	}

	function quickExists(path) {
		// In browser, we can't check file existence
		return true;
	}

	public function getImageData( key : String ) : String {
		return Reflect.field(imageBank, key);
	}

	public function getAbsPath( file : String ) {
		return file.charAt(0) == "/" || file.charAt(1) == ":" ? file : new haxe.io.Path(prefs.curFile).dir.split("\\").join("/") + "/" + file;
	}

	public inline function getSheet( name : String ) {
		return base.getSheet(name);
	}

	public function save( history = true ) {
		var sdata = quickSave();
		if( history && (curSavedData == null || sdata.d != curSavedData.d || sdata.o != curSavedData.o) ) {
			this.history.push(curSavedData);
			this.redo = [];
			if( this.history.length > 100 || sdata.d.length * (this.history.length + this.redo.length) * 2 > 300<<20 ) this.history.shift();
			curSavedData = sdata;
		}
		if( prefs.curFile == null )
			return;
		// Browser: save directly without lock file
		BrowserFile.saveFile(sdata.d, prefs.curFile);
		saveImages();
		savePrefs();
		if (onSaveCallback != null) onSaveCallback();
	}

	function saveImages() {
		if( prefs.curFile == null )
			return;
		var img = prefs.curFile.split(".");
		img.pop();
		var path = img.join(".") + ".img";
		if( imageBank == null ) {
			// Can't delete, just skip
		} else {
			BrowserFile.saveFile(untyped haxe.Json.stringify(imageBank, null, "\t"), path);
		}
	}

	function quickSave() : HistoryElement {
		return {
			d : base.save(),
			o : haxe.Serializer.run(openedList),
		};
	}

	function quickLoad(sdata:HistoryElement) {
		base.load(sdata.d);
		openedList = haxe.Unserializer.run(sdata.o);
	}

	public function compressionEnabled() {
		return base.compress;
	}

	function error( msg ) {
		js.Browser.alert(msg);
	}

	public function loadFile(callback: Void -> Void, errorCallback: String -> Void) {
		history = [];
		redo = [];
		base = new cdb.Database();
		
		BrowserFile.openFile(function(content: String) {
			try {
				base.load(content);
				if( prefs.curSheet > base.sheets.length )
					prefs.curSheet = 0;
				else while( base.sheets[prefs.curSheet].props.hide )
					prefs.curSheet--;
			} catch( e : Dynamic ) {
				errorCallback(Std.string(e));
				prefs.curFile = null;
				prefs.curSheet = 0;
				base = new cdb.Database();
			}
			
			// Load images
			var img = prefs.curFile.split(".");
			img.pop();
			var imgPath = img.join(".") + ".img";
			// Note: In browser, we can't auto-load images. They need to be loaded manually.
			imageBank = null;
			
			curSavedData = quickSave();
			if (callback != null) callback();
		});
	}

	public function setCurrentFile(fileName: String) {
		prefs.curFile = fileName;
		addRecent(fileName);
		savePrefs();
	}

	function addRecent(file: String) {
		var found = false;
		for( f in prefs.recent.copy() ) {
			if( f == file ) {
				prefs.recent.remove(f);
				prefs.recent.unshift(f);
				found = true;
				break;
			}
		}
		if( !found )
			prefs.recent.unshift(file);
		if( prefs.recent.length > 10 )
			prefs.recent.pop();
	}

	function cleanImages() {
		if( imageBank == null )
			return;
		var used = new Map();
		for( s in base.sheets )
			for( c in s.columns ) {
				switch( c.type ) {
				case TImage:
					for( obj in s.getLines() ) {
						var v = Reflect.field(obj, c.name);
						if( v != null ) used.set(v, true);
					}
				default:
				}
			}
		for( f in Reflect.fields(imageBank) )
			if( !used.get(f) )
				Reflect.deleteField(imageBank, f);
	}

	function loadPrefs() {
		try {
			var stored = js.Browser.getLocalStorage().getItem("castle_prefs");
			if (stored != null) {
				prefs = haxe.Unserializer.run(stored);
				if( prefs.recent == null ) prefs.recent = [];
			}
		} catch( e : Dynamic ) {
		}
	}

	function savePrefs() {
		try {
			js.Browser.getLocalStorage().setItem("castle_prefs", haxe.Serializer.run(prefs));
		} catch( e : Dynamic ) {
		}
	}

}
