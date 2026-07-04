# Changelog

## 2026-07-04

### Fixed

- Fixed a packaged-app launch crash caused by SwiftPM's generated `Bundle.module` resource accessor looking for `nomospace_nomospace.bundle` in the development `.build` directory after the app was moved or downloaded.
- The storage rule loader now resolves `storage-rules.json` from packaged app resources first, then executable-adjacent resources, then the source-tree fallback used during local development.
- `scripts/package-app.sh` now validates the packaged app while the build-output resource bundle is temporarily hidden, so release packaging fails if the app accidentally depends on the repo's `.build` folder.
