# Deployment

nomospace has two deployable surfaces:

- Native macOS app bundle for demos and beta testing.
- Static sales landing page on Cloudflare Pages.

## macOS app

Build and package the local demo app:

```sh
scripts/test.sh
scripts/package-app.sh
open .build/release/nomospace.app
```

The package script copies the SwiftPM resource bundle, copies the app icon, ad-hoc signs the bundle when possible, and runs the app self-test.

Production distribution still needs:

- Developer ID signing.
- Apple notarization.
- DMG or signed ZIP packaging.
- Real-device beta testing across several macOS machines.

## Cloudflare Pages

The sales page is a static site in `landing/`.

Production URL:

[https://nomospace.pages.dev](https://nomospace.pages.dev)

Local preview:

```sh
python3 -m http.server 8788 -d landing
```

Regenerate page assets:

```sh
swift scripts/make-landing-assets.swift
```

Deploy:

```sh
wrangler pages deploy landing --project-name nomospace --branch main
```

The project config is in `wrangler.toml`.
