from pathlib import Path

from factory import check


def _steps(results):
    return [(k, k.title(), (lambda r: lambda root: r)(r), "docs/" + k) for k, r in results]


def test_report_stops_at_first_failure_and_shows_output(tmp_path: Path, monkeypatch):
    (tmp_path / "docs").mkdir()
    for name in ("a", "b", "c"):
        (tmp_path / "docs" / name).write_text("x")
    monkeypatch.setattr(check, "STEPS", _steps([("a", []), ("b", ["flutter test failed: AC-3"]), ("c", [])]))
    ok, report = check.run_checks(tmp_path)
    assert not ok
    assert "| A | passed |" in report
    assert "| B | FAILED (1) |" in report
    assert "AC-3" in report
    assert "| C | not run (an earlier step failed) |" in report
    assert (tmp_path / "docs/CHECK_REPORT.md").read_text() == report


def test_unstarted_steps_are_not_failures(tmp_path: Path, monkeypatch):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs/a").write_text("x")
    monkeypatch.setattr(check, "STEPS", _steps([("a", []), ("b", [])]))
    ok, report = check.run_checks(tmp_path)
    assert ok
    assert "not run yet (`docs/b` does not exist)" in report
