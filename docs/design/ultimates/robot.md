# Robot weapon ultimates

The Robot package promotes the three frozen Robot declarations to exact class-local executors. Each overlay is discovered conventionally below `data/ultimates/classes/robot`; no shared registry, Player, class-weapon, progression, or animation asset changes are required.

| Weapon | Ultimate | Role | Accepted presentation events |
| --- | --- | --- | --- |
| `robot_magnetic_anchor` | Сингулярный Якорь | Aimed gravity well: normal targets are pulled to the selected point, then implode and receive an EMP; bosses take capped damage without displacement. | `windup`, `implosion`, `emp` |
| `robot_hydraulic_press` | Протокол Сжатия | Aimed corridor: three opposed crushes squeeze normals to the axis, then a hydraulic release finishes the corridor. | `windup`, `crush`, `release` |
| `robot_reactor_core` | Красная Зона | Source-centered overdrive: eight rotating vents clear radial lanes under a temporary absorb window, then release a final exhaust pulse. | `windup`, `vent_wave`, `final_vent` |

All damage is routed through `UltimateActivation`, so the 8% whole-activation boss cap, event idempotency, mitigation-aware actual HP attribution, one-cast encounter ledger, active-window charge lock, and activation-owned cleanup are shared rather than reimplemented. The accepted Robot timeline scenes remain read-only; their shared presentation adapter is owned by FAN-1541, while these event IDs preserve the hand-off seam.

## Balance evidence

The normal Robot trio remains the frozen baseline. The focused level-1 proof measures these ultimate ratios against each weapon's 20–35 second charge budget:

| Weapon | Solo | AoE | Crowd cap | Defense |
| --- | ---: | ---: | ---: | ---: |
| `robot_magnetic_anchor` | 1.13 | 1.13 | 8 | 0.00 |
| `robot_hydraulic_press` | 1.02 | 1.02 | 8 | 0.00 |
| `robot_reactor_core` | 0.99 | 0.99 | 8 | 1.00 (temporary absorb) |
| Robot trio | 1.05 | 1.05 | 1.00 | 0.33; total 0.86 |

The test also verifies the inherited 51-row harness, rare-charge contract, boss cap, and active-window charge lock. Ultimate roles deliberately split setup/control (Anchor), corridor cadence (Press), and radial defense/clear (Reactor) instead of changing the normal weapon budgets.

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_balance_test.gd
```
