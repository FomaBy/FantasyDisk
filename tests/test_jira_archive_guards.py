#!/usr/bin/env python3
"""Regression guards for the fail-closed FantasyDisk Jira archive boundary."""

from __future__ import annotations

import ast
import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
RETIRED_TOOLS = (
    "jira_next_task.py",
    "jira_board_sync.py",
    "jira_qa_helper.py",
    "jira_qa_next.py",
    "jira_release_stuck.py",
)
JIRA_ARCHIVE_PROJECT_ID = "a2cb75b5-d6c9-451c-8a29-4d267f09d67d"
LIVE_FANTASYDISK_PROJECT_ID = "2ac963eb-b644-4540-8042-a1a4508f1a65"


class JiraArchiveGuardTest(unittest.TestCase):
    def test_retired_tools_fail_before_credentials_or_network(self) -> None:
        env = os.environ.copy()
        env["JIRA_API_TOKEN"] = "must-not-be-used"
        for name in RETIRED_TOOLS:
            path = ROOT / "tools" / name
            with self.subTest(tool=name):
                result = subprocess.run(
                    [sys.executable, str(path), "--help"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    timeout=5,
                    check=False,
                )
                self.assertEqual(2, result.returncode)
                self.assertIn("RETIRED", result.stderr)
                self.assertIn("Multica", result.stderr)

    def test_retired_tools_have_no_network_or_secret_access(self) -> None:
        forbidden = ("urllib", "requests", "JIRA_API_TOKEN", "security")
        for name in RETIRED_TOOLS:
            source = (ROOT / "tools" / name).read_text(encoding="utf-8")
            with self.subTest(tool=name):
                for marker in forbidden:
                    self.assertNotIn(marker, source)

    def test_asset_generator_cannot_invoke_jira_sync(self) -> None:
        source = (
            ROOT
            / "skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py"
        ).read_text(encoding="utf-8")
        self.assertNotIn("jira_board_sync", source)
        self.assertNotIn("Jira: pending sync", source)

    def test_archive_importer_jira_requests_are_get_only(self) -> None:
        path = ROOT / "tools/jira_to_multica.py"
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        request_calls = [
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "Request"
        ]
        self.assertTrue(request_calls)
        for call in request_calls:
            self.assertEqual(
                1,
                len(call.args),
                "a positional Request payload defaults the request to POST",
            )
            self.assertFalse(
                any(keyword.arg == "data" for keyword in call.keywords),
                "a Request with data defaults to POST even without method=",
            )
            methods = [kw.value for kw in call.keywords if kw.arg == "method"]
            for method in methods:
                self.assertIsInstance(method, ast.Constant)
                self.assertEqual("GET", method.value)

    def test_archive_importer_rejects_live_project_before_jira_access(self) -> None:
        env = os.environ.copy()
        env.pop("JIRA_API_TOKEN", None)
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools/jira_to_multica.py"),
                "--apply",
                "--project",
                LIVE_FANTASYDISK_PROJECT_ID,
            ],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
            check=False,
        )
        self.assertEqual(2, result.returncode)
        self.assertIn(JIRA_ARCHIVE_PROJECT_ID, result.stderr)
        self.assertNotIn("JIRA_API_TOKEN is required", result.stderr)

    def test_archive_lookup_is_project_scoped_and_unique(self) -> None:
        path = ROOT / "tools/jira_to_multica.py"
        spec = importlib.util.spec_from_file_location("jira_to_multica_test", path)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        with mock.patch.object(
            module,
            "run_multica",
            return_value=[{"identifier": "FAN-ARCHIVE"}],
        ) as run:
            self.assertEqual(
                "FAN-ARCHIVE",
                module.find_existing("SCRUM-1", JIRA_ARCHIVE_PROJECT_ID),
            )
        args = run.call_args.args[0]
        self.assertIn("--project", args)
        self.assertEqual(JIRA_ARCHIVE_PROJECT_ID, args[args.index("--project") + 1])

        with mock.patch.object(
            module,
            "run_multica",
            return_value=[{"identifier": "FAN-1"}, {"identifier": "FAN-2"}],
        ):
            with self.assertRaisesRegex(RuntimeError, "duplicate archival jira_key"):
                module.find_existing("SCRUM-1", JIRA_ARCHIVE_PROJECT_ID)


if __name__ == "__main__":
    unittest.main()
