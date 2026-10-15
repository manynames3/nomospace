#!/usr/bin/env python3
"""Check one NomoSpace layered-glass identity across app and website."""
import struct
from pathlib import Path

def png_dimensions(path):
    data = Path(path).read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), f"Invalid PNG: {path}"
    return struct.unpack(">II", data[16:24])

assert png_dimensions("branding/nomospace-glass.png") == (1024, 1024)
assert png_dimensions("Sources/nomospace/Resources/Brand/nomospace-mark.png") == (512, 512)
assert png_dimensions("landing/assets/nomospace-icon.png") in [(512, 512), (1024, 1024)]

for asset in ["branding/nomospace-glass.svg", "branding/nomospace-mark.svg"]:
    s = Path(asset).read_text()
    assert "<svg " in s and "</svg>" in s
    assert "#9FE0D6" not in s or "mint" in s.lower()  # explicit mint documentation
    assert "https://" not in s and "http://" not in s.replace('http://www.w3.org/2000/svg', ''), "Unexpected external resources"

icns = Path("Packaging/nomospace.icns").read_bytes()
assert icns.startswith(b"icns"), "Not a macOS icon container"
assert len(icns) > 40_000, "Unexpectedly small Mac icon"

html = Path("landing/index.html").read_text()
assert '<img src="/assets/nomospace-icon.png"' in html
assert '<strong>Nomo</strong>Space' in html
assert '<span class="brand-mark">n</span>' not in html

code = Path("Sources/nomospace/Design.swift").read_text()
assert 'Bundle.module.url(' in code and '"nomospace-mark"' in code
assert "Abstract N mark" not in code

print("NomoSpace brand validation passed: app ICNS, master, native mark, site/favicon, wordmark")
