# Persistence

Обновлено: 2026-06-14 (0.1.5)

## Settings

- Video, audio, input bindings, `aim_mode`, `debug_mode`, screen shake and
  last-seen patch notes version are saved by `scripts/game_settings.gd` to
  `user://settings.cfg`.
- Settings are loaded in `Main._ready()` before the main menu is shown and are
  applied immediately when changed in the settings screen.

## Meta Progression

- Long-term progression is saved by `scripts/meta_progression.gd` to
  `user://fantasydisk_meta.cfg`.
- The file stores meta points, unlocked Ascension levels and purchased skill-tree
  nodes. Combat-facing bonuses are applied at run start through
  `Main.apply_ascension_bonuses()` and player meta-skill hooks.
- SCRUM-621 adds Codex discovery state to the same persistent meta file:
  `discovered_monsters`, `discovered_bosses` and `discovered_artifacts`.
  Runtime records monsters and bosses when they are encountered/spawned in
  gameplay, and records artifacts when an artifact reward is actually applied.
  The lists are normalized, deduplicated and filtered against canonical
  Codex/ProgressionData ids; missing keys in old saves load as empty lists.

## Run Autosave

SCRUM-349 adds a separate autosave for the active run:

- Module: `scripts/run_autosave.gd`.
- Path: `user://fantasydisk_autosave.cfg`.
- Format: `ConfigFile`, schema-versioned with `RunAutosave.SCHEMA_VERSION`.
- Invalid, missing, corrupted or incompatible saves load as `{}` and are ignored.
- Save is atomic: runtime writes to `.tmp`, then renames over the active file.

Autosave is written only at safe map checkpoints, never mid-combat:

- after non-combat route elements via `RouteMapScreen._advance_route_after_noncombat()`;
- after leaving a shop via `_return_to_map_after_shop_visit()`, preserving
  current node-bound stock/purchased state until the next route node is chosen;
- after combat reward/attribute flow returns to the route map;
- after deferred/selected level-up rewards on map screens when the run state
  changed.

The saved dictionary contains the selected class/weapon/Ascension, route layout,
current `route_stage`, selected route branches, player snapshot
(`health`, `max_health`, stats, run modifiers, artifacts, XP/level/money),
pending level-up/attribute offers, used events, current shop stock and shop
re-entry state.

Main menu start checks `RunAutosave.has_run()`:

- `Продолжить` loads the snapshot into `Main` and opens the route map.
- `Новая игра` clears the autosave and enters fresh hero select.
- Victory and death screens clear the autosave immediately so completed runs are
  not offered again.

## Tests

- `tests/run_autosave_persistence_test.gd` covers round-trip, atomic save,
  overwrite, clear, corrupted file and incompatible schema behavior.
- `tests/runtime_smoke_test.gd` covers the user flow: save exists, main menu
  prompt appears, Continue restores route/snapshot state, New Game clears the
  save, and death/victory clear the save.
