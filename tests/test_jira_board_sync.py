import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "jira_board_sync.py"


def load_sync_module():
    spec = importlib.util.spec_from_file_location("jira_board_sync_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class JiraBoardSyncSafeModeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self.tmp.name)
        self.tasks = self.tmp_path / "tasks"
        self.tasks.mkdir()
        self.map_path = self.tmp_path / "jira_sync_map.json"
        self.lock_path = self.tmp_path / "jira_sync.lock"
        self.module = load_sync_module()
        self.module.TASKS_GLOB = str(self.tasks / "*.md")
        self.module.MAP_PATH = str(self.map_path)
        self.module.LOCK_PATH = str(self.lock_path)

    def tearDown(self):
        self.tmp.cleanup()

    def write_task(self, name, status="done", jira_key=None):
        jira_line = f"Jira: {jira_key}\n" if jira_key else ""
        path = self.tasks / name
        path.write_text(
            f"# Test Task {name}\n\n"
            f"Статус: {status}\n"
            f"{jira_line}\n"
            "Body changed.\n",
            encoding="utf-8",
        )
        return path

    def run_safe_main(self, argv, api=None):
        calls = []

        def fake_api(method, path, payload=None, **kwargs):
            calls.append((method, path, payload, kwargs))
            if api:
                return api(method, path, payload, **kwargs)
            return {}

        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["jira_board_sync.py"] + argv), \
                mock.patch.object(self.module, "api", side_effect=fake_api), \
                contextlib.redirect_stdout(out):
            self.module.safe_main()
        return out.getvalue(), calls

    def test_no_create_broad_run_guards_status_moves(self):
        self.write_task("SCRUM-700_guarded_task.md", status="done")
        self.map_path.write_text(json.dumps({
            "SCRUM-700_guarded_task.md": {
                "key": "SCRUM-700",
                "status": "К выполнению",
                "desc_hash": "same",
            }
        }, ensure_ascii=False), encoding="utf-8")

        output, calls = self.run_safe_main(["--no-create"])

        self.assertIn("SAFE_GUARD", output)
        self.assertIn("GUARD_SKIP_MOVE SCRUM-700", output)
        self.assertEqual(calls, [])

    def test_no_create_broad_run_does_not_link_declared_jira_keys(self):
        self.write_task("SCRUM-704_unmapped_declared_task.md", status="done", jira_key="SCRUM-704")
        self.map_path.write_text("{}", encoding="utf-8")

        output, calls = self.run_safe_main(["--no-create"])
        mapping = json.loads(self.map_path.read_text(encoding="utf-8"))

        self.assertIn("SAFE_GUARD", output)
        self.assertIn("SKIP_CREATE SCRUM-704_unmapped_declared_task.md", output)
        self.assertEqual(mapping, {})
        self.assertEqual(calls, [])

    def test_scoped_issue_skips_inaccessible_jira_issue(self):
        self.write_task("SCRUM-701_missing_task.md", status="done", jira_key="SCRUM-701")
        self.map_path.write_text(json.dumps({
            "SCRUM-701_missing_task.md": {
                "key": "SCRUM-701",
                "status": "К выполнению",
                "desc_hash": "old",
            }
        }, ensure_ascii=False), encoding="utf-8")

        def api(method, path, payload=None, **kwargs):
            self.assertTrue(kwargs.get("tolerate_not_found"))
            return None

        output, calls = self.run_safe_main(["--no-create", "--issue", "SCRUM-701"], api=api)

        self.assertIn("inaccessible 1", output)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0], "PUT")

    def test_issue_scope_ignores_unrelated_mapped_tasks(self):
        self.write_task("SCRUM-702_target_task.md", status="done", jira_key="SCRUM-702")
        self.write_task("SCRUM-703_other_task.md", status="done", jira_key="SCRUM-703")
        self.map_path.write_text(json.dumps({
            "SCRUM-702_target_task.md": {"key": "SCRUM-702", "status": "К выполнению", "desc_hash": "same"},
            "SCRUM-703_other_task.md": {"key": "SCRUM-703", "status": "К выполнению", "desc_hash": "same"},
        }, ensure_ascii=False), encoding="utf-8")

        output, calls = self.run_safe_main(["--dry-run", "--issue", "SCRUM-702"])

        self.assertIn("done: scanned 1", output)
        self.assertIn("MOVE SCRUM-702", output)
        self.assertNotIn("SCRUM-703", output)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
