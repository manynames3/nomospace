#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Foundation/AppKit core tests compile independently of the SwiftUI app.
mkdir -p .build/safety-tests
swiftc -swift-version 6 -framework AppKit \
  Sources/nomospace/Models.swift Sources/nomospace/CleanupSafety.swift \
  Sources/nomospace/StorageScanner.swift Sources/nomospace/FolderInspector.swift \
  Tests/CleanupSafetyTests.swift -o .build/safety-tests/cleanup-safety
.build/safety-tests/cleanup-safety

swift build
plutil -lint Packaging/Info.plist >/dev/null
python3 -m json.tool Sources/nomospace/Resources/Rules/storage-rules.json >/dev/null
python3 Tests/test_rules.py
test -f Packaging/nomospace.icns
test -f landing/index.html
test -f landing/styles.css
test -s landing/assets/nomospace-icon.png
test -s landing/assets/nomospace-hero-preview.png
test -s landing/assets/nomospace-report-preview.png
test -s landing/assets/nomospace-evaluation-mode.png
test -x scripts/package-download.sh
grep -q "Download evaluation build" landing/index.html
grep -q "Request access code" landing/index.html
grep -q "nomospace-evaluation-mode.png" landing/index.html
grep -q "rule-matrix" landing/index.html
grep -q "nomospace" landing/index.html

grep -q '"id": "apple-aerial-wallpaper-videos"' Sources/nomospace/Resources/Rules/storage-rules.json
grep -q '"risk": "review"' Sources/nomospace/Resources/Rules/storage-rules.json
grep -q '"risk": "safe"' Sources/nomospace/Resources/Rules/storage-rules.json

.build/debug/nomospace --self-test >/dev/null

echo "nomospace smoke tests passed"
