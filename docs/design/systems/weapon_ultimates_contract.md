# Weapon-keyed ultimate contract

Status: schema v1 is implemented as a declaration and migration foundation, and
the generic runtime that executes a ready declaration now exists. Gameplay still
executes the existing class ultimate until an individual weapon profile is
explicitly marked `ready`; no shipped profile is, so behaviour is unchanged.

## Scope and source of truth

The catalog contains one immutable declaration for every playable
class/weapon pair: 17 classes × 3 weapons = 51 profiles.

Profiles are composed from the JSON files in
`data/ultimates/schema/v1/classes/`. Each class owns one file and its three
profiles. There is deliberately no hand-maintained central manifest: the
registry scans the directory, validates the files against the canonical weapon
inventory supplied by its caller, and builds the runtime index only after the
entire catalog passes validation.

`scripts/ultimates/schema/weapon_ultimate_schema.gd` validates the catalog.
`scripts/ultimates/registry/weapon_ultimate_registry.gd` loads and indexes it.
`scripts/ultimates/registry/weapon_ultimate_resolver.gd` owns the pure
selection and migration policy.

The registry should be constructed once at an integration boundary with
`ProgressionData.WEAPONS_BY_CLASS` and cached. Do not parse the directory on
every cast, hit, or frame.

## Profile contract

Each profile is keyed by the exact `(class_id, weapon_id)` pair and declares:

| Area | Required contract |
| --- | --- |
| Identity | Immutable profile, title, and mechanic IDs |
| Targeting | Aim ID, targeting strategy, and declarative parameters |
| Charge | Charge policy ID, strategy, and declarative parameters |
| Cast lifecycle | Acquire, windup, execute, active, recover, and cleanup phase IDs |
| Execution | Executor ID, strategy, and declarative parameters |
| Boss safety | Whole-activation `total_boss_cap` |
| Presentation | Presentation, animation, VFX, and SFX IDs plus parameters |
| Cleanup | Cleanup policy, strategy, and parameters |

All IDs use the namespace
`weapon_ultimate.<family>.<class_id>.<weapon_id>[.<phase>]`. Profile, title,
mechanic, aim, charge, executor, presentation, animation, VFX, SFX, cleanup,
and phase IDs are unique. These IDs are data contracts: rename them only
through an explicit versioned migration.

The legacy class field `boss_cap` is a per-hit cap. It must not be copied into
`total_boss_cap`, which limits the damage of the whole ultimate activation.
Declared v1 profiles therefore use `null`; a profile cannot become `ready`
until it supplies a numeric value in `(0, 1]`.

## Executor parameter admission

`UltimateExecutorLibrary` is the production owner of every live executor
family's parameter contract. Before a ready profile creates an
`UltimateActivation`, `UltimateController` asks the library to validate and
normalize the executor parameters. Unknown families or keys, missing keys,
wrong types, non-finite numbers, fractional integer fields, and values outside
the live executor domains fail closed with no activation or host side effect.

The library returns deterministic normalized dictionaries and canonical
signatures. Nested `status`, `properties`, and `modifiers` dictionaries are
ordered recursively; non-finite numeric leaves are rejected. `status.dot_damage`
is excluded from the normalized semantic signature because the live
`status_zone` and `control` executors deliberately discard it so DoT cannot
bypass the activation-wide damage ledger. `properties` remain deliberately
scene-specific until FAN-1541 owns a generic property contract.

## Declaration and execution states

`declared` means the data identity and lifecycle shape exist, but gameplay
strategies are intentionally unbound. Targeting, charge, executor, and cleanup
strategies must all be `unbound`, and the profile is not executable.

`ready` means those strategies are bound and `total_boss_cap` is valid. Only
the exact selected weapon's ready profile may resolve as an executable weapon
ultimate. A ready profile never activates either sibling weapon declaration.

Catalog lookup and executable resolution are separate APIs:

- `catalog_profile_for(class_id, weapon_id)` returns the exact declaration for
  inspection, Codex context, tooling, and future UI.
- `resolve_executable(...)` returns either the exact ready weapon profile or an
  exact deep copy of the caller-provided legacy class configuration.
- `resolution_source(...)` exposes whether the result is a weapon profile,
  legacy fallback, invalid pair, or unavailable because fallback was disabled.

Unknown class/weapon pairs fail closed and never inherit an unrelated class
ultimate.

## Migration fallback

During migration, every declared or temporarily missing profile for a known
canonical pair resolves to the existing class ultimate when
`allow_legacy_fallback` is enabled. The caller supplies that legacy dictionary;
the resolver does not import `ProgressionData` and cannot create a preload
cycle.

The fallback is returned unchanged as a deep copy. Weapon targeting, charge,
phase, executor, total-cap, presentation, and cleanup declarations are bypassed
completely. This preserves current gameplay until the exact weapon profile is
ready. The migration gate can disable fallback later without changing the
catalog.

No save migration is part of schema v1. The persisted contract remains
`character_id`, `weapon_id`, and `ultimate_charge`; no profile ID or weapon
ultimate state is written.

## Runtime: controller, activation, executor families

`scripts/ultimates/controller/ultimate_controller.gd` is the single activation
path. It reads `resolution_source(...)`, and only a `weapon_profile` result is
taken over; a `legacy_class_fallback` result makes `activate()` return false so
the caller keeps running its unchanged class ultimate. That is the migration
bridge, and it is why every profile can stay `declared` without any gameplay
change.

`scripts/ultimates/controller/ultimate_activation.gd` is one live cast. Executors
never touch the Player: they ask the activation for targets, damage, modifiers,
spawns and presentation. The host side is the eight `ultimate_host_*` methods
listed in `UltimateActivation.HOST_METHODS`, implemented by
`scripts/ultimates/controller/ultimate_player_host.gd`, a Node the Player owns as
a child. Nothing below the adapter may branch on a class or a weapon.

`scripts/player.gd` therefore keeps only a four-line boundary: the host preload,
`ULTIMATE_HOST.reset(self)` at the top of `configure_character`, and the
`ULTIMATE_HOST.activate(self)` delegation in `activate_ultimate`. Death,
scene change and node end need no hook at all — the host is a Player child, so
its own `_exit_tree` cancels the cast. Only the new run needs the explicit call,
and it must stay before `run_modifiers` is reset, otherwise the modifier revert
would land on freshly created defaults.

Executor families live in `scripts/ultimates/executors/` and are selected purely
by `executor.strategy_id`:

| `strategy_id` | Shape |
| --- | --- |
| `burst` | One instant hit on everything the declaration selects |
| `aimed_sequence` | N aimed shots over time, re-acquiring dead targets |
| `timed_modifier` | Hold declared run modifiers for the cast duration |
| `status_zone` | Lingering area that ticks damage and refreshes a status |
| `control` | Displacement plus a lockdown status in a radius |
| `deploy_summon` | Place declared scenes the activation owns |
| `chained_projectile` | Hops between distinct targets with damage falloff |

A family that schedules its own tween expresses the whole cast length in that
tween; the controller chains completion onto it rather than racing it with a
parallel timer. A family that schedules nothing returns its lifetime instead.

`UltimateDamageResult.applied` is the HP the target actually lost, mirroring the
overkill-clamped delta `enemy.gd` publishes. Attribution, ledgers and charge read
`applied`, never the attempted amount, so overkill and damage-taken reductions
cannot inflate them.

`total_boss_cap` is a budget for the whole activation, opened once per boss at
`max_health * total_boss_cap` and drawn down by applied HP. Multi-hit, DoT-style
zone ticks and deferred summon damage all spend the same budget: a spawn that
exposes an `ultimate_damage_sink` property is bound to the activation ledger, and
zone ticks deliberately do not use a StatusEffects `dot_damage`, which would tick
on the target and bypass the budget. Normal enemies are never capped.

The activation owns every resource it created. Player death, leaving the tree and
a new run all call `cancel()`, which kills tracked tweens, frees summons, deploys
and presentation nodes, and unwinds modifiers in reverse order. A cast that simply
ran to completion unwinds the same way but lets its last VFX fade.

## Codex and downstream consumers

For current player-visible behavior and balance, the authoritative executable
source remains the class-level `ProgressionData.ultimate_config(class_id)`.
The new catalog is authoritative only for weapon-profile identity and future
bindings. Codex may inspect the exact selected declaration, but must not
describe an unbound `declared` profile as implemented gameplay.

Before FAN-1541, class packages may add only declaration data, class-local
evidence, and in-memory proof. They must not bind strategies, mark a profile
`ready`, or activate a profile independently. FAN-1541 owns the later binding
and activation stage; when it runs, it must keep immutable IDs, avoid selection
branches in `Player` or `ClassWeapon`, supply a whole-activation boss cap, and
prove the selected weapon resolves while both siblings remain negative controls.

## Verification

Run the focused contract and mutation tests directly:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_validator_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/executor_contract_audit_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/controller_runtime_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/controller_player_integration_test.gd
```

`controller_runtime_test` drives every executor family through the same
`activate(class_id, weapon_id)` call from fixture declarations, and asserts that
no source file under `scripts/ultimates/controller/` or
`scripts/ultimates/executors/` mentions any canonical class or weapon id. It also
covers refused re-entry, a paused tree, cancellation, applied-versus-attempted
HP, and the whole-activation boss budget including deferred summon damage.
`controller_player_integration_test` holds the other half: every shipped profile
still resolves to the legacy class ultimate, all 17 class ultimates still fire and
spend their charge exactly once, and — with a ready declaration injected — the
host adapter drives a real cast that a new run or a node end drops.

The tests cover all 51 selections, both sibling negative controls for every
selection, exact legacy fallback preservation, fail-closed unknown pairs,
missing and duplicate pairs, unknown classes and weapons, unique profile,
title, mechanic, and presentation IDs, and readiness safety in both
directions: a `declared` profile may not bind an executor, and a `ready`
profile may neither omit its whole-activation boss cap nor keep its executor
unbound.

Run them explicitly, as shown above, for focused local evidence.
`tools/quality_gate.py` also discovers Godot tests recursively and maps nested
paths such as `tests/ultimates/` to their `res://tests/...` script paths. The
certifying changed or full profile therefore includes both registry tests when
this package changes; `--static-only` deliberately runs no Godot tests.
