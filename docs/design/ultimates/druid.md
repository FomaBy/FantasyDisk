# Druid weapon ultimates

Status: the three exact Druid packages are ready. Each JSON binding is paired
with one class-local executor and its accepted Druid presentation scene. The
shared registry, controller, Player, ClassWeapon, progression data and
animation assets remain untouched.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `summon_amulet` | Дикая Охота | Eight transient spectral beasts burst along the compass directions, then complete six priority-target hunt waves. Each primary strike has a capped nearby splash, giving the pack crowd pressure without multiplying its persistent summon count. All spirits are activation-owned and vanish with the sigil. |
| `briar_staff` | Лес за Одно Дыхание | Five seeds grow one connected lattice with readable safe paths. It roots normal targets, slows resistant epic/boss targets, then resolves two impale pulses and a thorn-crown finish against a capped three-target damage rail. |
| `raven_totem` | Ночь Тысячи Крыльев | The totem marks a capped flock of enemies, reducing speed and accuracy/damage, performs four staggered three-target dives, returns one wisp per applied strike, and ends in a single capped collapse pulse. |

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
| Wild Hunt | 6.6s | 12 priority targets | 8 beasts, 6 hunt waves, 4-target splash |
| Forest In One Breath | 7.9s | 20 control / 3 damage | 5 seeds, 3 impale pulses |
| Night of a Thousand Wings | 8.4s | 22 marked / 3 dive | 4 dives, 1 collapse pulse |

The focused balance proof derives base Druid magic damage and the selected
weapon's `ultimate_multiplier`, measures every declared coefficient against
its 20–35 second frozen budget row, verifies the trio's solo/control/crowd
corridor, and contains a runaway-hunt negative control.

| Weapon | Solo / budget midpoint | 5-target AoE / midpoint | Crowd | Defense role |
| --- | ---: | ---: | ---: | --- |
| Wild Hunt | 0.999 | 0.943 | 12 | transient hunt pressure |
| Forest In One Breath | 0.996 | 0.958 | 20 / 3 damage | 5.0s root/slow |
| Night of a Thousand Wings | 1.008 | 0.968 | 22 / 3 dive | 7.8s mark/slow |

The class-trio composite is `solo 1.001 / AoE 0.956 / crowd 1.000 /
defense 0.999 / total 0.989`, inside the `0.90…1.10` corridor.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/druid_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
