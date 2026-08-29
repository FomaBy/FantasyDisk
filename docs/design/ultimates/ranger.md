# Ranger weapon ultimates

Status: the three exact Ranger packages are ready. Each JSON binding is paired
with one class-local executor and its accepted Ranger presentation scene. The
shared registry, controller, executors, Player, ClassWeapon, progression data
and animation assets remain untouched.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `moon_crossbow` | Лунная Охота | The heaviest silhouette in the aim sample takes the moon mark and the full bolt. Each of five waves also gives every other live enemy a fixed split floor; a killed mark transfers to the closest survivor. |
| `storm_longbow` | Око Бури | Six lightning beats keep their aimed moving front as the full-hit priority, while every live enemy receives the `beat_floor`; every struck body is pushed off the axis and slowed. |
| `hunter_trap` | Великий Капкан | Three spectral rings and the closing chain net catch every live enemy. Each snap keeps the nearest body as the full jaw bite and gives all other bodies the declared `net_ratio`; normals stay locked, resistant tiers keep shortened pull and slow. |

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

| Weapon | Lifetime | Map coverage | Per-target shaping |
| --- | ---: | ---: | --- |
| Лунная Охота | 4.80 s | every live enemy on every wave | 5 waves, 10% split floor; mark takes full bolt |
| Око Бури | 4.45 s | every live enemy on every beat | 6 beats, 0.46 focus falloff, 12% floor |
| Великий Капкан | 5.35 s | every live enemy on every ring/closure | 3 rings, 1 closure, 11% chain floor |

Ranger prices its ultimates as a burst archetype: the class ultimate declares no
duration, so the trio's defensive contribution is measured against its own
2.0 s class reference instead of the shared control-save bar.

The focused balance proof derives base Ranger damage and the selected weapon's
`ultimate_multiplier`, keeps solo output inside each frozen budget row, checks
the all-map per-enemy floor and control role, and contains a runaway-damage
negative control. Charge cadence and the 9% whole-activation boss cap remain
unchanged.

| Weapon | Solo / budget midpoint | Guaranteed floor | Defense role |
| --- | ---: | ---: | --- |
| Лунная Охота | 1.052 | 10% bolt split | none — pure mark pressure |
| Око Бури | 0.874 | 12% beat floor | 2.6 s push and slow |
| Великий Капкан | 0.806 | 11% chain floor | 3.4 s jaw lock |

The class-trio composite remains inside the `0.90…1.10` solo/control corridor;
map coverage is now a binary runtime assertion rather than a target-count score.

## Downstream presentation handoff

All three visuals must show arena-wide reach without hiding the Ranger identity:
Moon Hunt keeps the archer/mark silhouette central while distant targets receive
moon-split impacts; Storm Eye keeps the advancing arrow corridor central while
the full arena flashes at its floor; Grand Trap keeps the aimed jaw as the focal
impact while spectral chains visibly span the arena. The mechanic phases and
Cast IDs are unchanged; presentation work must not alter charge economy or the
frozen 9% boss cap.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
