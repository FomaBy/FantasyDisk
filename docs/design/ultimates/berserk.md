# Berserk weapon ultimates

Status: the three exact Berserk packages are ready. Each JSON overlay is paired
with one class-local executor and its accepted Berserk presentation scene. The
shared executor library, registry, controller, Player, progression data and the
immutable schema-v1 catalog entry remain untouched — the catalog keeps
`declared`/`unbound` for all three profiles and the package covers it as an
overlay, exactly as FAN-1477 left Elementalist.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `sword` | Алый Вихрь | Three spectral blades take turns on one expanding orbit — sweep `n` belongs to blade `n % 3`, and a blade may not touch the same target again before its own 2.2s cooldown. The orbit grows from 190 to 420 across eleven sweeps and collapses into one aim-oriented inward cross slash. |
| `axe` | Петля Палача | One giant axe flies along the aim to the arena edge, marks every corridor target on the way out, turns, and detonates on the way back. A marked normal target under 30% of its own pool takes the finisher; epic and boss tiers are denied the execute by the control policy and a boss never exceeds the two declared passes. |
| `hammer` | Раскол Четырёх Сторон | Three ordered beats and no other order: four world-cardinal ground lanes, then the four diagonals, then a central quake that staggers and launches whatever survived. A beat that arrives out of turn aborts the composition instead of resolving early. |

The runtime scenes embed the accepted `BerserkSwordScarletWhirlwind`,
`BerserkAxeExecutionLoop` and `BerserkHammerFourfoldRift` presentations. Their
immutable Cast phase IDs remain the seam with FAN-1494; shared live presentation
forwarding remains owned by FAN-1541.

## Class-local primitives

The audited executor family set stays at exactly seven, so the four primitives
Berserk needs and the shared library does not have are derived inside the
package as pure static functions, each falsified in both directions by the live
suite:

| Primitive | Owner | Contract |
| --- | --- | --- |
| per-blade hit cooldown | `sword.gd::blade_ready` | an untouched blade bites, a blade inside its own cooldown does not, a blade re-arms exactly at the cooldown |
| arena bounds query | `axe.gd::arena_edge` | the loop always reaches the declared arena radius along the aim, never the (much closer) aim point; a degenerate aim falls back deterministically |
| trajectory motion | `axe.gd::trajectory_point` | hero-to-edge interpolation for the outbound, turn and detonation waypoints |
| execute threshold | `axe.gd::execute_ready` | only a live target already under its declared health share can be finished |
| ordered step composition | `hammer.gd::beat` | the declared step order is traced through the activation; any other order aborts the composition |

The double-pass cap (`axe.gd::pass_allowed`) is the ledger ceiling that keeps a
boss on two loop contacts while a normal target spends a third event on the
execute.

## Safety and lifecycle

- Every profile uses the frozen Berserk `total_boss_cap = 0.10`. All delayed
  hits go through the same activation ledger, so actual removed HP — not
  attempted damage — is attributed and the cap applies to the full cast.
- All three use the shared control policy: normals receive the complete effect,
  epic targets 45% duration (35% displacement), bosses 20% duration (10%
  displacement), and neither tier can be movement-locked or executed.
- Every beat claims its own activation event id, so a repeated callback, two
  overlapping lanes or two corridor passes over the same target resolve once.
- Effect nodes, VFX children, tweens and status leases are activation-owned.
  Cancellation, death, node end and a new run remove them; nothing is persisted.
- All three declare `rare_charge_ledger`, so one full bar buys one activation per
  encounter and a refilled bar is refused until the encounter boundary.

## Caps and balance

| Weapon | Lifetime | Coverage | Additional hard caps |
| --- | ---: | --- | --- |
| Алый Вихрь | 7.45s | every live enemy | 3 blades, 11 sweeps, 2.2s per-blade cooldown, 1 cross |
| Петля Палача | 5.85s | every live enemy | 2 passes, 1 execute, 30% execute threshold |
| Раскол Четырёх Сторон | 3.40s | every live enemy | 3 ordered beats, 4 lanes each, 1 quake |

Each lifetime equals the authorized `recovery` timing in
`docs/design/references/weapon_ultimates/berserk/manifest.json`, and the package
test reads the lifetime back from that manifest instead of duplicating it. The
manifest's `performance.crowd_cap` is a purely visual budget (FAN-1541); since
FAN-2953 no mechanics reach cap exists — every live enemy is reached.

The focused balance proof derives base Berserk physical damage and the selected
weapon's `ultimate_multiplier`, measures every declared coefficient against its
20–35 second frozen budget row, verifies the trio corridor, and contains a
runaway-blade negative control. The sword coefficient is not a free number: it
is however many blade bites the declared round-robin actually clears through
`blade_ready`.

| Weapon | Solo / budget midpoint | 3-target AoE / midpoint | One-activation power | Per-enemy floor share |
| --- | ---: | ---: | ---: | ---: |
| Алый Вихрь | 1.102 | 1.056 | 41.31s | 0.701 |
| Петля Палача | 1.167 | 1.118 | 43.76s | 0.375 |
| Раскол Четырёх Сторон | 0.820 | 0.787 | 30.74s | 1.000 |

The class-trio composite is `solo 1.030 / AoE 0.987`, inside the `0.90…1.10`
corridor (the AoE average carries the rift's documented displacement-paid
discount below). These rows come from the runtime fixture proof above,
re-measured after the FAN-2953 map-wide conversion and re-pricing; the live
51-row corridor reading is the next section.

## Power corridor (FAN-2525)

The corridor is `UltimateChargeBudget.POWER_SECONDS_MIN..MAX` — one activation
is worth 20…35 s of the weapon's OWN normal output — and the live reading of it
is the solo `effect_total` of
`scripts/ultimates/balance/ultimate_effectiveness_runner.gd` (51 rows, solo /
crowd 5 / 10 / 20 / elite / boss).

**The finding.** The live instrument measures every probe at full health, and
the shared control policy denies the execute to epic and boss tiers, so the
axe's declared finisher channel is unreadable by every one of the six
scenarios: the loop's price was carried by the two passes alone. At the shipped
`outbound_damage 17 / return_damage 27` those two passes measured 789.42 —
0.8% above the 783.0 floor — while the closed-form table above (0.995) assumed
the execute lands. The arithmetic correction reprices the loop's own always-
readable channel: `outbound_damage` 17 → 20, `return_damage` 27 → 32. Nothing
else moved — no timing, no cap, no threshold, no execute coefficient.

| Weapon | corridor | solo effect before → after | of budget | boss cap ratio |
| --- | ---: | ---: | ---: | ---: |
| `sword` | 784.4 … 1372.7 | 1080.15 → 1080.15 | 0.787 | 0.784 |
| `axe` | 783.0 … 1370.25 | 789.42 → 932.19 | 0.680 | 0.573 → 0.677 |
| `hammer` | 782.4 … 1369.2 | 1213.98 → 1213.98 | 0.887 | 0.549 |

Baseline is the committed `build/ultimate_effectiveness_baseline.json`; final
is the same instrument after this card. The other 48 rows are bit-identical and
`regressions()` stays clean, so the committed baseline is not rewritten. Crowd
evidence: crowd_20 15209.88 / 15831.19 / 22074.64 — the hammer clears the
widest crowd, the sword the longest control uptime, exactly as declared.

**Two bounded exceptions.** The axe is the class finisher: its execute channel
(16 at ≤30% health, normal tier only) is unreadable by construction on every
probe tier, so the corridor is priced by its loop passes; the twin bounds those
passes at ≥ 0.33 of the budget so the finisher trade can never quietly decay
into a hole. The hammer is the control identity: 460 of its 1213.98 solo effect
is stagger/launch displacement its own boss policy scales to ×0.1, and its
damage-only channel (751.58 = 19.2 s) sits below the floor by design; the twin
bounds that channel at ≥ 0.33 of the budget on the venom_wire precedent. The
class boss answers are the whirlwind (0.784) and the repriced loop (0.677).

**Niches after the correction**, each on a channel the other two do not use:
`sword` is the longest (7.45 s) multi-hit crowd orbit with the only slow-field;
`axe` is the heaviest single contact (return 50 > cross 41 > quake 21) with the
only low-health execute; `hammer` is the only staggering/launching burst and
the shortest (3.4 s). The deterministic corridor proof is
`tests/ultimates/berserk_balance_test.gd`, the closed-form twin of the live
instrument (1080.15 / 932.19 / 1213.98 exactly); it rebuilds the blade
round-robin, the loop corridor and the world-cardinal lanes from the shipped
statics and goes red for a round-robin that never re-arms.

**Timing contract for the downstream visual-animation cards
(FAN-2544/FAN-2545/FAN-2546).** No beat moved: Алый Вихрь stays 0.6 s release +
11 sweeps × 0.55 s + the collapsing cross, Петля Палача stays 0.45 s release +
2.2 s outbound + 2.4 s return + 3.2 s mark, Раскол Четырёх Сторон stays 0.7 s
release + 3 ordered beats × 0.85 s. The only change is numeric: the loop's two
contact hits are priced 20/32 instead of 17/27. The three cards inherit the
timing contract unchanged.

## Map-wide coverage (FAN-2953, Ultimate Direction v2)

The three executors left capped targeting: every sweep of the whirlwind and
every rift beat bites every live enemy (lane membership and the orbit radii are
presentation, never reach), the loop's outbound pass strikes and marks the
whole map with the return corridor as the aimed bonus that carries the execute,
and the whirlwind's cross stays geometric on top of the sweeps' guaranteed
floor. The count-shaped `crowd_cap` parameter is gone from all three contracts
and data profiles; per-target shaping (per-blade cooldown, double-pass cap,
execute threshold) and the frozen `total_boss_cap 0.10` / charge economy are
untouched.

The trio sat below the FAN-2949 re-derived 30–45 s corridor (the same finding
the assassin conversion had), so the coverage change re-priced the always-
readable channels: `blade_damage` 11 → 16 and `cross_damage` 25 → 41,
`outbound_damage` 20 → 30 and `return_damage` 32 → 50, and the rift's three
beats 12/13/18 → 13/14/21 (its damage-only channel now includes the diagonal
beat every enemy takes). Closed-form solo effects: 1080.15 → 1624.14 /
932.19 → 1431.87 / 1213.98 → 1664.92, all inside 1174…1765. The per-enemy
floor is asserted under crowd pressure at counts 1…1000 in
`tests/ultimates/berserk_balance_test.gd`, and the live trio-reach proof lives
in `tests/ultimates/mechanics/berserk_live_test.gd`. The committed
`build/ultimate_effectiveness_baseline.json` was rebuilt: only the three
berserk rows moved, the other 48 rows are bit-identical, and the charge economy
plus `total_boss_cap` are unchanged on every row.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_mechanics_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/berserk_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/tracked_tween_natural_completion_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/executor_contract_audit_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
