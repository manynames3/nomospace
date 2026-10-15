# NomoSpace — layered-glass identity

The user-approved direction is **three floating, translucent architectural glass panes** with a luminous mint discovery layer. This replaces the unrelated blue utility icon, the letter-N badge, and the website-only lowercase tile.

## Source of truth

- `nomospace-glass.svg`: editable vector source for the dark macOS app icon.
- `nomospace-glass.png`: 1024×1024 checked-in master derived from that SVG.
- `nomospace-mark.svg`: transparent version of the same shape for dark brand surfaces.
- `../Sources/nomospace/Resources/Brand/nomospace-mark.png`: 512px native navigation image.
- `../Packaging/nomospace.icns`: generated Mac iconset with all standard sizes.
- `../landing/assets/nomospace-icon.png`: matching website/favicon tile.

To adjust the shape, edit SVG source and regenerate the masters using `rsvg-convert` on a Mac:

```bash
rsvg-convert -w 1024 -h 1024 branding/nomospace-glass.svg > branding/nomospace-glass.png
rsvg-convert -w 512 -h 512 branding/nomospace-mark.svg > Sources/nomospace/Resources/Brand/nomospace-mark.png
swift scripts/make-icon.swift
swift scripts/make-landing-assets.swift
```

The native app build does **not** need an SVG renderer or network connection. Master PNG and generated ICNS files are checked into Git. The app icon script always uses this artwork; the landing asset generator copies the same master rather than painting a separate icon.

## Usage

Palette: ink `#0C1518`, mineral `#EDF0EE`, luminous mint `#9FE0D6`, secondary teal `#5CC4B8`. The three panes represent layers of hidden storage being revealed.

Wordmark: **Nomo** semibold + **Space** regular, in Instrument Sans on the website and native SF font in the app. Match the spacing and contrast of the approved concept board. Use the dark icon tile for app icons, favicons, and light-page branding; use the transparent mark within the dark navigation rail.

Do not substitute a globe, letter monogram, data cylinder, or unrelated abstract glyph. Keep the icon static; the live scanning animation is a separate experience.

**Distribution:** Updating artwork in the repository does not make a prior packaged release use the new icon. Before publishing a new signed/notarized installer, verify Dock/Finder icon cache behavior and the built app's resource bundle on a real Mac.
