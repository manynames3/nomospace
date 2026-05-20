# Deployment

nomospace has two deployable surfaces:

- Native macOS app bundle for demos and beta testing.
- Static sales landing page on Cloudflare Pages.

## macOS app

Build and package the local evaluation app:

```sh
scripts/test.sh
scripts/package-app.sh
scripts/package-download.sh
open .build/release/nomospace.app
```

The package script copies the SwiftPM resource bundle, copies the app icon, ad-hoc signs the bundle when possible, and runs the app self-test. The download script writes `.build/dist/nomospace-evaluation.zip` for GitHub Releases or website hosting.

The app opens in evaluation mode by default. Evaluation mode can audit and show findings; full access requires a local access code.

Production distribution still needs:

- Developer ID signing.
- Apple notarization.
- DMG or signed ZIP packaging for website download.
- Real-device beta testing across several macOS machines.
- A payment/licensing flow for issuing real customer codes.

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
