import json
import os
import stat
from pathlib import Path

from factory.claude import run_agent


def _fake_claude(tmp_path: Path, payload: dict, code: int = 0) -> Path:
    script = tmp_path / "claude"
    script.write_text(
        "#!/usr/bin/env python3\nimport json, sys\n"
        "open(sys.argv[0] + '.args', 'w').write(json.dumps(sys.argv[1:]))\n"
        f"print(json.dumps({payload!r}))\nsys.exit({code})\n"
    )
    script.chmod(script.stat().st_mode | stat.S_IEXEC)
    return script


def test_read_only_agent_gets_only_read_tools_and_schema(tmp_path, monkeypatch):
    fake = _fake_claude(tmp_path, {"result": "", "structured_output": {"approved": True}, "total_cost_usd": 0.25})
    monkeypatch.setenv("FACTORY_CLAUDE_BIN", str(fake))
    r = run_agent("supervisor", "check", cwd=tmp_path, log_dir=tmp_path / "logs", read_only=True,
                  json_schema={"type": "object"})
    assert r.ok and r.structured == {"approved": True} and r.cost_usd == 0.25
    args = json.loads(Path(str(fake) + ".args").read_text())
    assert args[args.index("--tools") + 1] == "Read,Grep,Glob"
    assert "bypassPermissions" not in args
    assert args[args.index("--model") + 1] == "claude-opus-5-5"


def test_structured_output_falls_back_to_json_in_text(tmp_path, monkeypatch):
    fake = _fake_claude(tmp_path, {"result": "```json\n{\"approved\": false}\n```"})
    monkeypatch.setenv("FACTORY_CLAUDE_BIN", str(fake))
    r = run_agent("supervisor", "check", cwd=tmp_path, log_dir=tmp_path / "logs", read_only=True,
                  json_schema={"type": "object"})
    assert r.structured == {"approved": False}


def test_agent_error_is_reported_not_raised(tmp_path, monkeypatch):
    fake = _fake_claude(tmp_path, {"is_error": True, "subtype": "error_max_budget_usd", "result": ""}, code=1)
    monkeypatch.setenv("FACTORY_CLAUDE_BIN", str(fake))
    r = run_agent("coder", "build", cwd=tmp_path, log_dir=tmp_path / "logs")
    assert not r.ok and "max_budget" in r.error
