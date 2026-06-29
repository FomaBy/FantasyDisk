# Validation And Reports

Use this before finishing a balance task.

## Required Reports

Generate or inspect:

- `build/balance_report.md` from `tools/balance_harness.gd`.
- `build/balance_final_audit_0_1_5.md` when the harness writes it for the current sprint.
- `build/global_damage_balance_report.md` from `tests/global_damage_balance_smoke_test.gd`.

For defense or sustain:

- `build/global_survivability_balance_report.md`.
- `build/survivability_report.md`.
- `build/survivability_scenarios_report.md` if using class roster projection.

For live timing:

- `build/live_combat_report.md` or the report path produced by `tools/live_combat_harness.gd`.

## Minimum Test Set

Always run:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_damage_balance_smoke_test.gd
```

Run these when relevant:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_survivability_balance_smoke_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/survivability_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/survivability_scenario_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/live_combat_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/live_balance_simulation_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

If a command cannot run, say exactly why and keep the task status honest.

## Completion Report Template

Include this in the task result:

```text
Balance result:
- Scope:
- Baseline reports:
- Before class trio table:
- After class trio table:
- Per-weapon identity changes:
- Mechanics changed:
- Numeric tuning changed:
- Commands run:
- Docs updated:
- Remaining risk:
```

## QA Failure Signals

Treat these as failures until explained or fixed:

- A class total is balanced only because one weapon is overpowered and another is useless.
- A weapon contributes no clear solo, AoE, crowd, defense, or utility niche.
- A class has all three weapons weak on the same axis.
- A defensive mechanic is counted but is not implemented or testable.
- A numeric buff fixes one axis and accidentally breaks another.
- Automated reports pass pair-level gates but class-trio totals fail.
