import json
import shutil
from pathlib import Path

import pytest
from PIL import Image, ImageDraw

from factory import gates
from factory.assets.icons import build_icons
from factory.assets.store_images import compose_feature_graphic, compose_screenshots
from factory.validate_store import validate

FIX = Path(__file__).parent / "fixtures"


@pytest.fixture
def app_root(tmp_path: Path) -> Path:
    (tmp_path / "docs").mkdir()
    shutil.copy(FIX / "app.json", tmp_path / "docs/app.json")
    shutil.copytree(FIX / "brand", tmp_path / "brand")
    (tmp_path / "store").mkdir()
    shutil.copy(FIX / "listing.json", tmp_path / "store/listing.json")
    shutil.copy(FIX / "privacy-policy.html", tmp_path / "store/privacy-policy.html")
    (tmp_path / "app").mkdir()
    return tmp_path


def _raw_shots(root: Path, ids):
    d = root / "app/build/screenshots"
    d.mkdir(parents=True)
    for i, n in enumerate(ids):
        im = Image.new("RGB", (1080, 2400), "#e0f2fe")
        ImageDraw.Draw(im).rectangle([60, 300 + i * 50, 1020, 900], fill="#0B6E99")
        im.save(d / f"{n}.png")


def test_contrast_matches_wcag_reference_values():
    assert gates.contrast("#000000", "#FFFFFF") == pytest.approx(21.0)
    assert gates.contrast("#777777", "#FFFFFF") == pytest.approx(4.48, abs=0.01)


def test_spec_gate_rejects_bad_app_json(app_root):
    (app_root / "docs/SPEC.md").write_text("\n".join(f"AC-{i} given when then" for i in range(1, 6)))
    assert gates.spec(app_root) == []
    data = json.loads((app_root / "docs/app.json").read_text())
    data.update(name="A name that is far too long for any store title", package_id="nodots")
    (app_root / "docs/app.json").write_text(json.dumps(data))
    problems = gates.spec(app_root)
    assert any("30 characters" in p for p in problems)
    assert any("package_id" in p for p in problems)


def test_full_store_asset_run_passes_validation(app_root):
    assert build_icons(app_root) == []
    _raw_shots(app_root, ["home", "history", "settings"])
    assert compose_screenshots(app_root) == []
    assert compose_feature_graphic(app_root) == []
    assert validate(app_root) == []
    assert Image.open(app_root / "store/appstore/icon-1024.png").mode == "RGB"
    assert Image.open(app_root / "store/appstore/iphone-6.9/01-home.png").size == (1320, 2868)


def test_foreground_outside_safe_zone_is_caught(app_root):
    (app_root / "brand/icon-foreground.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<rect x="40" y="40" width="944" height="944" fill="#fff"/></svg>')
    problems = build_icons(app_root)
    assert any("safe zone" in p for p in problems)


def test_rounded_icon_is_caught(app_root):
    (app_root / "brand/icon.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<rect width="1024" height="1024" rx="220" fill="#0B6E99"/><circle cx="512" cy="512" r="200" fill="#fff"/></svg>')
    assert any("corners" in p for p in build_icons(app_root))


def test_validator_catches_long_text_and_missing_images(app_root):
    listing = json.loads((app_root / "store/listing.json").read_text())
    listing["play"]["short_description"] = "x" * 81
    listing["appstore"]["keywords"] = "water, hydration"
    (app_root / "store/listing.json").write_text(json.dumps(listing))
    problems = validate(app_root)
    assert any("short_description is 81" in p for p in problems)
    assert any("spaces after commas" in p for p in problems)
    assert any("icon-1024.png is missing" in p for p in problems)
