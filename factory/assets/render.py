"""Render HTML or SVG to exact-size PNGs with headless Chromium."""

from __future__ import annotations

import contextlib
from pathlib import Path

from PIL import Image


@contextlib.contextmanager
def browser():
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        b = p.chromium.launch()
        try:
            yield b
        finally:
            b.close()


def html_to_png(b, html: str, size: tuple[int, int], out: Path, *, transparent: bool = False) -> Path:
    """Render `html` at exactly `size` pixels. Opaque PNGs are saved as RGB (no alpha)."""
    w, h = size
    page = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
    try:
        page.set_content(html, wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        out.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(out), omit_background=transparent, clip={"x": 0, "y": 0, "width": w, "height": h})
    finally:
        page.close()
    img = Image.open(out)
    img = img.convert("RGBA") if transparent else img.convert("RGB")
    img.save(out, optimize=True)
    return out


def svg_to_png(b, svg_path: Path, size: int, out: Path, *, transparent: bool) -> Path:
    svg = svg_path.read_text(encoding="utf-8")
    html = (
        "<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent}"
        f"svg{{display:block;width:{size}px;height:{size}px}}</style></head><body>{svg}</body></html>"
    )
    return html_to_png(b, html, (size, size), out, transparent=transparent)
