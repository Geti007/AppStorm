"""Run one Claude Code agent headless (`claude -p`) and collect its result.

Workers get the full tool set inside the throwaway CI machine. The supervisor
and the reviewer get read-only tools and must answer in a fixed JSON shape.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path

PROMPTS = Path(__file__).parent / "prompts"

MODEL = os.environ.get("FACTORY_MODEL", "claude-opus-5-5")
READ_ONLY_TOOLS = "Read,Grep,Glob"


@dataclass
class AgentResult:
    ok: bool
    text: str
    structured: dict | None = None
    cost_usd: float = 0.0
    error: str = ""
    raw: dict = field(default_factory=dict)


def role_prompt(role: str) -> str:
    return (PROMPTS / f"{role}.md").read_text(encoding="utf-8")


def run_agent(
    role: str,
    task: str,
    *,
    cwd: Path,
    log_dir: Path,
    read_only: bool = False,
    json_schema: dict | None = None,
    effort: str = "high",
    max_budget_usd: float = 15.0,
    timeout_s: int = 3 * 3600,
) -> AgentResult:
    """Run the agent for `role` on `task`. Never raises for agent failures."""
    claude = os.environ.get("FACTORY_CLAUDE_BIN", "claude")
    cmd = [
        claude, "-p", task,
        "--model", MODEL,
        "--effort", effort,
        "--output-format", "json",
        "--append-system-prompt", role_prompt(role),
        "--max-budget-usd", f"{max_budget_usd:.2f}",
    ]
    if read_only:
        cmd += ["--tools", READ_ONLY_TOOLS]
    else:
        # The CI runner is a disposable VM holding nothing but this repository.
        cmd += ["--permission-mode", "bypassPermissions"]
    if json_schema is not None:
        cmd += ["--json-schema", json.dumps(json_schema)]

    log_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    log = log_dir / f"{stamp}-{role}.json"
    try:
        proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout_s)
    except subprocess.TimeoutExpired:
        return AgentResult(False, "", error=f"{role} timed out after {timeout_s}s")
    log.write_text(proc.stdout or proc.stderr, encoding="utf-8")

    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return AgentResult(False, proc.stdout[-4000:], error=f"{role} did not return JSON: {proc.stderr[-2000:]}")

    text = data.get("result") or ""
    structured = data.get("structured_output")
    if json_schema is not None and structured is None:
        structured = _json_from_text(text)
    cost = float(data.get("total_cost_usd") or 0.0)
    ok = proc.returncode == 0 and not data.get("is_error", False)
    if json_schema is not None and structured is None:
        ok = False
    error = "" if ok else (data.get("subtype") or proc.stderr[-2000:] or "agent reported an error")
    return AgentResult(ok, text, structured, cost, error, data)


def _json_from_text(text: str) -> dict | None:
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`")
        text = text[text.find("\n") + 1:] if "\n" in text else text
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        return None
    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None
