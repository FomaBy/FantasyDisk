# Weapon-keyed ultimate contract

Status: schema v1 has live exact-pair discovery. The generic runtime executes
the admitted JSON/GDScript package for every canonical class/weapon selection;
the 17-class roster has 51 such pairs. A missing, duplicated or mismatched pair
invalidates discovery rather than being silently replaced.

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

Class mechanics are additive overlays, discovered recursively from matching
relative paths below `data/ultimates/classes/<class>/**` and
`scripts/ultimates/classes/<class>/**`. They never edit or duplicate the
immutable catalog declaration.

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
Integral JSON numbers are canonicalized to `int`; no fractional value is
truncated.

The library returns deterministic normalized dictionaries and canonical
signatures. Nested `status`, `properties`, and `modifiers` dictionaries are
ordered recursively; non-finite numeric leaves are rejected. `status.dot_damage`
is excluded from the normalized semantic signature because the live
`status_zone` and `control` executors deliberately discard it so DoT cannot
bypass the activation-wide damage ledger. Central-family `properties` remain
scene-specific; summon interaction snapshots only explicitly declared property
names.

## Declaration and execution states

`declared` means the data identity and lifecycle shape exist, but gameplay
strategies are intentionally unbound. Targeting, charge, executor, and cleanup
strategies must all be `unbound`, and the profile is not executable.

`ready` means those strategies are bound and `total_boss_cap` is valid. Only
the exact selected weapon's ready profile with an admitted executor pair may
resolve as an executable weapon ultimate. Ready data without its exact script
remains on legacy fallback. A ready profile never activates either sibling
weapon declaration.

Catalog lookup and executable resolution are separate APIs:

- `catalog_profile_for(class_id, weapon_id)` returns the exact declaration for
  inspection, Codex context, tooling, and future UI.
- `resolve_executable(...)` returns either the exact ready weapon profile or an
  exact deep copy of the caller-provided legacy class configuration.
- `resolution_source(...)` exposes whether the result is a weapon profile,
  legacy fallback, invalid pair, or unavailable because fallback was disabled.

Unknown class/weapon pairs fail closed and never inherit an unrelated class
ultimate.

## Class-package convention and admission

A package data file is a ready binding overlay, not another full profile. It
identifies the immutable `profile_id` and `executor_id`, binds targeting,
charge, executor and cleanup strategies, supplies executor parameters and a
whole-activation boss cap. Its executor script must occupy the identical
relative path with `.gd` replacing `.json`, declare matching `PROFILE_ID` and
`EXECUTOR_ID` constants, and expose typed static
`parameter_contract() -> Dictionary` and `execute(activation) -> float` methods.

Discovery is recursive and manifest-free. A package is admitted only when its
path class/file identity, exact fields, immutable IDs, ready bindings, executor
constants/methods and normalized parameter contract all agree. Missing,
orphaned, duplicated, mismatched or incomplete pairs are recorded by
`package_validation_errors()` and omitted; they do not invalidate the 51-row
base registry and cannot make a ready data file executable by itself.

The controller asks the registry for the executor belonging to the exact
`(class_id, weapon_id)` pair and runs it through the same `UltimateActivation`
ledger and cleanup path as central families. A class-local executor should
compose shared families and primitives rather than duplicate them.

## Migration fallback

During a partial migration, a declared or temporarily missing profile for a
known canonical pair may resolve to the existing class ultimate when
`allow_legacy_fallback` is enabled. The caller supplies that legacy dictionary;
the resolver does not import `ProgressionData` and cannot create a preload
cycle. In the fully admitted 51-pair roster, all canonical selections resolve
to `weapon_profile`; legacy fallback is neither selected nor used as a ready
package substitute.

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
the caller keeps running its unchanged class ultimate. A ready activation also
requires its exact presentation package to validate before gameplay begins.

`scripts/ultimates/controller/ultimate_activation.gd` is one live cast. Executors
never touch the Player: they ask the activation for targets, damage, modifiers,
spawns and presentation. The host side is the ten `ultimate_host_*` methods
listed in `UltimateActivation.HOST_METHODS`, implemented by
`scripts/ultimates/controller/ultimate_player_host.gd`, a Node the Player owns as
a child. Repair is an optional eleventh channel: a host that exposes
`UltimateActivation.HOST_REPAIR_METHOD` (`ultimate_host_repair`) opts in, and
`host_supports()` deliberately does not require it, so every pre-existing host
keeps passing while `repair()` fails closed against it. Nothing below the
adapter may branch on a class or a weapon.

`scripts/player.gd` keeps the host preload, `ULTIMATE_HOST.reset(self)` at the
top of `configure_character`, `ULTIMATE_HOST.activate(self)` delegation in
`activate_ultimate`, and one generic measured-prevention emission after its
existing mitigation arithmetic. Death, scene change and node end need no hook at
all — the host is a Player child, so its own `_exit_tree` cancels the cast. Only
the new run needs the explicit call, and it must stay before `run_modifiers` is
reset, otherwise the modifier revert would land on freshly created defaults.

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
Activation-owned tweens measure that declared lifecycle in wall time: gameplay
`Engine.time_scale` changes do not stretch their callbacks or natural cleanup.
They remain bound to the pausable host, so a true `SceneTree.paused` freezes the
cast and its callbacks until the tree resumes.

### Targeting, geometry and composition primitives

The seven executor families remain unchanged. `UltimateExecutorLibrary` also
registers exactly nine reusable primitive IDs with strict parameter admission:

| `primitive_id` | Deterministic contract |
| --- | --- |
| `aim_context` | Captures one source/target/direction snapshot from exact `host_aim` or `nearest_target` mode; a missing requested mode result never falls through to the other mode |
| `priority_target_selector` | Orders a bounded candidate set by `nearest`, `aimed`, `highest_hp`, `marked`, or `densest_cluster`, with positional/instance tie-breaks and exact policy-specific hints |
| `line_pierce_geometry` | Selects a forward corridor by length and half-width, ordered by projection/lateral distance and deduplicated by target instance |
| `pattern_geometry` | Produces `ring`, `grid`, `radial`, `polygon`, or deterministic `seeded_annulus` points, then walks those points in order to build one deduplicated target set |
| `stateful_target_ledger` | Records, adds or consumes an activation-local value per target through an explicit idempotency event; the activation also exposes lossless transfer for class-local executors |
| `per_target_damage_cap` | Opens one fraction-plus-flat applied-HP budget per target for the activation; mitigation and overkill spend only the HP actually lost |
| `control_resistance_policy` | Requires exact `normal`, `epic` and `boss` displacement, duration, movement-lock and execute policy dictionaries |
| `summon_interaction_contract` | Queries player-owned summons, deduplicates and snapshots declared properties, suspends them, caps temporary spawns, and restores or frees everything on shutdown |
| `ordered_step_composition` | Runs a non-empty, non-decreasing `steps` array; each step names exactly one primitive or existing family and shares the same activation ledger |

Composition is admitted through the normal controller `executor.strategy_id`
path. Every nested family/primitive parameter dictionary is normalized before
the activation exists. Unknown steps, missing fields, decreasing offsets and a
nested `ordered_step_composition` fail closed. At runtime each declared step is
recorded and invoked once in declaration order; a primitive that cannot satisfy
its exact world mode aborts later steps instead of selecting a fallback mode.
Existing families consume the activation's current primitive-selected target
set, so geometry and selectors compose without class or weapon branches.

`UltimateActivation.aim_context()` caches the first host sample per range.
Corridor order is projection → lateral distance → position/instance ID. Pattern
target order is pattern-point order → nearest-within-point, with the first
occurrence winning deduplication. `seeded_annulus` uses an activation-independent
integer sequence, so identical center/params/seed produces the same ordered
points and target set.

`UltimateDamageResult.applied` is the HP the target actually lost, mirroring the
overkill-clamped delta `enemy.gd` publishes. Attribution, ledgers and charge read
`applied`, never the attempted amount, so overkill and damage-taken reductions
cannot inflate them.

Damage calls may carry a target-qualified event ID. Repeating the same event is
idempotent and never reaches the host twice. A secondary result is marked
`secondary` and `creditable == false`, so a class executor has an explicit
non-recursive trigger gate even when the secondary hit deals damage or kills.

`total_boss_cap` is a budget for the whole activation, opened once per boss at
`max_health * total_boss_cap` and drawn down by applied HP. Multi-hit, DoT-style
zone ticks and deferred summon damage all spend the same budget: a spawn that
exposes an `ultimate_damage_sink` property is bound to the activation ledger, and
zone ticks deliberately do not use a StatusEffects `dot_damage`, which would tick
on the target and bypass the budget. Normal enemies are never capped.

Tiered control flows through `apply_control()`: normal, elite/epic and boss
targets never inherit each other's policy, status DoT is stripped, and movement
lock or execute permission must be explicitly allowed. Summon interaction uses
the tenth host method to return only player-owned nodes from a declared group;
duplicates are snapshotted once, setup is fail-closed, and shutdown restores
original visibility, process mode and declared properties.

### Repair and safe temporary deploy host primitives

Two bounded host primitives extend the activation for class executors that
heal or place hardware; both are default-off and class-agnostic.

`configure_repair(total_cap)` opens the activation's whole repair budget once —
a repeat only agrees with the identical value — and without it every `repair()`
fails closed. `repair(target, amount, event_id)` returns
`{"requested", "applied"}`; the host decides ownership (the hero itself, a
device whose `owner_node` is the Player, or one owned by the adapter for the
activation's own deploys), refuses foreign, freed and dead targets, never
resurrects and never exceeds `max_health`. `applied` is the HP the target
actually regained — the same clamped-delta attribution the damage path uses —
and only that actual HP draws the budget, so overheal and refused targets spend
nothing. The optional `event_id` shares the activation's idempotency ledger with
damage events. Shutdown clears the cap and budget with the rest of the cast.

`deploy_temporary(scene, init, count)` places `count` instances of a declared
`PackedScene` as one atomic batch. Each instance is fully initialized off-tree
first: ownership attribution into an `owner_node` property when the scene
declares one, the generic init contract — `properties` (every key must exist),
optional `setup_method` called with `setup_args` (only an explicit `false`
return rejects, so a plain void `setup(...)` such as the existing SentryTurret
lifecycle qualifies without any hard-coded class, weapon or scene path) — and
because a typed property silently ignores a mismatched `set()`, every write is
read back and a value that did not land rejects the deploy. Any failure frees
everything the call created before a single node entered the tree; on success
every node parents into the host effect parent, registers with the activation
like any other spawn and binds the damage sink, so deferred deploy damage
spends the same whole-activation boss budget and `cancel()`, carrier death and
a new run remove the entire deploy. A declared summon-interaction contract's
`temporary_cap` counts these deploys together with `spawn()` instances.
Temporary deploys attribute to the host adapter, never to the Player — that
distinction is what keeps `ultimate_host_summons` (and with it the permanent
summon/device park) blind to the activation's own hardware.

### Measured guard prevention and owner-resource counters

`Player.take_damage()` leaves its mitigation arithmetic unchanged. Once that
pipeline has calculated final damage, it emits `guard_prevention_measured` only
when all of these are present: a non-empty source, a valid incoming direction
from the attacker, an active guard owner, and a positive measured difference
between incoming and final mitigated damage. The emitted value is
`incoming_amount - applied_amount`; it is not a requested counter number and is
not derived from the overkill-clamped HP delta.

An executor opens one activation-local guard with
`configure_guard_prevention(owner_id, resource_id, cap, facing, arc_degrees,
sources)`. The Player host routes the event to the current activation. It rejects
wrong owner, source, facing, malformed or zero prevention, and replayed event
IDs; it then calls `apply_owner_resource(...)`. Resources are keyed by owner and
resource ID, fix their cap on first accepted measurement, and cannot refill after
`consume_owner_resource(owner_id, resource_id, event_id)` spends them. That
consume returns and emits one `owner_resource_emitted` dictionary containing the
exact measured amount, which a class-local executor can use for its counter
without a shared class/weapon branch.

Both the guard and owner-resource ledger are activation-local. Completion,
cancel, death, node end and new-run reset clear them through the existing
`shutdown()` path, so stale events cannot credit a later cast.

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

Class packages may now add one ready overlay/script pair below their class-local
roots plus their own evidence. They must keep immutable IDs, avoid selection
branches in `Player` or `ClassWeapon`, supply a whole-activation boss cap, reuse
the shared activation seam, and prove the selected exact pair resolves while
siblings and malformed packages remain negative controls.

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
  --script res://tests/ultimates/executor_primitives_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_package_discovery_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/controller_runtime_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/controller_player_integration_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/controller_host_primitives_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/guard_prevention_resource_test.gd
```

`controller_runtime_test` drives every executor family through the same
`activate(class_id, weapon_id)` call from fixture declarations, and asserts that
no source file under `scripts/ultimates/controller/` or
`scripts/ultimates/executors/` mentions any canonical class or weapon id. It also
covers refused re-entry, a paused tree, cancellation, applied-versus-attempted
HP, and the whole-activation boss budget including deferred summon damage.
`controller_player_integration_test` holds the other half: every shipped profile
still resolves to the legacy class ultimate, all 17 class ultimates still fire and
spend their charge exactly once, and — with a library-normalized ready declaration
injected — the host adapter drives a real cast that a new run or a node end drops.
Its fixture rejects incomplete parameters before replacing the player registry, so
the rejected declaration cannot spend charge, activate the player, or create a host.

`executor_primitives_test` covers the exact nine-ID registry, strict admission,
idempotent target state, actual-HP target caps and overkill, non-creditable
secondary hits, exact normal/epic/boss control, and lossless duplicate-free
summon snapshot/restore. `controller_host_primitives_test` covers the repair
and temporary-deploy primitives against the real Player adapter: actual-HP and
overheal attribution, the per-activation repair cap, foreign/dead/null target
rejection, hero and both device ownership forms, fail-closed behaviour against
a host without the repair channel, the SentryTurret lifecycle through the
generic init contract, invalid-init rejection, mid-batch partial-failure
rollback with no orphan nodes, the summon-contract temporary cap, and
idempotent cleanup that leaves permanent player-owned devices untouched; the
player integration suite additionally proves a new run drops live deploys and
repair state through the real charge path. `registry_package_discovery_test` proves a real paired
fixture executes through the controller and that declared, mismatched,
incomplete, missing, orphaned and duplicated packages remain fail-closed.

`guard_prevention_resource_test` runs the ingress through the real Player adapter
and proves final-mitigation measurement, source/direction/owner rejection,
capped accumulation, one-shot counter emission, replay refusal, and cleanup on
new run and node end.

The tests cover all 51 selections, both sibling negative controls for every
selection, exact legacy fallback preservation, fail-closed unknown pairs,
missing and duplicate pairs, unknown classes and weapons, unique profile,
title, mechanic, and presentation IDs, and readiness safety in both
directions: a `declared` profile may not bind an executor, and a `ready`
profile may neither omit its whole-activation boss cap nor keep its executor
unbound.

Run them explicitly, as shown above, for focused local evidence.
`tools/quality_gate.py` also discovers Godot tests recursively and maps nested
paths such as `tests/ultimates/` to their `res://tests/...` script paths.
Controller/executor changes select the runtime, player integration, audit,
primitive and package-discovery suites. Registry, schema and any
`data/ultimates/classes/**` or `scripts/ultimates/classes/**` change select the
exact-pair package matrix. `--static-only` deliberately runs no Godot tests.
