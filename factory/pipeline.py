"""The pipeline: stages, the retry loop, the supervisor, status and commits."""

from __future__ import annotations

import json
import os
import re
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from . import gates
from .claude import run_agent
from .scaffold import scaffold

MAX_ROUNDS = int(os.environ.get("FACTORY_MAX_ROUNDS", "3"))
MAX_TOTAL_USD = float(os.environ.get("FACTORY_MAX_USD", "60"))

SUPERVISOR_SCHEMA = {
    "type": "object",
    "properties": {
        "approved": {"type": "boolean"},
        "summary": {"type": "string"},
        "issues": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["approved", "summary", "issues"],
    "additionalProperties": False,
}

REVIEW_SCHEMA = {
    "type": "object",
    "properties": {
        "findings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "severity": {"type": "string", "enum": ["critical", "major", "minor"]},
                    "file": {"type": "string"},
                    "line": {"type": "integer"},
                    "problem": {"type": "string"},
                    "fix": {"type": "string"},
                },
                "required": ["severity", "file", "line", "problem", "fix"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["findings"],
    "additionalProperties": False,
}


@dataclass
class Stage:
    name: str
    title: str
    worker: str | None
    task: str
    gate: Callable[[Path], list[str]]
    review_files: list[str] = field(default_factory=list)
    rubric: str = ""
    fixer: str | None = None  # who fixes a failed round; defaults to worker
    effort: str = "high"


def stages(package_prefix: str) -> list[Stage]:
    return [
        Stage(
            "spec", "Writing the spec", "planner",
            f"Read docs/IDEA.md and write docs/SPEC.md and docs/app.json. "
            f"Use the package id prefix {package_prefix}.",
            gates.spec,
            ["docs/IDEA.md", "docs/SPEC.md", "docs/app.json"],
            "Does the spec capture the idea faithfully, fill the gaps sensibly, keep version 1 small enough to "
            "finish well, and give testable criteria for every feature, screen, and state? Is the name good and "
            "the store category right? Would this app be useful enough that people keep it?",
        ),
        Stage("scaffold", "Creating the Flutter project", None, "", scaffold, fixer="coder"),
        Stage(
            "design", "Designing screens, colors and the icon", "designer",
            "Design the app and draw its icon as described in your role.",
            gates.design,
            ["docs/SPEC.md", "docs/DESIGN.md", "brand/brand.json", "app/assets/icon/icon.png",
             "app/assets/icon/icon_foreground.png"],
            "Look at the rendered icon PNGs. Is the icon simple, distinctive, recognisable at small size, and does it "
            "fit the app? Does DESIGN.md cover every screen and state in the spec with exact copy, and is the visual "
            "direction coherent and professional rather than a stock template?",
        ),
        Stage(
            "build", "Building the app", "coder",
            "Build the whole app in app/ as described in your role.",
            gates.build,
            ["docs/SPEC.md", "docs/DESIGN.md", "app/lib", "app/pubspec.yaml"],
            "Read the code. Is every screen, state, and acceptance criterion in the spec implemented as DESIGN.md "
            "describes, with no shortcuts, stubs, or hard-coded demo data in the shipped app? Is the code "
            "structured so it is maintainable?",
            effort="xhigh",
        ),
        Stage(
            "test", "Testing every acceptance criterion", "tester",
            "Test the app as described in your role.",
            gates.test,
            ["docs/SPEC.md", "docs/TEST_REPORT.md", "app/test", "app/integration_test"],
            "Do the tests actually prove each acceptance criterion (they would fail if the behaviour broke), and did "
            "the tester try the edge cases in their role? Are MANUAL items genuinely impossible to automate?",
            fixer="tester",
            effort="xhigh",
        ),
        Stage(
            "store", "Writing the store listing and privacy policy", "store-writer",
            "Write the store listing and privacy policy as described in your role.",
            gates.store_text,
            ["docs/SPEC.md", "store/listing.json", "store/privacy-policy.html"],
            "Is the listing accurate to what the app does, persuasive, free of policy problems (misleading claims, "
            "keyword stuffing, other brands), and are the privacy answers consistent with the spec and the code "
            "(including AdMob when ads are on)?",
        ),
        Stage(
            "assets", "Capturing screenshots and making store images", None, "",
            gates.assets,
            ["store/listing.json", "store/play/phone", "store/appstore/iphone-6.9", "store/play/feature-graphic.png",
             "store/play/icon-512.png"],
            "Open every PNG. Would these screenshots make someone install the app? Check that each shows real, "
            "believable content (no empty states, debug banners, overflow stripes, cut-off text, or lorem ipsum), "
            "the caption matches the screen, and the set looks consistent and professional.",
            fixer="coder",
        ),
        Stage(
            "final", "Final audit", None, "",
            gates.final,
            ["docs/IDEA.md", "docs/SPEC.md", "docs/TEST_REPORT.md", "docs/REVIEW.json", "store/listing.json",
             "store/play/phone", "app/lib"],
            "This is the last look before the owner publishes without testing. Check the Definition of done in "
            "CLAUDE.md item by item, then ask: does the finished app deliver the idea in docs/IDEA.md, and is there "
            "anything a store reviewer or a first-day user would reject?",
            fixer="coder",
        ),
        Stage("release", "Building the release files", None, "", gates.release, fixer="coder"),
    ]


class Pipeline:
    def __init__(self, root: Path, *, push: bool = False, package_prefix: str = "com.example"):
        self.root = root
        self.push = push
        self.package_prefix = package_prefix
        self.status_path = root / "docs/STATUS.json"
        self.log_dir = root / "docs/agent-logs"
        self.status = self._load_status()
        self.run_start_cost = self.status.get("cost_usd", 0.0)

    # ------------------------------------------------------------ status

    def _load_status(self) -> dict:
        if self.status_path.exists():
            return json.loads(self.status_path.read_text(encoding="utf-8"))
        return {"stages": {}, "cost_usd": 0.0, "log": []}

    def _save(self) -> None:
        self.status_path.parent.mkdir(parents=True, exist_ok=True)
        self.status_path.write_text(json.dumps(self.status, indent=2) + "\n", encoding="utf-8")

    def note(self, line: str) -> None:
        stamp = time.strftime("%Y-%m-%d %H:%M")
        print(f"[{stamp}] {line}", flush=True)
        self.status["log"].append(f"{stamp} {line}")
        self._save()

    def _set(self, stage: str, **kw) -> None:
        self.status["stages"].setdefault(stage, {}).update(kw)
        self._save()

    def _spend(self, cost: float) -> None:
        self.status["cost_usd"] = round(self.status.get("cost_usd", 0.0) + cost, 4)
        self._save()

    def over_budget(self) -> bool:
        """The limit applies to this run, so a stopped app can be continued with a fresh limit."""
        return self.status.get("cost_usd", 0.0) - self.run_start_cost >= MAX_TOTAL_USD

    # ------------------------------------------------------------ git

    def commit(self, message: str) -> None:
        gates.sh(["git", "add", "-A"], self.root)
        gates.sh(["git", "commit", "-q", "-m", message], self.root)
        if self.push:
            gates.sh(["git", "push", "-q", "-u", "origin", "HEAD"], self.root, timeout=600)

    # ------------------------------------------------------------ agents

    def agent(self, role: str, task: str, **kw):
        result = run_agent(role, task, cwd=self.root, log_dir=self.log_dir, **kw)
        self._spend(result.cost_usd)
        if not result.ok:
            self.note(f"{role} agent problem: {result.error[:300]}")
        return result

    def supervise(self, stage: Stage) -> tuple[bool, list[str], str]:
        files = "\n".join(f"- {f}" for f in stage.review_files)
        task = (
            f"Stage: {stage.title}.\nThe app idea is in docs/IDEA.md.\nFiles to review:\n{files}\n\n"
            f"Question: {stage.rubric}\n\nAnswer with approved, a one-line summary, and the issues to fix."
        )
        r = self.agent("supervisor", task, read_only=True, json_schema=SUPERVISOR_SCHEMA, max_budget_usd=5)
        if not r.ok or not r.structured:
            return False, ["The supervisor could not complete its review; run the stage review again."], ""
        s = r.structured
        return bool(s.get("approved")), list(s.get("issues") or []), s.get("summary", "")

    # ------------------------------------------------------------ stages

    def run_stage(self, stage: Stage) -> bool:
        previous = self.status["stages"].get(stage.name, {})
        # When continuing a blocked stage, start from what stopped it last time.
        feedback: list[str] = [previous["reason"]] if previous.get("status") == "BLOCKED" and previous.get("reason") \
            and "spending limit" not in previous["reason"] else []
        self._set(stage.name, status="IN PROGRESS", title=stage.title, reason="")
        self.note(f"start {stage.name}: {stage.title}")
        for round_no in range(1, MAX_ROUNDS + 1):
            if self.over_budget():
                self._set(stage.name, status="BLOCKED", reason=f"spending limit of ${MAX_TOTAL_USD} reached")
                self.note(f"{stage.name}: stopped, spending limit reached")
                return False
            role = stage.worker if round_no == 1 or not feedback else (stage.fixer or stage.worker)
            if role:
                task = stage.task or f"Fix the problems below so the stage '{stage.title}' passes."
                if feedback:
                    task += "\n\nThe previous round was not accepted. Fix every one of these:\n" + _bullets(feedback)
                self.agent(role, task, effort=stage.effort)
            problems = stage.gate(self.root)
            self._set(stage.name, rounds=round_no)
            if problems:
                self.note(f"{stage.name} round {round_no}: {len(problems)} check(s) failed")
                feedback = problems
                if not (stage.fixer or stage.worker):
                    break
                continue
            if stage.rubric:
                approved, issues, summary = self.supervise(stage)
                self.note(f"{stage.name} round {round_no}: supervisor {'approved' if approved else 'rejected'}: {summary}")
                if not approved:
                    feedback = issues or ["The supervisor rejected the work without details; review it against the role."]
                    continue
            self._set(stage.name, status="DONE", rounds=round_no)
            self.commit(f"factory: {stage.title.lower()} done")
            return True
        self._set(stage.name, status="BLOCKED", reason=_bullets(feedback)[:4000])
        self.note(f"{stage.name}: blocked after {MAX_ROUNDS} rounds")
        self.commit(f"factory: {stage.title.lower()} blocked")
        return False

    def run_review(self) -> bool:
        """Independent review. The coder fixes critical and major findings, the
        build and tests must still pass, and the reviewer looks again until a
        review comes back with nothing blocking."""
        name = "review"
        self._set(name, status="IN PROGRESS", title="Independent code review")
        self.note("start review")
        reason = ""
        for round_no in range(1, MAX_ROUNDS + 1):
            self._set(name, rounds=round_no)
            r = self.agent(
                "reviewer", "Review the app as described in your role.",
                read_only=True, json_schema=REVIEW_SCHEMA, effort="xhigh", max_budget_usd=10,
            )
            if not r.ok or r.structured is None:
                reason = "the reviewer did not return findings"
                self.note(f"review round {round_no}: {reason}")
                continue
            findings = r.structured.get("findings", [])
            (self.root / "docs/REVIEW.json").write_text(
                json.dumps({"round": round_no, "findings": findings}, indent=2) + "\n", encoding="utf-8")
            blocking = [f for f in findings if f["severity"] in ("critical", "major")]
            self.note(f"review round {round_no}: {len(blocking)} blocking, {len(findings) - len(blocking)} minor")
            if not blocking:
                problems = gates.test(self.root)
                if not problems:
                    self._set(name, status="DONE")
                    self.commit("factory: independent review done")
                    return True
                reason = _bullets(problems)
                self.agent("coder", "The build or tests fail. Fix every one of these:\n" + reason, effort="xhigh")
                continue
            reason = _bullets([f"[{f['severity']}] {f['file']}:{f['line']} {f['problem']} Fix: {f['fix']}"
                               for f in blocking])
            self.agent("coder", "Fix these review findings in app/, keeping every test passing:\n" + reason,
                       effort="xhigh")
            problems = gates.test(self.root)
            if problems:
                self.agent("coder", "The build or tests now fail. Fix every one of these:\n" + _bullets(problems),
                           effort="xhigh")
        self._set(name, status="BLOCKED", reason=reason[:4000])
        self.note(f"review: blocked after {MAX_ROUNDS} rounds")
        self.commit("factory: review blocked")
        return False

    def stage_names(self) -> list[str]:
        names = [s.name for s in stages(self.package_prefix)]
        if "test" in names:
            names.insert(names.index("test") + 1, "review")
        return names

    def remaining(self) -> list[str]:
        return [n for n in self.stage_names() if self.status["stages"].get(n, {}).get("status") != "DONE"]

    def run(self, until: str | None = None) -> bool:
        order = stages(self.package_prefix)
        for name in self.stage_names():
            if self.status["stages"].get(name, {}).get("status") == "DONE":
                continue
            stage = next((s for s in order if s.name == name), None)
            ok = self.run_review() if name == "review" else self.run_stage(stage)
            if not ok:
                return False
            if until and name == until:
                return True
        return True


def _bullets(items: list[str]) -> str:
    return "\n".join(f"- {re.sub(r'\s+$', '', i)}" for i in items)
