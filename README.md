# nomospace

nomospace is a Mac Storage Auditor: a native macOS app that finds hidden storage, explains what created it, and lets users choose what to move to Trash.

Positioning:

> Your Mac is full. nomospace shows exactly why.

## Run locally

```sh
cd nomospace
swift run nomospace
```

This Swift Package builds a native SwiftUI macOS executable. A full app bundle/export step can be added once the product shape is settled.

## Build a local `.app`

```sh
cd nomospace
chmod +x scripts/package-app.sh
scripts/package-app.sh
open .build/release/nomospace.app
```

## Product principles

- Audit before cleanup.
- Show human explanations, not just paths.
- Default to moving items to Trash.
- Never auto-select personal files, browser profiles, cloud folders, or risky app data.
- Every finding should answer: what is this, why is it big, and what happens if I remove it?
