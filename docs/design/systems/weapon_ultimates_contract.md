# Weapon-keyed ultimate contract

Status: schema v1 is implemented as a declaration and migration foundation.
Gameplay still executes the existing class ultimate until an individual weapon
profile is explicitly marked `ready`.

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

## Codex and downstream consumers

For current player-visible behavior and balance, the authoritative executable
source remains the class-level `ProgressionData.ultimate_config(class_id)`.
The new catalog is authoritative only for weapon-profile identity and future
bindings. Codex may inspect the exact selected declaration, but must not
describe an unbound `declared` profile as implemented gameplay.

Future per-weapon implementations should:

1. Keep the immutable profile and presentation IDs.
2. Add class-local strategy bindings without adding selection branches to
   `Player` or `ClassWeapon`.
3. Supply a whole-activation boss cap.
4. Change only that profile to `ready`.
5. Prove the selected weapon resolves the profile while both siblings remain
   negative controls.

## Verification

Run the focused contract and mutation tests directly:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_validator_test.gd
```

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
