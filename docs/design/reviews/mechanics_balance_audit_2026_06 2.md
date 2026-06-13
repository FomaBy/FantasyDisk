# Mechanics And Balance Audit — 2026-06

Дата: 2026-06-13  
Версия аудита: 0.1.4  
Источник: SCRUM-176 / `docs/tasks/audit_mechanics_balance_full.md`  
Scope: read-only audit; balance values and gameplay code were not changed.

## Harness Run

Command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
```

Result: passed, regenerated `build/balance_report.md`.

The generated report covers 17 classes x 3 weapons = 51 class/weapon pairs. After the current budget tuning model, all pairs are inside ±0.1% of their model targets. Before tuning, many raw weapon identities are far outside the target window, which means runtime balance depends heavily on `budget_damage_multiplier`.

## Model Summary

| Profile | Count | Avg Solo DPS | Avg 5T DPS | Avg EHP |
| --- | ---: | ---: | ---: | ---: |
| balanced | 27 | 44.55 | 145.75 | 163.2 |
| aoe | 15 | 40.53 | 202.57 | 93.0 |
| solo | 9 | 66.25 | 120.48 | 132.1 |

Reference targets:
- Base solo target: 48 DPS.
- Base 5-target target: 150 DPS.
- Window: 30 seconds.

## Important Outliers And Risks

### P1 — "After tuning" is too perfect to be sufficient gameplay proof

Evidence:
- `ProgressionData.weapon()` injects `budget_damage_multiplier`, `budget_solo_multiplier`, `budget_aoe_multiplier` into the returned weapon config (`scripts/progression_data.gd:2104-2114`).
- `derived_parameters()` multiplies damage by `budget_damage_multiplier` (`scripts/progression_data.gd:2117-2155`).
- The harness report states max combined deviation after tuning is 0.1%.

Impact:
- The harness proves that the budget model can normalize expected DPS, not that live combat feels balanced.
- Delay, target acquisition, enemy movement, overkill, projectile travel, blocked uptime, summon/deployable cleanup and player positioning are not fully represented by the deterministic hit-count model.

Required child task:
- Add a live-combat balance simulation harness that instantiates Player + enemies in deterministic scenes and measures actual damage/TTK over time.

### P1 — raw identity tuning has extreme spread before budget multiplier

Examples from `build/balance_report.md` before tuning:

| Class | Weapon | Solo Dev | 5T Dev |
| --- | --- | ---: | ---: |
| assassin | `venom_wire` | +61.5% | +283.9% |
| doctor | `plague_syringe` | +121.7% | -26.0% |
| engineer | `engineer_repair_drone` | -84.0% | -84.5% |
| robot | `robot_reactor_core` | -82.2% | -75.1% |
| berserk | `hammer` | -80.3% | -84.9% |

Impact:
- If any runtime path bypasses `ProgressionData.weapon()` or ignores the tuning fields, some weapons become broken immediately.
- Even with tuning, feel can diverge: a low raw weapon boosted by x2.8 may still be sensitive to missed uptime, while high raw DoT/chain weapons may overperform in dense scenes.

Required child task:
- Add regression tests that instantiate every weapon from `ProgressionData.weapon()` and assert the tuning fields are applied in live `derived_parameters`.

### P2 — survivability model is useful but simplified

Evidence:
- EHP formula in harness: `HP / (1-defense) / (1-dodge) + absorb*10 + regeneration*30 + lifesteal estimate`.
- Runtime damage uses dodge/defense/absorb/regeneration in `player.gd` and vampiric healing budget (`scripts/player.gd:378-393`, `scripts/player.gd:527-544`).

Risk:
- EHP does not model incoming projectile density, contact damage cooldowns, elite/boss burst, player movement speed, crowd control, or class-specific avoidance windows.
- Current EHP spread is large by design: dark mage 65.6, robot/knight >236. That may be acceptable if damage budget compensates, but needs live survival scenarios.

Required child task:
- Add deterministic survival scenarios: contact swarm, projectile crossfire, elite burst, boss phase attack.

### P2 — economy target is close but XP tempo is below requested +10-15% range

Evidence from generated report:
- Expected gold: +21.7%.
- Effective buying power after 1.10x costs: +10.6%.
- Expected XP: +7.1%.
- XP curve changed from `ceil(req*1.35+2)` to `ceil(req*1.42+3)`.

Assessment:
- Buying power matches target.
- XP tempo is intentionally guarded but below the requested +10-15% economy task range. This should be reviewed after live combat pacing because slower XP plus harder enemies can make level-up choice cadence feel thin.

Required child task:
- Re-run economy/XP simulation with actual route mixes and measured kill counts, then decide whether XP should move from +7.1% toward +10%.

### P2 — class identity is broad, but several patterns still share helper families

Evidence:
- 51 weapons map to many `attack_mode` entries in `progression_data.gd`.
- Runtime still executes all non-Berserk modes through one `ClassWeapon` script.

Risk:
- Classes can look different while sharing too much targeting/damage semantics.
- Deployable/summon-like modes (`sound_amp`, traps, raven totem, homunculus, engineer devices) need live cleanup and max-count stress tests.

Required child task:
- Add a mechanics identity review test matrix: for each class, assert its core weapon modes use distinct runtime mode ids, target geometry, damage type tags and cleanup groups.

## Current 51 Pair Table

Full before/after rows are in `build/balance_report.md`. This audit treats that generated file as the canonical metric attachment for SCRUM-176.

High-level result:
- 51/51 model-normalized pairs are inside the target window after tuning.
- 36+ raw weapon rows were outside target before tuning; several were extreme.
- No direct numeric balance change was made in this audit.

## Proposed Child Tasks

Created in `docs/tasks/`:

1. `backend_balance_live_combat_harness_task.md`
2. `backend_balance_survivability_scenarios_task.md`
3. `backend_balance_economy_xp_live_route_model_task.md`
4. `backend_balance_weapon_tuning_application_regression_task.md`
