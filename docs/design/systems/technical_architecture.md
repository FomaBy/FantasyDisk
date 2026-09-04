# Technical architecture

Updated: 2026-09-05. Measured at `a53a521604cd7ab7137733838cdda11b3efaf71e`. The checkout contains 1,028 GDScript/Python source and test files. This is a runtime map, not a substitute for source or a work-ownership lease.

## Runtime components

| Component | Responsibility | Lines at recorded baseline |
| --- | --- | ---: |
| `scripts/main.gd` | run coordinator and shared state | 1,842 |
| `scripts/route_map_screen.gd` | route generation and map interaction | 1,574 |
| `scripts/combat_director.gd` | combat lifecycle, spawning, arena/rewards | 1,493 |
| `scripts/player.gd` | player configuration, stats, equipment, damage | 4,295 |
| `scripts/enemy.gd` | enemy AI, contact damage, elites, HP bars | 1,950 |
| `scripts/boss.gd` | boss patterns and victory | 1,041 |
| `scripts/ui_screens.gd` | UI inheritance facade | 50 |
| `scripts/class_weapon.gd` | non-Berserk weapon inheritance facade | 46 |
| `scripts/full_frame_animation_registry.gd` | optional full-frame visual registry | 405 |

The UI and class-weapon figures show physical inheritance-chain splits, not independent components: their `scripts/ui/screens/**` and `scripts/classes/**` modules still share facade, state, virtual API, and ordering contracts.

`progression_data.gd` is a compatibility facade over data slices; `docs/design/content_registry.md` remains the canonical entity/asset-ID index. `run_autosave.gd` owns schema-checked atomic active-run checkpoints; `feedback_reporter.gd` uses local fallback and requires a server relay for production delivery; `scene_contracts.gd` validates configurable Node2D instantiation boundaries.

## Runtime invariants

- Temporary world nodes use established groups (`enemies`, `bosses`, `projectiles`, `enemy_projectiles`, `enemy_hazards`, `pickups`, `player_weapons`, `player_weapon_effects`, `level_up_effects`, and `arena_backgrounds`) and transition ownership cleans them up.
- Combat owns one current player lifecycle generation. Menu snapshots are disabled temporary `menu_snapshot` instances; `current_player` is never cleanup authority.
- Preserve canonical IDs, save compatibility, balance values, public facade APIs, and observable random-number ordering.
- Avoid hot-path synchronous loading and repeated group scans. Use bounded caches/snapshots with an owner and teardown rule; a Windows performance claim requires a native release profile with baseline and frame-time evidence.

## Verification

Run focused Godot suites through `tools/godot_gate.py`. The static guard and certifying profiles are documented in `docs/process/code_quality_and_performance.md`; use the profile appropriate to risk, never remove an assertion or raise a ratchet to hide a regression. New GDScript requires `.gd.uid`.

The later FD02 inventory tool is intentionally not created by this documentation card. Link its machine-readable report here when it exists; until then, repeat the recorded source-count command against the candidate base.
