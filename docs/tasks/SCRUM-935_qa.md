# SCRUM-935 — independent QA: Soldier double-action trait

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`
Combined implementation: SCRUM-935, SCRUM-936, SCRUM-937, SCRUM-938
Implementation commits: `4eaae863`, `2f91805e`

## QA-Вердикт

Статус: PASSED

The Soldier-only `double_action` trait is data-driven and rolls once per weapon
activation. A successful 50% roll schedules exactly one full copy after 0.18s;
the copy executes below `_attack()`, is guarded by `_action_echo_active`, and
cannot roll another copy. It therefore does not reapply cooldown, charge,
heal-on-attack or unrelated cast effects. Rifle, grenade and bayonet copies use
the same live owner stats and their own damage/crit execution.

Focused evidence passed for all three weapons: 2,000 rolls each remain within
45–55%; 200 attempts while the recursion guard is active produce zero echoes;
forced chance 1.0 produces exactly two actions and never three or more; all
other classes produce zero action echoes.

## Class-balance result

The mechanic-first redesign changes each tactical rhythm while preserving the
existing Soldier trio budget.

| Trio state | Solo | AoE | Crowd | Defense | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before: suppression / short fuse / brace | 1.000 | 1.000 | 0.960 | 1.22 | 1.046 |
| After: explosive bullet / long fuse / melee cone | 1.000 | 1.000 | 0.960 | 1.22 | 1.046 |

The before row is the accepted pre-wave trio matrix in
`docs/design/reports/full_class_rebalance_identity_audit.md`. The after row was
recomputed from the current balance/crowd reports: the expected ×1.5 action
output is included in the budget model, so new tuning compensates the trait
without removing its visible two-action fantasy.

| Weapon | Before identity / tuning / solo / 5T | After identity / tuning / solo / 5T / EHP |
| --- | --- | --- |
| `soldier_rifle` | 3-shot suppression line / 1.723 / 47.99 / 150.03 | fast explosive bullet / 1.951 / 47.99 / 149.93 / 103.1 |
| `soldier_grenade` | short cooked blast / 2.643 / 48.02 / 149.94 | slow flight + visible fuse nuke / 1.659 / 48.00 / 150.05 / 103.1 |
| `soldier_bayonet` | defensive brace corridor / 1.833 / 48.01 / 149.92 | 105° melee cone + rare ranged shot / 1.158 / 47.99 / 150.02 / 106.0 |

Current crowd-clear deviations all pass: rifle `+0.0/+4.2/+10.9%`, grenade
`-3.9/+0.1/+6.5%`, bayonet `+2.0/+6.3/+13.1%` at 5/10/20 targets. The weapons
remain distinct: frequent ranged splash, high-commit delayed AoE, and close
control with 3% passive defense and a secondary 25% shot.

## Verification

All commands ran through `tools/godot_gate.py` and passed:

- `tools/balance_harness.gd`;
- `tests/soldier_kit_test.gd`;
- `tests/weapon_tuning_application_test.gd` — 51/51 pairs;
- `tests/global_damage_balance_smoke_test.gd`;
- `tests/global_survivability_balance_smoke_test.gd`;
- `tests/contact_stuck_attack_deadzone_test.gd`;
- `tests/melee_unique_mechanics_test.gd`;
- `tests/projectile_chain_pierce_identity_test.gd`;
- `tests/animation_smoke_test.gd`;
- `tests/runtime_smoke_weapon_mechanics_test.gd`;
- `tools/survivability_harness.gd`;
- `tests/survivability_scenario_test.gd`;
- `tests/live_balance_simulation_test.gd`;
- `tests/runtime_smoke_test.gd`.

The Soldier-focused and global gates were repeated after rebasing onto the
Elementalist wave at `origin/dev` `1fca052c`; they remained green. Runtime
emitted only the known dummy-renderer null-texture screenshot diagnostic and
completed PASS. No production fix or follow-up bug was required. Remaining
non-blocking risk is subjective live feel of the 0.18s echo/fuse pacing; the
separate animation events, projectile VFX and behavioral timings are covered.
