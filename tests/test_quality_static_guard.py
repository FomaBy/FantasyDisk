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
    "scripts/class_weapon.gd": 500,
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


# FAN-3840: линейная extends-цепочка распределённого боевого класса ClassWeapon.
# Каждый модуль обязан существовать и оставаться в пределах NEW_SCRIPT_LINE_LIMIT;
# фасад scripts/class_weapon.gd — не более 500 строк. Классы berserk и knight
# живут в отдельных семействах (berserk_weapon.gd и наследники) и модулей тут
# не имеют.
CLASS_WEAPON_CHAIN_MODULES = [
    "scripts/classes/class_weapon_state.gd",
    "scripts/classes/class_weapon_shared_api.gd",
    "scripts/classes/class_weapon_core.gd",
    "scripts/classes/class_weapon_combat.gd",
    "scripts/classes/assassin_weapon.gd",
    "scripts/classes/biologist_weapon.gd",
    "scripts/classes/chemist_weapon.gd",
    "scripts/classes/dark_mage_weapon.gd",
    "scripts/classes/doctor_weapon.gd",
    "scripts/classes/druid_weapon.gd",
    "scripts/classes/elementalist_weapon.gd",
    "scripts/classes/engineer_weapon.gd",
    "scripts/classes/guitarist_weapon.gd",
    "scripts/classes/priest_weapon.gd",
    "scripts/classes/ranger_weapon.gd",
    "scripts/classes/robot_weapon.gd",
    "scripts/classes/sniper_weapon.gd",
    "scripts/classes/soldier_weapon.gd",
    "scripts/classes/thief_weapon.gd",
]


class ClassWeaponArchitectureTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_class_weapon_facade_stays_a_facade(self):
        # FAN-3840: возврат монолита — это рост фасада; ловим его в живом
        # чекауте, не только через потолок гарда.
        lines = (ROOT / "scripts/class_weapon.gd").read_text(encoding="utf-8").splitlines()
        self.assertLessEqual(
            len(lines),
            500,
            "scripts/class_weapon.gd must stay a facade; weapon code belongs in scripts/classes/**",
        )

    def test_class_weapon_chain_modules_present_and_bounded(self):
        for relative in CLASS_WEAPON_CHAIN_MODULES:
            path = ROOT / relative
            self.assertTrue(
                path.is_file(),
                f"{relative}: ClassWeapon chain module is missing",
            )
            self.assertLessEqual(
                len(path.read_text(encoding="utf-8").splitlines()),
                self.module.NEW_SCRIPT_LINE_LIMIT,
                f"{relative}: ClassWeapon module exceeds NEW_SCRIPT_LINE_LIMIT; "
                "extract a focused module instead of growing this one",
            )


# FAN-3845: домены владения и бюджет общих файлов (docs/process/ownership_map.md).
class OwnershipDomainGuardTest(unittest.TestCase):
    BASE_FILES = {
        "README.md": "fixture\n",
        "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n",
        "scripts/classes/sniper_weapon.gd": "extends ClassWeapon\n",
        "scripts/classes/class_weapon_core.gd": "extends ClassWeaponSharedApi\n",
        "scripts/summoner_weapon.gd": "extends Node2D\n",
        "scripts/berserk_weapon.gd": "extends Node2D\n",
        "scripts/ui/screens/route_map.gd": "extends UiScreensState\n",
        "CHANGELOG.md": "fixture\n",
        "docs/design/systems/animation.md": "fixture\n",
        "tests/balance/druid/dps_test.gd": "extends SceneTree\n",
    }

    def setUp(self):
        self.module = load_module()

    def repo(self, tmp: str) -> Path:
        root = Path(tmp)
        subprocess.run(["git", "init", "-q", "-b", "candidate"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.name", "Ownership Test"], cwd=root, check=True)
        subprocess.run(
            ["git", "config", "user.email", "ownership@example.invalid"], cwd=root, check=True
        )
        for relative, text in self.BASE_FILES.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        subprocess.run(["git", "add", "--", "."], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", "base"], cwd=root, check=True)
        subprocess.run(["git", "branch", "integration"], cwd=root, check=True)
        return root

    def commit(self, root: Path, changes: dict, message: str = "candidate"):
        for relative, text in changes.items():
            path = root / relative
            if text is None:
                path.unlink()
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        subprocess.run(["git", "add", "--all", "--", "."], cwd=root, check=True)
        subprocess.run(["git", "commit", "-qm", message], cwd=root, check=True)

    def errors(self, root: Path, ref: str = "integration") -> list[str]:
        return self.module.ownership_domain_errors(root, ref)

    def test_domain_inference_follows_the_ownership_map(self):
        cases = {
            "scripts/classes/druid_weapon.gd": "class/druid",
            "scripts/classes/druid_weapon.gd.uid": "class/druid",
            "scripts/robot_hydraulic_press_weapon.gd": "class/robot",
            "scripts/ultimates/classes/priest/beam.gd": "class/priest",
            "data/ultimates/classes/priest/beam.json": "class/priest",
            "tests/balance/knight/dps_test.gd": "class/knight",
            "docs/design/ultimates/thief.md": "class/thief",
            "data/animation/enemy/void_mage.json": "actor/void_mage",
            "tests/actors/void_mage_smoke_test.gd": "actor/void_mage",
            "scripts/ui/screens/route_map.gd": "ui/route_map",
            "scripts/player.gd": "core",
            "tools/quality_static_guard.py": "core",
            "scripts/ultimates/registry/registry.gd": "core",
            "docs/process/ownership_map.md": "process/docs",
            # Общие поверхности и бюджетные файлы доменом не владеют.
            "scripts/class_weapon.gd": None,
            "scripts/classes/class_weapon_combat.gd": None,
            "scripts/summoner_weapon.gd": None,
            "scripts/berserk_weapon.gd": None,
            "scripts/two_handed_axe_weapon.gd": None,
            "scripts/ui_screens.gd": None,
            "scripts/ui/screens/ui_style_kit.gd": None,
            "scripts/progression_data_weapons.gd": None,
            "CHANGELOG.md": None,
            "docs/design/systems/animation.md": None,
        }
        for relative, expected in cases.items():
            with self.subTest(path=relative):
                self.assertEqual(self.module.ownership_domain(relative), expected)

    def test_single_domain_candidate_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "tests/balance/druid/dps_test.gd": "extends SceneTree\n# tuned\n",
                },
            )
            self.assertEqual(self.errors(root), [])

    def test_no_change_candidate_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(self.errors(self.repo(tmp)), [])

    def test_one_budgeted_shared_file_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "CHANGELOG.md": "fixture\n- druid\n",
                },
            )
            self.assertEqual(self.errors(root), [])

    def test_two_budgeted_shared_files_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "CHANGELOG.md": "fixture\n- entry\n",
                    "docs/design/systems/animation.md": "fixture\n- entry\n",
                },
            )
            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("2 budgeted shared files", errors[0])

    def test_shared_legacy_weapon_families_stay_shared_not_class_local(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            # summoner (druid+chemist) вместе с классом druid — один домен и
            # один бюджетный общий файл.
            self.commit(
                root,
                {
                    "scripts/summoner_weapon.gd": "extends Node2D\n# tuned\n",
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                },
            )
            self.assertEqual(self.errors(root), [])

    def test_two_shared_weapon_families_exceed_the_budget(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/summoner_weapon.gd": "extends Node2D\n# tuned\n",
                    "scripts/berserk_weapon.gd": "extends Node2D\n# tuned\n",
                },
            )
            self.assertIn("budgeted shared files", self.errors(root)[0])

    def test_mixed_classes_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "scripts/classes/sniper_weapon.gd": "extends ClassWeapon\n# tuned\n",
                },
            )
            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("class/druid, class/sniper", errors[0])

    def test_class_and_ui_change_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "scripts/ui/screens/route_map.gd": "extends UiScreensState\n# tuned\n",
                },
            )
            self.assertIn("class/druid, ui/route_map", self.errors(root)[0])

    def test_explicit_cross_domain_declaration_allows_multi_domain_work(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "scripts/ui/screens/route_map.gd": "extends UiScreensState\n# tuned\n",
                    "CHANGELOG.md": "fixture\n- entry\n",
                    "docs/design/systems/animation.md": "fixture\n- entry\n",
                },
                message="candidate\n\ncross-domain: FAN-3845 core architecture refactor",
            )
            self.assertEqual(self.errors(root), [])

    def test_malformed_cross_domain_declarations_cannot_bypass_the_guard(self):
        for name, trailer in (
            ("no issue id", "cross-domain: core refactor"),
            ("no rationale", "cross-domain: FAN-3845"),
            ("short rationale", "cross-domain: FAN-3845 core"),
            ("indented marker", "  cross-domain: FAN-3845 core architecture refactor"),
            ("bare marker", "cross-domain:"),
        ):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = self.repo(tmp)
                self.commit(
                    root,
                    {
                        "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                        "scripts/classes/sniper_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    },
                    message=f"candidate\n\n{trailer}",
                )
                errors = self.errors(root)
                self.assertTrue(
                    any("malformed cross-domain declaration" in error for error in errors),
                    errors,
                )

    def test_rename_across_domains_is_rejected_and_within_a_domain_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            (root / "tests/balance/sniper").mkdir(parents=True, exist_ok=True)
            subprocess.run(
                [
                    "git",
                    "mv",
                    "tests/balance/druid/dps_test.gd",
                    "tests/balance/sniper/dps_test.gd",
                ],
                cwd=root,
                check=True,
            )
            subprocess.run(["git", "commit", "-qm", "move"], cwd=root, check=True)
            self.assertIn("class/druid, class/sniper", self.errors(root)[0])

        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            subprocess.run(
                [
                    "git",
                    "mv",
                    "tests/balance/druid/dps_test.gd",
                    "tests/balance/druid/burst_test.gd",
                ],
                cwd=root,
                check=True,
            )
            subprocess.run(["git", "commit", "-qm", "move"], cwd=root, check=True)
            self.assertEqual(self.errors(root), [])

    def test_deletions_count_toward_their_domains(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": None,
                    "scripts/classes/sniper_weapon.gd": None,
                },
            )
            self.assertIn("class/druid, class/sniper", self.errors(root)[0])

    def test_untracked_candidate_files_count_toward_their_domains(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            (root / "scripts/ui/screens/inventory.gd").write_text(
                "extends UiScreensState\n", encoding="utf-8"
            )
            (root / "scripts/classes/thief_weapon.gd").write_text(
                "extends ClassWeapon\n", encoding="utf-8"
            )
            self.assertIn("class/thief, ui/inventory", self.errors(root)[0])

    def test_absent_integration_base_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            for ref in ("", "   "):
                with self.subTest(ref=ref):
                    self.assertEqual(
                        self.errors(root, ref),
                        ["ownership guard: integration base is absent"],
                    )

    def test_unresolved_integration_base_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            errors = self.errors(root, "origin/does-not-exist")
            self.assertEqual(len(errors), 1)
            self.assertIn(
                "integration base 'origin/does-not-exist' cannot be resolved", errors[0]
            )

    def test_unrelated_history_base_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            subprocess.run(
                ["git", "checkout", "-q", "--orphan", "unrelated"], cwd=root, check=True
            )
            subprocess.run(["git", "rm", "-rq", "--cached", "."], cwd=root, check=True)
            (root / "unrelated.md").write_text("fixture\n", encoding="utf-8")
            subprocess.run(["git", "add", "--", "unrelated.md"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "unrelated"], cwd=root, check=True)

            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("cannot be resolved", errors[0])

    def test_guard_cli_reports_the_ownership_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            # Release files keep the unrelated invariants readable; this test
            # asserts only that the CLI surfaces the ownership verdict.
            shutil.copy(ROOT / "project.godot", Path(tmp) / "project.godot")
            shutil.copy(ROOT / "export_presets.cfg", Path(tmp) / "export_presets.cfg")
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scripts/classes/druid_weapon.gd": "extends ClassWeapon\n# tuned\n",
                    "scripts/classes/sniper_weapon.gd": "extends ClassWeapon\n# tuned\n",
                },
            )
            result = subprocess.run(
                [
                    sys.executable,
                    MODULE_PATH,
                    "--root",
                    root,
                    "--changed-ref",
                    "integration",
                ],
                cwd=root,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("candidate spans ownership domains", result.stderr)

    def test_quality_gate_hands_the_integration_base_to_the_guard(self):
        gate = (ROOT / "tools" / "quality_gate.py").read_text(encoding="utf-8")
        self.assertIn('"tools/quality_static_guard.py",\n                "--changed-ref"', gate)


# FAN-3856: поверхности, где id владельца встроен в имя файла или папки.
class EmbeddedOwnershipIdTest(unittest.TestCase):
    BASE_FILES = {
        "README.md": "fixture\n",
        "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "png\n",
        "assets/sprites/enemies/full_frame/bone_caller_8dir/idle_0.png": "png\n",
        "assets/sprites/allies/ally_homunculus_tank.png": "png\n",
        "assets/sprites/ui/frame_border.png": "png\n",
        "tests/ultimates/assassin_balance_test.gd": "extends SceneTree\n",
        "tests/ultimates/berserk_balance_test.gd": "extends SceneTree\n",
        "tests/ultimates/registry_contract_test.gd": "extends SceneTree\n",
        "scenes/vfx/ultimates/druid/DruidBriarStaff.tscn": "[gd_scene]\n",
        "scenes/vfx/ultimates/sniper/sniper_ultimate_v2_driver.gd": "extends Node2D\n",
        "CHANGELOG.md": "fixture\n",
    }

    def setUp(self):
        self.module = load_module()

    repo = OwnershipDomainGuardTest.repo
    commit = OwnershipDomainGuardTest.commit
    errors = OwnershipDomainGuardTest.errors

    def test_registry_matches_the_canonical_checkout_sources(self):
        actors = {path.stem for path in (ROOT / "data/animation").glob("*/*.json")}
        actors |= {
            path.name.removesuffix("_smoke_test.gd")
            for path in (ROOT / "tests/actors").glob("*_smoke_test.gd")
        }
        classes = {path.name for path in (ROOT / "data/ultimates/classes").iterdir()}
        self.assertEqual(self.module.ACTOR_IDS, actors)
        self.assertEqual(self.module.CLASS_IDS, classes)

    def test_broken_registry_fails_closed(self):
        for name, ids, expected in (
            ("duplicate", ("void_mage", "void_mage"), "duplicate id 'void_mage'"),
            ("upper case", ("Void_Mage",), "invalid id 'Void_Mage'"),
            ("separator", ("void-mage",), "invalid id 'void-mage'"),
            ("empty", ("",), "invalid id ''"),
            ("trailing underscore", ("void_mage_",), "invalid id 'void_mage_'"),
        ):
            with self.subTest(name=name):
                with self.assertRaises(ValueError) as raised:
                    self.module._id_registry("actor", ids)
                self.assertIn(expected, str(raised.exception))

    def test_embedded_ids_classify_their_owning_domain(self):
        cases = {
            # actor id как префикс сегмента, как суффикс имени и в sidecar-файлах
            "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "actor/void_mage",
            "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png.import": "actor/void_mage",
            "assets/sprites/bosses/boss_ashen_colossus.png": "actor/ashen_colossus",
            "assets/sprites/allies/ally_leadership_echo_spriteframes.tres": "actor/leadership_echo",
            # длинный зарегистрированный id побеждает более короткий вложенный
            "assets/sprites/allies/ally_homunculus_tank.png": "actor/homunculus_tank",
            "assets/sprites/allies/ally_homunculus.png": "actor/homunculus",
            # class id в тестах ультимейтов и в class-owned сценах
            "tests/ultimates/assassin_balance_test.gd": "class/assassin",
            "tests/ultimates/mechanics/dark_mage_ultimate_live_test.gd": "class/dark_mage",
            "tests/ultimates/presentation/sniper_visual_distinction.gd.uid": "class/sniper",
            "scenes/vfx/ultimates/druid/DruidBriarStaff.tscn": "class/druid",
            "scenes/vfx/ultimates/berserk/berserk_ultimate_v2_driver.gd": "class/berserk",
            "scenes/ultimates/knight_ultimate_stage.tscn": "class/knight",
            # неизвестный id и совпадение внутри более длинного постороннего токена
            "assets/sprites/enemies/full_frame/dragon_king_8dir/idle_0.png": None,
            "assets/sprites/ui/frame_border.png": None,
            "assets/sprites/enemies/avoid_mage.png": None,
            "assets/sprites/enemies/voidmage.png": None,
            "assets/sprites/enemies/void_mage2.png": None,
            "tests/ultimates/registry_contract_test.gd": None,
            "tests/ultimates/mechanics/xdruid_test.gd": None,
            "scenes/ui/ultimate_hud/ultimate_hud_widget.tscn": None,
            # реестры не протекают на чужую поверхность
            "assets/sprites/characters/druid_idle.png": None,
            "tests/ultimates/void_mage_probe_test.gd": None,
        }
        for relative, expected in cases.items():
            with self.subTest(path=relative):
                self.assertEqual(self.module.ownership_domain(relative), expected)

    def test_equal_priority_matches_fail_closed(self):
        with self.assertRaises(self.module.AmbiguousOwnershipError) as raised:
            self.module.ownership_domain(
                "assets/sprites/effects/void_mage_vs_bone_caller.png"
            )
        self.assertIn("ambiguous actor ids bone_caller, void_mage", str(raised.exception))

        with self.assertRaises(self.module.AmbiguousOwnershipError):
            self.module.ownership_domain("tests/ultimates/druid_sniper_duel_test.gd")

    def test_candidate_ambiguity_is_reported_instead_of_guessed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {"assets/sprites/effects/void_mage_vs_bone_caller.png": "png\n"},
            )
            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("ambiguous actor ids bone_caller, void_mage", errors[0])

    def test_one_actor_or_class_zone_passes(self):
        for name, changes in (
            (
                "actor sprites",
                {
                    "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "png\n# t\n",
                    "assets/sprites/enemies/full_frame/void_mage_8dir/walk_0.png": "png\n",
                },
            ),
            (
                "class ultimate tests and scene",
                {
                    "tests/ultimates/assassin_balance_test.gd": "extends SceneTree\n# t\n",
                    "scenes/vfx/ultimates/assassin/AssassinChakrams.tscn": "[gd_scene]\n",
                },
            ),
        ):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = self.repo(tmp)
                self.commit(root, changes)
                self.assertEqual(self.errors(root), [])

    def test_two_actor_zones_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "png\n# t\n",
                    "assets/sprites/enemies/full_frame/bone_caller_8dir/idle_0.png": "png\n# t\n",
                },
            )
            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("actor/bone_caller, actor/void_mage", errors[0])

    def test_two_class_zones_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "tests/ultimates/assassin_balance_test.gd": "extends SceneTree\n# t\n",
                    "tests/ultimates/berserk_balance_test.gd": "extends SceneTree\n# t\n",
                },
            )
            errors = self.errors(root)
            self.assertEqual(len(errors), 1)
            self.assertIn("class/assassin, class/berserk", errors[0])

    def test_class_scene_and_foreign_class_test_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "scenes/vfx/ultimates/druid/DruidBriarStaff.tscn": "[gd_scene]\n# t\n",
                    "tests/ultimates/berserk_balance_test.gd": "extends SceneTree\n# t\n",
                },
            )
            self.assertIn("class/berserk, class/druid", self.errors(root)[0])

    def test_cross_domain_declaration_covers_the_new_surfaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "png\n# t\n",
                    "assets/sprites/enemies/full_frame/bone_caller_8dir/idle_0.png": "png\n# t\n",
                },
                message="candidate\n\ncross-domain: FAN-3856 shared skeleton re-export",
            )
            self.assertEqual(self.errors(root), [])

    def test_unowned_sprite_and_shared_ultimate_test_do_not_invent_a_domain(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "assets/sprites/ui/frame_border.png": "png\n# t\n",
                    "tests/ultimates/registry_contract_test.gd": "extends SceneTree\n# t\n",
                },
            )
            self.assertEqual(self.errors(root), [])

    def test_rename_delete_and_untracked_count_on_the_new_surfaces(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            (root / "assets/sprites/enemies/full_frame/bone_caller_8dir").mkdir(
                parents=True, exist_ok=True
            )
            subprocess.run(
                [
                    "git",
                    "mv",
                    "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png",
                    "assets/sprites/enemies/full_frame/bone_caller_8dir/idle_1.png",
                ],
                cwd=root,
                check=True,
            )
            subprocess.run(["git", "commit", "-qm", "move"], cwd=root, check=True)
            self.assertIn("actor/bone_caller, actor/void_mage", self.errors(root)[0])

        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "tests/ultimates/assassin_balance_test.gd": None,
                    "tests/ultimates/berserk_balance_test.gd": None,
                },
            )
            self.assertIn("class/assassin, class/berserk", self.errors(root)[0])

        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            (root / "scenes/vfx/ultimates/thief").mkdir(parents=True, exist_ok=True)
            (root / "scenes/vfx/ultimates/thief/ThiefCloak.tscn").write_text(
                "[gd_scene]\n", encoding="utf-8"
            )
            self.commit(
                root,
                {"tests/ultimates/assassin_balance_test.gd": "extends SceneTree\n# t\n"},
            )
            self.assertIn("class/assassin, class/thief", self.errors(root)[0])

    def test_previously_accepted_rules_still_hold_alongside_the_new_surfaces(self):
        # Один actor-домен плюс один бюджетный общий файл остаётся валидным.
        with tempfile.TemporaryDirectory() as tmp:
            root = self.repo(tmp)
            self.commit(
                root,
                {
                    "assets/sprites/enemies/full_frame/void_mage_8dir/idle_0.png": "png\n# t\n",
                    "CHANGELOG.md": "fixture\n- void_mage\n",
                },
            )
            self.assertEqual(self.errors(root), [])


if __name__ == "__main__":
    unittest.main()
