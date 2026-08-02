# Chemist weapon ultimates

The Chemist class package for the generic weapon-ultimate runtime (FAN-1483).
It is a class-local package in the sense of
`WeaponUltimatePackageDiscovery`: one JSON overlay and one GDScript executor at
the identical relative path below each root.

| Weapon | Title | Data | Executor |
| --- | --- | --- | --- |
| `blast_powder` | Философский Взрыв | `data/ultimates/classes/chemist/blast_powder.json` | `scripts/ultimates/classes/chemist/blast_powder.gd` |
| `acid_flask` | Царь-Колба | `data/ultimates/classes/chemist/acid_flask.json` | `scripts/ultimates/classes/chemist/acid_flask.gd` |
| `homunculus_vial` | Совершенный Гомункул | `data/ultimates/classes/chemist/homunculus_vial.json` | `scripts/ultimates/classes/chemist/homunculus_vial.gd` |

Nothing here touches the immutable 51-profile catalog: the overlay promotes only
its own base declaration, and identity, cast phases and presentation stay
exactly as `data/ultimates/schema/v1/classes/chemist.json` declares them. The
accepted mechanic contracts come from
`docs/design/references/weapon_ultimates/executor_contract_audit.json`; the
telegraph beats come from
`docs/design/references/weapon_ultimates/chemist/manifest.json` and every
declared beat below is one of that manifest's `timing_seconds` values.

## Why the mechanics are class-local

The audit classifies all three profiles as `needs_new_generic_primitive`. The
shared families cannot express an inward pull (`control` only pushes away), a
measured-outcome resource conversion, or a fusion/split of persistent summons.
The class-local executors compose the shared primitives that DO exist
(`pattern_geometry`, `stateful_target_ledger`, `control_resistance_policy`,
`per_target_damage_cap`, `aim_context`, `summon_interaction_contract`) and add
only the weapon-specific step on top. Every hit still goes through
`UltimateActivation`, so one boss budget, one ledger and one `shutdown()` cover
the whole cast.

## `blast_powder` — Философский Взрыв

Five charges form a pentagram, crystallize what stands under them, pull that set
inward and transmute it in one capped blast.

- `pattern_geometry` places five `polygon` vertices at `pentagram_radius` around
  the caster and selects everything within `charge_radius` of a vertex, up to
  `target_limit` (18, the manifest crowd cap).
- `stateful_target_ledger` records the caught set once under
  `philosopher_crystal`.
- At `pull_at` (0.5 s — the manifest release beat) each recorded target takes an
  inward `apply_control` impulse of `pull_force` plus the crystal lock.
- At `detonate_at` (1.3 s — the active beat) the blast consumes each mark and
  deals `damage` once. The cast recovers until `recover_at` (2.2 s).

**No recursive kill chain.** The detonation iterates the set the pentagram
recorded and never re-queries the world, so a kill cannot recruit a fresh
victim. Consuming the mark makes a repeated detonation a no-op even if the step
is reached twice.

**Caps.** `per_target_damage_cap` bounds the blast at `target_damage_cap` (0.35)
of each target's max health; the class boss cap (0.10) bounds the whole
activation on one boss. Both are proven together in the mechanics test: a normal
enemy loses the per-target cap, a boss loses the smaller boss budget.

**Tier resistance.** `control_policy` is data: elites and bosses take 0.25 of the
displacement, and a boss is not movement-locked at all.

## `acid_flask` — Царь-Колба

One aimed flask floods a lake that expands from `start_ratio` of `lake_radius`
to the full radius across its `tick_count` ticks.

- `aim_context` anchors the lake at the host aim point within `aim_range`. A
  host that cannot report an aim (headless fixtures, a Player without the aim
  methods) floods the caster's own position instead of spending the charge on
  nothing.
- Every `tick_interval` the lake corrodes what stands in it for `damage`
  through the activation, so the boss budget binds the whole pour, and refreshes
  the `chemist_acid_dissolve` armour debuff.
- Beats: pour at 0.75 s, last tick at 3.25 s, recover at 3.7 s.

**Capped permanent charge.** The charge is granted only from a MEASURED outcome
— a tick whose `UltimateDamageResult.applied` is positive — and it is capped
twice:

1. `record_target_value` claims one ledger event per target, so one cast can
   never hand the same enemy a second charge;
2. the status uses the SCRUM-944 `acid_charge` prefix, so
   `StatusEffects.count_status_prefix` keeps the target inside the documented
   five-charge ceiling it already has from ordinary pools. A target already
   saturated by pool charges gets nothing from the ultimate.

The permanent charge is the accepted lasting payload of this weapon and is the
only thing that outlives the cast; the tick damage that fed it does not.

**Encounter-bound cleanup.** The lake is the activation's own tween and
presentation, so a completed cast, a cancel, a death or an encounter end all
reach the same `shutdown()` and the lake stops ticking immediately.

## `homunculus_vial` — Совершенный Гомункул

The persistent tank/caster pair fuses into one temporary avatar.

- `summon_interaction_contract` snapshots and parks every player-owned member of
  `summon_group` (`allies`): they are hidden and their processing is disabled,
  and the activation holds the snapshot.
- The activation spawns exactly one avatar. `temporary_cap` is 1, so a
  retriggered execute cannot stack a second one.
- At `fuse_at` (0.9 s) the taunt halo drags the crowd onto the avatar and slows
  it. The pull runs through `apply_control`, so the declared tier policy shrinks
  it for elites and bosses.
- Each of `beat_count` beats (0.85 s apart) is one broad stomp for `damage`
  through the activation plus the narrower toxic cascade, which adds one
  `homunculus_caster_dot` stack up to `wave_stack_cap` (4 — the SCRUM-946
  ceiling the persistent caster already uses). Recover at 4.2 s.

**Lossless, duplication-free split.** The split back is the activation's own
teardown, not a second construction step: `shutdown()` frees the avatar and
restores the parked pair from the snapshot. Nothing is instantiated to replace
them, so the pair cannot be duplicated and cannot be lost, and a cancel reaches
the same restore path as a completed cast.

## Class trio

All three declare the same `total_boss_cap` 0.10 — the Chemist
`ULTIMATE_CONFIGS.boss_cap`, which is also what
`UltimateChargeBudget.build_rows` publishes for the three Chemist balance rows.
`UltimateBalanceHarness._check_class_trio` requires exactly one cap per class.

The trio keeps the class identity split: `blast_powder` is the decisive capped
burst, `acid_flask` is the sustained area denial that leaves permanent charges
behind, `homunculus_vial` is the defensive/summon window. Charge income is
untouched — every profile binds the existing `legacy_charge` policy, so
`UltimateChargeLedger` still spends the charge exactly once and still allows one
activation per encounter, and charge still survives battles, acts and Continue.

## Deliberate simplifications

- The permanent charges apply through `StatusEffects.apply_status`, not
  `apply_status_from`, so the Chemist «Катализатор» periodic multiplier is NOT
  baked into them. The activation host adapter is not the Player and exposes no
  `periodic_damage_multiplier`; reaching past the ten-method host contract to
  find one would break the rule that executors never touch the host directly.
  Tick damage, which goes through `ultimate_host_apply_damage` as
  `damage_type: "dot"`, does receive the trait.
- The acid-charge ceiling is the documented base five. The «Кислотный
  катализатор» artifact bonus (+3) is a legacy-weapon path that reads
  `run_modifiers`; the ultimate deliberately never pushes a target above the
  base cap.
- The taunt is expressed as an activation-owned control pull rather than
  `bastion_taunt`. That status resolves its owner to a node with `take_damage`,
  and the avatar is a presentation scene; the persistent tank's own
  `bastion_taunt` aggro is a separate, unchanged mechanic.

## Activation status

A package under `data/ultimates/classes/**` is executable as soon as it exists:
discovery admits only `implementation_state: "ready"` pairs, and anything else
below that root is reported as a package validation error. There is no inert
state, so landing this package IS the Chemist activation.

Three shared suites still assert that nothing has been activated yet and go red
with the first class package on `dev`. They are outside this card's write set
and belong to the activation owner (FAN-1541):

- `tests/ultimates/registry_contract_test.gd` — `package_pair_keys()` must be
  empty and every v1 profile must be `declared`;
- `tests/ultimates/controller_player_integration_test.gd` — every pair must
  still resolve to the legacy class ultimate;
- `tests/runtime_smoke_test.gd` — `_test_ultimate_framework` expects measurable
  HP loss in the activation frame, which no telegraphed weapon ultimate can
  produce.

## Evidence

`tests/ultimates/mechanics/chemist_ultimate_mechanics_test.gd` runs the shipped
package through the real registry, the real discovery pass and the real
controller: admission and no leakage onto the other 16 classes, the declared
tier policies, and one live cast per weapon covering pull/lock resistance, the
per-target and boss caps, actual-HP attribution, mark idempotency, the charge
ceilings and the cleanup paths.
