#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build
plutil -lint Packaging/Info.plist >/dev/null
python3 -m json.tool Sources/nomospace/Resources/Rules/storage-rules.json >/dev/null
test -f Packaging/nomospace.icns

grep -q '"id": "apple-aerial-wallpaper-videos"' Sources/nomospace/Resources/Rules/storage-rules.json
grep -q '"risk": "review"' Sources/nomospace/Resources/Rules/storage-rules.json
grep -q '"risk": "safe"' Sources/nomospace/Resources/Rules/storage-rules.json

.build/debug/nomospace --self-test >/dev/null

echo "nomospace smoke tests passed"
