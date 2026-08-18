# Assassin weapon ultimates

Status: the three exact Assassin packages are ready. Each JSON binding is
paired with one class-local executor and is discovered by the shared weapon
ultimate registry; no Player, registry, schema, progression or sibling-class
code is changed.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `chakrams` | Восемь Лун | Eight chakrams orbit once, launch along the eight compass lanes, and follow curved paths back to the hero. Only targets marked on the outbound pass can be struck on return; a marked normal enemy at or below 25% health is executed. Secondary lanes retain 12% damage so the pattern keeps broad reach without multiplying focused output. |
| `shadow_daggers` | Момент Перед Смертью | Up to seven highest-health silhouettes are marked before a sequential backstab run. The owner leases the existing untargetable gate for the sequence. Each backstab stores damage in the activation ledger; the final reveal resolves every surviving mark on the same frame, with one focused mark and 10% secondary marks. |
| `venom_wire` | Черная Паутина | Six anchors form one hex web: six perimeter edges and three crossing chords. Three cut pulses admit at most three wire intersections per target, pull normal enemies, and lease poison/slow. One toxin burst consumes the bounded stack count; epic and boss targets keep damage but reject displacement. |

The runtime scenes under `scripts/ultimates/classes/assassin/` own mechanics and
embed the accepted Assassin presentation scene as a child. Every deferred hit
uses `ultimate_damage_sink`, so the activation ledger remains authoritative for
idempotency, applied-HP attribution and the whole-cast boss budget.

## Safety and lifecycle

- All profiles use the frozen Assassin `total_boss_cap = 0.08`; every outbound,
  return, stored backstab, cut and toxin-burst event shares that budget.
- Eight Moons permits its return execute only for normal enemies. Epic and boss
  targets cannot be executed or displaced and retain their tier-adjusted
  control duration.
- Moment Before Death snapshots the owner's existing `_shadow_invisible_left`
  value, extends it only for the declared 1.75-second window, and restores the
  snapshot on completion or cancellation. It does not add a second targeting
  system to Player.
- Black Web uses activation- and target-specific status IDs. Teardown removes
  only those poison/slow leases and preserves unrelated statuses.
- Controller completion or cancellation kills tracked timelines and frees all
  mechanics scenes. The live tests cover normal completion and mid-sequence
  cancellation, including restoration of the owner targeting gate.
- Event IDs are stable per target and phase. Outbound marks and stored damage
  are consumed once, while the per-pulse cut set and per-target stack cap keep
  crossing wires bounded.
- Charge declares `ultimate_charge_ledger`. The package proof covers one spend,
  no active-window income, one activation per encounter, and battle/act/Continue
  persistence for all three weapon rows.

## Caps and timing

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Chakrams | 0.5s orbit + 0.5s outbound + 6×0.12s return | 8 compass lanes | one outbound and one return hit per target; normal-only execute at ≤25% health |
| Shadow Daggers | 0.45s mark + 7×0.16s backstabs + 0.15s reveal | 7 marks | one stored hit per mark; one simultaneous reveal; 1.75s untargetable lease |
| Venom Wire | 3×0.35s cuts + toxin burst | 24 targets | 6 anchors; 9 segments; 3 cuts per target per pulse; one burst per admitted target |

## Balance evidence

Before this package, all three catalog entries were `declared` and had no
executable weapon-level output to measure. The ready-package proof now derives
live weapon damage and `ultimate_multiplier` from ProgressionData, prices each
activation against the frozen 20–35 second budget, and measures the declared
coefficients instead of accepting a hand-authored score.

| Weapon | Solo / budget midpoint | Five-target AoE / midpoint | Crowd cap | Defense |
| --- | ---: | ---: | ---: | ---: |
| Chakrams | 1.002 | 0.885 | 8 | — |
| Shadow Daggers | 1.051 | 0.876 | 7 | 1.75s untargetable |
| Venom Wire | 0.904 | 1.378 | 24 | 3.0s poison/slow |

Shadow Daggers leads focused burst, Chakrams provides the even outward/return
duel, and Venom Wire trades solo share for the widest crowd reach and strongest
area control. The class composite is 1.005 across solo, AoE, capped crowd and
defense axes, inside the project 0.90–1.10 corridor. The balance test also
mutates stored backstab damage to 600 and requires the proof to go red, which
prevents an inherited always-green result.

## Power corridor (FAN-2524)

The corridor is `UltimateChargeBudget.POWER_SECONDS_MIN..MAX` — one activation
is worth 20…35 s of the weapon's OWN normal output — and the live reading of it
is the solo `effect_total` of
`scripts/ultimates/balance/ultimate_effectiveness_runner.gd`.

**The finding.** Unlike the Chemist (FAN-2527) and Engineer (FAN-2532) trios,
the Assassin's weakness was geometric, not arithmetic. Eight Moons prices its
solo output as two full passes — the declared model in
`tests/ultimates/mechanics/assassin_balance_test.gd` has always counted
`pass_damage * 2.0` — but the shipped `return_curve_offset` 132 bends the
return curve up to 66 px away from the lane axis while the hit corridor is the
lane's own 48 px `lane_half_width`. The curved return therefore could never
re-enter the corridor of a target sitting on the lane it was aimed down: the
live instrument measured exactly one pass on the aim-point probe (987.61,
0.69 of the corridor floor), and the marquee out-and-back duel silently halved.
The coefficient was right and the geometry broke its promise, so the correction
is mechanic-first: `return_curve_offset` 132 → 90 caps the curve's lateral
deviation at 45 px < 48 px, the return re-enters every marked lane, and no
damage coefficient moved.

Baseline is the committed `build/ultimate_effectiveness_baseline.json`
(FAN-2911 at `000234e0`); final is the same instrument after this card. The
other 48 rows are bit-identical, so `regressions()` stays clean without a
rewritten baseline.

| Weapon | corridor | solo effect before → after | of budget | boss cap ratio |
| --- | --- | --- | --- | --- |
| `chakrams` | 1433.2 … 2508.1 | 988.61 → 1976.23 | 0.788 | 0.394 → 0.787 |
| `shadow_daggers` | 1432.0 … 2506.0 | 2070.76 → 2070.76 | 0.826 | 0.826 → 0.826 |
| `venom_wire` | 1435.8 … 2512.65 | 1517.16 → 1517.16 | 0.604 | 0.363 → 0.363 |

Charge cadence is untouched: all three stay at 4 normal encounters to ready and
32.7 charge per neutral normal encounter, inside the frozen 25…35 corridor.

**`venom_wire`'s low boss ratio is an explicit exception.** Its coefficients
did not move and its solo effect sits inside the corridor. 604 of its 1517 solo
effect is pull impulse and poison/slow seconds, and its own declared boss
policy rejects displacement (×0.0) and shortens control (×0.25) by
construction, so a boss admits only the 913.16 cut/burst channel — 0.363 of
the budget. That is the crowd specialist's trade, not a gap: across twenty
probes the web applies 22144.11, the widest clear in the trio by a factor of
five. The class's boss answers are Shadow Daggers (0.826) and the corrected
Eight Moons (0.787). `assassin_balance_test.gd` bounds the exception so the
boss-readable channel can never quietly decay below a third of the budget.

**Niches after the correction**, each on a channel the other two do not use:
`chakrams` is the only out-and-back double pass and the only low-health
execute; `shadow_daggers` is the pure focused burst behind the only
owner-untargetable lease, and the class's strongest boss answer;
`venom_wire` owns every control and displacement channel and the widest crowd
cap (24 targets). The deterministic corridor proof is
`tests/ultimates/assassin_balance_test.gd`, the closed-form twin of the live
instrument (1976.23 / 2070.76 / 1517.16 exactly); it rebuilds the return
curve and the hex web from the shipped statics and goes red if the return
curve ever leaves its own lane corridor again.

**Timing contract for the downstream visual-animation cards.** No beat moved:
Eight Moons stays 0.5 s orbit + 0.5 s outbound + 6 × 0.12 s return steps
(1.72 s), Moment Before Death stays 0.45 s mark + n × 0.16 s backstabs +
0.15 s reveal, Black Web stays 3 × 0.35 s cut pulses + toxin burst. The only
visual change is the Eight Moons return arc: its control-point offset is now
90 (was 132), a visibly curved but shallower path whose lateral deviation
peaks at 45 px.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/assassin_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/assassin_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/assassin_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/assassin_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/assassin_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_package_discovery_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/assassin_ultimate_timelines.gd
```
