from __future__ import annotations

import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools import quality_gate
from tools.quality import selection


ROOT = Path(__file__).resolve().parents[1]


class QualitySelectionPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.discovered = quality_gate.discover_godot_tests()
        cls.discovered_paths = tuple(
            path.relative_to(ROOT).as_posix() for path in cls.discovered
        )
        cls.parent_resources = {}
        for path in cls.discovered:
            match = quality_gate.TEST_SCRIPT_EXTENDS_RE.search(
                path.read_text(encoding="utf-8")
            )
            if match is not None:
                cls.parent_resources[path.relative_to(ROOT).as_posix()] = match.group(
                    "resource"
                )
        cls.fixtures = quality_gate.defensive_fixture_paths()
        cls.recipes = quality_gate.feature_list_recipe_scripts()

    def _select(
        self,
        changed_paths: set[str],
        *,
        profile: str = "changed",
        filters: tuple[str, ...] = (),
        skip_umbrella: bool = False,
    ) -> selection.SelectionResult:
        return selection.select_suite_paths(
            profile=profile,
            filters=filters,
            changed_paths=changed_paths,
            discovered_paths=self.discovered_paths,
            parent_resources=self.parent_resources,
            defensive_fixture_paths=self.fixtures,
            feature_list_recipe_scripts=self.recipes,
            skip_umbrella=skip_umbrella,
        )

    def test_known_path_keeps_the_pre_extraction_selection(self) -> None:
        result = self._select({"scripts/enemy.gd"})
        self.assertFalse(result.used_full_fallback)
        self.assertEqual(
            set(result.suite_paths),
            {
                "tests/combat_target_query_cache_test.gd",
                "tests/enemy_separation_behavior_test.gd",
                "tests/runtime_smoke_combat_test.gd",
                "tests/runtime_smoke_test.gd",
                "tests/runtime_smoke_ui_test.gd",
                "tests/semantic_typography_scrum1061_test.gd",
                "tests/ultimates/presentation/weapon_ultimate_contact_sheet_beats_test.gd",
                "tests/ultimates/presentation/weapon_ultimate_timing_distinctness_test.gd",
            },
        )

    def test_unknown_domain_falls_back_to_the_full_suite_fleet(self) -> None:
        result = self._select({"addons/unknown_runtime/component.gd"})
        self.assertEqual(result.full_fallback_paths, ("addons/unknown_runtime/component.gd",))
        self.assertEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_deleted_or_renamed_suite_falls_back_to_full(self) -> None:
        cases = {
            "deleted": {"tests/deleted_contract_test.gd"},
            "renamed": {
                "tests/deleted_contract_test.gd",
                "tests/weapon_integrity_test.gd",
            },
        }
        for label, changed_paths in cases.items():
            with self.subTest(label=label):
                result = self._select(changed_paths)
                self.assertTrue(result.used_full_fallback)
                self.assertEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_other_unclassified_domains_fail_conservatively_to_full(self) -> None:
        cases = (
            "assets/new_runtime_contract.json",
            "data/items/new_runtime_contract.json",
            "tests/support/new_runtime_helper.gd",
            "tests/support/runtime_smoke_helpers.gd.uid",
        )
        for changed_path in cases:
            with self.subTest(changed_path=changed_path):
                result = self._select({changed_path})
                self.assertEqual(result.full_fallback_paths, (changed_path,))
                self.assertEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_canonical_release_note_inputs_keep_core_without_full_fallback(self) -> None:
        for changed_path in (
            "CHANGELOG.md",
            "changelog.d/FAN-1.md",
            "changelog.d/FAN-3912.md",
        ):
            with self.subTest(changed_path=changed_path):
                result = self._select({changed_path})

                self.assertEqual(result.full_fallback_paths, ())
                self.assertEqual(
                    {Path(path).stem for path in result.suite_paths},
                    selection.CORE_CHANGED_TESTS,
                )

    def test_malformed_or_unexpected_release_note_paths_fall_back_to_full(self) -> None:
        cases = (
            "changelog.d/FAN-0.md",
            "changelog.d/FAN-01.md",
            "changelog.d/FAN-3912.txt",
            "changelog.d/FAN-3912.md.bak",
            "changelog.d/FAN-example.md",
            "changelog.d/archive/FAN-3912.md",
        )
        for changed_path in cases:
            with self.subTest(changed_path=changed_path):
                result = self._select({changed_path})

                self.assertEqual(result.full_fallback_paths, (changed_path,))
                self.assertEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_release_note_with_unknown_runtime_change_retains_full_fallback(self) -> None:
        unknown_runtime_path = "addons/unknown_runtime/component.gd"

        result = self._select({"changelog.d/FAN-3912.md", unknown_runtime_path})

        self.assertEqual(result.full_fallback_paths, (unknown_runtime_path,))
        self.assertEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_progression_weapons_keeps_the_accepted_additive_coverage(self) -> None:
        result = self._select({"scripts/progression_data_weapons.gd"})
        selected_names = {Path(path).stem for path in result.suite_paths}
        self.assertFalse(result.used_full_fallback)
        self.assertLessEqual(selection.OFFENSIVE_CONTRACT_TESTS, selected_names)
        self.assertLessEqual(selection.CADENCE_STATUS_CONTRACT_TESTS, selected_names)
        self.assertLessEqual(selection.BALANCE_CONTRACT_TESTS, selected_names)

    def test_existing_suite_sidecar_selects_its_suite_without_full_fallback(self) -> None:
        result = self._select({"tests/weapon_integrity_test.gd.uid"})
        self.assertFalse(result.used_full_fallback)
        self.assertIn("tests/weapon_integrity_test.gd", result.suite_paths)
        self.assertNotEqual(set(result.suite_paths), set(self.discovered_paths))

    def test_shared_helper_keeps_transitive_umbrella_coverage(self) -> None:
        result = self._select({selection.RUNTIME_SMOKE_HELPER_PATH})
        selected = set(result.suite_paths)
        self.assertFalse(result.used_full_fallback)
        for required in (
            "tests/runtime_smoke_test.gd",
            "tests/runtime_smoke_ui_test.gd",
            "tests/runtime_smoke_combat_test.gd",
            "tests/combat/smoke_bootstrap_test.gd",
            "tests/combat/smoke_contact_feedback_test.gd",
            "tests/combat/smoke_death_flow_test.gd",
            "tests/combat/smoke_hud_layout_test.gd",
            "tests/combat/smoke_projectile_test.gd",
            "tests/combat/smoke_wave_cap_test.gd",
        ):
            self.assertIn(required, selected)
        self.assertNotEqual(selected, set(self.discovered_paths))

    def test_shared_class_base_keeps_class_wide_and_umbrella_coverage(self) -> None:
        result = self._select({"scripts/class_weapon.gd"})
        selected = set(result.suite_paths)
        balance_suites = {
            path for path in self.discovered_paths if path.startswith("tests/balance/")
        }
        self.assertFalse(result.used_full_fallback)
        self.assertLessEqual(balance_suites, selected)
        self.assertIn("tests/runtime_smoke_test.gd", selected)
        self.assertIn("tests/coverage_cap_gate.gd", selected)
        self.assertNotEqual(selected, set(self.discovered_paths))

    def test_full_profile_filters_and_umbrella_flag_remain_deterministic(self) -> None:
        full = self._select(set(), profile="full")
        self.assertEqual(
            full.suite_paths,
            tuple(sorted(self.discovered_paths, key=lambda path: Path(path).stem)),
        )

        filtered = self._select(
            {"addons/unknown_runtime/component.gd"},
            filters=("weapon_integrity",),
        )
        self.assertTrue(filtered.used_full_fallback)
        self.assertEqual(filtered.suite_paths, ("tests/weapon_integrity_test.gd",))

        without_umbrella = self._select(
            {"scripts/enemy.gd"},
            skip_umbrella=True,
        )
        self.assertNotIn("tests/runtime_smoke_test.gd", without_umbrella.suite_paths)
        self.assertIn("tests/enemy_separation_behavior_test.gd", without_umbrella.suite_paths)

    def test_runner_applies_the_existing_shard_slice_after_selection(self) -> None:
        selected = [ROOT / "tests" / f"suite_{index}_test.gd" for index in range(5)]
        with (
            mock.patch.object(
                quality_gate, "select_godot_tests", return_value=selected
            ),
            mock.patch.object(
                quality_gate, "_resolved_commit", return_value="a" * 40
            ),
            mock.patch.object(
                quality_gate,
                "_cleanup_generated_import_sidecars",
                return_value=[],
            ),
            contextlib.redirect_stdout(io.StringIO()) as stdout,
        ):
            code = quality_gate.main([
                "--profile", "full",
                "--list",
                "--shard-count", "2",
                "--shard-index", "1",
            ])
        self.assertEqual(code, 0)
        output = stdout.getvalue()
        self.assertIn("tests/suite_1_test.gd", output)
        self.assertIn("tests/suite_3_test.gd", output)
        self.assertNotIn("tests/suite_0_test.gd", output)
        self.assertNotIn("tests/suite_2_test.gd", output)
        self.assertNotIn("tests/suite_4_test.gd", output)

    def test_git_change_discovery_retains_deleted_and_both_rename_paths(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-selection-git-") as scratch:
            repo = Path(scratch)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(
                ["git", "config", "user.name", "Selection Test"],
                cwd=repo,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "selection@example.invalid"],
                cwd=repo,
                check=True,
            )
            tests = repo / "tests"
            tests.mkdir()
            (tests / "deleted_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
            (tests / "old_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
            subprocess.run(["git", "add", "tests"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "base"], cwd=repo, check=True)
            base = subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=repo, text=True
            ).strip()
            (tests / "deleted_test.gd").unlink()
            subprocess.run(
                ["git", "mv", "tests/old_test.gd", "tests/new_test.gd"],
                cwd=repo,
                check=True,
            )
            with mock.patch.object(quality_gate, "ROOT", repo):
                changed = quality_gate._git_changed_paths(base)
        self.assertEqual(changed, {
            "tests/deleted_test.gd",
            "tests/old_test.gd",
            "tests/new_test.gd",
        })


if __name__ == "__main__":
    unittest.main()
