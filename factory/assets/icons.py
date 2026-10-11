"""Turn the designer's SVG icon into every icon the app and the stores need.

Inputs (written by the designer):
  brand/icon.svg             full square icon, opaque background, no rounded corners
  brand/icon-foreground.svg  the same symbol on a transparent background, for
                             Android adaptive icons
  brand/brand.json           colors, including colors.icon_background

Outputs:
  app/assets/icon/icon.png, app/assets/icon/icon_foreground.png
  app/flutter_launcher_icons.yaml  (the build stage runs flutter_launcher_icons)
  store/play/icon-512.png, store/appstore/icon-1024.png
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from .. import store_rules
from .render import browser, svg_to_png

# Android adaptive icons are 108dp with a 66dp circle that is always visible.
ADAPTIVE_SAFE_FRACTION = 66 / 108


def build_icons(root: Path) -> list[str]:
    """Render all icons. Returns a list of problems (empty when everything is fine)."""
    brand = json.loads((root / "brand/brand.json").read_text(encoding="utf-8"))
    problems: list[str] = []
    for name in ("icon.svg", "icon-foreground.svg"):
        svg = (root / "brand" / name).read_text(encoding="utf-8")
        if "viewBox" not in svg:
            problems.append(f"brand/{name} has no viewBox, so it cannot be scaled cleanly")
        if "<image" in svg or "<text" in svg:
            problems.append(f"brand/{name} uses <image> or <text>; draw shapes only so it renders the same everywhere")
    if problems:
        return problems

    icon_dir = root / "app/assets/icon"
    with browser() as b:
        # Render with transparency first so rounded or see-through corners are visible.
        full = svg_to_png(b, root / "brand/icon.svg", 1024, icon_dir / "icon.png", transparent=True)
        fg = svg_to_png(b, root / "brand/icon-foreground.svg", 1024, icon_dir / "icon_foreground.png", transparent=True)

    problems += check_full_icon(full)
    Image.open(full).convert("RGB").save(full, optimize=True)
    problems += check_foreground(fg)

    play = root / "store/play/icon-512.png"
    play.parent.mkdir(parents=True, exist_ok=True)
    Image.open(full).convert("RGBA").resize(store_rules.PLAY_ICON, Image.LANCZOS).save(play, optimize=True)
    apple = root / "store/appstore/icon-1024.png"
    apple.parent.mkdir(parents=True, exist_ok=True)
    Image.open(full).convert("RGB").save(apple, optimize=True)

    bg = brand["colors"]["icon_background"]
    (root / "app/flutter_launcher_icons.yaml").write_text(
        "flutter_launcher_icons:\n"
        '  image_path: "assets/icon/icon.png"\n'
        "  android: true\n"
        '  adaptive_icon_background: "' + bg + '"\n'
        '  adaptive_icon_foreground: "assets/icon/icon_foreground.png"\n'
        "  ios: true\n"
        "  remove_alpha_ios: true\n",
        encoding="utf-8",
    )
    return problems


def check_full_icon(path: Path) -> list[str]:
    img = Image.open(path).convert("RGBA")
    problems = []
    w, h = img.size
    alpha = img.getchannel("A")
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    if any(alpha.getpixel(c) < 255 for c in corners):
        problems.append("brand/icon.svg has rounded or transparent corners; fill the whole square (the stores add their own mask)")
    elif alpha.getextrema()[0] < 255:
        problems.append("brand/icon.svg has transparent areas; the full icon must be opaque everywhere")
    colors = img.convert("RGB").resize((64, 64)).getcolors(64 * 64) or []
    if len(colors) < 2:
        problems.append("brand/icon.svg renders as a single flat color")
    return problems


def check_foreground(path: Path) -> list[str]:
    img = Image.open(path).convert("RGBA")
    bbox = img.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    if bbox is None:
        return ["brand/icon-foreground.svg renders as fully transparent"]
    size = img.size[0]
    margin = size * (1 - ADAPTIVE_SAFE_FRACTION) / 2
    left, top, right, bottom = bbox
    if left < margin - 2 or top < margin - 2 or right > size - margin + 2 or bottom > size - margin + 2:
        return [
            "brand/icon-foreground.svg draws outside the adaptive-icon safe zone "
            f"(keep it inside the central {ADAPTIVE_SAFE_FRACTION:.0%}, about x/y {margin:.0f}..{size - margin:.0f} "
            f"of 1024; it currently spans {bbox}). Android launchers would crop it."
        ]
    corner = img.getpixel((0, 0))
    if corner[3] > 16:
        return ["brand/icon-foreground.svg must have a transparent background"]
    return []

