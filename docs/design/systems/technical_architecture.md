# Technical Architecture

Обновлено: 2026-06-14 (0.1.5)

Этот файл кратко описывает runtime architecture FantasyDisk для будущих Back-end задач.

## Main Modules

- `scripts/main.gd`: thin coordinator, shared run state, constants, delegated test-compatible methods.
- `scripts/ui_screens.gd`: menus, HUD, shop/event/rest, level-up, victory/death, shared UI styles.
- `scripts/ui/hero_stat_radar.gd`: reusable hero-select stat radar control.
- `scripts/ui/ui_theme_paths.gd`: dark-fantasy theme texture path registry.
- `scripts/ui/shop_ui_constants.gd`: shop icon/slot/cursor UI constants.
- `scripts/ui/hero_select_constants.gd`: hero-select radar stats and class colors.
- `scripts/route_map_screen.gd`: route generation/rendering, scroll/pan/click handling.
- `scripts/combat_director.gd`: combat lifecycle, spawn, arena, pickups, rewards.
- `scripts/player.gd`: character config, stats, weapon equip, damage, rewards.
- `scripts/enemy.gd`: enemy AI, contact damage, elite attacks, HP bars.
- `scripts/boss.gd`: boss patterns and victory flow.
- `scripts/full_frame_animation_registry.gd`: optional SpriteFrames registry and
  state adapter for full-frame hero/enemy/ally/elite/boss animation fallback.
- `scripts/run_autosave.gd`: active-run persistence helper for safe route
  checkpoint autosaves (`user://fantasydisk_autosave.cfg`), with schema checks
  and atomic `.tmp` writes.

`scripts/class_weapon.gd` owns non-Berserk class weapon runtime behavior. SCRUM-196
replaced the old long `attack_mode` dispatch match with `ATTACK_MODE_EXECUTORS`,
a public registry that maps data-driven weapon modes to executor wrappers while
preserving existing `_fire_*` mechanics and cleanup contracts.

## Data

- `scripts/progression_data.gd`: compatibility facade for public data/API used by runtime, tests, and older systems.
- `scripts/progression_data_characters.gd`: base stats, character configs, class interpretations, ultimate configs.
- `scripts/progression_data_weapons.gd`: 51 class/weapon definitions and `WEAPONS_BY_CLASS`.
- `scripts/progression_data_content.gd`: stat rewards, artifacts, level-up reward pools.
- `scripts/progression_data_shop.gd`: shop item data.
- `scripts/progression_data_ascension.gd`: ascension levels, run difficulty modifiers, per-level metadata.
- `scripts/progression_data_balance.gd`: balance budgets, stage scaling, economy/XP/drop constants.
- `scripts/progression_data_enemies.gd`: enemy-side data slices such as mini-elite kinds.
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

Main umbrella check:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Focused runtime smoke suites (SCRUM-202) reuse the umbrella helper/assertion layer and are intended for faster refactor regression checks:

- `tests/runtime_smoke_ui_test.gd` — menus, settings, Codex, hero/weapon UI, no-overlap/HUD/shop layout.
- `tests/runtime_smoke_combat_test.gd` — combat startup, arena, HUD, player/enemy/projectile damage, health bars, death flow.
- `tests/runtime_smoke_progression_economy_test.gd` — rewards, artifacts, settings persistence, attribute wiring, economy/FAB, ascension.
- `tests/runtime_smoke_weapon_mechanics_test.gd` — character/weapon configs, all variants equip, class weapon mechanics, aiming, ultimate.
- `tests/runtime_smoke_boss_elite_test.gd` — elite flow, elite attacks, boss HUD, boss/mini-elite rosters, victory flow.

Weapon smoke also checks that every non-Berserk weapon config with an
`attack_mode` has a registered `ClassWeapon` executor, so newly added weapon
modes fail fast in tests instead of falling through silently at runtime.

Additional checks:

- `tests/animation_smoke_test.gd`;
- `tests/attack_vfx_smoke_test.gd`;
- `tests/melee_weapon_targeting_test.gd`;
- `tests/meta_progression_smoke_test.gd`.
- `tests/run_autosave_persistence_test.gd`.

## Branching

Follow `docs/process/versioning_and_branching.md`:

- `main` = stable `0.1`;
- `dev` = active `0.1.x` working line; текущий sprint target — `0.1.5`;
- new feature work happens in `dev` unless explicitly stated otherwise.
