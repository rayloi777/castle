# CastleDB Agent Guidelines

## Project Overview

CastleDB is a Haxe library for structured database editing. Source code uses `.hx` files and targets JavaScript (node.js/web) and HashLink.

## Build Commands

### Build
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

### macOS ARM64 Build (Legacy NWJS Editor)

The main editor uses NWJS (node-webkit) which only has x64 binaries. On Apple Silicon (ARM64), use Rosetta 2 translation.

1. **Register castle as dev library:**
```bash
haxelib dev castle /path/to/castle
```

2. **Download NWJS:**
```bash
cd bin
curl -L -o nwjs.zip "https://dl.nwjs.io/v0.87.0/nwjs-v0.87.0-osx-x64.zip"
unzip -q nwjs.zip
mv nwjs-v0.87.0-osx-x64/nwjs.app ./
rm nwjs.zip
mkdir -p nwjs.app/Contents/Resources/app.nw
```

3. **Build castle.js** (requires workaround for hxnodejs sys package):
```bash
cat > /tmp/build-js.hxml << 'EOF'
--macro allowPackage('sys')
--macro define('nodejs')
--macro _internal.SuppressDeprecated.run()
-cp src
-js bin/castle.js
-main Main
-cp /usr/local/lib/haxe/lib/hxnodejs/git/src/
-cp /usr/local/lib/haxe/lib/hx3compat/git/std/
-cp /usr/local/lib/haxe/lib/format/3,8,0/
-cp /usr/local/lib/haxe/lib/hxbit/1,5,0/
-D hxnodejs=12.2.0
-D lz4js
EOF
haxe /tmp/build-js.hxml
```

4. **Copy files to app.nw:**
```bash
cp -R bin/cdb.cmd bin/dock bin/icon.* bin/index.html bin/libs bin/package.json bin/Release.hx bin/style.* bin/castle.js bin/nwjs.app/Contents/Resources/app.nw/
```

5. **Run via Rosetta 2:**
```bash
open bin/nwjs.app
```

### Browser Version Build

For a browser-based version that works on all platforms (including macOS ARM64):

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

The browser version provides basic sheet editing functionality:
- Open/Save .cdb files
- Create new sheets and columns
- Add/Delete rows
- Basic data editing

Note: The browser version does not include the Level Editor functionality.

## Code Style

### File Structure
```
/cdb/          - Core database library (Database, Sheet, Types, Parser, etc.)
/src/          - Main application entry point (Main.hx)
/src/lvl/      - Level editor functionality
/src/js/       - JavaScript/nodewebkit bindings
/src/test/     - Unit tests using haxe.unit
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
