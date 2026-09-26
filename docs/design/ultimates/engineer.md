# Engineer weapon ultimates

FAN-1466 promotes the three frozen Engineer weapon profiles from declarations
with a legacy fallback to exact, executable, class-local packages. The base
catalog identities remain unchanged; only convention-discovered overlays below
`data/ultimates/classes/engineer` and matching executors below
`scripts/ultimates/classes/engineer` make these three pairs ready.

## Runtime contracts

| Weapon | Exact mechanic | Active window | Power identity |
| --- | --- | ---: | --- |
| `engineer_sentry_wrench` | Six temporary sentries occupy a fixed 210px hex. Eight synchronized volleys suppress every live enemy on the map; the three opposing chords raise that floor on whoever the beams cross. | 4.60s | sustained solo/corridor crossfire |
| `engineer_repair_drone` | Twelve temporary microdrones orbit the hero. Six waves ram every live enemy, repair the hero and owned permanent devices through the shared repair channel, then open a flat final shield. | 5.50s | map-wide intercept plus defensive save |
| `engineer_pressure_mines` | Sixteen temporary mines use deterministic annulus seed `1466`. One occupied mine may trigger two local neighbors; remaining mines finish from the outside inward. Every detonation is an arena-wide pressure wave, bounded per target. | 4.00s | per-target-bounded crowd-clear field |

Each JSON overlay has a matching GDScript at the same class-relative path. The
profile and executor IDs exactly match the immutable declarations in
`data/ultimates/schema/v1/classes/engineer.json`; all three use
`rare_charge_ledger`, an `activation_owned` cleanup policy, and the inherited
`0.08` total boss-health cap.

### Sentry wrench

The activation atomically deploys all six temporary sentries before any one of
them enters play. Each volley is one damage event per enemy: the map-wide floor
is a single chord's worth, and the shared corridor query counts how many of the
three beams a silhouette actually stands in, which raises its hit to at most
three. The permanent `engineer_devices` park is neither hidden, replaced, nor
included in cleanup. Damage event IDs are target-local and unique per volley, so
repeated callbacks cannot duplicate one hit.

### Repair drone

Each wave rams every live enemy. The shared resistance policy applies
100% normal, 35% epic, and 10% boss displacement without movement lock or
execute. Repair has an activation-wide budget of eight scaled damage units and
is applied in one-unit pulses; the shared host accepts only the hero or a
player-owned permanent device and reports actual HP restored, so overheal and
foreign devices spend no budget. At 4.30s the final pulse adds five scaled
damage units of flat absorption for 1.20s. Activation shutdown unwinds it.

The hero the pulse is offered to is the host's `player` when the host has one,
and otherwise the host itself. `player` is the Player adapter's own field rather
than one of the ten contract methods, so before FAN-2532 a host that stands in
for the hero — the FAN-2516 measuring host does exactly that — silently lost the
entire repair channel instead of failing closed. Eligibility is still decided
where it belongs, in `ultimate_host_repair`, which refuses anything that is
neither the hero nor a device it owns.

### Pressure mines

The shared seeded-annulus primitive places 16 mines between 80px and 260px.
After a 0.70s arm delay, the first occupied trigger may detonate itself and at
most two nearest mines inside 155px. The finale starts at 1.70s, orders every
remaining point by descending radius with an index tie-break, and fires at 0.10s
intervals, so all sixteen detonate exactly once inside the window. Each
detonation is a pressure wave that reaches every live enemy on the map;
`blast_radius` is what the wave looks like, never how far it reaches, and
`chain_count` selects mines rather than enemies. Mine indices and damage event
IDs are idempotent. A 75% per-target activation cap bounds non-boss targets,
while the inherited 8% boss cap is the stricter budget for bosses; the shared
damage result attributes only HP actually removed.

## Shared lifecycle boundary

The packages mutate combat only through accepted `UltimateActivation` and
`UltimatePlayerHost` surfaces: atomic temporary deployment, target selection,
damage, control, repair, modifiers, presentation, tracked tweens, and cleanup.
They do not branch the shared registry, controller, executor library, schema,
Player, or ProgressionData.

The runtime contract is:

- a full bar buys one activation and is spent once;
- an active payoff window earns neither dealt-damage nor taken-damage charge;
- another activation in the same encounter is refused without spending charge;
- charge alone survives battle, act, and Continue snapshots;
- active state, the encounter-use latch, tweens, temporary devices,
  presentation, primitive state, and modifiers do not survive completion,
  cancellation, a new run, or node teardown.

The shared ledger and shipped snapshot chain own persistence. Wiring persisted
activation into the final shared runtime adapter remains FAN-1541; this package
does not widen that boundary.

## Balance evidence

The table is generated by `engineer_ultimate_balance_test.gd` from the current
level-1 normal-weapon budget with ultimate contribution excluded. It is the
before/after control: the normal trio remains unchanged while the three formerly
fallback ultimate identities become executable and distinct.

| Weapon | Solo DPS | 5-target DPS | 20-target DPS | Reference EHP | Trio-normalized total |
| --- | ---: | ---: | ---: | ---: | ---: |
| `engineer_sentry_wrench` | 45.14 | 160.90 | 139.39 | 84.97 | 0.995 |
| `engineer_repair_drone` | 44.95 | 160.36 | 138.92 | 84.97 | 0.993 |
| `engineer_pressure_mines` | 44.38 | 157.28 | 154.99 | 84.97 | 1.012 |
| Class mean | 44.82 | 159.51 | 144.43 | 84.97 | 1.000 |

`Trio-normalized total` equally weights each weapon's solo, AoE, crowd, and
shared base-EHP ratio against the class mean. The three results remain inside
the repository's 0.85–1.15 corridor. Ultimate defense is additionally proven
at runtime rather than folded into normal EHP: actual-HP repair affects the hero
and owned device only, while the final absorption modifier opens and cleanly
unwinds. All three rows retain the Engineer `control_save` archetype, exceed its
4.0s minimum, price power at the corridor seconds of their own output (20–35 s
when this table was taken, 30–45 s since FAN-2949), and declare the same 8% boss
cap.

## Power corridor (FAN-2532)

The corridor is `UltimateChargeBudget.POWER_SECONDS_MIN..MAX` — one activation is
worth 20…35 s of the weapon's OWN normal output (re-derived to 30…45 s by
FAN-2949; the re-measured rows are in the FAN-2955 section below) — and the live
reading of it is the solo `effect_total` of
`scripts/ultimates/balance/ultimate_effectiveness_runner.gd`.

**The finding.** The same root cause the Chemist trio had in FAN-2527: all three
executors price damage as `context.damage * damage`, i.e. off the equipped
weapon's PER-HIT channel, which inside the Engineer spans 2.50 / 10.39 / 38.45,
while the three power budgets are nearly identical because they are priced off
`reference_solo_dps`, which is ~44…45 for all three. The spread is not an
accident: `engineer_sentry_wrench` (`damage_multiplier` 0.55) and
`engineer_repair_drone` (2.40) carry their real DPS in turret and orbit-contact
summon channels an ultimate never reads, while `engineer_pressure_mines` (3.60)
is a direct-blast weapon. The coefficients were authored before FAN-2516 existed,
against the assumption that per-hit damage is comparable across a trio, so the
hex crossfire sat at 1.9% of its own corridor floor. **An Engineer coefficient is
only readable next to its weapon's per-hit damage** — that is why the hex's 62.0
and the field's 8.0 were the same amount of power.

Baseline is the committed `build/ultimate_effectiveness_baseline.json`
(FAN-2516 at `5e96dd1f`); final is the same instrument after this card. The other
48 rows are bit-identical, so `regressions()` stays clean without a rewritten
baseline.

As measured by FAN-2532 against the then-frozen 20…35 s corridor:

| Weapon | corridor | solo effect before → after | of budget | boss cap ratio |
| --- | --- | --- | --- | --- |
| `engineer_sentry_wrench` | 902.8 … 1579.9 | 16.98 → 1243.69 | 0.787 | 0.007 → 0.783 |
| `engineer_repair_drone` | 899.0 … 1573.2 | 1664.43 → 1706.21 | 1.085 | 0.026 → 0.026 |
| `engineer_pressure_mines` | 887.6 … 1553.3 | 200.56 → 1025.64 | 0.660 | 0.119 → 0.792 |

Charge cadence is untouched: all three stay at 4 normal encounters to ready and
33.22 charge per neutral normal encounter, inside the frozen 25…35 corridor.

**The mine field lands on its own cap, and that is the design.** The field's
declared `target_cap_fraction` bounds any one target at that share of its max
health, so solo and elite read the cap rather than the coefficient. That is the
field's anti-one-shot identity: a full detonation never kills a single enemy
alone. The coefficient stays readable where the cap does not bind — on the boss
row and across a pack — and `engineer_balance_test.gd` asserts the cap stays the
binding constraint so a later retune cannot quietly turn it into flat damage.

**`engineer_repair_drone` is priced on the impulse it delivers.** Its
coefficients did not move in FAN-2532 and have not moved since. 1560 of its 1706
solo effect is knockback impulse, which the instrument sums into `effect_total`
in pixels next to HP-denominated channels; on HP-denominated channels alone the
row is 134.2 — 40.50 ram damage, 41.79 repair and 51.93 flat absorption. Read as
the defensive save its `control_save` archetype asks for, that is 93.71 HP of
repair plus absorption against a reference EHP of 83.57, i.e. more than one hero
health bar, and it is the only row in the class that has such a channel at all.
Its low boss ratio is the same statement from the other side: the declared boss
policy resists displacement at 0.10 and refuses the movement lock, so a boss
keeps only the 40.50 ram damage and the save the drone spends on its owner. The
class's boss answers are the hex and the field; the drone is the survival
answer, and that split is the trio identity, not a gap. Against the FAN-2532
corridor this row needed a declared 1.10× ceiling exception; the FAN-2949
corridor contains it outright, so the exception is gone and the drone is held to
the same corridor as the other two plus its own save (see below).

## Map-wide coverage (FAN-2955, Ultimate Direction v2)

The three executors left capped targeting. Every volley of the hex suppresses
every live enemy on the map, on screen and off — the three chords are
attribution, raising that floor to at most three hits on a silhouette the beams
actually cross. Every microdrone ram wave intercepts every live enemy; the orbit
radius is the swarm's presentation, never its reach, and the declared
control-resistance policy is what still shapes a single target. All sixteen
mines detonate exactly once inside the window as arena-wide pressure waves, with
`blast_radius` as the shape of the wave and `chain_count` selecting mines rather
than enemies. The count-shaped parameters are gone from the contracts and the
shipped packages: `target_limit` (hex) and `intercept_target_cap` (swarm). The
per-TARGET damage shaping survives untouched in kind — it bounds how much one
enemy takes, never how many are reached.

Re-measured on the live 51-row instrument against the corridor FAN-2949
re-derived (30…45 s of the weapon's own output):

| Weapon | corridor | solo effect | of budget | struck at 20 probes | boss cap ratio |
| --- | --- | ---: | ---: | ---: | ---: |
| `engineer_sentry_wrench` | 1354.2 … 2031.3 | 1702.83 | 1.006 | 8 → 20 of 20 | 0.609 → 0.835 |
| `engineer_repair_drone` | 1348.5 … 2022.8 | 1706.21 | 1.012 | 4 → 20 of 20 | 0.020 |
| `engineer_pressure_mines` | 1331.4 … 1997.1 | 1513.83 | 0.910 | 17 → 20 of 20 | 0.616 → 1.000 |

`of budget` is the solo effect against the corridor midpoint. Two coefficients
moved, because the trio sat below the FAN-2949 floor — the same finding the
assassin and berserk conversions had: the hex `damage` 62.0 → 85.0, and the mine
field's `target_cap_fraction` 0.65 → 0.75. The fraction is the field's bound
rather than a free knob, but a 0.65 cap prices one activation at 0.65 × 45 s =
29.25 s of the weapon's own output, i.e. **below** the 30 s corridor floor by
construction; 0.75 is the smallest bound that fits inside the corridor while
still leaving a quarter of any single enemy standing. The swarm's coefficients
did not move. Charge economy and `total_boss_cap` are byte-identical on all 51
rows, and the other 48 rows are bit-identical.

The field's boss ratio reaching 1.000 is the inherited 8% activation cap binding
in full, which is what the cap is for; `engineer_ultimate_mechanics_test.gd`
asserts the boss never loses more than that.

**Niches after the conversion**, each on a channel the other two do not use. All
three now reach the whole map, so the identity is the SHAPE of the guaranteed
channel, never a reach cap: `engineer_sentry_wrench` is the only cast with no
per-target cap at all, so it is the one that can spend its whole budget on one
target across 4.60 s of sustained volleys; `engineer_repair_drone` is the only
repair, absorption and displacement channel, and the only one whose per-enemy
guarantee is a launch rather than a kill (40.50 ram damage per enemy);
`engineer_pressure_mines` is the only cast bounded per target, so it is the one
that can never finish an enemy alone. `engineer_balance_test.gd` asserts exactly
that split, plus a per-enemy floor of `PER_ENEMY_FLOOR_FRACTION` of one standard
monster's HP at counts 1…1000 and the absence of count-shaped parameters in the
class's own vocabulary, so a later retune cannot quietly collapse two of the
three into one or re-introduce a cap under another name.

## Timing and mechanic contract for the visual cards

The three downstream animation cards inherit this contract unchanged. **No beat
moved in FAN-2532 or FAN-2955** — every `timing_seconds` value in
`docs/design/references/weapon_ultimates/engineer/manifest.json` is still the beat
the executor fires on, and no formation, radius, count, interval or cast length
changed, so no capture, contact sheet or timeline needs re-shooting for balance
reasons:

| Weapon | windup | release | active | recovery | cancel | what the beats carry |
| --- | --- | --- | --- | --- | --- | --- |
| `engineer_sentry_wrench` | 0.00 | 0.35 six pylons rise | 0.70 | 4.60 | 5.10 | 8 synchronized volleys at 0.55 s along the three chords of a FIXED hex, then a 0.75 s hold |
| `engineer_repair_drone` | 0.00 | 0.55 swarm unwinds | 1.05 | 5.40 | 6.10 | 6 ram waves at 0.55 s on every live enemy, repair pulse each wave, dome at 4.30 s for 1.20 s |
| `engineer_pressure_mines` | 0.00 | 0.90 mines burrow up | 1.70 | 3.10 | 3.60 | arm at 0.70 s, finale from 1.70 s outer-to-inner at 0.10 s, 0.80 s tail |

What changed for presentation, and only this: nothing in the beats. The hex
still rises in place on its fixed 210 px hexagon, the swarm still runs six waves
and one dome, and the field still detonates sixteen seeded mines outer-to-inner.
The rebalanced numbers are damage coefficients, a repair target lookup and a
per-target bound; none of them is readable on screen as a shape, a position or a
beat. What IS readable is intensity and extent: the hex and the field remove
real health per hit, so their beam and blast reads should carry the weight of a
payoff rather than of a tick — and since FAN-2955 all three reach the whole
arena, which the presentation rework card owes a full-screen read for.

## Executable evidence

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/engineer_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/engineer_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/engineer_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/engineer_ultimate_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_charge_economy_test.gd
```

The mechanics suite covers formation, permanent-park isolation, epic
resistance, repair eligibility and actual HP, idempotency, shield unwind,
deterministic placement, bounded chaining, finale order, boss cap, and cleanup.
The live suite drives all three exact pairs through `Player.tscn`, verifies
6/12/16 atomic deployments, one charge spend, active charge lockout, re-entry
refusal, and new-run cleanup. The balance suites cover per-weapon/class-trio
power, one activation per encounter, abuse caps, and battle/act/Continue
persistence.

## Presentation boundary

FAN-1465 presentation manifests, timelines, scenes, audio, source images, and
runtime images are read-only inputs here. The executors reuse the accepted
Engineer pylon, microdrone, and mine runtime textures, but do not modify any
presentation-owned path. The shared live presentation bridge remains outside
this package and is part of the FAN-1541 integration boundary.
