"""Create the Flutter project from docs/app.json. Deterministic, no agent."""

from __future__ import annotations

import re
from pathlib import Path

from .gates import _cmd_check, load_app

TEMPLATES = Path(__file__).parent / "templates/flutter"

SIGNING_BLOCK = """    signingConfigs {
        create("upload") {
            // Filled from CI secrets when the owner adds an upload key; see README.
            val keystore = System.getenv("ANDROID_KEYSTORE_PATH")
            if (keystore != null) {
                storeFile = file(keystore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

"""


def scaffold(root: Path) -> list[str]:
    app = load_app(root)
    app_dir = root / "app"
    if (app_dir / "pubspec.yaml").exists():
        return []
    org, _, _ = app["package_id"].rpartition(".")
    p = _cmd_check(
        "flutter create",
        ["flutter", "create", "--org", org, "--project-name", app["slug"], "--platforms", "android,ios",
         "--description", app.get("tagline", app["name"]), str(app_dir)],
        root,
    )
    if p:
        return p
    # flutter create derives the last part of the id from the project name.
    # Use the exact package_id from the spec everywhere it appears.
    expected = f"{org}.{app['slug']}"
    if expected != app["package_id"]:
        for f in [*app_dir.joinpath("android").rglob("*.kts"), *app_dir.joinpath("android").rglob("*.kt"),
                  app_dir / "ios/Runner.xcodeproj/project.pbxproj"]:
            if f.exists():
                f.write_text(f.read_text(encoding="utf-8").replace(expected, app["package_id"]), encoding="utf-8")

    for src in TEMPLATES.rglob("*"):
        if src.is_file():
            dest = app_dir / src.relative_to(TEMPLATES)
            dest.parent.mkdir(parents=True, exist_ok=True)
            text = src.read_text(encoding="utf-8").replace("package:app/", f"package:{app['slug']}/")
            dest.write_text(text, encoding="utf-8")

    p += _cmd_check("add test packages", ["flutter", "pub", "add", "dev:integration_test:{\"sdk\":\"flutter\"}",
                                          "dev:flutter_launcher_icons"], app_dir)
    set_names(app_dir, app["name"])
    p += add_release_signing(app_dir)
    iphone_only(app_dir)
    return p


def set_names(app_dir: Path, name: str) -> None:
    manifest = app_dir / "android/app/src/main/AndroidManifest.xml"
    text = manifest.read_text(encoding="utf-8")
    manifest.write_text(re.sub(r'android:label="[^"]*"', f'android:label="{_xml(name)}"', text, count=1), encoding="utf-8")
    plist = app_dir / "ios/Runner/Info.plist"
    text = plist.read_text(encoding="utf-8")
    text = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{_xml(name)}\g<2>", text)
    plist.write_text(text, encoding="utf-8")


def add_release_signing(app_dir: Path) -> list[str]:
    gradle = app_dir / "android/app/build.gradle.kts"
    if not gradle.exists():
        return ["android/app/build.gradle.kts not found; cannot set up release signing"]
    text = gradle.read_text(encoding="utf-8")
    if 'create("upload")' in text:
        return []
    if "    buildTypes {" not in text or 'signingConfig = signingConfigs.getByName("debug")' not in text:
        return ["android/app/build.gradle.kts has an unexpected layout; release signing was not added"]
    text = text.replace("    buildTypes {", SIGNING_BLOCK + "    buildTypes {", 1)
    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName(\n'
        '                if (System.getenv("ANDROID_KEYSTORE_PATH") != null) "upload" else "debug"\n'
        "            )",
        1,
    )
    text = re.sub(r"\n\s*// TODO: Add your own signing config for the release build\.\n"
                  r"\s*// Signing with the debug keys for now, so `flutter run --release` works\.", "", text)
    gradle.write_text(text, encoding="utf-8")
    return []


def iphone_only(app_dir: Path) -> None:
    pbx = app_dir / "ios/Runner.xcodeproj/project.pbxproj"
    text = pbx.read_text(encoding="utf-8")
    pbx.write_text(re.sub(r'TARGETED_DEVICE_FAMILY = "1,2";', "TARGETED_DEVICE_FAMILY = 1;", text), encoding="utf-8")


def _xml(s: str) -> str:
    return s.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")
