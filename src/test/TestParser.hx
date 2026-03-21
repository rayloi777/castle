/*
 * Copyright (c) 2025, CastleDB Contributors
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
package test;

import haxe.unit.*;
import cdb.Parser;
import cdb.Data.ColumnType;

class TestParser extends TestCase {
	
	function testGetTypeIndex() {
		assertEquals(TId, Parser.getType("0"));
		assertEquals(TString, Parser.getType("1"));
		assertEquals(TBool, Parser.getType("2"));
		assertEquals(TInt, Parser.getType("3"));
		assertEquals(TFloat, Parser.getType("4"));
		assertEquals(TImage, Parser.getType("7"));
		assertEquals(TList, Parser.getType("8"));
		assertEquals(TColor, Parser.getType("11"));
		assertEquals(TFile, Parser.getType("13"));
		assertEquals(TDynamic, Parser.getType("16"));
		assertEquals(TGuid, Parser.getType("20"));
	}
	
	function testGetTypeEnum() {
		assertTrue(Parser.getType("5:a,b").match(TEnum(["a", "b"])));
		assertTrue(Parser.getType("5:x,y,z").match(TEnum(["x", "y", "z"])));
	}
	
	function testGetTypeRef() {
		assertTrue(Parser.getType("6:sheet").match(TRef("sheet")));
		assertTrue(Parser.getType("6:monsters").match(TRef("monsters")));
	}
	
	function testGetTypeCustom() {
		assertTrue(Parser.getType("9:MyType").match(TCustom("MyType")));
		assertTrue(Parser.getType("9:Effect2").match(TCustom("Effect2")));
	}
	
	function testGetTypeFlags() {
		assertTrue(Parser.getType("10:x,y").match(TFlags(["x", "y"])));
		assertTrue(Parser.getType("10:a,b,c,d").match(TFlags(["a", "b", "c", "d"])));
	}
	
	function testGetTypeLayer() {
		assertTrue(Parser.getType("12:layer").match(TLayer("layer")));
		assertTrue(Parser.getType("12:Ground").match(TLayer("Ground")));
	}
	
	function testGetTypeUnknown() {
		var caught = false;
		try {
			Parser.getType("999");
		} catch(e: Dynamic) {
			caught = true;
		}
		assertTrue(caught);
	}
	
	function testGetTypeString() {
		assertEquals(TId, Parser.getType("id"));
		assertEquals(TString, Parser.getType("string"));
		assertEquals(TInt, Parser.getType("int"));
		assertEquals(TFloat, Parser.getType("float"));
		assertEquals(TBool, Parser.getType("bool"));
	}
	
	function testSaveTypeIndex() {
		assertEquals("0", Parser.saveType(TId));
		assertEquals("1", Parser.saveType(TString));
		assertEquals("2", Parser.saveType(TBool));
		assertEquals("3", Parser.saveType(TInt));
		assertEquals("4", Parser.saveType(TFloat));
	}
	
	function testSaveTypeEnum() {
		assertEquals("5:a,b", Parser.saveType(TEnum(["a", "b"])));
		assertEquals("5:x,y,z", Parser.saveType(TEnum(["x", "y", "z"])));
	}
	
	function testSaveTypeRef() {
		assertEquals("6:sheet", Parser.saveType(TRef("sheet")));
		assertEquals("6:monsters", Parser.saveType(TRef("monsters")));
	}
	
	function testSaveTypeCustom() {
		assertEquals("9:MyType", Parser.saveType(TCustom("MyType")));
	}
	
	function testSaveTypeFlags() {
		assertEquals("10:x,y", Parser.saveType(TFlags(["x", "y"])));
	}
	
	function testSaveTypeLayer() {
		assertEquals("12:layer", Parser.saveType(TLayer("layer")));
	}
	
	function testSaveTypeRoundTrip() {
		var types = [TId, TString, TBool, TInt, TFloat, TImage, TList, TColor, TFile, TDynamic, TGuid];
		for(t in types) {
			var saved = Parser.saveType(t);
			var restored = Parser.getType(saved);
			assertEquals(t, restored);
		}
	}
	
	function testParseMinimal() {
		var data = Parser.parse('{"sheets":[],"customTypes":[],"compress":false}', true);
		assertEquals(0, data.sheets.length);
		assertEquals(0, data.customTypes.length);
	}
	
	function testParseSheet() {
		var json = '{"sheets":[{"name":"Test","columns":[{"name":"id","typeStr":"0","opt":false}],"lines":[],"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		assertEquals(1, data.sheets.length);
		assertEquals("Test", data.sheets[0].name);
		assertEquals(1, data.sheets[0].columns.length);
		assertEquals("id", data.sheets[0].columns[0].name);
		assertEquals(TId, data.sheets[0].columns[0].type);
	}
	
	function testParseMultipleColumnTypes() {
		var json = '{"sheets":[{"name":"Test","columns":[' +
			'{"name":"id","typeStr":"0","opt":false},' +
			'{"name":"name","typeStr":"1","opt":false},' +
			'{"name":"active","typeStr":"2","opt":false},' +
			'{"name":"count","typeStr":"3","opt":false},' +
			'{"name":"rate","typeStr":"4","opt":false},' +
			'{"name":"kind","typeStr":"5:a,b,c","opt":false}' +
		'],"lines":[],"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		var cols = data.sheets[0].columns;
		assertEquals(6, cols.length);
		assertEquals(TId, cols[0].type);
		assertEquals(TString, cols[1].type);
		assertEquals(TBool, cols[2].type);
		assertEquals(TInt, cols[3].type);
		assertEquals(TFloat, cols[4].type);
		assertTrue(cols[5].type.match(TEnum(_)));
	}
	
	function testParseLines() {
		var json = '{"sheets":[{"name":"Items","columns":[{"name":"id","typeStr":"0","opt":false},{"name":"name","typeStr":"1","opt":false}],"lines":[{"id":"001","name":"Sword"},{"id":"002","name":"Shield"}],"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		var lines = data.sheets[0].lines;
		assertEquals(2, lines.length);
		assertEquals("001", Reflect.field(lines[0], "id"));
		assertEquals("Sword", Reflect.field(lines[0], "name"));
		assertEquals("002", Reflect.field(lines[1], "id"));
		assertEquals("Shield", Reflect.field(lines[1], "name"));
	}
	
	function testParseNullContent() {
		var caught = false;
		try {
			Parser.parse(null, true);
		} catch(e: Dynamic) {
			caught = true;
			assertEquals("CDB content is null", e);
		}
		assertTrue(caught);
	}
	
	function testParseEmptySheets() {
		var json = '{"sheets":[],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, false);
		assertEquals(0, data.sheets.length);
	}
	
	function testParseNullLines() {
		var json = '{"sheets":[{"name":"Test","columns":[{"name":"id","typeStr":"0"}],"lines":null,"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		assertEquals(0, data.sheets[0].lines.length);
	}
	
	function testParseSeparatorsNotModified() {
		var json = '{"sheets":[{"name":"Test","columns":[{"name":"id","typeStr":"0","opt":false}],"lines":[{"id":"1"},{"id":"2"}],"props":{},"separators":[{"index":1}]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		assertEquals(1, data.sheets[0].separators.length);
	}
	
	function testSaveParseRoundTrip() {
		var original = '{"sheets":[{"name":"Test","columns":[{"name":"id","typeStr":"0","opt":false},{"name":"name","typeStr":"1","opt":false}],"lines":[{"id":"001","name":"Item"}],"props":{"displayColumn":"name"},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(original, true);
		var saved = Parser.save(data);
		var reparsed = Parser.parse(saved, true);
		assertEquals(1, reparsed.sheets.length);
		assertEquals("Test", reparsed.sheets[0].name);
		assertEquals(2, reparsed.sheets[0].columns.length);
		assertEquals("001", Reflect.field(reparsed.sheets[0].lines[0], "id"));
		assertEquals("Item", Reflect.field(reparsed.sheets[0].lines[0], "name"));
	}
	
	function testSavePreservesColumnOrder() {
		var json = '{"sheets":[{"name":"Test","columns":[{"name":"a","typeStr":"1"},{"name":"b","typeStr":"3"},{"name":"c","typeStr":"1"}],"lines":[],"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		var saved = Parser.save(data);
		var reparsed = Parser.parse(saved, true);
		assertEquals("a", reparsed.sheets[0].columns[0].name);
		assertEquals("b", reparsed.sheets[0].columns[1].name);
		assertEquals("c", reparsed.sheets[0].columns[2].name);
	}
	
	function testSaveParseColumnTypeRoundTrip() {
		var json = '{"sheets":[{"name":"Test","columns":[{"name":"id","typeStr":"0"}],"lines":[],"props":{},"separators":[]}],"customTypes":[],"compress":false}';
		var data = Parser.parse(json, true);
		var saved = Parser.save(data);
		var reparsed = Parser.parse(saved, true);
		assertEquals(TId, reparsed.sheets[0].columns[0].type);
	}
	
	static function main() {
		var runner = new TestRunner();
		runner.add(new TestParser());
		
		#if sys
		var succeed = runner.run();
		Sys.exit(succeed ? 0 : 1);
		#else
		if (!runner.run()) throw "tests failed";
		#end
	}
}