"""Run Graphify from the project's exact, locally installed environment."""

from __future__ import annotations

import os
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
GRAPHIFY_DIR = ROOT / ".claude" / "skills" / "graphify"
PIN_FILE = GRAPHIFY_DIR / ".graphify_pin.json"


def project_python() -> Path:
    return GRAPHIFY_DIR / (".venv/Scripts/python.exe" if os.name == "nt" else ".venv/bin/python")


def exact_install(python: Path) -> bool:
    try:
        pin = json.loads(PIN_FILE.read_text(encoding="utf-8"))
        package = pin["package"]
        revision = pin["revision"]
        repository = pin["repository"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", package):
            return False
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            return False
        if not repository.startswith("https://github.com/"):
            return False
    except (OSError, KeyError, TypeError, ValueError):
        return False

    verify = (
        "import importlib.metadata as metadata, json, sys; "
        "dist = metadata.distribution(sys.argv[1]); "
        "direct = json.loads(dist.read_text('direct_url.json') or '{}'); "
        "vcs = direct.get('vcs_info', {}); "
        "assert direct.get('url') == sys.argv[3] and vcs.get('commit_id') == sys.argv[2]"
    )
    return subprocess.run(
        [str(python), "-c", verify, package, revision, repository],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    python = project_python()
    if args == ["--print-python"]:
        if python.is_file():
            print(python)
            return 0
        return 2

    if not python.is_file():
        # Hooks must never turn a missing/stale local tool into a Git or test
        # blocker. Explicit commands still explain how to create the venv.
        if args[:1] == ["hook-guard"]:
            return 0
        print(
            "Graphify is not installed for this project; run "
            'python ".claude/skills/graphify/install.py" first.',
            file=sys.stderr,
        )
        return 2

    if not exact_install(python):
        if args[:1] == ["hook-guard"]:
            return 0
        print(
            "Graphify project environment is incomplete; run "
            'python ".claude/skills/graphify/install.py" again.',
            file=sys.stderr,
        )
        return 2

    os.chdir(ROOT)
    os.execv(str(python), [str(python), "-m", "graphify", *args])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
