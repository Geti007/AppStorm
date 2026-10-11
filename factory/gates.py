"""Deterministic checks. Each gate returns a list of problems; empty means pass.

Agents never decide whether these pass. The orchestrator runs them itself and
feeds the exact output back to the agent that has to fix it.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

from . import store_rules
from .validate_store import validate as validate_store_assets

TEST_AD_PUBLISHER = "ca-app-pub-3940256099942544"


def sh(cmd: list[str] | str, cwd: Path, timeout: int = 3600) -> tuple[bool, str]:
    """Run a command; return (passed, last part of its output)."""
    try:
        proc = subprocess.run(
            cmd, cwd=cwd, shell=isinstance(cmd, str), capture_output=True, text=True, timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s: {cmd}"
    out = (proc.stdout + "\n" + proc.stderr).strip()
    return proc.returncode == 0, out[-6000:]


def _cmd_check(name: str, cmd, cwd: Path, timeout: int = 3600) -> list[str]:
    ok, out = sh(cmd, cwd, timeout)
    return [] if ok else [f"{name} failed:\n{out}"]


def load_app(root: Path) -> dict:
    return json.loads((root / "docs/app.json").read_text(encoding="utf-8"))


# ---------------------------------------------------------------- spec

def spec(root: Path) -> list[str]:
    p = []
    spec_md = root / "docs/SPEC.md"
    if not spec_md.exists():
        return ["docs/SPEC.md is missing"]
    text = spec_md.read_text(encoding="utf-8")
    acs = set(re.findall(r"\bAC-\d+\b", text))
    if len(acs) < 5:
        p.append(f"docs/SPEC.md has {len(acs)} acceptance criteria; write at least 5 testable ones (AC-1, AC-2, ...)")
    try:
        app = load_app(root)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return p + [f"docs/app.json is missing or invalid: {e}"]
    name = app.get("name", "")
    if not 2 <= len(name) <= 30:
        p.append("app.json name must be 2 to 30 characters (store title limit)")
    if not re.fullmatch(r"[a-z][a-z0-9_]{1,30}", app.get("slug", "")):
        p.append("app.json slug must be a valid Dart package name: lowercase letters, digits, underscores")
    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2,}", app.get("package_id", "")):
        p.append("app.json package_id must look like com.owner.appname")
    if not isinstance(app.get("ads"), bool):
        p.append("app.json ads must be true or false")
    screens = app.get("screens")
    if not isinstance(screens, list) or len(screens) < 2:
        p.append("app.json screens must list every screen (at least 2)")
    if not isinstance(app.get("screenshots"), list) or not 3 <= len(app.get("screenshots", [])) <= 8:
        p.append("app.json screenshots must list 3 to 8 screen ids to show in the stores")
    for w in store_rules.PLACEHOLDER_WORDS:
        if re.search(r"\b" + re.escape(w) + r"\b", text.lower()) and w not in ("todo",):
            p.append(f"docs/SPEC.md contains placeholder text '{w}'")
    return p


# ---------------------------------------------------------------- design

def _luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a: str, b: str) -> float:
    la, lb = sorted((_luminance(a), _luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def design(root: Path) -> list[str]:
    from .assets.icons import build_icons

    p = []
    if not (root / "docs/DESIGN.md").exists():
        p.append("docs/DESIGN.md is missing")
    try:
        brand = json.loads((root / "brand/brand.json").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return p + [f"brand/brand.json is missing or invalid: {e}"]
    colors = brand.get("colors", {})
    needed = ["primary", "on_primary", "secondary", "background", "on_background", "surface", "on_surface",
              "error", "icon_background"]
    for k in needed:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(colors.get(k, ""))):
            p.append(f"brand.json colors.{k} must be a #RRGGBB color")
    if p:
        return p
    for fg, bg in (("on_primary", "primary"), ("on_background", "background"), ("on_surface", "surface")):
        ratio = contrast(colors[fg], colors[bg])
        if ratio < 4.5:
            p.append(f"text contrast {fg} on {bg} is {ratio:.2f}:1; WCAG AA needs at least 4.5:1")
    for k in ("app_name", "tagline"):
        if not brand.get(k):
            p.append(f"brand.json {k} is empty")
    for f in ("brand/icon.svg", "brand/icon-foreground.svg"):
        if not (root / f).exists():
            p.append(f"{f} is missing")
    if p:
        return p
    return build_icons(root)


# ---------------------------------------------------------------- build / test

def _no_leftovers(app_dir: Path) -> list[str]:
    p = []
    for f in sorted((app_dir / "lib").rglob("*.dart")):
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"(//|/\*|\*).*\b(TODO|FIXME|XXX)\b", line) or re.search(r"lorem ipsum", line, re.I):
                p.append(f"unfinished marker or placeholder: {f.relative_to(app_dir)}:{n}: {line.strip()}")
    return p


def _no_secrets_or_real_ads(root: Path, app_dir: Path) -> list[str]:
    p = []
    secret = re.compile(r"(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]", re.I)
    for folder in ("lib", "test", "integration_test"):
        for f in (app_dir / folder).rglob("*.dart") if (app_dir / folder).exists() else []:
            text = f.read_text(encoding="utf-8")
            if secret.search(text):
                p.append(f"hard-coded credential in {f.relative_to(app_dir)}")
            for m in re.findall(r"ca-app-pub-\d{16}", text):
                if m != TEST_AD_PUBLISHER:
                    p.append(f"real AdMob ID {m} in {f.relative_to(app_dir)}; only Google's test IDs may be in code")
    ok, files = sh(["git", "ls-files"], root)
    for line in files.splitlines():
        if re.search(r"\.(jks|keystore|p12|mobileprovision)$|key\.properties$", line):
            p.append(f"signing material is committed: {line}")
    return p


def _store_ready_app(root: Path, app_dir: Path) -> list[str]:
    """Things a store reviewer notices that tests do not."""
    p = []
    app = load_app(root)
    main_text = "\n".join(f.read_text(encoding="utf-8") for f in (app_dir / "lib").rglob("*.dart"))
    if "debugShowCheckedModeBanner: false" not in main_text:
        p.append("set debugShowCheckedModeBanner: false on the MaterialApp so screenshots have no DEBUG banner")
    manifest = app_dir / "android/app/src/main/AndroidManifest.xml"
    if manifest.exists():
        m = re.search(r'android:label="([^"]*)"', manifest.read_text(encoding="utf-8"))
        if not m or m.group(1) != app["name"]:
            p.append(f'AndroidManifest android:label must be the app name "{app["name"]}"')
    plist = app_dir / "ios/Runner/Info.plist"
    if plist.exists():
        m = re.search(r"<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>", plist.read_text(encoding="utf-8"))
        if not m or m.group(1) != app["name"]:
            p.append(f'ios/Runner/Info.plist CFBundleDisplayName must be the app name "{app["name"]}"')
    return p


def build(root: Path) -> list[str]:
    app_dir = root / "app"
    if not (app_dir / "pubspec.yaml").exists():
        return ["app/pubspec.yaml is missing"]
    p = []
    p += _cmd_check("flutter pub get", ["flutter", "pub", "get"], app_dir)
    if p:
        return p
    if (app_dir / "flutter_launcher_icons.yaml").exists():
        p += _cmd_check("launcher icons", ["dart", "run", "flutter_launcher_icons"], app_dir)
    p += _cmd_check("dart format", ["dart", "format", "--output=none", "--set-exit-if-changed", "lib", "test", "integration_test"], app_dir)
    p += _cmd_check("flutter analyze", ["flutter", "analyze", "--fatal-infos", "--fatal-warnings"], app_dir)
    p += _cmd_check("flutter test", ["flutter", "test", "--reporter", "compact"], app_dir)
    p += _no_leftovers(app_dir)
    p += _no_secrets_or_real_ads(root, app_dir)
    p += _store_ready_app(root, app_dir)
    if not p and os.environ.get("FACTORY_SKIP_APK") != "1":
        p += _cmd_check("debug APK build", ["flutter", "build", "apk", "--debug"], app_dir, timeout=5400)
    return p


def acceptance_coverage(root: Path) -> list[str]:
    """Every AC in the spec must be named in a test, or listed as MANUAL with a reason."""
    spec_text = (root / "docs/SPEC.md").read_text(encoding="utf-8")
    acs = sorted(set(re.findall(r"\bAC-\d+\b", spec_text)), key=lambda a: int(a[3:]))
    tests = ""
    for folder in ("test", "integration_test"):
        d = root / "app" / folder
        if d.exists():
            tests += "\n".join(f.read_text(encoding="utf-8") for f in d.rglob("*.dart"))
    report = root / "docs/TEST_REPORT.md"
    report_text = report.read_text(encoding="utf-8") if report.exists() else ""
    p = []
    if not report_text:
        p.append("docs/TEST_REPORT.md is missing")
    for ac in acs:
        in_tests = re.search(rf"\b{ac}\b", tests)
        manual = re.search(rf"\b{ac}\b.*\bMANUAL\b.*\S{{10,}}", report_text)
        if not in_tests and not manual:
            p.append(f"{ac} is not named in any test and is not listed as MANUAL with a reason in docs/TEST_REPORT.md")
    manual_count = len(re.findall(r"\bMANUAL\b", report_text))
    if acs and manual_count > max(1, len(acs) // 5):
        p.append(f"{manual_count} criteria are MANUAL; automate all but at most {max(1, len(acs) // 5)}")
    return p


def device_tests(root: Path) -> list[str]:
    device = os.environ.get("FACTORY_DEVICE")
    target = root / "app/integration_test/app_test.dart"
    if not target.exists():
        return ["app/integration_test/app_test.dart is missing (end-to-end tests that run on the emulator)"]
    if not device:
        return []
    return _cmd_check(
        "integration tests on the emulator",
        ["flutter", "test", "integration_test/app_test.dart", "-d", device, "--reporter", "compact"],
        root / "app", timeout=5400,
    )


def test(root: Path) -> list[str]:
    return build(root) + acceptance_coverage(root) + device_tests(root)


# ---------------------------------------------------------------- store text

def store_text(root: Path) -> list[str]:
    p = []
    try:
        listing = json.loads((root / "store/listing.json").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return [f"store/listing.json is missing or invalid: {e}"]
    problems = validate_store_assets(root)
    # Images are made in a later stage; keep only text and policy problems here.
    p += [x for x in problems if not re.search(r"\.png|screenshots|looks blank", x)]
    app = load_app(root)
    ids = [s.get("id") for s in listing.get("screenshots", [])]
    if ids != app.get("screenshots"):
        p.append(f"listing.json screenshots ids {ids} must match app.json screenshots {app.get('screenshots')}")
    return p


# ---------------------------------------------------------------- assets

def capture_screenshots(root: Path) -> list[str]:
    device = os.environ.get("FACTORY_DEVICE")
    if not device:
        return ["no emulator available (FACTORY_DEVICE is not set), so screenshots cannot be captured"]
    shots = root / "app/build/screenshots"
    if shots.exists():
        for f in shots.glob("*.png"):
            f.unlink()
    return _cmd_check(
        "screenshot run",
        ["flutter", "drive", "--driver=test_driver/integration_test.dart",
         "--target=integration_test/screenshots_test.dart", "-d", device],
        root / "app", timeout=3600,
    )


def assets(root: Path) -> list[str]:
    from .assets.store_images import compose_feature_graphic, compose_screenshots

    p = capture_screenshots(root)
    if p:
        return p
    p += compose_screenshots(root)
    if p:
        return p
    p += compose_feature_graphic(root)
    return p + validate_store_assets(root)


# ---------------------------------------------------------------- release

def release(root: Path) -> list[str]:
    app_dir = root / "app"
    p = _cmd_check("release app bundle", ["flutter", "build", "appbundle", "--release"], app_dir, timeout=5400)
    p += _cmd_check("release APK", ["flutter", "build", "apk", "--release"], app_dir, timeout=5400)
    aab = app_dir / "build/app/outputs/bundle/release/app-release.aab"
    if not p and not aab.exists():
        p.append("app-release.aab was not produced")
    return p


def final(root: Path) -> list[str]:
    # Re-capture the screenshots too, in case a fix in this stage changed a screen.
    return test(root) or assets(root)
