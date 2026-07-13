# Technical Architecture

Обновлено: 2026-07-13 (0.2.1 quality/performance pass)

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
- `scripts/feedback_reporter.gd`: in-game feedback/bug-report delivery helper
  for explicitly configured Discord-compatible webhook sends plus checked
  `user://feedback/` local fallback reports. Client exports never contain a
  webhook credential; production network delivery requires a server-side relay.
- `scripts/scene_contracts.gd`: typed PackedScene instantiation boundary for
  configurable Node2D spawners; wrong-root scenes fail locally without a null
  dereference or orphan instance.

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

### Player lifecycle ownership (SCRUM-1071)

- A live combat has exactly one lifecycle generation: `CombatDirector._start_combat()`
  is always idempotent while a start is in progress. Once built, a repeated
  route/mouse/key/gamepad/dev-console trigger is ignored only when
  `combat_active` is backed by the owned current Player, matching generation
  metadata and a live combat HUD. A stale boolean after direct route teardown is
  normalized and cannot block the next RouteNode activation.
- Every full `Player.tscn` instance created by Main receives
  `player_lifecycle_owner` and `player_lifecycle_role`. Combat instances remain
  in `player`; stat-only menu snapshots use role `menu_snapshot`, group
  `temporary_players`, disabled processing/collision and a disabled `Camera2D`.
- `current_player` is a convenience reference, not the cleanup authority.
  `_clear_world()` finds every Player owned by that Main, removes it from groups
  and detaches it from the tree synchronously, then uses deferred `queue_free()`
  for signal-safe destruction. `_clear_ui()` performs the same central cleanup
  for temporary menu snapshots before pause/settings UI references are cleared.
- The focused invariant/stress gate is
  `tests/duplicate_player_spawn_regression_test.gd`: 50 new/continue transitions
  across battle/elite/boss starts, unresolved dossier snapshots, repeated start
  triggers, the stale-`combat_active` RouteMap gamepad-A boundary, process+physics
  frames, one Player/Camera/HUD/weapon and one handler per combat signal.

## Resource Loading

- Avoid `load()` in hot paths.
- Use preload/exported resources or local caches (`main._cached_texture`, `UIIconRegistry`).
- Missing optional Design assets may have safe fallback, but final active UI should use real PNG when available.

## Performance Guardrails

- HUD updates only when snapshot values change.
- Artifact HUD rebuilds only when artifact list changes.
- Enemy HP bars redraw only when HP changes.
- Avoid per-frame `get_node_or_null`/`get_nodes_in_group` in large enemy loops where cached references or limited scans are practical.
- `CombatTargetQuery.enemies()` owns the once-per-frame enemy-group snapshot;
  separation refreshes reuse it and keep at most four neighbors per enemy.
- Status hot paths use scalar reads (`StatusEffects.status_value`) rather than a
  deep snapshot; DoT method-signature introspection runs only when a tick is due.
- Route map builds once per open, not every frame.

## Tests

Unified required check:

```bash
python3 tools/quality_gate.py
```

It runs fast repository/Python guards plus an explicit reviewed Godot manifest,
including derived smoke suites that first-line discovery cannot see. CI runs
`--static-only`; local/release verification with the exact Godot 4.7 toolchain
runs the full profile. See `docs/process/code_quality_and_performance.md`.

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
- `tests/ui_no_overlap_matrix_test.gd` — SCRUM-483 UI render gate for headless
  1920x1080 / 2560x1440 / 3840x2160 screen passes, text allocation overflow,
  peer-control overlap, parent content containment and exact UI frame
  TextureRect no-stretch checks. The focused runner includes this standalone
  SceneTree test.
- `tests/melee_weapon_targeting_test.gd`;
- `tests/meta_progression_smoke_test.gd`.
- `tests/projectile_visual_registry_test.gd` — SCRUM-1066 manifest/registry
  integrity for all 17 classes and 51 weapons, 20 canonical projectile profiles,
  valid asset selection, 31 intentional non-projectile entries and fail-safe
  behavior for missing IDs.
- `tests/run_autosave_persistence_test.gd`.
- In-game feedback smoke is embedded in `tests/runtime_smoke_test.gd` and
  verifies the `P` action, overlay lifecycle, screenshot preview, local fallback
  files and multipart payload markers.
- SCRUM-454 adds a runtime regression inside `tests/runtime_smoke_test.gd` for
  paid random-event options: unaffordable `cost_money` choices must render
  disabled with an insufficient-gold tooltip, and direct activation must fail
  without mutating the run snapshot.

### Test-suite architecture audit (SCRUM-722)

Snapshot of the runtime-smoke architecture after the 0.2.0 refactor-wave pass.

- **Umbrella** `tests/runtime_smoke_test.gd` (~8k lines, 71 `_test_*` helpers) is the
  base class; every focused suite `extends` it and reuses its helper/assertion layer.
- **Single failure point.** All suites fail through one helper:
  `_fail(message, evidence_path := "")` — `push_error` + a deterministic evidence
  crumb at `build/qa/runtime_smoke_last_failure.md` (records the broken
  screen/system message and any caller-supplied evidence path) + `quit(1)`. The
  crumb is written only on failure, so green runs are unaffected. Naming the broken
  system in `message` is mandatory; assertions read like
  `_fail("Expected the settings backdrop in UI smoke.")`.
- **No raw fail triplets.** The legacy `push_error(...); quit(1); return` triplet was
  consolidated into `_fail(...); return` across the umbrella (400 sites). New
  assertions must call `_fail`, never re-introduce the raw triplet, so failure
  formatting/evidence stays centralised.
- **Bool integrity helpers** (`_assert_*` returning `bool`) keep their
  `push_error(...); return false` form on purpose — they report up to a caller that
  decides whether to `quit`, so they are intentionally excluded from `_fail`.
- **Determinism.** A small number of real-time `await create_timer(...)` waits remain
  where the test genuinely advances live simulation (combat/animation settling);
  these are load-sensitive and run serialized via `tools/godot_gate.py`. Prefer
  `await process_frame` / condition polling for new tests; only use timed waits when
  exercising real elapsed-time behaviour, and document why.
- **Python unit test** `tests/test_jira_board_sync.py` (4 cases) covers board-sync
  status mapping and is run with `python3 tests/test_jira_board_sync.py`.

Gate everything through the semaphore wrapper to avoid headless single-instance
crashes: `python3 tools/godot_gate.py --headless --path . --script res://tests/<suite>.gd`.

## Branching

Follow `docs/process/versioning_and_branching.md`:

- `main` = stable released `0.1.x` line;
- `dev` = active `0.2.x` working line; текущий sprint target — `0.2.1`;
- new feature work happens in `dev` unless explicitly stated otherwise.
