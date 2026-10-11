"""Write docs/HANDOFF.md: what was built, what was proven, and what the owner does next."""

from __future__ import annotations

import json
import os
from pathlib import Path


def write_handoff(root: Path, finished: bool, remaining: list[str] | None = None) -> Path:
    status = json.loads((root / "docs/STATUS.json").read_text(encoding="utf-8"))
    app = _read_json(root / "docs/app.json")
    listing = _read_json(root / "store/listing.json")
    review = _read_json(root / "docs/REVIEW.json")
    email = os.environ.get("FACTORY_CONTACT_EMAIL", "").strip()

    policy = root / "store/privacy-policy.html"
    if email and policy.exists():
        policy.write_text(policy.read_text(encoding="utf-8").replace("{{CONTACT_EMAIL}}", email), encoding="utf-8")

    name = app.get("name", "The app")
    lines = [f"# {name}: hand-off", ""]
    if finished:
        lines += [f"{name} went through every stage and every check below passed. It is ready for you to upload.", ""]
    else:
        blocked = [v.get("title", k) for k, v in status["stages"].items() if v.get("status") == "BLOCKED"]
        if blocked:
            lines += [f"**Not finished.** The pipeline stopped at: {', '.join(blocked)}. The reason is in the stage "
                      "table below. Run the workflow again with this branch to continue.", ""]
        else:
            lines += ["**Not finished yet.** Stages still to run: " + (", ".join(remaining or []) or "none") + ".", ""]

    lines += ["## Stages", "", "| Stage | Status | Rounds | Note |", "|---|---|---|---|"]
    for key, v in status["stages"].items():
        note = (v.get("reason") or "").replace("\n", " ")[:200]
        lines.append(f"| {v.get('title', key)} | {v.get('status')} | {v.get('rounds', '')} | {note} |")
    lines += ["", f"Claude usage for this app: about ${status.get('cost_usd', 0):.2f}.", ""]

    if finished:
        lines += _checked(review)
    lines += _publish_steps(app)
    return _finish(root, lines, app, listing, email)


def _checked(review: dict) -> list[str]:
    return [
        "## What was checked automatically",
        "",
        "- `flutter analyze` with no warnings, `dart format`, every widget test, and the end-to-end tests on an "
        "Android emulator",
        "- every acceptance criterion in docs/SPEC.md is named in a passing test (see docs/TEST_REPORT.md)",
        f"- an independent review with no open critical or major finding "
        f"({len((review or {}).get('findings', []))} finding(s) in the last round, see docs/REVIEW.json)",
        "- screenshots taken from the real app on the emulator, then looked at by the supervisor",
        "- store images and text checked against Google Play and App Store size and length limits",
        "- a release app bundle and APK built",
        "",
    ]


def _publish_steps(app: dict) -> list[str]:
    return [
        "## Not verified",
        "",
        "- the app on a real phone (it ran on an Android emulator only)",
        "- the iPhone build on a real iPhone; the iOS job only proves it compiles",
        "- whether a store reviewer accepts it; the checks follow the published rules, but review is a human decision",
        "",
        "## Your steps to publish",
        "",
        "### Google Play",
        "",
        "1. Create the app in Play Console with the title from `store/listing.json` (play.title).",
        "2. Upload `app-release.aab` from the workflow run's artifacts to an internal testing or production track. "
        "If you have not added your upload key as repository secrets (see README), sign it first.",
        "3. Store listing: paste the texts from `store/listing.json`, upload `store/play/icon-512.png`, "
        "`store/play/feature-graphic.png`, and the images in `store/play/phone/`.",
        "4. Privacy policy: publish `store/privacy-policy.html` at a public URL and paste the URL.",
        "5. Data safety and content rating: answer with `store/listing.json` privacy and play.content_rating_notes.",
        "",
        "### App Store",
        "",
        "1. Create the app in App Store Connect with bundle id "
        f"`{app.get('package_id', '')}` and the name from appstore.name.",
        "2. Build and upload from a Mac with Xcode (`flutter build ipa` in `app/`). Uploading from the workflow "
        "instead needs your App Store Connect API key; it is not set up yet.",
        "3. Paste the texts from `store/listing.json` (appstore), upload `store/appstore/iphone-6.9/` screenshots.",
        "4. Use the same privacy policy URL, and answer the privacy labels from `store/listing.json` privacy.",
        "",
    ]


def _finish(root: Path, lines: list[str], app: dict, listing: dict, email: str) -> Path:
    if app.get("ads"):
        lines += [
            "### AdMob",
            "",
            "Ads were tested with Google's test IDs only. Before release: create the app and the ad units listed "
            "in docs/SPEC.md in your AdMob account, put the real IDs in `app/config/ads.release.json` and the "
            "manifest/Info.plist app IDs listed in docs/OWNER_TODO.md, set up the consent message in AdMob, and "
            "block the ad categories the spec lists.",
            "",
        ]
    if not email:
        lines += ["The privacy policy still says `{{CONTACT_EMAIL}}`. Replace it with your support email, or set "
                  "the FACTORY_CONTACT_EMAIL repository variable before the next run.", ""]
    if (root / "docs/OWNER_TODO.md").exists():
        lines += ["Also see docs/OWNER_TODO.md for values only you can fill in.", ""]
    if listing:
        lines += ["## Listing at a glance", "",
                  f"- Play: **{listing.get('play', {}).get('title', '')}**: {listing.get('play', {}).get('short_description', '')}",
                  f"- App Store: **{listing.get('appstore', {}).get('name', '')}**: {listing.get('appstore', {}).get('subtitle', '')}",
                  ""]
    out = root / "docs/HANDOFF.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def _read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}
