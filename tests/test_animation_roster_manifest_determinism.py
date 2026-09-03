"""FAN-3875 — determinism contract of the canonical animation roster manifest.

The recursive roster audit is the certifying pass for actor packs, but it also
owns `data/meta/animation_roster_manifest.json`. Before FAN-3875 it rewrote that
tracked file on every run, including `--check`: the committed manifest listed
`mini_rot_hound` in its pre-FAN-3627 position, so a certifying audit reordered an
otherwise-identical file and left the worktree dirty.

These checks run without Godot and without loading a single PNG: they cover the
manifest seam only, so the static profile can certify it cheaply.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "data" / "meta" / "animation_roster_manifest.json"


def load_audit():
    spec = importlib.util.spec_from_file_location(
        "animation_roster_audit", ROOT / "tools" / "animation_roster_audit.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit = load_audit()


class CommittedManifestTests(unittest.TestCase):
    def test_committed_manifest_matches_roster_byte_for_byte(self):
        # Order is part of the contract: a set-equal but reordered manifest is
        # exactly the drift that dirtied the worktree.
        expected = json.dumps(audit.build_manifest(), indent=2, ensure_ascii=False) + "\n"
        self.assertEqual(MANIFEST_PATH.read_text(encoding="utf-8"), expected)

    def test_check_reports_no_drift_on_an_unchanged_checkout(self):
        self.assertEqual(audit.sync_manifest(True), "")


class SyncManifestTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.path = Path(self._tmp.name) / "animation_roster_manifest.json"

    def test_check_reports_drift_without_touching_the_file(self):
        stale = json.dumps(list(reversed(audit.build_manifest())), indent=2,
                           ensure_ascii=False) + "\n"
        self.path.write_text(stale, encoding="utf-8")
        self.assertIn("stale roster manifest", audit.sync_manifest(True, self.path))
        self.assertEqual(self.path.read_text(encoding="utf-8"), stale)

    def test_check_reports_a_missing_manifest_without_creating_it(self):
        self.assertIn("stale roster manifest", audit.sync_manifest(True, self.path))
        self.assertFalse(self.path.exists())

    def test_plain_run_regenerates_then_stays_idempotent(self):
        self.assertEqual(audit.sync_manifest(False, self.path), "")
        first = self.path.read_bytes()
        self.assertEqual(audit.sync_manifest(False, self.path), "")
        self.assertEqual(self.path.read_bytes(), first)
        self.assertEqual(json.loads(first.decode("utf-8")), audit.build_manifest())


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
