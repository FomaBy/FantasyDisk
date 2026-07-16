import importlib.util
import re
import shutil
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "quality_static_guard.py"


def load_module():
    spec = importlib.util.spec_from_file_location("quality_static_guard_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class QualityStaticGuardTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_current_checkout_passes(self):
        self.assertEqual(self.module.collect_errors(ROOT), [])

    def test_resource_case_mismatch_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            (root / "assets").mkdir()
            (root / "scripts" / "probe.gd").write_text(
                'const ICON = preload("res://assets/Icon.png")\n', encoding="utf-8"
            )
            (root / "assets" / "icon.png").write_bytes(b"png")
            tracked = ["scripts/probe.gd", "assets/icon.png"]
            errors = self.module.case_and_resource_errors(root, tracked)
            self.assertEqual(len(errors), 1)
            self.assertIn("resource case mismatch", errors[0])

    def test_accepts_four_component_hotfix_and_uses_it_for_windows_file_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            project = root / "project.godot"
            exports = root / "export_presets.cfg"
            project.write_text(
                project.read_text(encoding="utf-8").replace(
                    'config/version="0.2.4"', 'config/version="0.2.3.1"'
                ),
                encoding="utf-8",
            )
            text = exports.read_text(encoding="utf-8")
            text = re.sub(
                r'(?m)^application/(short_version|version|product_version)="0\.2\.4"$',
                lambda match: f'application/{match.group(1)}="0.2.3.1"',
                text,
            ).replace(
                'application/file_version="0.2.4.0"',
                'application/file_version="0.2.3.1"',
            )
            exports.write_text(text, encoding="utf-8")
            self.assertEqual(self.module.version_and_windows_errors(root), [])

    def test_rejects_five_component_release_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            project = root / "project.godot"
            project.write_text(
                project.read_text(encoding="utf-8").replace(
                    'config/version="0.2.4"', 'config/version="0.2.3.1.1"'
                ),
                encoding="utf-8",
            )
            self.assertIn(
                "project.godot: config/version must use X.Y.Z or X.Y.Z.R",
                self.module.version_and_windows_errors(root),
            )


if __name__ == "__main__":
    unittest.main()
