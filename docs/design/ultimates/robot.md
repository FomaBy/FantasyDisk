# Robot weapon ultimates

The Robot package promotes the three frozen Robot declarations to exact class-local executors. Each overlay is discovered conventionally below `data/ultimates/classes/robot`; no shared registry, Player, class-weapon, progression, or animation asset changes are required.

| Weapon | Ultimate | Role | Accepted presentation events |
| --- | --- | --- | --- |
| `robot_magnetic_anchor` | Сингулярный Якорь | Aimed gravity well: gripped normals are dragged toward the anchor and movement-locked until the black-point implosion, so a held normal neither walks nor fires; the implosion then detonates into a cyan EMP ring. Bosses take capped damage without displacement or lock. | `windup`, `release`, `implosion`, `emp` |
| `robot_hydraulic_press` | Протокол Сжатия | Aimed corridor: three opposed crushes squeeze normals to the axis, then a hydraulic release finishes the corridor. | `windup`, `crush`, `release` |
| `robot_reactor_core` | Красная Зона | Source-centered overdrive: eight vents whose spin accelerates every wave clear radial lanes under a temporary absorb window, then release a final uncapped exhaust pulse. | `windup`, `overdrive`, `vent_wave`, `final_vent` |

The trio separates on targeting/geometry (aimed point well vs aimed corridor vs source-centered ring), cadence (grip → single detonation vs repeated crush beats vs accelerating waves), and control/defense identity (hold-and-suppress vs squeeze displacement vs self absorb) — at least two axes apart for every pair.

All damage is routed through `UltimateActivation`, so the 8% whole-activation boss cap, event idempotency, mitigation-aware actual HP attribution, one-cast encounter ledger, active-window charge lock, and activation-owned cleanup are shared rather than reimplemented. The accepted Robot timeline scenes remain read-only; their shared presentation adapter is owned by FAN-1541, while these event IDs preserve the hand-off seam.

## Shared lifecycle boundary

The package mutates combat only through accepted `UltimateActivation` and `UltimatePlayerHost` surfaces: target selection, damage, control with the declared tier policy, modifiers, presentation, tracked tweens, and cleanup.

- The catalog's projectile clause of the Anchor is expressed through the accepted control surface: the well's movement lock freezes a gripped normal's fire for the whole grip window, which removes the ranged pressure the well swallows. Interacting with already-flying projectiles requires the `projectile_interaction_query` host primitive that the executor contract audit records as missing; that foundation seam stays outside this package, exactly as it does for the shipped Engineer intercept.
- The Reactor absorb opens only on the first deferred overdrive beat — never on the activation frame — and activation shutdown unwinds it, so an immediately cancelled cast leaves `run_modifiers` untouched and no buff is carried out of the cast.
- Control policy for all three: normals take full displacement (movement lock only from the Anchor's grip), epics resist at ×0.25 displacement and ×0.50 duration without lock, bosses reject displacement and lock entirely.

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
