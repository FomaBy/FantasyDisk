# Robot weapon ultimates

FAN-2537 reconciles the three frozen Robot ultimate profiles as one class-local
coverage-v2 package. Each overlay is still discovered conventionally below
`data/ultimates/classes/robot`; the aggregate change is limited to the shared
coverage ledger, deterministic evidence, and these focused tests and references.

| Weapon | Ultimate | Role | Accepted presentation events |
| --- | --- | --- | --- |
| `robot_magnetic_anchor` | Сингулярный Якорь | Aimed gravity well: every eligible target is re-enumerated for the singularity and EMP; gripped normals are dragged toward the anchor and movement-locked until the black-point implosion. Bosses take capped damage without displacement or lock. | `windup`, `release`, `implosion`, `emp` |
| `robot_hydraulic_press` | Протокол Сжатия | Aimed corridor: every eligible target is re-enumerated for each opposed crush and hydraulic release; normals squeeze toward the axis. | `windup`, `crush`, `release` |
| `robot_reactor_core` | Красная Зона | Source-centered overdrive: fixed vent lanes retain their nearest-target attribution while the final exhaust re-enumerates eligible targets under a temporary absorb window. | `windup`, `overdrive`, `vent_wave`, `final_vent` |

The trio separates on targeting/geometry (aimed point well vs aimed corridor vs source-centered ring), cadence (grip → single detonation vs repeated crush beats vs accelerating waves), and control/defense identity (hold-and-suppress vs squeeze displacement vs self absorb) — at least two axes apart for every pair.

All damage is routed through `UltimateActivation`, so the 8% whole-activation boss cap, event idempotency, mitigation-aware actual HP attribution, one-cast encounter ledger, active-window charge lock, and activation-owned cleanup are shared rather than reimplemented. The accepted Robot timeline scenes remain read-only; their shared presentation adapter is owned by FAN-1541, while these event IDs preserve the hand-off seam.

## Shared lifecycle boundary

The package mutates combat only through accepted `UltimateActivation` and `UltimatePlayerHost` surfaces: target selection, damage, control with the declared tier policy, modifiers, presentation, tracked tweens, and cleanup.

- The catalog's projectile clause of the Anchor is expressed through the accepted control surface: the well's movement lock freezes a gripped normal's fire for the whole grip window, which removes the ranged pressure the well swallows. Interacting with already-flying projectiles requires the `projectile_interaction_query` host primitive that the executor contract audit records as missing; that foundation seam stays outside this package, exactly as it does for the shipped Engineer intercept.
- The Reactor absorb opens only on the first deferred overdrive beat — never on the activation frame — and activation shutdown unwinds it, so an immediately cancelled cast leaves `run_modifiers` untouched and no buff is carried out of the cast.
- Control policy for all three: normals take full displacement (movement lock only from the Anchor's grip), epics resist at ×0.25 displacement and ×0.50 duration without lock, bosses reject displacement and lock entirely.

## Balance evidence

The normal Robot trio remains the frozen baseline. The focused level-1 proof
measures these ultimate ratios against each weapon's 20–35 second charge
budget. Reach is a v2 contract, not a headcount:

| Weapon | Solo | AoE | Reach | Defense |
| --- | ---: | ---: | ---: | ---: |
| `robot_magnetic_anchor` | 1.08 | 1.08 | uncapped | 0.00 |
| `robot_hydraulic_press` | 0.97 | 0.97 | uncapped | 0.00 |
| `robot_reactor_core` | 0.95 | 0.95 | uncapped | 1.00 (temporary absorb) |
| Robot trio | 1.00 | 1.00 | 1.00 | 0.33; total 0.83 |

The focused balance test now verifies the Robot entry in
`COVERAGE_V2_CLASSES`, absence from the migration allowlist, no executor
count-shaped reach parameter, the inherited 51-row harness, rare-charge
contract, boss cap, and active-window charge lock. Ultimate roles deliberately
split setup/control (Anchor), corridor cadence (Press), and radial
defense/clear (Reactor) without changing normal weapon budgets.

## Map-wide coverage (FAN-2537 / Ultimate Direction v2)

The three Robot leaves are already present on the admitted `dev` base. This
aggregate card records the conversion in the shared coverage ratchet and keeps
the existing weapon-local mechanics, overlays, scenes, and presentation
budgets untouched. The three executor packages declare no count-shaped target
parameter; direct full-set queries use `limit = 0`, while Reactor's fixed
one-target-per-vent lane remains a frozen identity rail.

| Weapon | Selection contract | Geometry that remains |
| --- | --- | --- |
| `robot_magnetic_anchor` | all eligible targets around the aimed anchor | 250px singularity pull, then the 300px EMP ring |
| `robot_hydraulic_press` | all eligible targets in the press query | 430px aimed corridor with three crush beats and release |
| `robot_reactor_core` | fixed nearest-target attribution per vent; full eligible set for terminal exhaust | source-centered 300px radial lanes and terminal exhaust |

The `performance.crowd_cap` values in the presentation manifest remain visual
node budgets owned by FAN-1541; they are not enemy-count limits and are not
changed by this conversion. The per-target rails, control tiers, temporary
Reactor absorb, and shared 8% whole-activation boss cap continue to bound
outcome.

The fresh 51-row final report is byte-identical to the admitted baseline after
the expected top-level `label` change, so
`build/ultimate_effectiveness_baseline.json` is intentionally unchanged. The
Robot rows still prove deterministic canonical probes:

| Weapon | Struck: solo / 5 / 10 / 20 / elite / boss | Boss cap ratio | Uptime |
| --- | --- | ---: | ---: |
| `robot_magnetic_anchor` | 1 / 5 / 10 / 20 / 1 / 1 | 0.901 | 4.76s |
| `robot_hydraulic_press` | 1 / 5 / 10 / 18 / 1 / 1 | 0.811 | 4.06s |
| `robot_reactor_core` | 1 / 5 / 9 / 16 / 1 / 1 | 0.789 | 6.04s |

The press and reactor rows intentionally retain their shape-specific misses in
the canonical formation while remaining free of a count cap; v2 means the
selection contract does not truncate the eligible set.

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/robot_ultimate_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/ultimate_effectiveness_report.gd -- --label=final
```
