"""Check that store/ holds everything both stores ask for, at the right sizes.

Returns a list of problems. An empty list means every check passed; it does
not mean a store reviewer will accept the app.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image

from . import store_rules as R


def _has_alpha(img: Image.Image) -> bool:
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        return img.convert("RGBA").getchannel("A").getextrema()[0] < 255
    return False


def _placeholders(text: str) -> list[str]:
    low = text.lower()
    return [w for w in R.PLACEHOLDER_WORDS if re.search(r"\b" + re.escape(w) + r"\b", low)]


def validate(root: Path) -> list[str]:
    p: list[str] = []
    store = root / "store"

    # Listing text
    listing_path = store / "listing.json"
    if not listing_path.exists():
        return ["store/listing.json is missing"]
    try:
        listing = json.loads(listing_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"store/listing.json is not valid JSON: {e}"]

    for section, limits in (("play", R.PLAY_TEXT), ("appstore", R.APPSTORE_TEXT)):
        data = listing.get(section) or {}
        for field, limit in limits.items():
            value = data.get(field)
            if not isinstance(value, str) or not value.strip():
                p.append(f"listing {section}.{field} is empty")
                continue
            size = len(value.encode("utf-8")) if field == "keywords" else len(value)
            if size > limit:
                p.append(f"listing {section}.{field} is {size} long; the limit is {limit}")
            for w in _placeholders(value):
                p.append(f"listing {section}.{field} contains placeholder text '{w}'")
    kw = (listing.get("appstore") or {}).get("keywords", "")
    if ", " in kw:
        p.append("listing appstore.keywords wastes bytes on spaces after commas")
    for cat_field in (("play", "category"), ("appstore", "primary_category")):
        if not (listing.get(cat_field[0]) or {}).get(cat_field[1]):
            p.append(f"listing {cat_field[0]}.{cat_field[1]} is empty")

    # Icons
    p += _check_image(store / "play/icon-512.png", R.PLAY_ICON, alpha_ok=True, max_bytes=R.PLAY_ICON_MAX_BYTES)
    p += _check_image(store / "appstore/icon-1024.png", R.APPSTORE_ICON, alpha_ok=False)
    p += _check_image(store / "play/feature-graphic.png", R.PLAY_FEATURE_GRAPHIC, alpha_ok=False)

    # Screenshots
    shots = listing.get("screenshots") or []
    for set_name, size in R.SCREENSHOT_SETS.items():
        files = sorted((store / set_name).glob("*.png"))
        lo, hi = (R.PLAY_SCREENSHOTS_MIN, R.PLAY_SCREENSHOTS_MAX) if set_name.startswith("play") else (
            R.APPSTORE_SCREENSHOTS_MIN, R.APPSTORE_SCREENSHOTS_MAX)
        lo = max(lo, 3)  # we always ship at least three
        if not lo <= len(files) <= hi:
            p.append(f"store/{set_name} has {len(files)} screenshots; need {lo} to {hi}")
        if shots and len(files) != len(shots):
            p.append(f"store/{set_name} has {len(files)} screenshots but listing.json lists {len(shots)}")
        for f in files:
            p += _check_image(f, size, alpha_ok=False)
        for f in files:
            if _looks_blank(f):
                p.append(f"{f.relative_to(root)} looks blank")

    # Privacy policy
    policy = store / "privacy-policy.html"
    if not policy.exists():
        p.append("store/privacy-policy.html is missing")
    else:
        text = policy.read_text(encoding="utf-8")
        name = (listing.get("play") or {}).get("title", "")
        if name and name.split(":")[0].strip().lower() not in text.lower():
            p.append("store/privacy-policy.html does not name the app")
        for w in _placeholders(re.sub(r"<[^>]+>", " ", text)):
            p.append(f"store/privacy-policy.html contains placeholder text '{w}'")

    # Data-safety / privacy-label answers
    privacy = listing.get("privacy")
    if not isinstance(privacy, dict) or "collects_data" not in privacy:
        p.append("listing privacy.collects_data is missing (needed for Play Data safety and Apple privacy labels)")
    return p


def _check_image(path: Path, size: tuple[int, int], *, alpha_ok: bool, max_bytes: int | None = None) -> list[str]:
    if not path.exists():
        return [f"{'/'.join(path.parts[-3:])} is missing"]
    img = Image.open(path)
    out = []
    if img.format != "PNG":
        out.append(f"{path.name} is {img.format}, expected PNG")
    if img.size != tuple(size):
        out.append(f"{path.name} is {img.size[0]}x{img.size[1]}, expected {size[0]}x{size[1]}")
    if not alpha_ok and img.mode not in ("RGB", "L"):
        if _has_alpha(img) or img.mode == "RGBA":
            out.append(f"{path.name} has an alpha channel; this asset must be opaque RGB")
    if max_bytes and path.stat().st_size > max_bytes:
        out.append(f"{path.name} is {path.stat().st_size} bytes; the limit is {max_bytes}")
    return out


def _looks_blank(path: Path) -> bool:
    img = Image.open(path).convert("L").resize((64, 64))
    lo, hi = img.getextrema()
    return hi - lo < 10


if __name__ == "__main__":
    import sys

    problems = validate(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
    for line in problems:
        print("FAIL:", line)
    print("store assets: OK" if not problems else f"store assets: {len(problems)} problem(s)")
    sys.exit(1 if problems else 0)
