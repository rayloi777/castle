# CastleDB Agent Guidelines

## Project Overview

CastleDB is a Haxe library for structured database editing. Source code uses `.hx` files and targets JavaScript (node.js/web) and HashLink.

**Browser Version**: A full-featured browser-based editor that works on all platforms including macOS ARM64, using the File System Access API for direct file read/write.

## Build Commands

### Build (Desktop NWJS)
```bash
haxe castle.hxml
```
Outputs to `bin/castle.js`

### Run Tests (JS)
```bash
cd src/test
haxe test-js.hxml && node test.js
```

### Run Tests (HashLink)
```bash
cd src/test
haxe test-hl.hxml && ../../hashlink/hl test.hl
```

### Install Dependencies
```bash
haxelib install castle.hxml
```

### Browser Version Build (Recommended for macOS ARM64)

The browser version provides full sheet editing functionality without requiring NWJS:

1. **Build the browser version:**
```bash
cd /path/to/castle
/usr/local/bin/haxe build-browser.hxml
```
Outputs to `bin/castle-browser.js`

2. **Serve the browser version:**
```bash
cd bin
python3 -m http.server 8080
```

3. **Open in browser:**
Navigate to `http://localhost:8080/index-browser.html`

**Browser Version Features:**
- Open/Save .cdb files using File System Access API
- Create new sheets and columns
- Add/Delete rows
- Edit all column types (string, int, float, bool, enum, color, image, etc.)
- Undo/Redo support
- Search/Filter rows
- Column context menu (rename, delete, move, convert type)
- Row context menu (duplicate, insert, delete, separator)
- Sheet tabs with context menu
- Image upload to localStorage image bank
- Color picker with alpha channel (spectrum-colorpicker2)
- Gradient and Curve editors
- Keyboard shortcuts (Ctrl+S/Z/Y/F, Delete, Escape)

**Browser Limitations:**
- Does not include the Level Editor functionality
- Requires HTTPS or localhost for File System Access API

### macOS ARM64 Build (NWJS v0.109.1)

NW.js v0.109.1 provides **native ARM64 support** for macOS without Rosetta 2 translation.

**Fixed Issues:**
- `nwsaveas` (Save As dialog) crash on ARM64 (Issue #8334) - **FIXED in v0.109.1**

**Known Issues:**
- Dev Tools menu is removed due to crash on ARM64 (Issue #8302)

1. **Download NWJS v0.109.1 ARM64:**
```bash
cd bin
# Backup old version if exists
mv nwjs.app nwjs.app.v109.0.bak 2>/dev/null || true

# Download ARM64 build
curl -L -o nwjs.zip "https://dl.nwjs.io/v0.109.1/nwjs-v0.109.1-osx-arm64.zip"
unzip -q nwjs.zip
mv nwjs-v0.109.1-osx-arm64/nwjs.app ./
rm nwjs.zip
mkdir -p nwjs.app/Contents/Resources/app.nw
```

2. **Build castle.js:**
```bash
haxe castle.hxml
```

3. **Copy files to app.nw:**
```bash
cp -R bin/cdb.cmd bin/dock bin/icon.* bin/index.html bin/libs bin/package.json bin/Release.hx bin/style.* bin/castle.js bin/nwjs.app/Contents/Resources/app.nw/
```

4. **Fix extended attributes** (prevents "app is damaged" error):
```bash
xattr -cr bin/nwjs.app
```

5. **Run:**
```bash
open bin/nwjs.app
```

**ARM64 Behavior:**
| Feature | Status | Notes |
|---------|--------|-------|
| Open File | ✅ Works | Standard HTML file dialog |
| Save | ✅ Works | System Save As dialog works (nwsaveas fixed in v0.109.1) |
| Export XML | ✅ Works | System Save As dialog works |
| Dev Tools | ❌ Removed | Crashes on ARM64 |
| Other features | ✅ Works | Full functionality |

## Code Style

### File Structure
```
/cdb/          - Core database library (Database, Sheet, Types, Parser, etc.)
/src/          - Main application entry point (Main.hx, CastleDBApp.hx)
/src/lvl/      - Level editor functionality
/src/js/       - JavaScript/nodewebkit bindings
/src/sys/      - Browser sys stubs for cross-platform compatibility
/src/test/     - Unit tests using haxe.unit
/test/         - Test database files (*.cdb)
/bin/          - Build output and browser version files
```

### Copyright Header
Every source file must begin with this ISC license header:
```haxe
/*
 * Copyright (c) [YEAR], [Author Name]
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
```

### Naming Conventions
- **Classes/Types**: `PascalCase` (e.g., `Database`, `Sheet`, `ColumnType`)
- **Variables/Functions**: `camelCase` (e.g., `getSheet`, `sheetName`, `parseValue`)
- **Private classes**: Prefixed with lowercase (e.g., `arrayIterator`, `flagsIterator`)
- **Static constants**: `PascalCase` with underscores for word separation (e.g., `GUID_INCR`, `HandleData`)
- **Enums**: `PascalCase` for both enum and constructors (e.g., `TInt`, `TBool`, `CurveKeyMode`)
- **Abstract types**: `PascalCase` (e.g., `ArrayRead<T>`, `Flags<T>`, `Curve`)

### Imports
```haxe
// Standard package imports
import cdb.Data;
import cdb.Sheet;

// External library imports
import js.jquery.Helper.*;
import js.jquery.JQuery;
import js.node.webkit.Menu;

// Use wildcard sparingly, prefer explicit imports
```

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Curly braces**: Same-line style for classes/functions, newline for control flow
- **Line length**: No strict limit, but keep under ~120 characters when practical
- **Whitespace**: One space after commas, around operators, not inside parentheses
  ```haxe
  function getSheet( name : String ) {
      return smap.get(name);
  }
  ```

### Type Annotations
- Always use explicit type annotations for function parameters and return types
- Use `Dynamic` sparingly, prefer proper types
- Use `@:privateAccess` to access private members when necessary
  ```haxe
  @:privateAccess psheet.sheet.lines[0] = val;
  ```
- Use `inline` functions for performance-critical or trivial accessors
- Use `cast` for type assertions when type system requires it

### JavaScript Interop
For browser compatibility, use `js.Syntax.code()` instead of deprecated `untyped __js__()`:
```haxe
// Correct - use js.Syntax.code with placeholders
js.Syntax.code("window.myVar = {0}", value);
js.Syntax.code("console.log({0})", message);

// Avoid - deprecated
untyped __js__("window.myVar = value");
```

### Error Handling
- Use `throw "message"` for assertion failures and unrecoverable errors
- Use `try/catch` blocks with specific exception types when parsing
  ```haxe
  try base.parseTypeVal(t, str) catch( msg : String ) {
      setErrorMessage(msg);
      i.addClass("error");
  }
  ```
- Return `null` for missing optional values rather than throwing
- Use `assertEquals`, `assertTrue` in unit tests

### Pattern Matching
- Use `switch` expressions for enum discrimination
- Use `case` guards for complex conditions
  ```haxe
  switch( c.type ) {
  case TRef(s):
      var sd = base.getSheet(s);
      if( sd != null ) { ... }
  default:
  }
  ```

### Enums and Abstracts
- Enums use `enum abstract` for type-safe primitives
- Abstracts wrap underlying types for custom behavior
  ```haxe
  enum abstract CurveKeyMode(Int) {
      var Aligned = 0;
      var Free = 1;
  }
  
  abstract Curve(CurveData) from CurveData {
      public function eval(t: Float) : Float { ... }
  }
  ```

### Collections
- Use `Array`, `Map`, `List` from Haxe standard library
- Use `Lambda` module functions for functional operations
- Use `ArrayRead<T>` abstract for read-only array access
- Use `Iterable<T>` for duck-typed iteration

### Macros
- Macro code goes in `#if macro` blocks
- Use `@:macro` metadata for macro-generated code
- Use `Context.error()` for compile-time errors
- Use `using Lambda` in macro context for collection utilities

### Testing
- Tests extend `haxe.unit.TestCase`
- Use `assertEquals(expected, actual)` and `assertTrue(condition)`
- Test files go in `src/test/` with corresponding `.hxml` build files
- Main entry point for tests uses `TestRunner`

## Build Configuration

### Main build (castle.hxml)
```
-cp src              Source path
-js bin/castle.js    JavaScript output
-main Main           Entry point
-lib hxnodejs        Node.js support
-lib hx3compat       Haxe 3 compatibility
-lib format          JSON/file parsing
-lib hxbit           Binary serialization
-D lz4js             LZ4 compression for JS
```

### Browser build (build-browser.hxml)
```
-cp src              Source path
-cp .                Root for MainBrowser
-js bin/castle-browser.js
-main MainBrowser     Browser entry point
-cp /usr/local/lib/haxe/lib/hx3compat/git/std/
-D js-es=6           ES6 JavaScript output
```

### Test build (test-js.hxml)
```
-lib castle          Local castle library
-cp .                Test source path
-js test.js          Test output
-cp res              Test resources
-main TestCastle      Test entry
-dce no              Disable dead code elimination
```

## Common Patterns

### Private Helper Classes
```haxe
private class ArrayIterator<T> {
    var a : Array<T>;
    var pos : Int;
    public inline function new(a) { ... }
}
```

### Typedefs for Structs
```haxe
typedef TilePos = {
    var file(default, never) : String;
    var size(default, never) : Int;
    var x(default, never) : Int;
    var y(default, never) : Int;
    var width(default, never) : Null<Int>;
    var height(default, never) : Null<Int>;
}
```

### Dynamic Field Access
Use `Reflect.field()` and `Reflect.setField()` for dynamic property access. Use `Reflect.deleteField()` to remove fields.

### Conditional Compilation
```haxe
#if sys
    Sys.exit(succeed ? 0 : 1);
#else
    if (!succeed) throw "failed";
#end
```

## CDB File Format

### Column Type Index
When creating CDB files programmatically, use these type indices:
- `0` = TId (unique identifier)
- `1` = TString (text)
- `2` = TBool (boolean)
- `3` = TInt (integer)
- `4` = TFloat (float/double)
- `5:values` = TEnum (comma-separated values)
- `6:refSheet` = TRef (reference to another sheet)
- `7` = TImage
- `8` = TList
- `9:values` = TCustom/custom type
- `10:values` = TFlags (bitfield flags)
- `11` = TColor
- `12:layerType` = TLayer
- `13` = TFile
- `14` = TTilePos
- `15` = TTileLayer
- `16` = TDynamic
- `17` = TProperties
- `18` = TGradient
- `19` = TCurve
- `20` = TGuid
- `21` = TPolymorph

### CDB JSON Structure
```json
{
  "sheets": [
    {
      "name": "SheetName",
      "columns": [
        {"Name": "id", "typeStr": "0", "opt": false},
        {"Name": "name", "typeStr": "1", "opt": false},
        {"Name": "type", "typeStr": "5:value1,value2,value3", "opt": false}
      ],
      "lines": [
        {"id": "001", "name": "Item 1", "type": "value1"},
        {"id": "002", "name": "Item 2", "type": "value2"}
      ],
      "props": {"displayColumn": "name"},
      "separators": []
    }
  ],
  "customTypes": [],
  "compress": false
}
```

Note: Use `typeStr` (string) not `type` (integer) for column definitions.
