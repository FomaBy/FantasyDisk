"""Pure Godot-suite selection policy for :mod:`tools.quality_gate`.

The runner owns repository discovery and Git/process I/O.  This module accepts
plain repo-relative paths and returns a deterministic selection, which keeps
the domain policy directly testable without a checkout or subprocesses.
Unknown domains fail toward the full discovered suite set.  Known shared
surfaces retain their broader inheritance, class-wide, or umbrella coverage.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import PurePosixPath
from typing import Iterable, Mapping, Sequence


RUNTIME_SMOKE = "runtime_smoke_test"
RUNTIME_SMOKE_HELPER_PATH = "tests/support/runtime_smoke_helpers.gd"
CORE_CHANGED_TESTS = frozenset({
    "combat_target_query_cache_test",
    "runtime_smoke_combat_test",
    "runtime_smoke_ui_test",
    "weapon_ultimate_contact_sheet_beats_test",
    "weapon_ultimate_timing_distinctness_test",
})
TYPOGRAPHY_INVENTORY_TEST = "semantic_typography_scrum1061_test"
TYPOGRAPHY_INVENTORY_SKIP = frozenset({
    "scripts/dev_console.gd",
    "scripts/ui/semantic_typography.gd",
})
TYPOGRAPHY_INVENTORY_RESOURCE_SUFFIXES = frozenset({".tscn", ".tres", ".theme"})
ULTIMATE_EXECUTOR_CONTRACT_TESTS = frozenset({
    "controller_runtime_test",
    "controller_player_integration_test",
    "executor_contract_audit_test",
    "executor_primitives_test",
    "registry_package_discovery_test",
})
ULTIMATE_PACKAGE_CONTRACT_TESTS = frozenset({
    "executor_primitives_test",
    "registry_contract_test",
    "registry_package_discovery_test",
})
# Class-package changes also affect Player routing and tracked-tween lifecycle.
ULTIMATE_CLASS_PACKAGE_TESTS = ULTIMATE_PACKAGE_CONTRACT_TESTS | frozenset({
    "controller_player_integration_test",
    "tracked_tween_natural_completion_test",
})
SHARED_PRESENTATION_CONSUMER_TESTS = frozenset({
    "fan1541_activation_integration_test",
    "presentation_contract_test",
    "presentation_contract_validator_test",
    "presentation_failure_contract_test",
    "ultimate_player_host_presentation_constructor_test",
    "ultimate_player_host_time_scale_test",
})
OFFENSIVE_CONTRACT_TESTS = frozenset({
    "attribute_consumability_fan1887_test",
    "attribute_ui_matrix_fan1927_test",
    "damage_type_isolation_test",
    "offensive_scaling_contract_test",
    "stat_formulas_smoke_test",
})
CADENCE_STATUS_CONTRACT_TESTS = frozenset({
    "chemist_kit_test",
    "engineer_kit_test",
    "persistent_hazard_contract_test",
    "pool_dot_runaway_gate",
})
ANIMATION_REGISTRY_TESTS = frozenset({
    "animation_smoke_test",
    "full_frame_eight_direction_contract_test",
    "full_frame_registry_integrity_test",
    "full_frame_registry_shard_validation_test",
})
BALANCE_CONTRACT_TESTS = frozenset({
    "balance_harness_test",
    "class_damage_table_3variants_test",
    "global_damage_balance_smoke_test",
})
DEFENSIVE_CONTRACT_TESTS = frozenset({
    "assassin_kit_test",
    "defensive_attribute_contract_fan1895_test",
    "robot_kit_test",
    "thief_kit_test",
})
BALANCE_SENSITIVE_PATHS = frozenset({
    "scripts/class_weapon.gd",
    "scripts/player.gd",
    "scripts/progression_data.gd",
    "scripts/progression_data_balance.gd",
    "scripts/progression_data_weapons.gd",
})
CONSUMABILITY_GATE_TEST = "attribute_consumability_fan1887_test"
ULTIMATE_FEATURE_LIST_TRIGGER_PREFIXES = ("data/ultimates/", "tests/ultimates/")
ULTIMATE_FEATURE_LIST_TRIGGER_PATHS = frozenset({
    "tools/ultimate_feature_list_check.py",
    "tests/test_ultimate_feature_list.py",
})

PATH_TEST_RULES: Mapping[str, frozenset[str]] = {
    "scripts/ultimates/classes/thief/thief_coin_pouch.gd": frozenset({
        "thief_live_test",
        "thief_balance_test",
    }),
    "scripts/attribute_contract.gd": (
        OFFENSIVE_CONTRACT_TESTS | CADENCE_STATUS_CONTRACT_TESTS
    ),
    "scripts/berserk_weapon.gd": frozenset({"berserk_rage_trait_test"}),
    "scripts/full_frame_animation_registry.gd": ANIMATION_REGISTRY_TESTS,
    "scripts/class_weapon.gd": CADENCE_STATUS_CONTRACT_TESTS | frozenset({"coverage_cap_gate"}),
    "scripts/meta_progression_tree_data.gd": frozenset({"offensive_scaling_contract_test"}),
    "scripts/player.gd": (
        OFFENSIVE_CONTRACT_TESTS
        | CADENCE_STATUS_CONTRACT_TESTS
        | DEFENSIVE_CONTRACT_TESTS
        | frozenset({"berserk_rage_trait_test"})
    ),
    "scripts/progression_data.gd": (
        OFFENSIVE_CONTRACT_TESTS
        | CADENCE_STATUS_CONTRACT_TESTS
        | BALANCE_CONTRACT_TESTS
        | DEFENSIVE_CONTRACT_TESTS
        | frozenset({"berserk_rage_trait_test"})
    ),
    "scripts/progression_data_characters.gd": frozenset({"berserk_rage_trait_test"}),
    "scripts/progression_data_balance.gd": (
        OFFENSIVE_CONTRACT_TESTS
        | BALANCE_CONTRACT_TESTS
        | DEFENSIVE_CONTRACT_TESTS
    ),
    "scripts/progression_data_content.gd": frozenset({"offensive_scaling_contract_test"}),
    "scripts/progression_data_weapons.gd": (
        OFFENSIVE_CONTRACT_TESTS
        | CADENCE_STATUS_CONTRACT_TESTS
        | BALANCE_CONTRACT_TESTS
    ),
    "scripts/sentry_turret.gd": frozenset({"engineer_kit_test"}),
    "scripts/stat_formulas.gd": OFFENSIVE_CONTRACT_TESTS,
    "scripts/status_effects.gd": frozenset({
        "chemist_kit_test",
        "persistent_hazard_contract_test",
        "pool_dot_runaway_gate",
    }),
    "scripts/enemy.gd": frozenset({"enemy_separation_behavior_test"}),
    "scripts/threat_indicators.gd": frozenset({"hot_path_cache_test"}),
    "scripts/feedback_reporter.gd": frozenset({
        "feedback_request_lifecycle_test",
        "feedback_relay_contract_test",
        "feedback_privacy_contract_test",
        "feedback_privacy_ui_test",
        "feedback_retry_policy_test",
        "feedback_webhook_config_test",
    }),
    "scripts/ui_screens.gd": frozenset({"feedback_privacy_ui_test"}),
    "scripts/ui/feedback_overlay.gd": frozenset({"feedback_privacy_ui_test"}),
    "scripts/ultimates/controller/ultimate_controller.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_activation.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_damage_result.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_player_host.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_control_executor.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_executor_library.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_targeting_primitives.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_package_discovery.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_registry.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_resolver.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/schema/weapon_ultimate_schema.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "data/ultimates/schema/v1/weapon_ultimate_profile.schema.json": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "tests/feedback_webhook_config_test.gd": frozenset({"feedback_webhook_config_test"}),
}

_STATIC_DOMAIN_PREFIXES = (
    ".claude/",
    ".github/",
    "docs/",
    "skills/",
    "source_docs/",
    "tools/",
)
_STATIC_ROOT_PATHS = frozenset({
    ".gitignore",
    "AGENTS.md",
    "LICENSE",
    "README.md",
    "requirements-ci.txt",
})
_CANONICAL_CHANGELOG_FRAGMENT_RE = re.compile(r"^changelog\.d/FAN-[1-9][0-9]*\.md$")


@dataclass(frozen=True)
class SelectionResult:
    """Selected repo-relative suite paths and any conservative fallback cause."""

    suite_paths: tuple[str, ...]
    full_fallback_paths: tuple[str, ...] = ()

    @property
    def used_full_fallback(self) -> bool:
        return bool(self.full_fallback_paths)


def index_suite_paths(discovered_paths: Sequence[str]) -> dict[str, str]:
    """Index suites by stem and reject ambiguous filter/rule names."""
    by_name: dict[str, str] = {}
    collisions: dict[str, list[str]] = {}
    for path in discovered_paths:
        name = PurePosixPath(path).stem
        previous = by_name.get(name)
        if previous is None:
            by_name[name] = path
            continue
        collisions.setdefault(name, [previous]).append(path)
    if collisions:
        details = "; ".join(
            f"{name} -> " + ", ".join(paths)
            for name, paths in sorted(collisions.items())
        )
        raise RuntimeError(f"ambiguous Godot test names across directories: {details}")
    return by_name


def dependent_suite_names(
    discovered_paths: Sequence[str],
    parent_resources: Mapping[str, str],
    dependency_resource: str,
) -> set[str]:
    """Return executable suites inheriting a resource, including transitively."""
    affected_resources = {dependency_resource}
    selected: set[str] = set()
    pending = dict(parent_resources)
    while pending:
        matched = sorted(
            path for path, parent in pending.items() if parent in affected_resources
        )
        if not matched:
            break
        for path in matched:
            affected_resources.add(f"res://{path}")
            selected.add(PurePosixPath(path).stem)
            del pending[path]
    return selected


def affects_typography_inventory(path: str) -> bool:
    path_parts = PurePosixPath(path).parts
    if path.startswith("scripts/"):
        return (
            path.endswith(".gd")
            and path not in TYPOGRAPHY_INVENTORY_SKIP
            and "/dev/" not in path
        )
    return (
        PurePosixPath(path).suffix in TYPOGRAPHY_INVENTORY_RESOURCE_SUFFIXES
        and ".godot" not in path_parts
        and "build" not in path_parts
    )


def touches_ultimate_feature_list(changed_paths: Iterable[str]) -> bool:
    return any(
        path.startswith(ULTIMATE_FEATURE_LIST_TRIGGER_PREFIXES)
        or path in ULTIMATE_FEATURE_LIST_TRIGGER_PATHS
        for path in changed_paths
    )


def _is_static_domain(path: str) -> bool:
    return (
        path in _STATIC_ROOT_PATHS
        or path == "CHANGELOG.md"
        or path.startswith(_STATIC_DOMAIN_PREFIXES)
        or _CANONICAL_CHANGELOG_FRAGMENT_RE.fullmatch(path) is not None
        or (path.startswith("tests/") and path.endswith(".py"))
    )


def select_suite_paths(
    *,
    profile: str,
    filters: Sequence[str],
    changed_paths: Iterable[str],
    discovered_paths: Sequence[str],
    parent_resources: Mapping[str, str],
    defensive_fixture_paths: Iterable[str],
    feature_list_recipe_scripts: Iterable[str],
    skip_umbrella: bool,
) -> SelectionResult:
    """Select suites without performing repository, Git, or process I/O."""
    if profile == "static":
        return SelectionResult(())

    by_name = index_suite_paths(discovered_paths)
    all_names = set(by_name)
    fallback_paths: set[str] = set()

    if profile in {"full", "windows"}:
        selected_names = set(all_names)
    else:
        selected_names = set(CORE_CHANGED_TESTS)
        fixtures = frozenset(defensive_fixture_paths)
        changed = frozenset(changed_paths)
        recipes = frozenset(feature_list_recipe_scripts)
        for changed_path in sorted(changed):
            recognized = False
            exact = PATH_TEST_RULES.get(changed_path)
            if exact is not None:
                selected_names.update(exact)
                recognized = True
            if changed_path == RUNTIME_SMOKE_HELPER_PATH:
                selected_names.update(dependent_suite_names(
                    discovered_paths,
                    parent_resources,
                    f"res://{RUNTIME_SMOKE_HELPER_PATH}",
                ))
                recognized = True
            if touches_ultimate_feature_list((changed_path,)):
                selected_names.update(
                    PurePosixPath(script.removeprefix("res://")).stem
                    for script in recipes
                    if PurePosixPath(script.removeprefix("res://")).stem in by_name
                )
                recognized = True
            if changed_path in fixtures:
                selected_names.add(CONSUMABILITY_GATE_TEST)
                recognized = True
            if changed_path.startswith((
                "data/ultimates/classes/",
                "scripts/ultimates/classes/",
            )):
                selected_names.update(ULTIMATE_CLASS_PACKAGE_TESTS)
                recognized = True
            if changed_path.startswith("data/animation/"):
                selected_names.update(ANIMATION_REGISTRY_TESTS)
                actor_stem = f"{PurePosixPath(changed_path).stem}_smoke_test"
                if actor_stem in by_name:
                    selected_names.add(actor_stem)
                else:
                    selected_names.update(
                        name for name, path in by_name.items()
                        if path.startswith("tests/actors/")
                    )
                recognized = True
            if changed_path == "scripts/full_frame_animation_registry.gd":
                selected_names.update(
                    name for name, path in by_name.items()
                    if path.startswith("tests/actors/")
                )
                recognized = True
            if changed_path in BALANCE_SENSITIVE_PATHS or changed_path.startswith("scripts/classes/"):
                selected_names.update(
                    name for name, path in by_name.items()
                    if path.startswith("tests/balance/")
                )
                recognized = True
            if changed_path.startswith("scripts/ultimates/presentation/"):
                selected_names.update(SHARED_PRESENTATION_CONSUMER_TESTS)
                selected_names.update(
                    name for name, path in by_name.items()
                    if path.startswith("tests/ultimates/presentation/")
                )
                recognized = True
            if affects_typography_inventory(changed_path):
                selected_names.add(TYPOGRAPHY_INVENTORY_TEST)
                recognized = True
            if changed_path.startswith("tests/") and changed_path.endswith(".gd"):
                suite_name = PurePosixPath(changed_path).stem
                if changed_path in discovered_paths:
                    selected_names.add(suite_name)
                    recognized = True
                elif changed_path != RUNTIME_SMOKE_HELPER_PATH:
                    fallback_paths.add(changed_path)
                    recognized = True
            if changed_path.startswith("tests/") and changed_path.endswith(".gd.uid"):
                script_path = changed_path.removesuffix(".uid")
                if script_path in discovered_paths:
                    selected_names.add(PurePosixPath(script_path).stem)
                    recognized = True
            if changed_path.startswith(("scripts/", "scenes/")) or changed_path in {
                "project.godot", "export_presets.cfg"
            }:
                selected_names.add(RUNTIME_SMOKE)
                recognized = True
            if _is_static_domain(changed_path):
                recognized = True
            if not recognized:
                fallback_paths.add(changed_path)

        if fallback_paths:
            selected_names = set(all_names)

    if skip_umbrella:
        selected_names.discard(RUNTIME_SMOKE)
    if filters:
        selected_names = {
            name for name in selected_names
            if any(pattern.lower() in name.lower() for pattern in filters)
        }
    return SelectionResult(
        tuple(by_name[name] for name in sorted(selected_names) if name in by_name),
        tuple(sorted(fallback_paths)),
    )
