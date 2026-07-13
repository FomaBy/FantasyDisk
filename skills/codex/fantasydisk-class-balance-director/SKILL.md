---
name: fantasydisk-class-balance-director
description: "Use this skill when designing, auditing, rebalancing, implementing, or validating FantasyDisk class and weapon balance: class weapon trios, class aggregate power, solo-target DPS, AoE and crowd-clear, defensive or survivability utility, ProgressionData weapon configs, balance harness reports, global damage or survivability smoke tests, or gameplay mechanic changes needed to make weapon kits and classes equally effective while preserving distinct playstyles."
---

# FantasyDisk Class Balance Director

Work only from the assigned Multica `FAN-*` issue and keep its owner, evidence,
and QA status truthful.

## Overview

Use this skill to balance FantasyDisk classes as complete three-weapon kits, not as isolated weapons. The goal is equal aggregate class effectiveness across solo targets, AoE or crowd pressure, and defensive mechanics, while every individual weapon keeps a distinct gameplay identity.

## Required Context

Before changing balance, read the current task file and these repository sources when present:

- `AGENTS.md`
- `docs/process/agent_role_boundaries_and_handoffs.md`
- `docs/process/multica_workflow.md`
- `docs/design/mechanics_extract.md`
- `docs/design/current_game_state.md`
- `docs/design/systems/characters_weapons.md`
- `docs/design/systems/progression_balance.md`
- `docs/design/systems/combat.md`
- `docs/design/content_registry.md` when class or weapon IDs matter

Then load only the needed bundled references:

- `references/class-balance-model.md` for score axes, trio totals, corridors, and class equality rules.
- `references/balance-workflow.md` for the step-by-step audit and implementation process.
- `references/mechanic-change-rules.md` when a weapon or class needs mechanic changes rather than only numeric tuning.
- `references/validation-and-reports.md` before finishing a task or reporting results.

## Non-Negotiables

1. Balance a class by the sum of its three weapons. A class is a kit, not one highlighted weapon.
2. Balance all classes against each other by their three-weapon kit totals.
3. Evaluate each class kit across solo pressure, AoE or crowd-clear, and defensive or survivability utility.
4. The three weapons inside one class must be aggregate-equal as a kit, but individually different in gameplay. Do not make them clones.
5. If a class or weapon fails because its mechanic cannot cover an axis, change the mechanic first. Numeric multipliers are only for small corrections after the mechanic is right.
6. Do not make a weak weapon acceptable by saying the player can ignore it. Every selectable weapon must have a real niche and a fair contribution to the class kit.
7. Do not weaken existing tests or balance gates to pass a task unless the task explicitly changes the product target and the rationale is documented.
8. Keep role boundaries: Back-end owns balance mechanics and tests; Design owns visuals; Animator owns motion. Create handoffs for other disciplines.

## Balance Axes

Use these axes unless the active task defines a stricter model:

- Solo: boss, elite, and durable single-target pressure.
- AoE: 5-target DPS plus crowd-clear time for 5, 10, and 20 targets.
- Defense: effective health, mitigation, dodge or shield windows, absorb, sustain, knockback, stagger, control, summon body-blocking, and other survival utility that exists in implementation.
- Kit identity: the three weapons must create different tactical rhythms, ranges, target patterns, risks, or payoff windows.

## Workflow

1. Inventory the class roster and three weapons per class from `ProgressionData.WEAPONS_BY_CLASS`.
2. Run or inspect the current reports from `tools/balance_harness.gd`, `tests/global_damage_balance_smoke_test.gd`, survivability harnesses, and live combat harnesses as appropriate.
3. Build a class-trio balance table: per class, aggregate all three weapons into solo, AoE, crowd-clear, defense, and total kit scores.
4. Classify each problem as a pair outlier, class-kit compensation case, class-wide missing axis, or class-wide overbudget.
5. Choose a mechanic-first correction when an axis is structurally missing or a weapon identity is not working.
6. Apply numeric tuning only after the mechanic has the right target pattern, risk, range, setup time, and defensive contribution.
7. Re-run focused tests and update the relevant design/system docs in the same task.
8. Leave an auditable Multica result: before/after tables, changed mechanics, commands run, reports generated, residual risk, and task-mirror notes.

## Default Commands

Run these after balance or weapon mechanic changes unless the task narrows validation:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_damage_balance_smoke_test.gd
```

Add survivability and live checks when touching defensive mechanics, sustain, mitigation, target pressure, real combat timing, or weapon scenes:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_survivability_balance_smoke_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/survivability_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/survivability_scenario_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/live_combat_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/live_balance_simulation_test.gd
```

## Result Contract

A completed balance task must report:

- Class-trio table before and after, with solo, AoE, crowd-clear, defense, and total kit scores.
- Per-weapon table before and after, explaining how each weapon contributes differently.
- Mechanical changes and why numeric tuning alone was not enough, or why numeric-only tuning was sufficient.
- Commands run and exact pass/fail results.
- Docs updated and any remaining playtest risk.
