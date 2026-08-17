# Chemist weapon ultimates

The Chemist class package for the generic weapon-ultimate runtime (FAN-1483).
It is a class-local package in the sense of `WeaponUltimatePackageDiscovery`:
one JSON overlay and one GDScript executor at the identical relative path below
each root.

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
`per_target_damage_cap`, `aim_context`, `summon_interaction_contract`) and the
activation's owner-resource ledger, adding only the weapon-specific step on top.
Every hit goes through `UltimateActivation`, so one boss budget, one ledger and
one `shutdown()` cover the whole cast.

## Everything lasting is activation-owned

`tests/ultimates/tracked_tween_natural_completion_test.gd` holds every ready
package to one rule: after a cast completes, the enemies it touched must be back
at their baseline statuses. The Chemist kit therefore keeps its lasting effects
in activation-owned ledgers instead of enemy statuses:

- corrosion and the toxic cascade are stacks in the activation TARGET ledger;
- the acid charge is a capped entry in the activation OWNER-RESOURCE ledger;
- the only statuses applied — the crystal lock and the taunt slow — go through
  `apply_control` and self-expire inside their own cast window.

`shutdown()` clears all of it, so a completed cast, a cancel, a death, an
encounter end and Continue all reach the same clean state. The permanent acid
charges and permanent caster DoT remain what they have always been: the LEGACY
Chemist weapons' own mechanics (SCRUM-944 / SCRUM-946), untouched by this
package.

## `blast_powder` — Философский Взрыв

Five charges form a pentagram, crystallize what stands under them, pull that set
inward and transmute it in one capped blast.

- `pattern_geometry` places five `polygon` vertices at `pentagram_radius` around
  the caster and selects everything within `charge_radius` of a vertex, up to
  `target_limit` (18, the manifest crowd cap).
- `stateful_target_ledger` records the caught set once under
  `philosopher_crystal`.
- At `pull_at` (0.5 s — the manifest release beat) each recorded target takes an
  inward `apply_control` impulse of `pull_force` plus the crystal lock. The lock
  runs for `crystal_status.duration` (0.8 s), so it expires exactly as the blast
  lands at 1.3 s rather than 0.1 s before it — FAN-2527 closed that gap, in which
  a pulled enemy was already free to walk out of the pentagram it was caught in.
- At `detonate_at` (1.3 s — the active beat) the blast consumes each mark and
  deals `damage` once. The cast recovers until `recover_at` (2.2 s).

**No recursive kill chain.** The detonation iterates the set the pentagram
recorded and never re-queries the world, so a kill cannot recruit a fresh
victim. Consuming the mark makes a repeated detonation a no-op even if the step
is reached twice.

**Caps.** `per_target_damage_cap` bounds the blast at `target_damage_cap` (0.35)
of each target's max health; the class boss cap (0.10) bounds the whole
activation on one boss. Both are proven together: a normal enemy loses the
per-target cap, a boss loses the smaller boss budget.

**Tier resistance.** `control_policy` is data: elites and bosses take 0.25 of the
displacement, and a boss is not movement-locked at all.

## `acid_flask` — Царь-Колба

One aimed flask floods a lake that expands from `start_ratio` of `lake_radius`
to the full radius across its `tick_count` ticks.

- `aim_context` anchors the lake at the host aim point within `aim_range`. A
  host that cannot report an aim (headless fixtures, a Player without the aim
  methods) floods the caster's own position instead of spending the charge on
  nothing.
- Every `tick_interval` the lake corrodes what stands in it through the
  activation, so the boss budget binds the whole pour.
- Beats: pour at 0.75 s, last tick at 3.25 s, finale immediately after, recover
  at 3.7 s.

**Armour dissolve.** Each tick that actually removes HP adds one `acid_dissolve`
stack in the activation target ledger, up to `dissolve_stack_cap`. A tick's
damage is scaled by `1 + dissolve_bonus * stacks`, so the lake bites harder the
longer a target stands in it. The stack lives and dies with the activation.

`dissolve_stack_cap` is 9 — one below `tick_count`, which is the highest stack a
target can carry into a tick of this pour. It used to be 5, so the escalation
saturated halfway through the lake's own cast and the last five ticks were flat;
FAN-2527 raised the ceiling to the length of the pour it belongs to.
`chemist_balance_test.gd` holds it there.

**Capped charge conversion.** The `owner_resource_conversion` primitive is now
part of the shared activation, so the accepted "converts measured outcomes into
capped charge" is expressed directly: every tick pays
`applied * charge_conversion` into `chemist_acid_flask.charge`, capped at
`scaled_damage() * charge_cap_ratio` — priced in the weapon's own tick damage so
the ceiling scales with the build instead of freezing one absolute number. Only
a tick whose `UltimateDamageResult.applied` is positive pays; a capped or
overkilled swing buys nothing.

**The pillars.** The finale consumes the whole charge exactly once and shares
`pillar_ratio` of it across the lake — the manifest's "capped charge pillars".
Consuming is what makes a repeated release a no-op.

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
- Each of `beat_count` beats (0.85 s apart) is one broad stomp plus the narrower
  toxic cascade. The stomp reads the target's accumulated cascade stacks BEFORE
  the wave adds the next one and scales by `1 + wave_toxin_bonus * stacks`, so
  the cascade escalates across beats instead of paying for itself on the beat
  that applied it. Stacks stop at `wave_stack_cap` (4 — the same ceiling the
  persistent caster uses). Recover at 4.2 s.

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
burst, `acid_flask` is the sustained area denial whose corrosion and charge
build over time, `homunculus_vial` is the defensive/summon window. Charge income
is untouched — every profile binds the existing `legacy_charge` policy, so
`UltimateChargeLedger` still spends the charge exactly once and still allows one
activation per encounter, and charge still survives battles, acts and Continue.

## Power corridor (FAN-2527)

The corridor is `UltimateChargeBudget.POWER_SECONDS_MIN..MAX` — one activation is
worth 20…35 s of the weapon's OWN normal output — and the live reading of it is
the solo `effect_total` of
`scripts/ultimates/balance/ultimate_effectiveness_runner.gd`.

**The finding.** All three executors price damage as `context.damage * damage`,
i.e. off the equipped weapon's PER-HIT channel. Inside the Chemist that channel
spans 53.24 / 4.41 / 3.18 (`blast_powder` is a direct-AoE weapon at
`damage_multiplier` 2.60, while `acid_flask` 0.24 and `homunculus_vial` 0.90 carry
their real DPS in pool-tick and summon channels an ultimate never reads), yet the
three power budgets are nearly identical because they are priced off
`reference_solo_dps`, which is ~31…32 for all three. The coefficients were
authored before FAN-2516 existed, against the assumption that per-hit damage is
comparable across a trio; two of the three therefore sat at 10% and 56% of their
own corridor floor. **A Chemist coefficient is only readable next to its weapon's
per-hit damage** — that is why 4.2, 7.6 and 39.0 are the same amount of power.

Baseline is the committed `build/ultimate_effectiveness_baseline.json`
(FAN-2516 at `5e96dd1f`); final is the same instrument after this card. The other
48 rows are bit-identical, so `regressions()` stays clean without a rewritten
baseline.

| Weapon | corridor | solo effect before → after | of budget | boss cap ratio |
| --- | --- | --- | --- | --- |
| `blast_powder` | 624.6 … 1093.0 | 890.35 → 890.45 | 0.81 | 0.247 → 0.247 |
| `acid_flask` | 643.4 … 1126.0 | 66.31 → 889.25 | 0.79 | 0.059 → 0.790 |
| `homunculus_vial` | 645.4 … 1129.5 | 363.22 → 888.79 | 0.79 | 0.019 → 0.484 |

Charge cadence is untouched: all three stay at 4 normal encounters to ready and
32.7 charge per neutral normal encounter, inside the frozen 25…35 corridor.

**`blast_powder`'s boss ratio is an explicit exception.** It was already inside
its corridor, so its coefficient did not move. 620 of its 890 solo effect is
displacement, and the declared boss policy resists displacement at 0.25 and
refuses the movement lock outright — so a boss keeps only the transmutation half
of a pull-and-transmute cast, and the row spends a quarter of its boss allowance
by construction. Lifting the coefficient until the boss allowance bound would
either push the solo row past its corridor ceiling or make the per-target cap the
de-facto flat damage number, which would end build scaling against normal
enemies. The class's boss answer is `acid_flask` (0.790) and its crowd answer is
the pentagram; that split is the trio identity, not a gap.

**Niches after the correction**, each measured on a channel the other two do not
use: `blast_powder` is the only movement lock and the strongest per-target
displacement (620); `acid_flask` is pure damage with no control or summon channel
at all, the widest reach (16 probes struck) and the class's boss answer;
`homunculus_vial` is the only summon window and the widest crowd hold (14 probes,
16.8 control-seconds at 20 targets). `chemist_balance_test.gd` asserts exactly
that split, so a later retune cannot quietly collapse two of the three into one.

## Timing and mechanic contract for the visual cards

The three downstream animation cards inherit this contract unchanged. **No beat
moved in FAN-2527** — every `timing_seconds` value in
`docs/design/references/weapon_ultimates/chemist/manifest.json` is still the beat
the executor fires on, so no capture, contact sheet or timeline needs re-shooting
for balance reasons:

| Weapon | windup | release | active | recovery | cancel | what the beats carry |
| --- | --- | --- | --- | --- | --- | --- |
| `blast_powder` | 0.00 | 0.50 pull + crystal lock | 1.30 transmute | 2.20 | 3.40 | one inward yank, then ONE blast; the lock now holds the full 0.50 → 1.30 window |
| `acid_flask` | 0.00 | 0.75 pour | 1.60 | 3.70 | 4.80 | 10 ticks at 0.25 s (1.00 → 3.25), each harder than the last for the WHOLE pour, then the pillars |
| `homunculus_vial` | 0.00 | 0.90 fuse + taunt | 1.70 | 4.20 | 5.40 | 3 stomps at 0.85 s (1.75 / 2.60 / 3.45), each carrying one more cascade stack |

What changed for presentation, and only this:

- `blast_powder`'s crystal lock is 0.8 s instead of 0.7 s, so the frozen-crystal
  read must stay on screen until the transmutation frame instead of releasing
  just before it.
- `acid_flask`'s corrosion escalates on all ten ticks instead of the first five —
  the lake's colour/intensity ramp should keep climbing to the last tick rather
  than flattening at the halfway point.
- `homunculus_vial`'s stomps are ~26x heavier; the impact language is unchanged,
  the hit weight is not.

## Lifecycle inventory

`tests/ultimates/tracked_tween_natural_completion_test.gd` requires one
lifecycle/deadline row per ready pair. The three Chemist rows are the wall-clock
cast lengths above plus the shared one-second grace:

| Pair | lifecycle | deadline |
| --- | --- | --- |
| `chemist/homunculus_vial` | 4.2 | 5.2 |
| `chemist/acid_flask` | 3.7 | 4.7 |
| `chemist/blast_powder` | 2.2 | 3.2 |

## Deliberate simplifications

- The lake's corrosion scales the lake's OWN damage rather than a general
  damage-taken debuff. A shared debuff would have to be a status on the enemy,
  which cannot outlive the cast under the rule above and cannot be leased
  without an activation-owned scripted scene — a path this card's write set does
  not include.
- The acid charge is spent inside the cast as the pillars. An owner resource is
  activation-scoped by construction; a run-level Chemist resource would be a
  shared Player/progression change, which is out of scope here.
- The taunt is expressed as an activation-owned control pull rather than
  `bastion_taunt`. That status resolves its owner to a node with `take_damage`,
  and the avatar is a presentation scene; the persistent tank's own
  `bastion_taunt` aggro is a separate, unchanged mechanic.

## Evidence

`tests/ultimates/mechanics/chemist_ultimate_mechanics_test.gd` runs the shipped
package through the real registry, the real discovery pass and the real
controller: admission, no cross-class leakage onto the other sixteen classes,
the declared tier policies, and one live cast per weapon covering pull/lock
resistance, the per-target and boss caps, actual-HP attribution, mark and charge
idempotency, the dissolve/cascade stack ceilings, status-residue freedom and the
cancel paths. `tracked_tween_natural_completion_test.gd` covers the same three
pairs end to end on the real Player.

`tests/ultimates/chemist_balance_test.gd` (FAN-2527) is the closed-form twin of
the live instrument: it reads the shipped declarations through the real discovery
pass, rebuilds each solo activation channel by channel off the RUNTIME damage
anchor (the CLASS damage parameter — `blast_powder` attacks as physical but its
ultimate scales from `magic_damage`, so the weapon key would price it against a
channel the cast never uses), and asserts the corridor, the single class boss cap,
the burst archetype, the dissolve ceiling and the three niches. It reproduces the
live numbers exactly (890.45 / 889.25 / 888.79) and goes red for a runaway lake
coefficient, so a retune fails in seconds instead of only in the 51-row run.
