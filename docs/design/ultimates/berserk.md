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

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Алый Вихрь | 7.45s | 24 | 3 blades, 11 sweeps, 2.2s per-blade cooldown, 1 cross |
| Петля Палача | 5.85s | 18 | 2 passes, 1 execute, 30% execute threshold |
| Раскол Четырёх Сторон | 3.40s | 20 | 3 ordered beats, 4 lanes each, 1 quake |

Each lifetime equals the authorized `recovery` timing in
`docs/design/references/weapon_ultimates/berserk/manifest.json`, and the package
test reads both the lifetime and the crowd cap back from that manifest instead
of duplicating them.

The focused balance proof derives base Berserk physical damage and the selected
weapon's `ultimate_multiplier`, measures every declared coefficient against its
20–35 second frozen budget row, verifies the trio corridor, and contains a
runaway-blade negative control. The sword coefficient is not a free number: it
is however many blade bites the declared round-robin actually clears through
`blade_ready`.

| Weapon | Solo / budget midpoint | 3-target AoE / midpoint | One-activation power | Crowd |
| --- | ---: | ---: | ---: | ---: |
| Алый Вихрь | 0.998 | 0.957 | 27.44s | 24 |
| Петля Палача | 0.995 | 0.952 | 27.35s | 18 |
| Раскол Четырёх Сторон | 1.001 | 0.961 | 27.54s | 20 |

The class-trio composite is `solo 0.998 / AoE 0.957 / crowd 1.000 /
total 0.985`, inside the `0.90…1.10` corridor.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/berserk_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/tracked_tween_natural_completion_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/executor_contract_audit_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
