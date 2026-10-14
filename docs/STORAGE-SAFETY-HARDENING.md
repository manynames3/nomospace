# NomoSpace storage reliability improvements

This implementation uses native macOS APIs, conservative cleanup rules, and independent regression tests.

## Implemented

- Centralized, fail-closed cleanup validation at selection and immediately before each Trash move.
- Protected personal and app-state paths, as well as out-of-home, missing, symlinked, and partially scanned targets.
- Running-app heuristics and a three-second bounded lsof open-file check. Output is checked even if exit status is 1.
- Unknown caches now require Review instead of being Safe by default.
- 25 rules, including inspection-only AI runtime data, containers, signed Xcode archives and Steam libraries.
- Read-only on-demand child-folder breakdown with explicit sampling disclosure.
- Actual macOS available disk capacity is shown separately from estimated file contents moved to Trash.
- Native safety tests, rule validation, and a macOS CI workflow.

## Remaining limitations

1. Allocated file-size totals are not exact APFS reclaimable capacity. Clones, snapshots, purgeable storage and filesystem accounting may differ. The available-capacity metric comes from macOS.
2. Open-file checks time out after three seconds and fail closed.
3. A small time-of-check-to-time-of-use race remains between validation and Finder Trash because there is no descriptor-anchored atomic Trash API.
4. Storage discovery is targeted, not exhaustive. Inspect shows up to 20 largest children among the first 120 inspected.
5. Native signing, notarization, field tests and payment licensing are not included in this change.

## Verification

Run scripts/test.sh using a full Xcode installation. The independent Foundation/AppKit safety tests can be run without Xcode SwiftUI plugins:

    swiftc -swift-version 6 -framework AppKit Sources/nomospace/Models.swift Sources/nomospace/CleanupSafety.swift Sources/nomospace/StorageScanner.swift Sources/nomospace/FolderInspector.swift Tests/CleanupSafetyTests.swift -o /tmp/nomospace-safety-tests
    /tmp/nomospace-safety-tests
    python3 Tests/test_rules.py
