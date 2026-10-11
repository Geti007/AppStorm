"""Run every automatic check on an app branch, with no agents and no API key.

Used when the agents' work happens in Claude sessions (on the owner's plan)
and GitHub Actions only builds, tests on the emulator, takes screenshots and
packages the release. Writes docs/CHECK_REPORT.md for the agents to read.
"""

from __future__ import annotations

import time
from pathlib import Path
from typing import Callable

from . import gates
from .scaffold import scaffold

# Same order as the pipeline. A step only runs when the files it needs exist.
STEPS: list[tuple[str, str, Callable[[Path], list[str]], str]] = [
    ("spec", "Spec", gates.spec, "docs/SPEC.md"),
    ("scaffold", "Flutter project", scaffold, "docs/app.json"),
    ("design", "Design and icons", gates.design, "brand/brand.json"),
    ("build", "Build and widget tests", gates.build, "app/pubspec.yaml"),
    ("test", "Acceptance coverage and emulator tests",
     lambda root: gates.acceptance_coverage(root) + gates.device_tests(root), "docs/TEST_REPORT.md"),
    ("store", "Store text", gates.store_text, "store/listing.json"),
    ("assets", "Screenshots and store images", gates.assets, "store/listing.json"),
    ("release", "Release bundle and APK", gates.release, "store/listing.json"),
]


def run_checks(root: Path) -> tuple[bool, str]:
    lines = ["# Check report", "", f"Run at {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}.", "",
             "| Step | Result |", "|---|---|"]
    details: list[str] = []
    all_ok = True
    stopped = False
    for key, title, gate, needs in STEPS:
        if stopped:
            lines.append(f"| {title} | not run (an earlier step failed) |")
            continue
        if not (root / needs).exists():
            lines.append(f"| {title} | not run yet (`{needs}` does not exist) |")
            stopped = True
            continue
        print(f"== {title}", flush=True)
        problems = gate(root)
        if problems:
            all_ok = False
            stopped = True
            lines.append(f"| {title} | FAILED ({len(problems)}) |")
            details += [f"## {title}", ""] + [f"```\n{p.strip()[-3000:]}\n```" for p in problems] + [""]
        else:
            lines.append(f"| {title} | passed |")
    report = "\n".join(lines + [""] + details)
    (root / "docs").mkdir(exist_ok=True)
    (root / "docs/CHECK_REPORT.md").write_text(report, encoding="utf-8")
    # Steps that have not started yet are not failures; the report lists them.
    return all_ok, report
