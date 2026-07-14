# Balance Workflow

Follow this workflow for class, weapon, progression, or defensive balance tasks.

## 1. Scope

Identify the affected classes, weapons, and mechanics:

- Read the active Multica issue and task-mirror context.
- Confirm current branch is `dev`.
- Inspect `scripts/progression_data_weapons.gd`, `ProgressionData.WEAPONS_BY_CLASS`, and any relevant weapon scenes/scripts.
- Check whether the change affects damage, target count, crowd-clear, survival, control, scaling, or live combat timing.

## 2. Baseline

Run or inspect the latest balance reports before editing when feasible:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_damage_balance_smoke_test.gd
```

For defense or sustain:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_survivability_balance_smoke_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/survivability_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/survivability_scenario_test.gd
```

For real combat behavior:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/live_combat_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/live_balance_simulation_test.gd
```

## 3. Class-Trio Table

Build a table with one row per class and at least these columns:

```text
class_id | weapon_ids | solo_score | aoe_score | crowd_score | defense_score | total_score | diagnosis
```

Also keep a per-weapon table:

```text
class_id | weapon_id | solo_ratio | aoe_ratio | crowd_ratio | defense_ratio | identity | problem
```

The class table decides balance. The per-weapon table explains why.

## 4. Diagnosis

Use this decision tree:

1. If a weapon is low on one axis but high on another, preserve the tradeoff if it is fun and readable.
2. If one weapon is low on every axis, give it a real mechanic or niche before tuning numbers.
3. If all three weapons are low on the same axis, the class kit has a missing axis. Add or reshape mechanics in at least one weapon.
4. If all three weapons are high on the same axis, the class kit is overbudget. Add tradeoffs, falloff, cooldown, setup cost, or reduce stacked multipliers.
5. If one weapon is high on every axis, reduce universality rather than only lowering damage.
6. If class total is off but individual pair tests pass, adjust the trio model, class budget profile, or mechanics so the full kit aligns.

## 5. Change Order

Prefer this order:

1. Mechanic shape: target pattern, hit cadence, projectile behavior, area shape, range, duration, summon behavior, control, or defensive window.
2. Scaling shape: stat interactions, cooldown scaling, ramping, falloff, target cap, or proc conditions.
3. Numeric tuning: `budget_tuning`, `budget_damage_multiplier`, `budget_solo_multiplier`, `budget_aoe_multiplier`, cooldown, damage, duration, and caps.

Use numeric-only tuning only when the mechanic is already correct and the gap is small.

## 6. Documentation

Update relevant docs in the same task:

- `docs/design/mechanics_extract.md` for formulas, class balance, or system behavior.
- `docs/design/current_game_state.md` for implemented state and reports.
- `docs/design/systems/progression_balance.md` for balance harnesses and budget model.
- `docs/design/systems/characters_weapons.md` for class or weapon roster behavior.
- `docs/design/systems/combat.md` for combat mechanics and runtime behavior.

Use Multica evidence rules from the repo, and leave a short before/after result in the task mirror.
