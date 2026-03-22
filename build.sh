#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building CastleDB..."

echo "1. Building castle.js..."
haxe castle.hxml

echo "2. Copying to nwjs.app..."
cp -R bin/castle.js bin/cdb.cmd bin/dock bin/icon.* bin/index.html bin/libs bin/package.json bin/Release.hx bin/style.* bin/nwjs.app/Contents/Resources/app.nw/

echo "3. Fixing extended attributes..."
xattr -cr bin/nwjs.app 2>/dev/null || true

echo "Build complete!"
