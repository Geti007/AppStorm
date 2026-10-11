import json
import subprocess
from pathlib import Path

import pytest

from factory import pipeline
from factory.claude import AgentResult
from factory.pipeline import Pipeline, Stage


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp_path, check=True)
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs/IDEA.md").write_text("an app")
    return tmp_path


class FakeAgents:
    """Stands in for run_agent. Supervisor verdicts are popped from a list."""

    def __init__(self, verdicts=()):
        self.calls = []
        self.verdicts = list(verdicts)

    def __call__(self, role, task, **kw):
        self.calls.append((role, task))
        if role == "supervisor":
            v = self.verdicts.pop(0) if self.verdicts else {"approved": True, "summary": "ok", "issues": []}
            return AgentResult(True, "", v, cost_usd=0.5)
        return AgentResult(True, "done", None, cost_usd=1.0)


def test_failed_gate_sends_exact_problems_back_to_the_worker(repo, monkeypatch):
    agents = FakeAgents()
    monkeypatch.setattr(pipeline, "run_agent", agents)
    results = iter([["flutter test failed: AC-2 expected 3 got 2"], []])
    stage = Stage("build", "Building", "coder", "Build it.", lambda root: next(results), ["app"], "good?")

    assert Pipeline(repo).run_stage(stage) is True
    worker_tasks = [t for r, t in agents.calls if r == "coder"]
    assert len(worker_tasks) == 2
    assert "AC-2 expected 3 got 2" in worker_tasks[1]
    status = json.loads((repo / "docs/STATUS.json").read_text())
    assert status["stages"]["build"]["status"] == "DONE"
    assert status["stages"]["build"]["rounds"] == 2


def test_supervisor_rejection_goes_to_the_fixer(repo, monkeypatch):
    agents = FakeAgents(verdicts=[{"approved": False, "summary": "weak", "issues": ["icon unreadable at 48px"]}])
    monkeypatch.setattr(pipeline, "run_agent", agents)
    stage = Stage("assets", "Screenshots", None, "", lambda root: [], ["store"], "good?", fixer="coder")

    assert Pipeline(repo).run_stage(stage) is True
    coder = [t for r, t in agents.calls if r == "coder"]
    assert len(coder) == 1 and "icon unreadable at 48px" in coder[0]


def test_stage_blocks_after_max_rounds(repo, monkeypatch):
    monkeypatch.setattr(pipeline, "run_agent", FakeAgents())
    stage = Stage("build", "Building", "coder", "Build it.", lambda root: ["still broken"], [], "")

    assert Pipeline(repo).run_stage(stage) is False
    status = json.loads((repo / "docs/STATUS.json").read_text())
    assert status["stages"]["build"]["status"] == "BLOCKED"
    assert "still broken" in status["stages"]["build"]["reason"]


def test_spending_limit_stops_the_stage(repo, monkeypatch):
    monkeypatch.setattr(pipeline, "run_agent", FakeAgents())
    monkeypatch.setattr(pipeline, "MAX_TOTAL_USD", 1.5)
    stage = Stage("build", "Building", "coder", "Build it.", lambda root: ["broken"], [], "")

    assert Pipeline(repo).run_stage(stage) is False
    status = json.loads((repo / "docs/STATUS.json").read_text())
    assert "spending limit" in status["stages"]["build"]["reason"]


def test_run_skips_stages_already_done(repo, monkeypatch):
    agents = FakeAgents()
    monkeypatch.setattr(pipeline, "run_agent", agents)
    ran = []
    fake = [Stage(n, n, None, "", (lambda n: lambda root: ran.append(n) or [])(n)) for n in ("spec", "test", "store")]
    monkeypatch.setattr(pipeline, "stages", lambda prefix: fake)
    monkeypatch.setattr(Pipeline, "run_review", lambda self: ran.append("review") or True)
    p = Pipeline(repo)
    p.status["stages"]["spec"] = {"status": "DONE"}
    assert p.run() is True
    assert ran == ["test", "review", "store"]


def test_deterministic_stage_without_fixer_stops_at_first_failure(repo, monkeypatch):
    agents = FakeAgents()
    monkeypatch.setattr(pipeline, "run_agent", agents)
    stage = Stage("x", "x", None, "", lambda root: ["no emulator"], [], "")
    assert Pipeline(repo).run_stage(stage) is False
    assert agents.calls == []


def test_continuing_a_blocked_stage_starts_from_its_reason(repo, monkeypatch):
    agents = FakeAgents()
    monkeypatch.setattr(pipeline, "run_agent", agents)
    p = Pipeline(repo)
    p.status["stages"]["build"] = {"status": "BLOCKED", "reason": "- analyzer: unused import in lib/a.dart"}
    stage = Stage("build", "Building", "coder", "Build it.", lambda root: [], [], "")
    assert p.run_stage(stage) is True
    assert "unused import in lib/a.dart" in agents.calls[0][1]


def test_spending_limit_counts_only_this_run(repo, monkeypatch):
    monkeypatch.setattr(pipeline, "run_agent", FakeAgents())
    monkeypatch.setattr(pipeline, "MAX_TOTAL_USD", 5)
    (repo / "docs/STATUS.json").write_text(json.dumps({"stages": {}, "cost_usd": 100.0, "log": []}))
    stage = Stage("build", "Building", "coder", "Build it.", lambda root: [], [], "")
    assert Pipeline(repo).run_stage(stage) is True
