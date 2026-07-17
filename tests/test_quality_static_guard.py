import importlib.util
import re
import shutil
import subprocess
import sys
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

    def release_assignment_errors(self, root: Path) -> list[str]:
        return self.module.release_assignment_errors(
            (root / "project.godot").read_text(encoding="utf-8"),
            (root / "export_presets.cfg").read_text(encoding="utf-8"),
            "0.2.4",
            self.module.platform_version_mapping("0.2.4"),
        )

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
                'application/version="1.2.40"',
                'application/version="1.2.31"',
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
                'application/version="1.2.40"',
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
                "export_presets.cfg macOS preset: application/short_version must equal '0.2.3'",
                errors,
            )
            self.assertIn(
                "export_presets.cfg macOS preset: application/version must equal '1.2.31'",
                errors,
            )

    def test_mapping_is_monotonic_and_bounds_the_hotfix_component(self):
        mappings = [
            self.module.platform_version_mapping(version)
            for version in ("0.2.3", "0.2.3.1", "0.2.4")
        ]
        self.assertEqual(
            [mapping.macos_build_version for mapping in mappings],
            ["1.2.30", "1.2.31", "1.2.40"],
        )
        self.assertEqual(
            self.module.platform_version_mapping("0.2.4.1").macos_build_version,
            "1.2.41",
        )
        with self.assertRaisesRegex(ValueError, "0..9"):
            self.module.platform_version_mapping("0.2.3.10")

    def test_build_script_uses_the_tagged_platform_mapping_tool(self):
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        self.assertIn('tools/release_version_contract.py', script)
        self.assertIn('tools/release_version_mapping.py', script)
        self.assertIn('MACOS_SHORT_VERSION MACOS_BUILD_VERSION WINDOWS_PRODUCT_VERSION WINDOWS_FILE_VERSION', script)
        self.assertIn('--project "${WORKTREE_DIR}/project.godot"', script)
        self.assertIn('--export-presets "${WORKTREE_DIR}/export_presets.cfg"', script)
        self.assertNotIn('grep -F -q "application/short_version=', script)

    def test_rejects_duplicate_or_suffix_version_assignments(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            project = root / "project.godot"
            exports = root / "export_presets.cfg"
            project.write_text(
                project.read_text(encoding="utf-8").replace(
                    'config/version="0.2.4"',
                    'config/version="0.2.4"\nconfig/version="0.2.3"',
                ),
                encoding="utf-8",
            )
            exports.write_text(
                exports.read_text(encoding="utf-8").replace(
                    'application/short_version="0.2.4"',
                    'application/short_version="0.2.4" # stale suffix',
                ),
                encoding="utf-8",
            )
            errors = self.module.version_and_windows_errors(root)
            self.assertIn(
                "project.godot [application]: config/version must have exactly one assignment",
                errors,
            )
            self.assertIn(
                "export_presets.cfg macOS preset: application/short_version must equal '0.2.4'",
                errors,
            )

    def test_rejects_version_field_in_the_wrong_platform_preset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            exports = root / "export_presets.cfg"
            text = exports.read_text(encoding="utf-8")
            text = text.replace('application/short_version="0.2.4"\n', "", 1)
            windows_marker = 'application/product_version="0.2.4"'
            text = text.replace(
                windows_marker,
                windows_marker + '\napplication/short_version="0.2.4"',
                1,
            )
            exports.write_text(text, encoding="utf-8")
            self.assertIn(
                "export_presets.cfg macOS preset: application/short_version must have exactly one assignment",
                self.module.version_and_windows_errors(root),
            )

    def test_rejects_global_conflicting_platform_version_assignments(self):
        cases = (
            (
                "macOS short version in Windows options",
                'application/product_version="0.2.4"',
                'application/short_version="9.9.99"',
                "application/short_version",
                "macOS",
            ),
            (
                "macOS build version in Windows options",
                'application/product_version="0.2.4"',
                'application/version="9.9.99"',
                "application/version",
                "macOS",
            ),
            (
                "Windows product version in macOS options",
                'application/version="1.2.40"',
                'application/product_version="9.9.99"',
                "application/product_version",
                "Windows Desktop",
            ),
            (
                "Windows file version in macOS options",
                'application/version="1.2.40"',
                'application/file_version="9.9.99.9"',
                "application/file_version",
                "Windows Desktop",
            ),
            (
                "macOS build version in a preset header",
                'platform="Windows Desktop"',
                'application/version="9.9.99"',
                "application/version",
                "macOS",
            ),
        )
        for name, marker, foreign_assignment, key, owner in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                shutil.copy(ROOT / "project.godot", root / "project.godot")
                shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
                exports = root / "export_presets.cfg"
                exports.write_text(
                    exports.read_text(encoding="utf-8").replace(
                        marker, f"{marker}\n{foreign_assignment}", 1
                    ),
                    encoding="utf-8",
                )
                self.assertIn(
                    f"export_presets.cfg: {key} must have exactly one exact assignment "
                    f"in {owner} preset options",
                    self.module.version_and_windows_errors(root),
                )

    def test_rejects_duplicate_or_lookalike_global_version_assignments(self):
        cases = (
            (
                "duplicate macOS build",
                'application/version="1.2.40"',
                'application/version="1.2.40"',
                "application/version",
                "macOS",
            ),
            (
                "nonexact macOS short value suffix",
                'application/short_version="0.2.4"',
                'application/short_version="0.2.4" # stale suffix',
                "application/short_version",
                "macOS",
            ),
            (
                "nonexact macOS build value junk",
                'application/version="1.2.40"',
                'application/version="1.2.40"junk',
                "application/version",
                "macOS",
            ),
            (
                "macOS build key suffix",
                'application/version="1.2.40"',
                'application/version_shadow="1.2.40"',
                "application/version",
                "macOS",
            ),
            (
                "Windows file key prefix",
                'application/file_version="0.2.4.0"',
                'shadow_application/file_version="0.2.4.0"',
                "application/file_version",
                "Windows Desktop",
            ),
        )
        for name, marker, extra_assignment, key, owner in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                shutil.copy(ROOT / "project.godot", root / "project.godot")
                shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
                exports = root / "export_presets.cfg"
                exports.write_text(
                    exports.read_text(encoding="utf-8").replace(
                        marker, f"{marker}\n{extra_assignment}", 1
                    ),
                    encoding="utf-8",
                )
                self.assertIn(
                    f"export_presets.cfg: {key} must have exactly one exact assignment "
                    f"in {owner} preset options",
                    self.module.version_and_windows_errors(root),
                )

    def test_rejects_global_project_version_assignment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            project = root / "project.godot"
            project.write_text(
                project.read_text(encoding="utf-8").replace(
                    "[rendering]", '[rendering]\nconfig/version="9.9.9"', 1
                ),
                encoding="utf-8",
            )
            self.assertIn(
                "project.godot: config/version must have exactly one exact assignment "
                "in [application]",
                self.module.version_and_windows_errors(root),
            )

    def test_rejects_sectionless_managed_version_assignments(self):
        cases = (
            (
                "project version",
                "project.godot",
                'config/version="9.9.9"\n',
                "project.godot: config/version must have exactly one exact assignment "
                "in [application]",
            ),
            (
                "macOS build version",
                "export_presets.cfg",
                'application/version="9.9.99"\n',
                "export_presets.cfg: application/version must have exactly one exact "
                "assignment in macOS preset options",
            ),
            (
                "Windows file version",
                "export_presets.cfg",
                'application/file_version="9.9.99.9"\n',
                "export_presets.cfg: application/file_version must have exactly one exact "
                "assignment in Windows Desktop preset options",
            ),
        )
        for name, filename, assignment, expected_error in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                shutil.copy(ROOT / "project.godot", root / "project.godot")
                shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
                config = root / filename
                config.write_text(
                    assignment + config.read_text(encoding="utf-8"), encoding="utf-8"
                )
                self.assertIn(expected_error, self.release_assignment_errors(root))

    def test_scans_hash_lookalikes_and_ignores_semicolon_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            exports = root / "export_presets.cfg"
            exports.write_text(
                exports.read_text(encoding="utf-8").replace(
                    'application/version="1.2.40"',
                    'application/version="1.2.40"\n#application/version="9.9.99"',
                    1,
                ),
                encoding="utf-8",
            )
            self.assertIn(
                "export_presets.cfg: application/version must have exactly one exact "
                "assignment in macOS preset options",
                self.release_assignment_errors(root),
            )

            exports.write_text(
                exports.read_text(encoding="utf-8").replace(
                    '#application/version="9.9.99"',
                    '  ;application/version="9.9.99"',
                    1,
                ),
                encoding="utf-8",
            )
            self.assertEqual(self.release_assignment_errors(root), [])

    def test_mapping_cli_fails_closed_for_foreign_platform_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            exports = root / "export_presets.cfg"
            exports.write_text(
                exports.read_text(encoding="utf-8").replace(
                    'application/product_version="0.2.4"',
                    'application/product_version="0.2.4"\napplication/version="9.9.99"',
                    1,
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    ROOT / "tools" / "release_version_mapping.py",
                    "--version",
                    "0.2.4",
                    "--project",
                    root / "project.godot",
                    "--export-presets",
                    exports,
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn(
                "application/version must have exactly one exact assignment "
                "in macOS preset options",
                result.stderr,
            )

    def test_mapping_cli_fails_closed_for_sectionless_platform_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copy(ROOT / "project.godot", root / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
            exports = root / "export_presets.cfg"
            exports.write_text(
                'application/version="9.9.99"\n'
                + exports.read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    ROOT / "tools" / "release_version_mapping.py",
                    "--version",
                    "0.2.4",
                    "--project",
                    root / "project.godot",
                    "--export-presets",
                    exports,
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn(
                "application/version must have exactly one exact assignment "
                "in macOS preset options",
                result.stderr,
            )

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
                "project.godot: config/version must use the canonical bounded X.Y.Z or X.Y.Z.R contract",
                self.module.version_and_windows_errors(root),
            )


if __name__ == "__main__":
    unittest.main()
