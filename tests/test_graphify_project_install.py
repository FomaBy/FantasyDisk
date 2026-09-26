"""Project-scoped Graphify pin, installer, and hook contract."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GRAPHIFY_DIR = ROOT / ".claude" / "skills" / "graphify"
PIN_FILE = GRAPHIFY_DIR / ".graphify_pin.json"
INSTALLER = GRAPHIFY_DIR / "install.py"
RUNNER = GRAPHIFY_DIR / "run.py"
SETTINGS = ROOT / ".claude" / "settings.json"
EXACT_SHA = "48682c0ee7c65028d756bcf694f700794075a673"


def _config_text() -> str:
    paths = [ROOT / "CLAUDE.md", ROOT / ".gitignore", SETTINGS]
    paths.extend(GRAPHIFY_DIR.rglob("*"))
    return "\n".join(
        path.read_text(encoding="utf-8")
        for path in paths
        if path.is_file()
        and ".venv" not in path.parts
        and path.suffix not in {".pyc"}
    )


def test_exact_pin_is_consumed_by_clean_install_command() -> None:
    pin = json.loads(PIN_FILE.read_text(encoding="utf-8"))
    assert pin["revision"] == EXACT_SHA
    assert re.fullmatch(r"[0-9a-f]{40}", pin["revision"])

    result = subprocess.run(
        [sys.executable, str(INSTALLER), "--print-requirement"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    assert result.stdout.strip() == (
        "graphifyy[gdscript] @ git+https://github.com/FomaBy/graphify.git@" + EXACT_SHA
    )


def test_hooks_use_portable_project_runner() -> None:
    settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
    commands = [
        hook["command"]
        for entry in settings["hooks"]["PreToolUse"]
        for hook in entry["hooks"]
    ]
    assert commands == [
        'python ".claude/skills/graphify/run.py" hook-guard search',
        'python ".claude/skills/graphify/run.py" hook-guard read',
    ]


def test_tracked_workflow_has_no_mutable_or_user_local_install_path() -> None:
    text = _config_text()
    assert "--upgrade" not in text
    assert "uv tool" not in text
    assert "/Users/" not in text
    assert "/.local/bin/graphify" not in text
    assert "pip install graphifyy" not in text
    assert EXACT_SHA in text


def test_code_only_guidance_uses_project_python_and_needs_no_api_key() -> None:
    skill = (GRAPHIFY_DIR / "SKILL.md").read_text(encoding="utf-8")
    guidance = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
    assert "--code-only" in guidance
    assert "graphify-out/.graphify_python" in skill
    assert "code-only corpus" in skill
    assert "GEMINI_API_KEY" in skill


def test_missing_project_environment_is_fail_open_for_hook() -> None:
    result = subprocess.run(
        [sys.executable, str(RUNNER), "hook-guard", "search"],
        cwd=ROOT,
        input="{}",
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert result.stdout == ""
