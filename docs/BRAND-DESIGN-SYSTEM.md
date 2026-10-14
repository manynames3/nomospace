# NomoSpace Brand UI / UX: Ink Ledger

Source of visual language: https://supremeaiventures.dev (reviewed 2026-10-14).
Claude Code (authenticated claude.ai subscription, Opus/high, read-only)
independently reviewed the original SwiftUI application and recommended the
"Ink Ledger" design direction. Design is implemented in native SwiftUI.

## Principles

- **Ink is factual.** Dark, technical audit summary with actual macOS capacity
  and on-device status labels. No fabricated diagnostic data or marketing fear.
- **Mineral paper is for decisions.** Light #EDF0EE canvas, subtle #F9FBF9
  findings surfaces, crisp hairline separators; dark mode adapts to #0B1416.
- **Teal is actionable.** #0B6B73 interactive emphasis on light surfaces,
  #5CC4B8 on dark; mint #9FE0D6 as a dark-band CTA fill.
- **Risk colors are separate** from brand and from the access-code paywall.
  All risk levels include a written label and icon, never color alone.
- **Mac-native.** SF font and native SwiftUI controls, no third-party font
  distribution, no network fetches, no background animations.
- **Trustworthy storage math.** Capacity bar represents macOS estimated
  free/total storage, not a sum of recoverable findings. Trash is not a
  promise of immediate storage recovery.

## Tokens and components

Design.swift defines adaptive canvas, surface, border, ink, mint, risk and
muted text colors; typography tokens and reusable button / panel components.
The sidebar uses a dark brand rail and clear nav states. Audit uses a dark
capacity-and-status ledger, compact file findings, and filters. Cleanup
confirmation shows the explicit Selected -> Trash -> Empty Trash progression.

## UX regression checklist

1. 1080x720 light and dark: no clipped actions or missing risk labels.
2. At larger text, names can wrap; search and filter controls remain accessible.
3. VoiceOver: sidebar and filter selected state; descriptive select/reveal labels.
4. Reduced Motion: no slide transitions for selected item dock or row expansion.
5. Incomplete / protected findings are inspection-only.
6. Review selections still require confirmation and cleanup safety validation.
7. No data, scans, files, permissions or license behavior change from styling.
8. Cross-check actual screenshots on a macOS release build before distribution.

## Further refinements

This UI change deliberately does not copy homepage canvas animations into an
audit app, does not ship the website font, and does not change the cleanup
engine. Future iterations can add richer APFS-aware visualization after
disk accounting is verified independently.

## Reviewing the build

GitHub Actions packages an **ad-hoc signed, unnotarized review ZIP** as a
short-lived workflow artifact. This is for an authorized Mac UI review only,
not a public release. Verify the commit and its build provenance and do not
present the artifact as notarized production software.
