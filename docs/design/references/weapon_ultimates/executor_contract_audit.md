# Weapon ultimate executor contract audit

This document is the readable companion to
`executor_contract_audit.json`. The JSON file is the authoritative,
machine-checked map. The audit reads the 51 canonical pairs from
`data/ultimates/schema/v1/classes/*.json` and compares their accepted mechanic
contracts with the seven families exposed by
`UltimateExecutorLibrary.strategy_ids()`.

Audited `origin/dev`: `c0a0e9568361af90f2b15b0d88d5c5b897f1f4b2`.

## Result

All 17 classes and all 51 weapon IDs are present exactly once:

- `expressible_now`: 0 profiles;
- `needs_param_generalization`: 6 profiles;
- `needs_new_generic_primitive`: 45 profiles;
- missing, duplicate or extra pairs: 0.

This is a capability audit, not balance approval. A concrete parameter set
below states what the current family can execute; it does not replace the
class-package balance evidence.

The stricter `0 / 6 / 45` result is intentional. The proposed `0 / 46 / 5`
split would claim that forty current world-query and stateful gaps are merely
parameters; the complete 51-pair audit cannot make that claim while the live
executor and activation contracts lack those capabilities.

## Current executor space

| Family | Current params | Current limit |
| --- | --- | --- |
| `aimed_sequence` | `radius`, `damage`, `shot_count`, `interval` | Plans nearest targets once and re-acquires a dead planned target. |
| `burst` | `radius`, `damage`, `target_limit` | One instant circular hit. |
| `chained_projectile` | `radius`, `damage`, `jumps`, `hop_delay`, `falloff` | Nearest unique hops; no return, split or kill trigger. |
| `control` | `radius`, `damage`, `target_limit`, `knockback`, `status_id`, `status` | One outward radial force/status pulse. |
| `deploy_summon` | `scene`, `count`, `spawn_radius`, `lifetime`, `damage`, `properties` | One scene type placed on a circle; only existing properties are set. |
| `status_zone` | `radius`, `damage`, `duration`, `interval`, `follow_host`, `status_id`, `status` | One circular tick pattern and one status. |
| `timed_modifier` | `duration`, `radius`, `modifiers` | Owner modifiers only; cleanup is supported, outcome storage is not. |

## Live parameter admission

`UltimateExecutorLibrary` owns the authoritative contract for the seven rows
above. It requires each listed top-level key exactly once, rejects unknown or
missing keys, wrong types, non-finite numbers, fractional count/limit fields,
and values that an executor would otherwise clamp or default. Its normalized
result is the only parameter map that may enter a ready `UltimateActivation`.

Normalization sorts nested `status`, `properties`, and `modifiers`
dictionaries before signature comparison and rejects non-finite numeric leaves.
`status.dot_damage` is validated then removed, matching the status/control
executors that discard it to preserve the whole-activation damage ledger.
`properties` remain scene-specific: the contract preserves their values but
does not invent a cross-scene property schema.

`sniper/sniper_spotter_scope` is not an exact fit. Its marked target-centered
kill-zone needs an `aimed_sequence.marked_target_zone` generalization with a
marked-target anchor, zone radius and membership, retained-anchor policy, and
zone-scoped reacquisition. Current `aimed_sequence` plans and re-acquires from
the player origin, so it cannot preserve that zone without class or weapon
branching.

## Required minimum capability rulings

The five gaps called out by the foundation issue are all real shared gaps:

| Capability | Evidence in current runtime | Ruling and class-agnostic API |
| --- | --- | --- |
| Line/pierce geometry | `UltimateActivation.targets(center, radius, limit)` can query only a circle. | Required: `targets_in_corridor(start, direction, length, half_width, limit)` sorted by projected distance. |
| Arena bounds / ricochet | The host and activation contracts expose no playable bounds. | Required: `arena_bounds() -> Rect2`, backed by `ultimate_host_arena_bounds()`. |
| Directed fan split | No family has direction, fan, branch, split or pierce params. | Required generic trajectory params: `fan_count`, `fan_arc_degrees`, `split_count`, `split_arc_degrees`, `pierce_limit`, `direction_source`. |
| Priority selector | The player host returns nearest targets only. | Required: `select_targets(center, radius, limit, priority, hint)` with generic policies such as `nearest`, `highest_hp`, `aimed` and `densest_cluster`. |
| Per-target damage cap | `remaining_boss_budget()` opens a ledger only for nodes in `bosses`. | Required: activation-local budgets for every target through `set_per_target_damage_cap(cap_fraction, cap_flat)`. |

None of these is implemented by this audit.

## Bounded family parameter generalizations

These five mechanics need no new world-query surface. Their closest family has
the required target access and cleanup, but lacks exact data-driven parameters:

| Pair | Family | Exact missing params |
| --- | --- | --- |
| `berserk/sword` | `status_zone` | `radius_steps`, `damage_steps`, `finale_damage` |
| `sniper/sniper_spotter_scope` | `aimed_sequence` | `marked_target_anchor`, `zone_radius`, `zone_membership`, `anchor_retention`, `zone_scoped_reacquisition` |
| `engineer/engineer_sentry_wrench` | `deploy_summon` | `spawn_setup` |
| `elementalist/elementalist_orb_ring` | `status_zone` | `pulse_sequence`, `finale` |
| `knight/holy_flail` | `control` | `pulse_sequence`, `force_mode`, `radius_curve` |
| `ranger/hunter_trap` | `control` | `pulse_sequence`, `force_mode`, `target_tier_overrides` |

The JSON map defines the type and meaning of every missing parameter.

## Delivered shared primitives

| Primitive ID | Shared contract |
| --- | --- |
| `guard_prevention_ledger` | Player emits final-mitigation prevention only with source, direction and active owner; activation validates facing and replay before crediting an owner-scoped ledger. |
| `owner_resource_conversion` | Activation caps a measured owner resource, consumes it once, and emits the exact counter value through `owner_resource_emitted`. |

## Shared primitive backlog

The 45 remaining mechanics require at least one of these class-agnostic
primitives. Exact proposed signatures live in the JSON map.

| Primitive ID | Shared responsibility |
| --- | --- |
| `aim_context` | Stable aim point and direction through the host boundary. |
| `priority_target_selector` | Generic target ordering beyond nearest. |
| `line_pierce_geometry` | Corridor membership and ordered pierce. |
| `arena_bounds_query` | Playable bounds for edge placement and reflection. |
| `directed_fan_split` | Directed fan and branch trajectory data. |
| `per_target_damage_cap` | One activation budget per target, not only per boss. |
| `trajectory_motion` | Orbit, return, reflection, bounce and curved paths. |
| `ordered_step_composition` | Several current families sharing one activation ledger. |
| `pattern_geometry` | Deterministic rings, grids, radial sets, polygons and seeded annuli. |
| `stateful_target_ledger` | Marks, delayed values, transfers, stack consumption and recursion guards. |
| `control_resistance_policy` | Target-tier-safe pin, pull, root, stun and execute policy. |
| `summon_interaction_contract` | Generic temporary summon setup, cap rules and snapshot/restore. |
| `projectile_interaction_query` | Query and affect hostile projectiles. |
| `execute_threshold` | Normal-only execute with safe stronger-tier fallback. |

## Pair map

`param` means `needs_param_generalization`; `primitive` means
`needs_new_generic_primitive`. The final column names the exact missing
generalization or primitive IDs.

| Class / weapon | Classification | Closest live family | Gap |
| --- | --- | --- | --- |
| `assassin/chakrams` | primitive | `status_zone` | `trajectory_motion`, `directed_fan_split`, `stateful_target_ledger`, `execute_threshold` |
| `assassin/shadow_daggers` | primitive | `aimed_sequence` | `ordered_step_composition`, `stateful_target_ledger` |
| `assassin/venom_wire` | primitive | `control` | `pattern_geometry`, `stateful_target_ledger`, `control_resistance_policy` |
| `berserk/sword` | param | `status_zone` | `status_zone.radius_damage_steps` |
| `berserk/axe` | primitive | `aimed_sequence` | `aim_context`, `arena_bounds_query`, `trajectory_motion`, `stateful_target_ledger`, `execute_threshold` |
| `berserk/hammer` | primitive | `burst` | `line_pierce_geometry`, `pattern_geometry`, `ordered_step_composition` |
| `biologist/biologist_spore_lens` | primitive | `status_zone` | `pattern_geometry`, `stateful_target_ledger`, `control_resistance_policy` |
| `biologist/biologist_sample_injector` | primitive | `aimed_sequence` | `aim_context`, `priority_target_selector`, `line_pierce_geometry`, `stateful_target_ledger`, `per_target_damage_cap` |
| `biologist/biologist_symbiote_seed` | primitive | `deploy_summon` | `aim_context`, `summon_interaction_contract`, `control_resistance_policy`, `ordered_step_composition` |
| `chemist/blast_powder` | primitive | `control` | `pattern_geometry`, `ordered_step_composition`, `stateful_target_ledger`, `control_resistance_policy` |
| `chemist/acid_flask` | primitive | `status_zone` | `aim_context`, `ordered_step_composition`, `stateful_target_ledger` |
| `chemist/homunculus_vial` | primitive | `deploy_summon` | `summon_interaction_contract`, `ordered_step_composition`, `stateful_target_ledger` |
| `dark_mage/dark_book` | primitive | `burst` | `pattern_geometry`, `stateful_target_ledger`, `ordered_step_composition` |
| `dark_mage/cursed_skull` | primitive | `status_zone` | `stateful_target_ledger`, `control_resistance_policy`, `ordered_step_composition` |
| `dark_mage/dark_wand` | primitive | `chained_projectile` | `aim_context`, `priority_target_selector`, `stateful_target_ledger` |
| `doctor/restore_potion` | primitive | `status_zone` | `aim_context`, `ordered_step_composition` |
| `doctor/plague_syringe` | primitive | `chained_projectile` | `priority_target_selector`, `stateful_target_ledger`, `per_target_damage_cap`, `control_resistance_policy` |
| `doctor/bone_saw` | primitive | `status_zone` | `stateful_target_ledger` |
| `druid/summon_amulet` | primitive | `deploy_summon` | `directed_fan_split`, `priority_target_selector`, `summon_interaction_contract` |
| `druid/briar_staff` | primitive | `deploy_summon` | `pattern_geometry`, `summon_interaction_contract`, `control_resistance_policy` |
| `druid/raven_totem` | primitive | `deploy_summon` | `priority_target_selector`, `stateful_target_ledger`, `summon_interaction_contract`, `ordered_step_composition` |
| `elementalist/elementalist_orb_ring` | param | `status_zone` | `status_zone.element_steps` |
| `elementalist/elementalist_prism_focus` | primitive | `aimed_sequence` | `aim_context`, `line_pierce_geometry`, `arena_bounds_query`, `trajectory_motion`, `per_target_damage_cap` |
| `elementalist/elementalist_meteor_core` | primitive | `burst` | `aim_context`, `ordered_step_composition`, `control_resistance_policy` |
| `engineer/engineer_sentry_wrench` | param | `deploy_summon` | `deploy_summon.spawn_setup` |
| `engineer/engineer_repair_drone` | primitive | `deploy_summon` | `summon_interaction_contract`, `projectile_interaction_query`, `ordered_step_composition` |
| `engineer/engineer_pressure_mines` | primitive | `deploy_summon` | `pattern_geometry`, `stateful_target_ledger`, `ordered_step_composition` |
| `guitarist/electric_guitar` | primitive | `control` | `aim_context`, `line_pierce_geometry`, `pattern_geometry`, `control_resistance_policy` |
| `guitarist/bass_guitar` | primitive | `control` | `ordered_step_composition`, `per_target_damage_cap`, `control_resistance_policy` |
| `guitarist/sound_amp` | primitive | `deploy_summon` | `pattern_geometry`, `summon_interaction_contract`, `ordered_step_composition` |
| `knight/long_spear` | primitive | `control` | `aim_context`, `line_pierce_geometry`, `control_resistance_policy`, `ordered_step_composition` |
| `knight/tower_shield` | primitive | `timed_modifier` | `aim_context`, `control_resistance_policy` |
| `knight/holy_flail` | param | `control` | `control.pull_launch_spiral` |
| `priest/priest_reliquary` | primitive | `status_zone` | `ordered_step_composition`, `pattern_geometry` |
| `priest/priest_censer` | primitive | `timed_modifier` | `ordered_step_composition` |
| `priest/priest_chime` | primitive | `control` | `ordered_step_composition`, `control_resistance_policy` |
| `ranger/moon_crossbow` | primitive | `aimed_sequence` | `aim_context`, `priority_target_selector`, `directed_fan_split`, `stateful_target_ledger` |
| `ranger/storm_longbow` | primitive | `status_zone` | `aim_context`, `line_pierce_geometry`, `ordered_step_composition`, `control_resistance_policy` |
| `ranger/hunter_trap` | param | `control` | `control.collapsing_pulses` |
| `robot/robot_magnetic_anchor` | primitive | `control` | `aim_context`, `projectile_interaction_query`, `ordered_step_composition`, `control_resistance_policy` |
| `robot/robot_hydraulic_press` | primitive | `control` | `aim_context`, `line_pierce_geometry`, `ordered_step_composition` |
| `robot/robot_reactor_core` | primitive | `status_zone` | `ordered_step_composition` |
| `sniper/sniper_deadeye_rifle` | primitive | `aimed_sequence` | `aim_context`, `priority_target_selector`, `line_pierce_geometry`, `per_target_damage_cap` |
| `sniper/sniper_spotter_scope` | param | `aimed_sequence` | `aimed_sequence.marked_target_zone` — marked-target anchor, zone radius/membership, retained anchor, zone-scoped reacquisition |
| `sniper/sniper_shatter_rounds` | primitive | `aimed_sequence` | `aim_context`, `arena_bounds_query`, `directed_fan_split`, `trajectory_motion`, `per_target_damage_cap` |
| `soldier/soldier_rifle` | primitive | `aimed_sequence` | `aim_context`, `line_pierce_geometry`, `priority_target_selector`, `ordered_step_composition` |
| `soldier/soldier_grenade` | primitive | `deploy_summon` | `aim_context`, `pattern_geometry`, `ordered_step_composition`, `stateful_target_ledger` |
| `soldier/soldier_bayonet` | primitive | `control` | `aim_context`, `line_pierce_geometry`, `control_resistance_policy` |
| `thief/thief_coin_pouch` | primitive | `chained_projectile` | `priority_target_selector`, `stateful_target_ledger`, `trajectory_motion` |
| `thief/thief_shadow_cloak` | primitive | `aimed_sequence` | `priority_target_selector`, `stateful_target_ledger`, `ordered_step_composition`, `per_target_damage_cap` |
| `thief/thief_smoke_bomb` | primitive | `timed_modifier` | `projectile_interaction_query`, `stateful_target_ledger`, `ordered_step_composition` |

## Class-package delivery contract

A class mechanics package may write only:

- `data/ultimates/schema/v1/classes/<class>.json`, and only profile `params`
  objects;
- `docs/design/references/weapon_ultimates/<class>/**`;
- its own `tests/ultimates/<class>_**` tests.

It must not write:

- `scripts/ultimates/executors/**`;
- `scripts/ultimates/registry/**`;
- `scripts/ultimates/controller/**`;
- `tests/ultimates/registry_contract_test.gd`.

Class packages may declare their profile data before FAN-1541. Every persisted
profile nevertheless remains `implementation_state: "declared"`, and the
`targeting`, `charge`, `executor` and `cleanup_policy` strategy IDs remain
`"unbound"`. Only FAN-1541 may bind or activate any of the 51 profiles; a
class-local package is never independently activatable.

Class tests prove weapon-local distinction in memory through
`tests/ultimates/weapon_ultimate_distinctness_helper.gd`. The helper deep-copies
the registry maps, delegates family/key/parameter validation and normalization
to `UltimateExecutorLibrary`, injects only its normalized ready/bound contracts,
and compares the library's canonical semantic signatures. It resolves all three
exact weapon IDs, rejects aliases, and verifies that the shipped registry still
selects the legacy fallback. The audit test demonstrates this once, on Sniper,
without changing catalog data.

## Runtime invariants

This audit adds no runtime primitive and changes no game behavior. All 51
profiles remain declared, all four binding strategy IDs remain unbound, and
legacy class fallback remains the executable path until FAN-1541.
