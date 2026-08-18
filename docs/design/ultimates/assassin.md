# Assassin weapon ultimates

Status: the three exact Assassin packages are ready. Each JSON binding is
paired with one class-local executor and is discovered by the shared weapon
ultimate registry; no Player, registry, schema, progression or sibling-class
code is changed.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `chakrams` | Восемь Лун | Eight chakrams orbit once, launch along the eight compass lanes, and follow curved paths back to the hero. The outbound pass strikes EVERY live enemy on the map; the lane an enemy belongs to decides which chakram claims it and how the hit is attributed, never whether it is reached. Only targets the curved return re-enters are struck a second time; a marked normal enemy at or below 25% health is executed. Silhouettes outside the duel keep 41% damage, the guaranteed per-enemy floor. |
| `shadow_daggers` | Момент Перед Смертью | EVERY live enemy on the map is marked, ordered by health, before a fixed seven-wave backstab run: wave `w` serves every mark with `index % 7 == w`, so the whole crowd is reached inside one constant active window. The owner leases the existing untargetable gate for the sequence. Each backstab stores damage in the activation ledger; the final reveal resolves every surviving mark on the same frame, with one focused mark and 21% secondary marks. |
| `venom_wire` | Черная Паутина | Six anchors form one hex web: six perimeter edges and three crossing chords. Three cut pulses cut EVERY live enemy on the map at least once, wherever it stands; the nine wires raise that to one cut per crossing, bounded at three per target per pulse. Normal enemies are pulled and leased poison/slow. One toxin burst consumes the stack count; epic and boss targets keep damage but reject displacement. |

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
| Chakrams | 0.5s orbit + 0.5s outbound + 6×0.12s return | every live enemy | one outbound and one return hit per target; normal-only execute at ≤25% health |
| Shadow Daggers | 0.45s mark + 7×0.16s backstab waves + 0.15s reveal | every live enemy | one stored hit per mark; one simultaneous reveal; 1.75s untargetable lease |
| Venom Wire | 3×0.35s cuts + toxin burst | every live enemy | 6 anchors; 9 segments; 3 cuts per target per pulse; one burst per cut target |

None of the three carries a target-count cap any more. What remains in the
"additional" column is per-target shaping — how much a struck silhouette takes,
never how many are struck.

## Balance evidence

Before this package, all three catalog entries were `declared` and had no
executable weapon-level output to measure. The ready-package proof derives live
weapon damage and `ultimate_multiplier` from ProgressionData, prices each
activation against the corridor (30–45 s of the weapon's own output since
FAN-2949), and measures the declared coefficients instead of accepting a
hand-authored score.

| Weapon | Solo / budget midpoint | Five-target AoE / reference | Guaranteed per-enemy share | Defense |
| --- | ---: | ---: | ---: | ---: |
| Chakrams | 0.998 | 1.084 | 0.205 | — |
| Shadow Daggers | 1.000 | 1.095 | 0.210 | 1.75s untargetable |
| Venom Wire | 0.775 | 2.310 | 1.000 | 3.0s poison/slow |

Shadow Daggers leads focused burst, Chakrams provides the outward/return duel,
and Venom Wire trades solo share for the evenest crowd spread and the strongest
area control. The crowd axis used to be the three hard target caps; Ultimate
Direction v2 retires them, so what separates the three in a crowd is the share
of the focused hit every other enemy is guaranteed — the fourth column. Solo and
defense stay inside the project 0.90–1.10 corridor; the AoE rail is scored
against a widened 1.00–2.00 band with a bounded trio spread, because an ultimate
that reaches the whole map necessarily scales with the crowd. The balance test
also mutates stored backstab damage to 600 and requires the proof to go red,
which prevents an inherited always-green result.

## Power corridor (FAN-2524)

> Historical record of the FAN-2524 geometry fix. Its corridor (20…35 s) and its
> target caps were superseded by FAN-2949 and FAN-2952 — see
> **Map-wide coverage** below for the numbers that hold today. The geometric
> finding itself still stands and is still guarded by the same red-test control.

The corridor is `UltimateChargeBudget.POWER_SECONDS_MIN..MAX` — one activation
was worth 20…35 s of the weapon's OWN normal output — and the live reading of it
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

## Map-wide coverage (FAN-2952, Ultimate Direction v2)

Owner directive FAN-2944 §2 makes reach part of the numeric contract, and
FAN-2949 published the rule plus the re-derived corridor. This card converts the
Assassin trio to it. The trio's design is not re-opened: the three niches, the
cast beats, the boss cap and the charge economy are the FAN-2524 ones.

**What was stripped.** `shadow_daggers.radius` (520) and `.target_count` (7),
`chakrams.targets_per_lane` (4) and `venom_wire.target_limit` (24). Per-target
shaping stays: `secondary_damage_ratio`, `max_cuts_per_pulse`, `stack_bonus`.

**How each weapon reaches the map now.**

* `shadow_daggers` marks every live enemy through the activation itself. The
  `priority_target_selector` primitive could not express it — its contract
  requires a finite radius — so the ordered set is read straight from
  `select_targets(origin, INF, 0, "highest_hp")`. The sequence became a FIXED
  seven waves partitioning the mark list (`index % waves == wave`), which is the
  wave/sequence exception the contract allows: the full sequence provably serves
  every mark, and the declared cast stops moving with the crowd size (it is now
  1.72 s at any count, where before it shrank to 0.76 s against one enemy).
* `chakrams` strikes every live enemy on the outbound pass, walked lane by lane
  and nearest-first inside a lane, so the duel target the first chakram claims is
  the one the old corridor sweep claimed. The curved return is unchanged and is
  now the geometric BONUS on top of the guaranteed outbound floor.
* `venom_wire` cuts every live enemy once per pulse wherever it stands; the nine
  wires raise that to one cut per crossing, still bounded per target per pulse.
  The poison is leased once per silhouette instead of being re-written on every
  pulse — an identical status three times over bought nothing but a refreshed
  timer, and at map-wide reach it is a whole crowd's worth of dictionaries.

**Re-measured on the live 51-row instrument** against the FAN-2949 corridor
(`k ∈ [1.0, 1.5]` × the live standard-monster pool). `struck` is probes damaged
out of probes present:

| Weapon | corridor | solo effect | solo | 5 | 10 | 20 | boss cap ratio |
| --- | --- | ---: | --- | --- | --- | --- | ---: |
| `chakrams` | 2149.8 … 3224.7 | 2684.02 | 1/1 | 3→5 | 6→10 | 10→20 | 0.613 → 0.832 |
| `shadow_daggers` | 2148.0 … 3222.0 | 2685.22 | 1/1 | 5/5 | 7→10 | 7→20 | 0.642 → 0.833 |
| `venom_wire` | 2153.7 … 3230.6 | 2691.22 | 1/1 | 5/5 | 10/10 | 19→20 | 0.283 → 0.646 |

Every scenario now strikes the whole formation. The coefficients were re-priced
onto the re-derived corridor — the trio sat BELOW its floor the moment FAN-2949
landed (1976.23 / 2070.76 / 1517.16 against a floor of ~2150) — by scaling each
weapon's own damage channel, so the relative standing of the three is preserved:
`pass_damage` 120 → 163, `backstab_damage` 256 → 332, `cut_damage` 42 → 96 and
`burst_damage` 210 → 480. Secondary ratios rose to carry the per-enemy floor:
`chakrams` 0.12 → 0.41, `shadow_daggers` 0.10 → 0.21.

**Per-enemy floor, measured under crowd pressure.** Every live enemy is
guaranteed `PER_ENEMY_FLOOR_FRACTION (0.5) ×` one standard monster's max HP.
`tests/ultimates/assassin_balance_test.gd` asserts it at counts
1, 2, 5, 10, 20, 100 and 1000 against the shipped pool rather than a literal, so
the floor moves with the corridor. The binding case is two enemies, where the
floor is a quarter of the pool: `chakrams` delivers 550.02 against 537.45,
`shadow_daggers` 563.69 against 537.00, and `venom_wire` — which hands every
enemy the same full cut/burst it hands the one in front of it — 2087.22 against
538.43. That even spread is what carries the Black Web's crowd niche now that a
target cap no longer can.

**Frozen things, proven unchanged.** Across all 51 rows `total_boss_cap`,
`encounters_to_ready`, `normal_charge`, `elite_charge`, `reference_solo_dps`,
`power_budget_min/max` and `power_archetype` are identical before and after;
the Assassin trio stays at 4 normal encounters to ready and 32.70 charge per
neutral normal encounter. `balance_charge_economy_test.gd` is untouched and
green. The other 48 baseline rows are bit-identical, so `regressions()` is clean
without a `regression_reason`.

**Ratchet.** `assassin` has left `COVERAGE_MIGRATION_ALLOWLIST` and is the first
entry of `COVERAGE_V2_CLASSES`. The shared FAN-2949 source scan only recognises
`*target_cap*` siblings and never could have seen this class's `target_count` /
`target_limit` / `targets_per_lane` names, so the corridor proof asserts the
absence of count-shaped parameters over the Assassin's own vocabulary too,
across both the executor contracts and the shipped parameters.

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
