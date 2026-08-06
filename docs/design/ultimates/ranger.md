# Ranger weapon ultimates

Status: the three exact Ranger packages are ready. Each JSON binding is paired
with one class-local executor and its accepted Ranger presentation scene. The
shared registry, controller, executors, Player, ClassWeapon, progression data
and animation assets remain untouched.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `moon_crossbow` | Лунная Охота | The aim samples the field and the heaviest silhouette inside it takes the moon mark. Five bolt waves land on the mark, each one splitting a fixed share into four distinct neighbours. A wave that kills the mark hands it to the closest surviving neighbour, so the hunt keeps its remaining waves instead of ending early. |
| `storm_longbow` | Око Бури | One aimed corridor is walked tail to tip by six lightning beats. The body nearest the advancing front takes the full strike, everything else on the rail keeps only `beat_falloff` of what the body ahead of it took, and every struck body is pushed off the axis and slowed. |
| `hunter_trap` | Великий Капкан | Three spectral rings close inward on the aimed point, then one chain net spans the whole trap. Each snap bites the body nearest the centre at full strength and shares the declared `net_ratio` with everything else it holds; normals stay locked in the jaws, resistant tiers keep only the shortened pull and slow. |

The runtime scenes embed the accepted `RangerMoonCrossbowMoonHunt`,
`RangerStormLongbowStormEye`, and `RangerHunterTrapGrandTrap` presentations from
FAN-1474, and each mechanic lifetime matches its accepted timeline (4.80 s /
4.45 s / 5.35 s). The immutable Cast phase IDs remain the seam with FAN-1494;
shared live presentation forwarding remains owned by FAN-1541.

## Safety and lifecycle

- Every profile uses the frozen Ranger `total_boss_cap = 0.09`. All delayed hits
  route through the same activation ledger, so actual removed HP — not attempted
  damage — is attributed and the cap applies to the whole cast.
- The moon mark is activation ledger state, not a target flag: it is recorded on
  the prey, transferred on a kill, and dropped with the activation. Nothing is
  written onto an enemy that outlives the cast.
- Storm and trap use the shared control policy. The storm never pins anything:
  normals take the full push and slow, epic targets 45% and bosses 20% of both.
  The trap locks normals only; epic targets keep 45% and bosses 20% of the pull
  and slow, both without a movement lock.
- Effect nodes, VFX children, tweens and status leases are activation-owned.
  Cancellation, death, node end and a new run remove them, and cleanup erases
  only the leases the cast itself took — a foreign status on the same target is
  left untouched.
- The frozen `ultimate_charge_ledger` contract remains the authority for one
  charge spend, no active-window income, one activation per encounter, and
  battle/act/Continue snapshots. Runtime adoption is shared infrastructure,
  outside this class-local package.

## Caps and balance

| Weapon | Lifetime | Crowd | Additional hard caps |
| --- | ---: | ---: | --- |
| Лунная Охота | 4.80 s | 1 mark + 4 splits | 5 bolt waves, 10% split share, 200 px split radius |
| Око Бури | 4.45 s | 8 corridor bodies | 6 beats, 0.46 rank falloff, 120 px half width |
| Великий Капкан | 5.35 s | 10 caught bodies | 3 rings, 1 closure, 11% chain share |

Ranger prices its ultimates as a burst archetype: the class ultimate declares no
duration, so the trio's defensive contribution is measured against its own
2.0 s class reference instead of the shared control-save bar.

The focused balance proof derives base Ranger damage and the selected weapon's
`ultimate_multiplier`, measures every declared coefficient against its 20–35
second frozen budget row, checks the trio's solo/crowd/control corridor, and
contains a runaway-corridor negative control.

| Weapon | Solo / budget midpoint | Crowd ceiling / AoE midpoint | Crowd | Defense role |
| --- | ---: | ---: | ---: | --- |
| Лунная Охота | 1.147 | 0.955 | 5 | none — pure mark pressure |
| Око Бури | 0.953 | 1.052 | 8 | 2.6 s push and slow |
| Великий Капкан | 0.880 | 1.045 | 10 | 3.4 s jaw lock |

The class-trio composite is `solo 0.993 / AoE 1.017 / crowd 1.000 /
defense 1.000 / total 1.003`, inside the `0.90…1.10` corridor.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
