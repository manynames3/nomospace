#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release

APP_DIR="$ROOT_DIR/.build/release/nomospace.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/nomospace" "$MACOS_DIR/nomospace"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ -f "$ROOT_DIR/Packaging/nomospace.icns" ]; then
  cp "$ROOT_DIR/Packaging/nomospace.icns" "$RESOURCES_DIR/nomospace.icns"
else
  echo "warning: Packaging/nomospace.icns is missing; app bundle will use the default icon" >&2
fi

RESOURCE_BUNDLE="$ROOT_DIR/.build/release/nomospace_nomospace.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
  echo "error: SwiftPM resource bundle was not built: $RESOURCE_BUNDLE" >&2
  exit 1
fi

cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/nomospace_nomospace.bundle"

if command -v codesign >/dev/null 2>&1; then
  if ! codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1; then
    echo "warning: ad-hoc signing failed; app bundle was still created" >&2
  fi
fi

"$MACOS_DIR/nomospace" --self-test >/dev/null

echo "$APP_DIR"
