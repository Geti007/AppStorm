"""Compose store screenshots and the Play feature graphic.

Raw screenshots come from the real app running on an Android emulator
(integration_test/screenshots_test.dart writes app/build/screenshots/<id>.png).
Each one gets the caption from store/listing.json and the brand colors, and is
rendered at every size in store_rules.SCREENSHOT_SETS.
"""

from __future__ import annotations

import base64
import html
import json
from pathlib import Path

from PIL import Image

from .. import store_rules
from .render import browser, html_to_png

TEMPLATES = Path(__file__).parent / "templates"
CAPTION_MAX_CHARS = 40


def _data_url(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def _font(brand: dict) -> tuple[str, str]:
    family = (brand.get("font") or {}).get("family") if isinstance(brand.get("font"), dict) else brand.get("font")
    if not family:
        return "", '"Noto Sans"'
    q = family.replace(" ", "+")
    link = f'<link href="https://fonts.googleapis.com/css2?family={q}:wght@400;700;800&display=block" rel="stylesheet">'
    return link, f'"{family}"'


def _fill(template: str, values: dict) -> str:
    for k, v in values.items():
        template = template.replace("{{" + k + "}}", str(v))
    return template


def compose_screenshots(root: Path) -> list[str]:
    brand = json.loads((root / "brand/brand.json").read_text(encoding="utf-8"))
    listing = json.loads((root / "store/listing.json").read_text(encoding="utf-8"))
    raw_dir = root / "app/build/screenshots"
    problems: list[str] = []
    shots = listing.get("screenshots", [])
    for s in shots:
        if len(s.get("caption", "")) > CAPTION_MAX_CHARS:
            problems.append(f"screenshot caption for '{s.get('id')}' is over {CAPTION_MAX_CHARS} characters")
        if not (raw_dir / f"{s.get('id')}.png").exists():
            problems.append(f"raw screenshot app/build/screenshots/{s.get('id')}.png is missing")
    if problems:
        return problems

    colors = brand["colors"]
    font_link, font_family = _font(brand)
    template = (TEMPLATES / "screenshot.html").read_text(encoding="utf-8")
    with browser() as b:
        for set_name, (w, h) in store_rules.SCREENSHOT_SETS.items():
            out_dir = root / "store" / set_name
            out_dir.mkdir(parents=True, exist_ok=True)
            for old in out_dir.glob("*.png"):
                old.unlink()
            for i, s in enumerate(shots, start=1):
                raw = raw_dir / f"{s['id']}.png"
                rw, rh = Image.open(raw).size
                pad_top = round(h * 0.06)
                caption_size = round(w * 0.075)
                caption_block = round(caption_size * 1.12 * 2)  # room for two lines
                gap = round(h * 0.035)
                pad_bottom = round(h * 0.04)
                shot_h = h - pad_top - caption_block - gap - pad_bottom
                shot_w = round(shot_h * rw / rh)
                if shot_w > w * 0.86:
                    shot_w = round(w * 0.86)
                    shot_h = round(shot_w * rh / rw)
                page = _fill(
                    template,
                    {
                        "W": w, "H": h, "PAD_TOP": pad_top, "GAP": gap,
                        "CAPTION_SIZE": caption_size, "CAPTION_W": round(w * 0.86),
                        "SHOT_W": shot_w, "SHOT_H": shot_h, "RADIUS": round(shot_w * 0.06),
                        "SHADOW_Y": round(h * 0.01), "SHADOW_BLUR": round(h * 0.03),
                        "PRIMARY": colors["primary"], "SECONDARY": colors.get("secondary", colors["primary"]),
                        "ON_PRIMARY": colors["on_primary"], "FONT_LINK": font_link, "FONT_FAMILY": font_family,
                        "CAPTION": html.escape(s["caption"]), "IMG": _data_url(raw),
                    },
                )
                html_to_png(b, page, (w, h), out_dir / f"{i:02d}-{s['id']}.png")
    return problems


def compose_feature_graphic(root: Path) -> list[str]:
    brand = json.loads((root / "brand/brand.json").read_text(encoding="utf-8"))
    colors = brand["colors"]
    font_link, font_family = _font(brand)
    page = _fill(
        (TEMPLATES / "feature.html").read_text(encoding="utf-8"),
        {
            "PRIMARY": colors["primary"], "SECONDARY": colors.get("secondary", colors["primary"]),
            "ON_PRIMARY": colors["on_primary"], "FONT_LINK": font_link, "FONT_FAMILY": font_family,
            "ICON": _data_url(root / "app/assets/icon/icon.png"),
            "NAME": html.escape(brand["app_name"]), "TAGLINE": html.escape(brand.get("tagline", "")),
        },
    )
    with browser() as b:
        html_to_png(b, page, store_rules.PLAY_FEATURE_GRAPHIC, root / "store/play/feature-graphic.png")
    return []
