# Ranger weapon ultimates

FAN-1475 promotes the three frozen Ranger declarations to ready, class-local
weapon packages. The overlays under `data/ultimates/classes/ranger` and matching
executors under `scripts/ultimates/classes/ranger` leave the shared registry,
controller, Player host and charge ledger unchanged.

## Runtime contracts

All three profiles use `ultimate_charge_ledger`, activation-owned cleanup and
the immutable Ranger 9% whole-activation boss cap. Each wrapper instantiates
the existing Ranger timeline scene from `scenes/vfx/ultimates/ranger`, while the
executor sends phase events through the activation presentation seam.

| Weapon | Distinct runtime identity |
| --- | --- |
| `moon_crossbow` | Aim-assisted prey is marked; otherwise the highest-HP valid target is marked. Three waves hit that prey and split to four distinct live neighbours. A lethal mark transfers before the next wave. |
| `storm_longbow` | Seven tail-to-tip beats walk the aimed corridor, never selecting an off-axis target. Each beat carries Ranger's range-control knockback with tier resistance. |
| `hunter_trap` | Three inward snap rings affect at most three enemies at the aimed trap site. Each snap damages and leases a 4.2-second snare; cancel or normal completion removes only those leases. |

## Balance evidence

The normal-weapon baseline remains the inherited 51-row charge harness; the
new test measures each ultimate against its own 20–35 second power window.
The ratios use the common 27.5-second midpoint, so weapon roles may differ
while the class trio stays balanced.

| Weapon | Solo ratio | 5-target AoE ratio | Crowd cap | Defensive utility |
| --- | ---: | ---: | ---: | --- |
| `moon_crossbow` | 1.212 | 1.048 | 5 | safe ranged mark transfer |
| `storm_longbow` | 0.993 | 0.593 | 12 | 3.15 s of resisted corridor knockback |
| `hunter_trap` | 0.852 | 1.526 | 3 | 4.20 s decisive snare |
| Ranger trio mean | 1.019 | 1.056 | distinct caps | precision / corridor / control split |

Moon Crossbow owns focused mark pressure, Storm Longbow owns long-range spatial
control, and Hunter Trap owns the durable crowd-control window. Their numeric
windows stay inside the frozen power corridor without changing normal weapon
balance or charge economy.

## Focused verification

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/ranger_ultimate_presentation_test.gd
```
