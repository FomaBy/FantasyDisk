# Druid weapon ultimates

Status: the three exact Druid packages are ready. Each JSON binding is paired
with one class-local executor and its accepted Druid presentation scene. The
shared registry, controller, Player, ClassWeapon, progression data and
animation assets remain untouched.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `summon_amulet` | Дикая Охота | Eight transient spectral beasts burst along the compass directions, then complete six fixed hunt waves against every live enemy. Nearby splash remains a local attribution bonus; all primary strikes reach the map. All spirits are activation-owned and vanish with the sigil. |
| `briar_staff` | Лес за Одно Дыхание | Five seeds grow one connected lattice with readable safe paths. It roots normal targets, slows resistant epic/boss targets, then resolves two impale pulses and a thorn-crown finish across every live enemy. |
| `raven_totem` | Ночь Тысячи Крыльев | The totem marks every live enemy, reducing speed and accuracy/damage, performs four staggered dive waves across the map, returns one wisp per applied strike, and ends in one collapse pulse. |

The runtime scenes embed the accepted `DruidSummonAmuletWildHunt`,
`DruidBriarStaffForestInOneBreath`, and
`DruidRavenTotemNightOfThousandWings` presentations. Their immutable Cast phase
IDs remain the seam with FAN-1494; shared live presentation forwarding remains
owned by FAN-1541.

## Safety and lifecycle

- Every profile uses the frozen Druid `total_boss_cap = 0.08`. All delayed
  hits use the same activation ledger, so actual removed HP — not attempted
  damage — is attributed and the cap applies to the full cast.
- Briar and raven use the shared control policy: normals receive the complete
  effect, epic targets get 45% duration without a lock, and bosses get 20%
  duration without a lock. Raven's mark carries both the exact accuracy value
  and the existing damage-output equivalent.
- Effect nodes, VFX children, tweens and status leases are activation-owned.
  Cancellation, death, node end and a new run remove them; no temporary beast,
  lattice, mark, deploy or modifier is persisted.
- The frozen `ultimate_charge_ledger` contract remains the authority for one
  charge spend, no active-window income, one activation per encounter, and
  battle/act/Continue snapshots. Runtime adoption is shared infrastructure,
  outside this class-local package.

## Caps and balance

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Wild Hunt | 6.6s | every live enemy | 8 beasts, 6 hunt waves, local splash attribution |
| Forest In One Breath | 7.9s | every live enemy | 5 seeds, 3 impale pulses |
| Night of a Thousand Wings | 8.4s | every live enemy | 4 dives, 1 collapse pulse |

The focused balance proof derives base Druid magic damage and the selected
weapon's `ultimate_multiplier`, measures every declared coefficient against
its 20–35 second frozen budget row, verifies the trio's solo/control/crowd
corridor, and contains a runaway-hunt negative control.

| Weapon | Solo / budget midpoint | 5-target AoE / midpoint | Crowd | Defense role |
| --- | ---: | ---: | ---: | --- |
| Wild Hunt | 0.996 | 0.956 | every live enemy | transient hunt pressure |
| Forest In One Breath | 0.993 | 0.955 | every live enemy | 5.0s root/slow |
| Night of a Thousand Wings | 1.005 | 0.965 | every live enemy | 7.8s mark/slow |

The class-trio composite is `solo 0.998 / AoE 0.959 / crowd 1.000 /
defense 0.999 / total 0.989`, inside the `0.90…1.10` corridor. The three
niches remain distinct: Wild Hunt owns fixed multi-wave pressure, Briar owns
the root/lattice control channel, and Raven owns the long marked-control
sequence with the strongest control duration.

## Map-wide coverage (FAN-2530, Ultimate Direction v2)

The three Druid executors already use map-wide runtime selection. This
aggregate card records that contract in the shared coverage ratchet and moves
Druid from the migration allowlist into `COVERAGE_V2_CLASSES`; no weapon-owned
mechanic, profile, scene, or presentation file changes here. The legacy
count-cap keys remain in the frozen package contracts for catalog compatibility
and are not read by the executors.

The rebuilt 51-row live artifact is `build/ultimate_effectiveness_baseline.json`.
Its Druid rows provide the following deterministic matrix:

| Weapon | Corridor | Solo effect | Struck: solo / 5 / 10 / 20 / elite / boss | Boss cap ratio | Uptime |
| --- | ---: | ---: | --- | ---: | ---: |
| Wild Hunt | 1439.10…2158.65 | 1793.51 | 1 / 5 / 10 / 20 / 1 / 1 | 0.830 | 6.6s |
| Forest In One Breath | 1435.50…2153.25 | 1788.33 | 1 / 5 / 10 / 20 / 1 / 1 | 0.828 | 7.9s |
| Night of a Thousand Wings | 1437.60…2156.40 | 1815.08 | 1 / 5 / 10 / 20 / 1 / 1 | 0.838 | 8.4s |

The aggregate proof is `tests/ultimates/mechanics/druid_balance_test.gd`;
the package proof is `druid_package_test.gd`. Together they retain the
distinct solo, crowd, control, elite, and boss roles while leaving charge
economy, boss caps, and weapon-owned mechanics unchanged.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/ultimate_effectiveness_report.gd -- --label=final
python3 tools/check_druid_baseline_isolation.py --base origin/dev
python3 tools/test_check_druid_baseline_isolation.py
```

`check_druid_baseline_isolation.py` is the FAN-3383 row-isolation guard: a
pure JSON diff, keyed by `class_id/weapon_id`, between the committed baseline
and a known-good base revision. It fails if any row outside `druid/*` moved,
which is exactly the FAN-2665 defect (a Druid-only rebuild silently changed
`doctor/restore_potion`). It does not run Godot, so it is immune to any live
re-measurement noise in unrelated classes.
