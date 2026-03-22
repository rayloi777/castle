#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building CastleDB QuickJS..."

echo "1. Cleaning..."
make clean

echo "2. Building..."
make

echo "3. Testing..."
make test_exe

echo "Build complete!"
