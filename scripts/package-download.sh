#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE_OUTPUT="$(scripts/package-app.sh)"
printf '%s\n' "$PACKAGE_OUTPUT"
APP_PATH="$(printf '%s\n' "$PACKAGE_OUTPUT" | tail -n 1)"
DIST_DIR="$ROOT_DIR/.build/dist"
ZIP_PATH="$DIST_DIR/nomospace-evaluation.zip"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
