# nomospace

nomospace is a native Mac Storage Auditor for people whose Mac is full but Apple Storage, CleanMyMac, CCleaner, or generic disk tools did not explain the real cause.

It finds hidden app-generated storage, explains what created it, labels cleanup risk, and lets users choose what to move to Trash.

> Your Mac is full. nomospace shows exactly why.

## Who it is for

- Mac users with large "System Data" or unexplained storage pressure.
- Photographers and creators with Adobe, Lightroom, Aftershoot, or media caches.
- Developers with Xcode, simulator, npm, pnpm, pip, uv, or local tool caches.
- Technical family/office helpers who need a clear cleanup report before deleting anything.

## What it does today

- Scans known hidden-storage locations and large first-level folders.
- Labels findings as `Safe`, `Usually Safe`, `Review`, or `Do Not Auto-Select`.
- Explains what each finding is and what happens if it is removed.
- Searches and filters findings by source, path, category, and risk.
- Moves selected items to macOS Trash first.
- Keeps a local cleanup receipt on the Mac.
- Exports a local Markdown audit report.
- Shows skipped paths so users know when Full Disk Access may be needed.

## What it does not do

- It does not upload file names, file contents, browser data, or cleanup history.
- It does not permanently delete files. Users empty Trash later if they are comfortable.
- It does not remove protected personal folders automatically.
- It is not antivirus, a duplicate finder, a RAM booster, or a broad app uninstaller.

## Run locally

```sh
cd nomospace
swift run nomospace
```

This Swift Package builds a native SwiftUI macOS executable. `scripts/package-app.sh` creates a local demo `.app`; production distribution still needs Developer ID signing and notarization.

## Build a local `.app`

```sh
cd nomospace
chmod +x scripts/package-app.sh
scripts/package-app.sh
open .build/release/nomospace.app
```

To regenerate the app icon:

```sh
cd nomospace
swift scripts/make-icon.swift
```

## Smoke test

```sh
cd nomospace
scripts/test.sh
```

The smoke test builds the app, validates packaging metadata, validates the bundled rule JSON, and runs the app's `--self-test` mode to confirm the cleanup rule library is available at runtime.

## Sales landing page

The static sales page lives in `landing/` and is deployed to Cloudflare Pages.

```sh
cd nomospace
swift scripts/make-landing-assets.swift
python3 -m http.server 8788 -d landing
wrangler pages deploy landing --project-name nomospace --branch main
```

## Demo flow

1. Launch the app.
2. Read the first-run trust panel.
3. Optional but recommended: open Full Disk Access and grant access to `nomospace`.
4. Run Storage Audit.
5. Search or filter findings.
6. Expand a finding to see path, source, risk rule, and side effect.
7. Export the audit report if the user wants a shareable receipt before cleanup.
8. Select only `Safe` or `Usually Safe` items for the demo.
9. Click `Move to Trash`.
10. Open `History` to see the local cleanup receipt.

## Monetization direction

The most realistic first paid offer is a simple utility purchase:

- Free: scan, top findings, risk explanations.
- Paid unlock: move to Trash, cleanup history, expanded rule library, exportable audit report.
- Suggested beta price: $19 one-time for early adopters.
- Later price: $29-$39 one-time or annual updates for the rule library.

The strongest first customer niche is Mac photographers, creators, and developers who have urgent disk pressure and cannot safely interpret `~/Library` on their own.

## Product principles

- Audit before cleanup.
- Show human explanations, not just paths.
- Default to moving items to Trash.
- Never auto-select personal files, browser profiles, cloud folders, or risky app data.
- Every finding should answer: what is this, why is it big, and what happens if I remove it?

## Privacy

See [PRIVACY.md](PRIVACY.md).

## Current MVP limits

- The app is not notarized yet.
- Payments are not implemented yet.
- The rule library is bundled with the app, not remotely updated.
- The scanner is optimized for high-signal known paths and large folders, not exhaustive file-by-file analysis.
