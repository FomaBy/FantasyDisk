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

    def test_maps_four_component_hotfix_to_three_component_macos_metadata(self):
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
            text = text.replace(
                'application/short_version="0.2.4"',
                'application/short_version="0.2.3"',
            ).replace(
                'application/version="0.2.4000"',
                'application/version="0.2.3001"',
            ).replace(
                'application/product_version="0.2.4"',
                'application/product_version="0.2.3.1"',
            ).replace(
                'application/file_version="0.2.4.0"',
                'application/file_version="0.2.3.1"',
            )
            exports.write_text(text, encoding="utf-8")
            self.assertEqual(self.module.version_and_windows_errors(root), [])

    def test_rejects_direct_four_component_macos_metadata(self):
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
            text = exports.read_text(encoding="utf-8").replace(
                'application/short_version="0.2.4"',
                'application/short_version="0.2.3.1"',
            ).replace(
                'application/version="0.2.4000"',
                'application/version="0.2.3.1"',
            ).replace(
                'application/product_version="0.2.4"',
                'application/product_version="0.2.3.1"',
            ).replace(
                'application/file_version="0.2.4.0"',
                'application/file_version="0.2.3.1"',
            )
            exports.write_text(text, encoding="utf-8")
            errors = self.module.version_and_windows_errors(root)
            self.assertIn(
                "export_presets.cfg: application/short_version must equal '0.2.3'",
                errors,
            )
            self.assertIn(
                "export_presets.cfg: application/version must equal '0.2.3001'",
                errors,
            )

    def test_mapping_is_monotonic_and_bounds_the_hotfix_component(self):
        mappings = [
            self.module.platform_version_mapping(version)
            for version in ("0.2.3", "0.2.3.1", "0.2.4")
        ]
        self.assertEqual(
            [mapping.macos_build_version for mapping in mappings],
            ["0.2.3000", "0.2.3001", "0.2.4000"],
        )
        with self.assertRaisesRegex(ValueError, "0..999"):
            self.module.platform_version_mapping("0.2.3.1000")

    def test_build_script_uses_the_tagged_platform_mapping_tool(self):
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        self.assertIn('tools/release_version_mapping.py', script)
        self.assertIn('MACOS_SHORT_VERSION MACOS_BUILD_VERSION WINDOWS_PRODUCT_VERSION WINDOWS_FILE_VERSION', script)

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
