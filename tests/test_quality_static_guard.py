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


# FAN-2425 F1: release fixtures follow the canonical checkout instead of a frozen
# literal. A marker left behind by a version bump would silently no-op every
# mutation below and turn the negative controls green without testing anything.
CURRENT_VERSION = re.search(
    r'(?m)^config/version="([^"]+)"$',
    (ROOT / "project.godot").read_text(encoding="utf-8"),
).group(1)
CURRENT_MAPPING = load_module().platform_version_mapping(CURRENT_VERSION)
PROJECT_VERSION_LINE = f'config/version="{CURRENT_VERSION}"'
MACOS_SHORT_LINE = f'application/short_version="{CURRENT_MAPPING.macos_short_version}"'
MACOS_BUILD_LINE = f'application/version="{CURRENT_MAPPING.macos_build_version}"'
WINDOWS_PRODUCT_LINE = f'application/product_version="{CURRENT_MAPPING.windows_product_version}"'
WINDOWS_FILE_LINE = f'application/file_version="{CURRENT_MAPPING.windows_file_version}"'


class QualityStaticGuardTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def release_fixture(self, tmp: str) -> Path:
        root = Path(tmp)
        shutil.copy(ROOT / "project.godot", root / "project.godot")
        shutil.copy(ROOT / "export_presets.cfg", root / "export_presets.cfg")
        return root

    def mutate(self, path: Path, old: str, new: str, count: int = -1) -> None:
        """Mutate a release fixture; a stale marker fails closed instead of no-op."""
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, count), encoding="utf-8")

    def committed_fixture(self, tmp: str, files: dict[str, str]) -> Path:
        root = Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(
            ["git", "config", "user.name", "Quality Guard Test"],
            cwd=root,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.email", "quality-guard@example.invalid"],
            cwd=root,
            check=True,
        )
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        subprocess.run(["git", "add", "--", "."], cwd=root, check=True)
        subprocess.run(
            ["git", "commit", "-qm", "fixture"], cwd=root, check=True
        )
        return root

    def fantasydisk_fixture(self, tmp: str) -> Path:
        root = self.release_fixture(tmp)
        files = {
            "icon.svg": "<svg/>\n",
            "assets/icon.ico": "fixture\n",
            "scenes/Main.tscn": "[gd_scene]\n",
            "scenes/Player.tscn": "[gd_scene]\n",
            "scripts/audio_manager.gd": "extends Node\n",
            "scripts/audio_manager.gd.uid": "uid://audio\n",
            "scripts/input_device_manager.gd": "extends Node\n",
            "scripts/input_device_manager.gd.uid": "uid://input\n",
            "scripts/player.gd": "extends Node\n",
            "scripts/player.gd.uid": "uid://player\n",
            "tests/import_cache_player_load_test.gd": (
                "extends SceneTree\n"
                'const PlayerScene := preload("res://scenes/Player.tscn")\n'
                "func _init() -> void:\n"
                "\tvar player := PlayerScene.instantiate()\n"
                "\tplayer.free()\n"
                "\tquit()\n"
            ),
            "tests/import_cache_player_load_test.gd.uid": "uid://fixture\n",
        }
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(
            ["git", "config", "user.name", "Quality Guard Test"],
            cwd=root,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.email", "quality-guard@example.invalid"],
            cwd=root,
            check=True,
        )
        subprocess.run(["git", "add", "--", "."], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", "fixture"], cwd=root, check=True)
        return root

    def release_assignment_errors(self, root: Path) -> list[str]:
        return self.module.release_assignment_errors(
            (root / "project.godot").read_text(encoding="utf-8"),
            (root / "export_presets.cfg").read_text(encoding="utf-8"),
            CURRENT_VERSION,
            CURRENT_MAPPING,
        )

    def test_current_checkout_passes(self):
        self.assertEqual(self.module.collect_errors(ROOT), [])

    def test_missing_fantasydisk_player_import_probe_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fantasydisk_fixture(tmp)
            (root / "tests/import_cache_player_load_test.gd").unlink()

            errors = self.module.collect_errors(root)

            self.assertIn(
                "tests/import_cache_player_load_test.gd: required FantasyDisk Player import probe is missing",
                errors,
            )

    def test_minimal_fixture_without_fantasydisk_player_assets_is_valid(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.committed_fixture(
                tmp,
                {
                    "project.godot": '[application]\nconfig/name="Fixture"\n',
                    "tests/probe.gd": "extends SceneTree\n",
                },
            )

            self.assertEqual(
                self.module.player_import_probe_errors(
                    root, self.module.tracked_files(root)
                ),
                [],
            )

    def test_fantasydisk_player_import_probe_contract_is_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fantasydisk_fixture(tmp)
            (root / "tests/import_cache_player_load_test.gd").write_text(
                "extends SceneTree\n", encoding="utf-8"
            )

            errors = self.module.player_import_probe_errors(
                root, self.module.tracked_files(root)
            )

            self.assertTrue(
                any("required Player import probe contract" in error for error in errors)
            )

    def test_fantasydisk_player_import_probe_contract_accepts_canonical_probe(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fantasydisk_fixture(tmp)

            self.assertEqual(
                self.module.player_import_probe_errors(
                    root, self.module.tracked_files(root)
                ),
                [],
            )

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

    def test_absent_tracked_runtime_source_still_gets_resource_case_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.committed_fixture(
                tmp,
                {
                    "scripts/probe.gd": 'const ICON = preload("res://assets/Icon.png")\n',
                    "assets/icon.png": "png",
                },
            )
            (root / "scripts" / "probe.gd").unlink()

            errors = self.module.case_and_resource_errors(
                root, self.module.tracked_files(root)
            )

            self.assertEqual(len(errors), 1)
            self.assertIn("resource case mismatch", errors[0])

    def test_absent_tracked_credential_source_is_scanned_from_head(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.committed_fixture(
                tmp,
                {
                    "hidden/probe.py": "BUILTIN_WEBHOOK_" + "B64 = 'fixture'\n",
                },
            )
            (root / "hidden" / "probe.py").unlink()
            errors = self.module.credential_errors(root, self.module.tracked_files(root))

            self.assertEqual(
                errors,
                [
                    "hidden/probe.py: reversible built-in webhook credential is forbidden"
                ],
            )

    def test_absent_text_missing_from_head_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.committed_fixture(tmp, {"README.md": "fixture\n"})
            with self.assertRaises(RuntimeError) as raised:
                self.module.credential_errors(root, ["missing.py"])

            self.assertIn("HEAD:missing.py", str(raised.exception))

    def test_reports_missing_uid_sidecar_in_imported_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = "tests/ultimates/presentation/sniper_visual_distinction.gd"
            fixture = root / path
            fixture.parent.mkdir(parents=True)
            fixture.write_text("extends SceneTree\n", encoding="utf-8")
            errors = self.module.script_uid_errors(root, [path])
            self.assertEqual(
                [error.replace("\\", "/") for error in errors],
                [f"{path}: missing committed .uid sidecar"],
            )

    def test_accepts_script_with_committed_uid_sidecar(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = "scripts/probe.gd"
            fixture = root / path
            fixture.parent.mkdir()
            fixture.write_text("extends SceneTree\n", encoding="utf-8")
            (root / f"{path}.uid").write_text("uid://probe\n", encoding="utf-8")
            self.assertEqual(self.module.script_uid_errors(root, [path, f"{path}.uid"]), [])

    def test_ignores_script_below_tracked_gdignore(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ignored = root / "vendor_ignored"
            ignored.mkdir()
            (ignored / ".gdignore").write_text("", encoding="utf-8")
            fixture = ignored / "qa" / "probe.gd"
            fixture.parent.mkdir()
            fixture.write_text("extends SceneTree\n", encoding="utf-8")
            self.assertEqual(
                self.module.script_uid_errors(
                    root,
                    ["vendor_ignored/.gdignore", "vendor_ignored/qa/probe.gd"],
                ),
                [],
            )

    def test_maps_four_component_hotfix_to_three_component_macos_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            project = root / "project.godot"
            exports = root / "export_presets.cfg"
            self.mutate(project, PROJECT_VERSION_LINE, 'config/version="0.2.3.1"')
            self.mutate(exports, MACOS_SHORT_LINE, 'application/short_version="0.2.3"')
            self.mutate(exports, MACOS_BUILD_LINE, 'application/version="1.2.31"')
            self.mutate(exports, WINDOWS_PRODUCT_LINE, 'application/product_version="0.2.3.1"')
            self.mutate(exports, WINDOWS_FILE_LINE, 'application/file_version="0.2.3.1"')
            self.assertEqual(self.module.version_and_windows_errors(root), [])

    def test_rejects_stale_release_version_in_the_project_file(self):
        # The canonical checkout version and the export metadata must move
        # together: a project file left on the previous release fails closed.
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            stale_mapping = self.module.platform_version_mapping("0.2.4")
            self.mutate(root / "project.godot", PROJECT_VERSION_LINE, 'config/version="0.2.4"')
            errors = self.module.version_and_windows_errors(root)
            self.assertIn(
                "export_presets.cfg macOS preset: application/short_version must equal "
                f"{stale_mapping.macos_short_version!r}",
                errors,
            )
            self.assertIn(
                "export_presets.cfg Windows Desktop preset: application/product_version must "
                f"equal {stale_mapping.windows_product_version!r}",
                errors,
            )

    def test_rejects_direct_four_component_macos_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            project = root / "project.godot"
            exports = root / "export_presets.cfg"
            self.mutate(project, PROJECT_VERSION_LINE, 'config/version="0.2.3.1"')
            self.mutate(exports, MACOS_SHORT_LINE, 'application/short_version="0.2.3.1"')
            self.mutate(exports, MACOS_BUILD_LINE, 'application/version="0.2.3.1"')
            self.mutate(exports, WINDOWS_PRODUCT_LINE, 'application/product_version="0.2.3.1"')
            self.mutate(exports, WINDOWS_FILE_LINE, 'application/file_version="0.2.3.1"')
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
            root = self.release_fixture(tmp)
            self.mutate(
                root / "project.godot",
                PROJECT_VERSION_LINE,
                f'{PROJECT_VERSION_LINE}\nconfig/version="0.2.3"',
            )
            self.mutate(
                root / "export_presets.cfg",
                MACOS_SHORT_LINE,
                f"{MACOS_SHORT_LINE} # stale suffix",
            )
            errors = self.module.version_and_windows_errors(root)
            self.assertIn(
                "project.godot [application]: config/version must have exactly one assignment",
                errors,
            )
            self.assertIn(
                "export_presets.cfg macOS preset: application/short_version must equal "
                f"{CURRENT_MAPPING.macos_short_version!r}",
                errors,
            )

    def test_rejects_version_field_in_the_wrong_platform_preset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            exports = root / "export_presets.cfg"
            self.mutate(exports, f"{MACOS_SHORT_LINE}\n", "", 1)
            self.mutate(
                exports,
                WINDOWS_PRODUCT_LINE,
                f"{WINDOWS_PRODUCT_LINE}\n{MACOS_SHORT_LINE}",
                1,
            )
            self.assertIn(
                "export_presets.cfg macOS preset: application/short_version must have exactly one assignment",
                self.module.version_and_windows_errors(root),
            )

    def test_rejects_global_conflicting_platform_version_assignments(self):
        cases = (
            (
                "macOS short version in Windows options",
                WINDOWS_PRODUCT_LINE,
                'application/short_version="9.9.99"',
                "application/short_version",
                "macOS",
            ),
            (
                "macOS build version in Windows options",
                WINDOWS_PRODUCT_LINE,
                'application/version="9.9.99"',
                "application/version",
                "macOS",
            ),
            (
                "Windows product version in macOS options",
                MACOS_BUILD_LINE,
                'application/product_version="9.9.99"',
                "application/product_version",
                "Windows Desktop",
            ),
            (
                "Windows file version in macOS options",
                MACOS_BUILD_LINE,
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
                root = self.release_fixture(tmp)
                self.mutate(
                    root / "export_presets.cfg",
                    marker,
                    f"{marker}\n{foreign_assignment}",
                    1,
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
                MACOS_BUILD_LINE,
                MACOS_BUILD_LINE,
                "application/version",
                "macOS",
            ),
            (
                "nonexact macOS short value suffix",
                MACOS_SHORT_LINE,
                f"{MACOS_SHORT_LINE} # stale suffix",
                "application/short_version",
                "macOS",
            ),
            (
                "nonexact macOS build value junk",
                MACOS_BUILD_LINE,
                f"{MACOS_BUILD_LINE}junk",
                "application/version",
                "macOS",
            ),
            (
                "macOS build key suffix",
                MACOS_BUILD_LINE,
                MACOS_BUILD_LINE.replace("application/version", "application/version_shadow"),
                "application/version",
                "macOS",
            ),
            (
                "Windows file key prefix",
                WINDOWS_FILE_LINE,
                f"shadow_{WINDOWS_FILE_LINE}",
                "application/file_version",
                "Windows Desktop",
            ),
        )
        for name, marker, extra_assignment, key, owner in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = self.release_fixture(tmp)
                self.mutate(
                    root / "export_presets.cfg",
                    marker,
                    f"{marker}\n{extra_assignment}",
                    1,
                )
                self.assertIn(
                    f"export_presets.cfg: {key} must have exactly one exact assignment "
                    f"in {owner} preset options",
                    self.module.version_and_windows_errors(root),
                )

    def test_rejects_global_project_version_assignment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            self.mutate(
                root / "project.godot",
                "[rendering]",
                '[rendering]\nconfig/version="9.9.9"',
                1,
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
                root = self.release_fixture(tmp)
                config = root / filename
                config.write_text(
                    assignment + config.read_text(encoding="utf-8"), encoding="utf-8"
                )
                self.assertIn(expected_error, self.release_assignment_errors(root))

    def test_scans_hash_lookalikes_and_ignores_semicolon_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            exports = root / "export_presets.cfg"
            self.mutate(
                exports,
                MACOS_BUILD_LINE,
                f'{MACOS_BUILD_LINE}\n#application/version="9.9.99"',
                1,
            )
            self.assertIn(
                "export_presets.cfg: application/version must have exactly one exact "
                "assignment in macOS preset options",
                self.release_assignment_errors(root),
            )

            self.mutate(
                exports,
                '#application/version="9.9.99"',
                '  ;application/version="9.9.99"',
                1,
            )
            self.assertEqual(self.release_assignment_errors(root), [])

    def test_mapping_cli_fails_closed_for_foreign_platform_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.release_fixture(tmp)
            exports = root / "export_presets.cfg"
            self.mutate(
                exports,
                WINDOWS_PRODUCT_LINE,
                f'{WINDOWS_PRODUCT_LINE}\napplication/version="9.9.99"',
                1,
            )
            result = subprocess.run(
                [
                    sys.executable,
                    ROOT / "tools" / "release_version_mapping.py",
                    "--version",
                    CURRENT_VERSION,
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
            root = self.release_fixture(tmp)
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
                    CURRENT_VERSION,
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
            root = self.release_fixture(tmp)
            self.mutate(
                root / "project.godot",
                PROJECT_VERSION_LINE,
                'config/version="0.2.3.1.1"',
            )
            self.assertIn(
                "project.godot: config/version must use the canonical bounded X.Y.Z or X.Y.Z.R contract",
                self.module.version_and_windows_errors(root),
            )


# FAN-3824: снимок-максимум потолков строк. Ratchet двусторонний: значение в
# LEGACY_LINE_CEILINGS можно только УМЕНЬШАТЬ, а новые legacy-записи запрещены —
# новый скрипт обязан жить в NEW_SCRIPT_LINE_LIMIT, а не получать свой потолок.
# Ужал потолок в tools/quality_static_guard.py → ужми и этот снимок.
LINE_CEILING_MAXIMA = {
    "scripts/ui_screens.gd": 500,
    "scripts/class_weapon.gd": 6000,
    "scripts/player.gd": 4300,
    "scripts/progression_data.gd": 2500,
    "scripts/pause_stats_menu.gd": 2250,
    "scripts/enemy.gd": 1950,
    "scripts/cutout_rig_2d.gd": 1950,
    "scripts/main.gd": 1850,
    "scripts/route_map_screen.gd": 1600,
    "scripts/combat_director.gd": 1500,
    "scripts/meta_progression.gd": 1500,
    "scripts/progression_data_weapons.gd": 1280,
    "scripts/progression_data_characters.gd": 1250,
}


class LineCeilingRatchetTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_legacy_ceilings_only_tighten(self):
        for path, ceiling in self.module.LEGACY_LINE_CEILINGS.items():
            self.assertIn(
                path,
                LINE_CEILING_MAXIMA,
                f"{path}: new legacy line-ceiling entries are forbidden; "
                "new scripts obey NEW_SCRIPT_LINE_LIMIT",
            )
            self.assertLessEqual(
                ceiling,
                LINE_CEILING_MAXIMA[path],
                f"{path}: raising a line ceiling is forbidden (ratchet only tightens)",
            )

    def test_new_script_limit_only_tightens(self):
        self.assertLessEqual(self.module.NEW_SCRIPT_LINE_LIMIT, 1200)

    def test_ui_screens_facade_stays_a_facade(self):
        # FAN-3824: возврат монолита — это рост фасада; ловим его и в живом
        # чекауте, не только через потолок гарда.
        lines = (ROOT / "scripts/ui_screens.gd").read_text(encoding="utf-8").splitlines()
        self.assertLessEqual(
            len(lines),
            500,
            "scripts/ui_screens.gd must stay a facade; screen code belongs in scripts/ui/screens/**",
        )


if __name__ == "__main__":
    unittest.main()
