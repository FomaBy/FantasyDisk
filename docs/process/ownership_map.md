# Parallel ownership map

Updated: 2026-09-05. Authority: `ADR-parallel-agent-ownership.md` and the live Multica card. This map describes path leases, not permission to start work. PM readiness, the dispatcher, and the same-card lifecycle remain control-plane concerns.

Two cards may proceed concurrently only when their declared write sets and behaviour contracts are disjoint. A broad label such as `core` is not an exclusive lease by itself. Actual shared files, generated outputs, data schemas, and observable contracts decide overlap. Integration into `dev` is always serial.

## Initial six owner-authorized slices

These are the concrete initial-frontier cards, not reusable architecture
categories. Their path lists are the exact declared leases at publication; live
Multica status decides whether a card may start.

| Card and resource | Exact declared paths |
| --- | --- |
| FD01 / [FAN-3908](mention://issue/01a06e33-1f4b-79fc-919d-003ef3bf9d17) — `git:FomaBy/FantasyDisk:paths:architecture-map` | `AGENTS.md`; `docs/design/systems/technical_architecture.md`; `docs/process/adr/ADR-parallel-agent-ownership.md`; `docs/process/agent_role_boundaries_and_handoffs.md`; `docs/process/ai_agent_memorandum.md`; `docs/process/code_quality_and_performance.md`; `docs/process/context_engineering.md`; `docs/process/dispatcher-authority.md`; `docs/process/human_readable_comments.md`; `docs/process/multica_workflow.md`; `docs/process/ownership_map.md`; `docs/process/pm_workflow.md`; `docs/process/qa_protocol.md`; `docs/process/story_points.md`; `docs/process/versioning_and_branching.md` |
| FD02 / [FAN-3909](mention://issue/01a06e33-3256-78d3-962a-f7484eaa3d70) — `git:FomaBy/FantasyDisk:paths:quality-tooling` | `tests/test_architecture_inventory.py`; `tests/test_gdscript_contracts.py`; `tests/test_quality_static_guard.py`; `tools/architecture_inventory.py`; `tools/check_gdscript_contracts.py`; `tools/quality_static_guard.py` |
| FD10 / [FAN-3917](mention://issue/01a06e33-c68a-7632-b216-9925b3eef746) — `git:FomaBy/FantasyDisk:paths:target-query` | `scripts/combat_target_query.gd`; `scripts/combat_target_query.gd.uid`; `tests/combat_target_query_cache_test.gd`; `tests/combat_target_query_cache_test.gd.uid`; `tests/combat_target_query_top_k_test.gd`; `tests/combat_target_query_top_k_test.gd.uid` |
| FD12 / [FAN-3919](mention://issue/01a06e33-ec38-7925-a04b-a46f91566420) — `git:FomaBy/FantasyDisk:paths:encounter-spawn` | `scripts/combat_director.gd`; `scripts/combat_director.gd.uid`; `scripts/encounters/encounter_adapter.gd`; `scripts/encounters/encounter_adapter.gd.uid`; `scripts/encounters/encounter_scene_cache.gd`; `scripts/encounters/encounter_scene_cache.gd.uid`; `tests/encounters/encounter_scene_prewarm_test.gd`; `tests/encounters/encounter_scene_prewarm_test.gd.uid`; `tests/encounters/encounter_spawn_plan_quota_test.gd`; `tests/encounters/encounter_spawn_plan_quota_test.gd.uid` |
| FD13 / [FAN-3920](mention://issue/01a06e33-fec6-72c6-b696-20db9397c946) — `git:FomaBy/FantasyDisk:paths:player-core` | `scripts/player.gd`; `scripts/player.gd.uid`; `scripts/player/player_damage_policy.gd`; `scripts/player/player_damage_policy.gd.uid`; `tests/player_damage_policy_characterization_test.gd`; `tests/player_damage_policy_characterization_test.gd.uid` |
| FD16 / [FAN-3923](mention://issue/01a06e34-35ec-7847-93af-26d68a2bf4e1) — `git:FomaBy/FantasyDisk:paths:progression-data` | `scripts/progression/weapon_budget_model.gd`; `scripts/progression/weapon_budget_model.gd.uid`; `scripts/progression_data.gd`; `scripts/progression_data.gd.uid`; `tests/weapon_budget_model_characterization_test.gd`; `tests/weapon_budget_model_characterization_test.gd.uid` |

The table does not reserve a broad `core` category. The six cards may proceed
when their live write sets are still disjoint; each retains its own acceptance
criteria and the shared `git:FomaBy/FantasyDisk:dev` integration lease.

## Existing split surfaces

- Animation data is per actor under `data/animation/**`; the facade remains `scripts/full_frame_animation_registry.gd`.
- Class-specific execution is under `scripts/classes/`; `scripts/class_weapon.gd` closes the inheritance chain.
- UI screen modules live under `scripts/ui/screens/`; `scripts/ui_screens.gd` is the facade.
- Per-class ultimates, tests, and design pages belong to the matching class slice.

Physical inheritance-chain files are not independent components. A module that extends another can share state, virtual methods, preload order, or a facade contract; cards touching that chain must declare the shared contract and serialize if it overlaps.

## Shared-path budget and conflict handling

A domain card may change no more than one shared path unless PM explicitly marks it `cross-domain`. Typical shared paths are `CHANGELOG.md`, `docs/design/content_registry.md`, `docs/design/systems/animation.md`, registry facades, UI kits, and progression-data files. A cross-domain card serializes with every affected lease. Do not broaden a lease during implementation: return the concrete additional path and reason for PM review.

QA reads the candidate write set but does not obtain a production-code lease. QA reports through the same card; screenshots and reports belong in Multica evidence unless the card explicitly owns an additive evidence path.

The later FD02 inventory tool is not part of this card. When it exists, use its machine-readable report to refresh this map; until then, verify paths from the current checkout and the issue's exact manifest.
