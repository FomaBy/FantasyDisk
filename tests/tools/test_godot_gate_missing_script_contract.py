"""Regression for FAN-2157: a suite that never loaded must not exit green.

Godot 4.7 reports a failed ``--script`` load as ``Can't load script:`` /
``Failed loading resource:`` while still exiting 0 itself; the gate has to
catch that from the captured output, not from the child's exit code.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
GODOT_GATE = ROOT / "tools" / "godot_gate.py"


def _run_gate(sem_dir: Path, godot_stub: str) -> subprocess.CompletedProcess[bytes]:
    """Invoke the real gate end-to-end with a stand-in ``godot`` process."""
    env = os.environ.copy()
    env.update(
        {
            "GODOT_BIN": sys.executable,
            "FSD_GODOT_SEM_DIR": str(sem_dir),
            "FSD_GODOT_SLOTS": "1",
            "FSD_GODOT_MAXWAIT": "10",
            "FSD_GODOT_RUN_TIMEOUT": "10",
        }
    )
    # sys.executable stands in for godot here; an inherited CI GODOT_BUILD_ID
    # would reject it before the stub ever runs (FAN-3834).
    env.pop("GODOT_BUILD_ID", None)
    # The stand-in "godot" is `sys.executable -c godot_stub`; the gate forwards
    # every argv it does not itself consume onto that command line.
    return subprocess.run(
        [sys.executable, str(GODOT_GATE), "-c", godot_stub],
        env=env,
        capture_output=True,
        timeout=20,
    )


class GodotGateMissingScriptContractTests(unittest.TestCase):
    def test_unloaded_script_fails_the_gate(self) -> None:
        stub = (
            "import sys; sys.stderr.write("
            "\"ERROR: Attempt to open script 'res://tests/does_not_exist_qa_probe.gd' "
            "resulted in error 'File not found'.\\n\""
            "\"ERROR: Failed loading resource: res://tests/does_not_exist_qa_probe.gd\\n\""
            "\"ERROR: Can't load script: res://tests/does_not_exist_qa_probe.gd\\n\")"
        )
        with tempfile.TemporaryDirectory() as sem_dir:
            result = _run_gate(Path(sem_dir), stub)
        self.assertEqual(result.returncode, 3, result.stdout.decode())

    def test_clean_run_still_passes(self) -> None:
        stub = "import sys; sys.stdout.write('ok\\n')"
        with tempfile.TemporaryDirectory() as sem_dir:
            result = _run_gate(Path(sem_dir), stub)
        self.assertEqual(result.returncode, 0, result.stdout.decode())

    def test_clean_run_passes_under_a_globally_pinned_build_id(self) -> None:
        """A CI-wide GODOT_BUILD_ID must not stop this stand-in godot from
        reaching its own assertion (FAN-3834)."""
        stub = "import sys; sys.stdout.write('ok\\n')"
        with mock.patch.dict(
            os.environ, {"GODOT_BUILD_ID": "4.7.stable.official.5b4e0cb0f"}, clear=False
        ):
            with tempfile.TemporaryDirectory() as sem_dir:
                result = _run_gate(Path(sem_dir), stub)
        self.assertEqual(result.returncode, 0, result.stdout.decode())


if __name__ == "__main__":
    unittest.main()
