"""Shell-syntax static step: one interpreter call per script.

``bash -n a.sh b.sh`` only parses ``a.sh`` — the remaining paths become
positional parameters — so the former single multi-file command reported
green for every script but the first (a zsh-only script with bash-invalid
syntax passed unnoticed).  These contracts pin the per-file shape, the
shebang-driven interpreter, the Windows skip and the actual detection.
"""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def _load_quality_gate():
    spec = importlib.util.spec_from_file_location(
        "quality_gate_shell_syntax_contract", ROOT / "tools" / "quality_gate.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ShellSyntaxCommandContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_quality_gate()

    def test_one_command_per_script_following_the_shebang(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bash_script = Path(tmp, "a.sh")
            bash_script.write_text("#!/usr/bin/env bash\necho a\n", encoding="utf-8")
            zsh_script = Path(tmp, "b.sh")
            zsh_script.write_text("#!/bin/zsh\necho b\n", encoding="utf-8")
            with mock.patch.object(self.quality.shutil, "which", side_effect=lambda name: f"/bin/{name}"):
                commands = self.quality._shell_syntax_commands([bash_script, zsh_script], host_os="posix")
        self.assertEqual(
            commands,
            [
                ("shell-syntax:a.sh", ["bash", "-n", str(bash_script)]),
                ("shell-syntax:b.sh", ["zsh", "-n", str(zsh_script)]),
            ],
        )

    def test_missing_interpreter_skips_only_that_script(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bash_script = Path(tmp, "a.sh")
            bash_script.write_text("#!/bin/bash\n", encoding="utf-8")
            zsh_script = Path(tmp, "b.sh")
            zsh_script.write_text("#!/bin/zsh\n", encoding="utf-8")
            with mock.patch.object(self.quality.shutil, "which", side_effect=lambda name: "/bin/bash" if name == "bash" else None):
                commands = self.quality._shell_syntax_commands([bash_script, zsh_script], host_os="posix")
        self.assertEqual([name for name, _ in commands], ["shell-syntax:a.sh"])

    def test_windows_host_runs_no_shell_syntax_step(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp, "a.sh")
            script.write_text("#!/bin/bash\n", encoding="utf-8")
            self.assertEqual(self.quality._shell_syntax_commands([script], host_os="nt"), [])

    @unittest.skipIf(os.name == "nt", "POSIX shells only")
    def test_syntax_error_in_a_later_script_is_detected(self) -> None:
        """The regression: a broken second script must fail, not ride on the first."""
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp, "good.sh")
            good.write_text("#!/bin/bash\necho ok\n", encoding="utf-8")
            broken = Path(tmp, "broken.sh")
            broken.write_text("#!/bin/bash\nif [ 1 ]; then echo x\n", encoding="utf-8")
            commands = self.quality._shell_syntax_commands([good, broken], host_os="posix")
            statuses = {
                name: subprocess.run(command, capture_output=True).returncode
                for name, command in commands
            }
        self.assertEqual(statuses["shell-syntax:good.sh"], 0)
        self.assertNotEqual(statuses["shell-syntax:broken.sh"], 0)


if __name__ == "__main__":
    unittest.main()
