# Technical Architecture

Обновлено: 2026-06-11

Этот файл кратко описывает runtime architecture FantasyDisk для будущих Back-end задач.

## Main Modules

- `scripts/main.gd`: thin coordinator, shared run state, constants, delegated test-compatible methods.
- `scripts/ui_screens.gd`: menus, HUD, shop/event/rest, level-up, victory/death, shared UI styles.
- `scripts/route_map_screen.gd`: route generation/rendering, scroll/pan/click handling.
- `scripts/combat_director.gd`: combat lifecycle, spawn, arena, pickups, rewards.
- `scripts/player.gd`: character config, stats, weapon equip, damage, rewards.
- `scripts/enemy.gd`: enemy AI, contact damage, elite attacks, HP bars.
- `scripts/boss.gd`: boss patterns and victory flow.

## Data

- `scripts/progression_data.gd`: character, weapon, rewards, artifacts, shop, ascension.
- `scripts/stat_formulas.gd`: stat explanations and derived parameter formulas.
- `docs/design/content_registry.md`: canonical entity/asset IDs.

## Cleanup Conventions

Use groups for temporary runtime nodes:

- `enemies`, `bosses`, `summoned_enemies`;
- `projectiles`, `enemy_projectiles`, `enemy_hazards`;
- `pickups`;
- `player_weapons`, `player_weapon_effects`, `deployed_sound_amps`;
- `level_up_effects`, `arena_backgrounds`.

`_clear_world()` and transition flows must remove class-specific leftovers.

## Resource Loading

- Avoid `load()` in hot paths.
- Use preload/exported resources or local caches (`main._cached_texture`, `UIIconRegistry`).
- Missing optional Design assets may have safe fallback, but final active UI should use real PNG when available.

## Performance Guardrails

- HUD updates only when snapshot values change.
- Artifact HUD rebuilds only when artifact list changes.
- Enemy HP bars redraw only when HP changes.
- Avoid per-frame `get_node_or_null`/`get_nodes_in_group` in large enemy loops where cached references or limited scans are practical.
- Route map builds once per open, not every frame.

## Tests

Main checks:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Additional checks:

- `tests/animation_smoke_test.gd`;
- `tests/attack_vfx_smoke_test.gd`;
- `tests/melee_weapon_targeting_test.gd`;
- `tests/meta_progression_smoke_test.gd`.

## Branching

Follow `docs/process/versioning_and_branching.md`:

- `main` = stable `0.1`;
- `dev` = active `0.2`;
- new feature work happens in `dev` unless explicitly stated otherwise.
