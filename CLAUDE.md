# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CastleDB is a Haxe library for structured database editing — a spreadsheet-like editor for game data (items, monsters, etc.). Data is stored in JSON format with newline-delimited records for easy GIT diff/merge collaboration.

The editor has been rewritten and integrated with [HIDE](https://github.com/heapsio/hide), but the **Castle library** is still actively developed here.

## Build Commands

### Build Desktop (NWJS)
```bash
haxe castle.hxml
```
Outputs to `bin/castle.js`

### Build Browser Version (Recommended for macOS ARM64)
```bash
haxe build-browser.hxml
```
Outputs to `bin/castle-browser.js`

### Run Tests (JavaScript)
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

### Serve Browser Version
```bash
cd bin && python3 -m http.server 8080
```
Then open `http://localhost:8080/index-browser.html`

## Architecture

| Directory | Purpose |
|-----------|---------|
| `/cdb/` | Core database library (Database, Sheet, Types, Parser, Macros) |
| `/src/` | Main application source (Main.hx, CastleDBApp.hx, Model.hx) |
| `/src/lvl/` | Level editor (Image, Image3D, LayerData, LayerGfx, Palette) |
| `/src/js/node/webkit/` | NWJS bindings (Window, App, Menu, MenuItem, Clipboard, Shell) |
| `/src/sys/` | Browser sys stubs for cross-platform compatibility |
| `/src/test/` | Unit tests using haxe.unit.TestCase |
| `/test/` | Test database files (*.cdb, *.img) |
| `/test/cdb_reader/` | C-based CDB reader with QuickJS bindings |
| `/bin/` | Build output and web resources |

## CDB File Format

Column types are identified by integer index:
- `0` = TId, `1` = TString, `2` = TBool, `3` = TInt, `4` = TFloat
- `5:values` = TEnum, `6:refSheet` = TRef, `7` = TImage, `8` = TList
- `9:values` = TCustom, `10:values` = TFlags, `11` = TColor
- `12:layerType` = TLayer, `13` = TFile, `14` = TTilePos, `15` = TTileLayer
- `16` = TDynamic, `17` = TProperties, `18` = TGradient, `19` = TCurve, `20` = TGuid, `21` = TPolymorph

Use `typeStr` (string) not `type` (integer) in column definitions.

## Code Style

### Copyright Header
Every source file must begin with the ISC license header:
```haxe
/*
 * Copyright (c) [YEAR], [Author Name]
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted...
 */
```

### Naming Conventions
- **Classes/Types**: `PascalCase` (e.g., `Database`, `Sheet`, `ColumnType`)
- **Variables/Functions**: `camelCase` (e.g., `getSheet`, `sheetName`)
- **Enums**: `PascalCase` for both enum and constructors (e.g., `TInt`, `TBool`)
- **Static constants**: `PascalCase` with underscores (e.g., `GUID_INCR`)

### Type Annotations
Always use explicit type annotations for function parameters and return types.

### JavaScript Interop
Use `js.Syntax.code()` instead of deprecated `untyped __js__()`:
```haxe
js.Syntax.code("window.myVar = {0}", value);
```

## Build Configuration Files

- `castle.hxml` — Main desktop build (outputs `bin/castle.js`)
- `build-browser.hxml` — Browser version build (outputs `bin/castle-browser.js`)
- `src/test/test-js.hxml` — JavaScript tests
- `src/test/test-hl.hxml` — HashLink tests
- `src/test/test-cdb-js.hxml` — CDB parser tests
