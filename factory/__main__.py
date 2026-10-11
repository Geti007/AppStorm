"""Command line for the factory.

  python -m factory start --idea "..." [--name short-name]   new app branch with docs/IDEA.md
  python -m factory run [--push] [--until STAGE]              run or continue the pipeline (needs an API key)
  python -m factory check                                     every automatic check, no agents (writes docs/CHECK_REPORT.md)
  python -m factory render-icons                              render brand/*.svg to every icon
  python -m factory compose                                   store screenshots + feature graphic from raw shots
  python -m factory validate-store [--text-only]              check store/ against store rules
  python -m factory handoff                                   write docs/HANDOFF.md
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

from . import gates
from .handoff import write_handoff


STOPWORDS = set("a an the to for of and or with that which who how much many my me i we our app apps "
                "simple small little new want would like make build create help helps lets let can".split())


def slugify(text: str, words: int = 4) -> str:
    parts = [w for w in re.findall(r"[a-z0-9]+", text.lower()) if w not in STOPWORDS][:words]
    return "-".join(parts) or "app"


def cmd_start(root: Path, idea: str, name: str | None) -> int:
    branch = f"app/{slugify(name or idea)}"
    ok, out = gates.sh(["git", "checkout", "-b", branch], root)
    if not ok:
        print(out)
        return 1
    (root / "docs").mkdir(exist_ok=True)
    (root / "docs/IDEA.md").write_text(f"# App idea\n\n{idea.strip()}\n", encoding="utf-8")
    status = {"idea": idea.strip(), "branch": branch, "started": time.strftime("%Y-%m-%d %H:%M"),
              "stages": {}, "cost_usd": 0.0, "log": []}
    (root / "docs/STATUS.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    gates.sh(["git", "add", "docs/IDEA.md", "docs/STATUS.json"], root)
    gates.sh(["git", "commit", "-q", "-m", f"factory: new app idea on {branch}"], root)
    print(branch)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"branch={branch}\n")
    return 0


def cmd_run(root: Path, push: bool, until: str | None) -> int:
    from .pipeline import Pipeline

    if not (root / "docs/IDEA.md").exists():
        print("docs/IDEA.md is missing; start with: python -m factory start --idea '...'")
        return 1
    owner = os.environ.get("GITHUB_REPOSITORY_OWNER", "example")
    prefix = os.environ.get("FACTORY_PACKAGE_PREFIX") or f"com.{re.sub(r'[^a-z0-9]', '', owner.lower()) or 'example'}"
    pipe = Pipeline(root, push=push, package_prefix=prefix)
    finished = pipe.run(until=until)
    all_done = finished and until is None
    write_handoff(root, all_done, remaining=pipe.remaining())
    pipe.commit("factory: hand-off" if all_done else "factory: progress report")
    print("\n" + (root / "docs/HANDOFF.md").read_text(encoding="utf-8"))
    return 0 if finished else 2


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m factory")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("--idea", required=True)
    s.add_argument("--name")
    r = sub.add_parser("run")
    r.add_argument("--push", action="store_true")
    r.add_argument("--until")
    sub.add_parser("check")
    sub.add_parser("render-icons")
    sub.add_parser("compose")
    v = sub.add_parser("validate-store")
    v.add_argument("--text-only", action="store_true")
    sub.add_parser("handoff")
    ap.add_argument("--root", default=".")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()

    if args.cmd == "start":
        return cmd_start(root, args.idea, args.name)
    if args.cmd == "run":
        return cmd_run(root, args.push, args.until)
    if args.cmd == "check":
        from .check import run_checks
        ok, report = run_checks(root)
        print(report)
        return 0 if ok else 1
    if args.cmd == "render-icons":
        from .assets.icons import build_icons
        problems = build_icons(root)
    elif args.cmd == "compose":
        from .assets.store_images import compose_feature_graphic, compose_screenshots
        problems = compose_screenshots(root) or compose_feature_graphic(root)
    elif args.cmd == "validate-store":
        problems = gates.store_text(root) if args.text_only else gates.validate_store_assets(root)
    else:
        write_handoff(root, finished=False)
        return 0
    for line in problems:
        print("FAIL:", line)
    print("OK" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
