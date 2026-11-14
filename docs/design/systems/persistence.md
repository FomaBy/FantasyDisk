# Persistence

Обновлено: 2026-06-14 (0.1.5)

## Settings

- Video, audio, input bindings, `aim_mode`, `debug_mode`, screen shake and
  last-seen patch notes version are saved by `scripts/game_settings.gd` to
  `user://settings.cfg`.
- Settings are loaded in `Main._ready()` before the main menu is shown and are
  applied immediately when changed in the settings screen.
- Audio defaults are intentionally silent for new profiles: `music_enabled` and
  `sfx_enabled` start as `false`, while master/music/SFX slider values stay at
  `1.0` so the player can restore sound by enabling the category toggles.

## Meta Progression

- Long-term progression is saved by `scripts/meta_progression.gd` to
  `user://fantasydisk_meta.cfg`.
- `save_state()` returns `bool`. The shared `scripts/atomic_config_file.gd`
  writer writes a same-directory `.tmp`, reloads it and compares every section,
  key and value, then moves the primary to `.bak` and the temporary file to the
  primary. Replacement never relies on renaming over an existing destination.
  Meta progression retains the previous committed good generation in `.bak`;
  failed placement attempts rollback, and a failed rollback leaves that backup
  available to the loader. This provides process-interruption recovery, not a
  guarantee against filesystem or hardware failure that loses buffered writes.
- Loading prefers a valid primary, then `.bak`, then a valid `.tmp` only when
  neither committed generation is usable (including an interrupted first save).
  A valid meta file must parse and contain `[meta]`; empty files, non-config text,
  parse errors and missing sections are damage. Existing key defaults, schema 6
  and all migrations are unchanged. Syntactically valid legacy files with missing
  keys still use their existing defaults.
- Damaged files encountered during recovery are moved to `.corrupt`, then
  `.corrupt.1`, `.corrupt.2`, etc.; earlier copies are never overwritten. If no
  recovery source works, defaults start only after attempting preservation.
  Saving validates the primary and backup again and refuses to overwrite damage
  if preservation fails. A sole valid temporary file is promoted before writing
  another temporary file, so a failed retry cannot destroy that recovery source.
- `Main.save_meta_progression()` returns the save result, retains in-memory
  progress on failure and logs the failure once per Main instance. Gameplay can
  retry on its next ordinary save event.
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
- Save uses the same verified `.tmp` / `.bak` replacement helper. Unlike permanent
  progression, a successful run save removes its backup, preserving the existing
  run lifecycle and clear behavior. Interrupted replacements still load `.bak`.

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

SCRUM-976 adds gameplay-sandbox persistence without changing the autosave schema
version. Five validated multipliers live in `user://settings.cfg`, while
`Main.begin_new_run_session()` copies them into a separate immutable
`run_sandbox_snapshot` at the weapon-confirm boundary. Safe checkpoints persist
that active snapshot; Continue restores it, and legacy autosaves with no field
normalize to neutral `1.0`. Resetting Settings is atomic and changes only the
configured values for the next run, never an active or restored run.

SCRUM-996 (event reveal / event shop) deliberately adds **no** new autosave
fields. The event outcome is applied to the in-memory run snapshot when the
choice is pressed, but the autosave is still written only at the next map
checkpoint (`_advance_route_after_noncombat`, reached by confirming the reveal
via `EventContinueButton` or by leaving an event `shop_after` shop). Quitting
the game during the reveal state or inside an event shop therefore rolls back
to the last autosave: the run re-enters the same unresolved event
(`current_event_definition` is part of the snapshot, SCRUM-530 — no reroll) and
the outcome/purchases made after the last checkpoint are discarded. This is the
intended contract, not a bug. `Main.event_shop_exit_action` (the deferred
event-shop exit) is runtime-only and is reset on autosave restore, act
transition, run end and new run.

Main menu start checks `RunAutosave.has_run()`:

- `Продолжить` loads the snapshot into `Main` and opens the route map.
- `Новая игра` clears the autosave and enters fresh hero select.
- Victory and death screens clear the autosave immediately so completed runs are
  not offered again.

## Tests

- `tests/meta_progression_atomic_save_test.gd` covers legacy 0.3.1.2 bytes/state,
  round-trip and backup rotation, damaged-primary recovery with/without backup,
  unique quarantine, interruption boundaries including the first save, observable
  write/rotation failures and Main's in-memory retry. The legacy fixture and full
  expected state were generated with commit `9a19870a15d71bc2b63e622c7895519bd84dafb4`.
- Every automated save/migration test must use a fresh scratch HOME and platform
  data directories as well as an explicit scratch `--user-data-dir`. The atomic
  and schema-6 migration suites refuse a user-data directory outside that root.
  `tools/quality_gate.py` supplies per-suite isolation; direct runs through
  `tools/godot_gate.py` must supply the same environment and user argument.
- `tests/run_autosave_persistence_test.gd` covers round-trip, atomic save,
  overwrite, clear, corrupted file and incompatible schema behavior.
- `tests/runtime_smoke_test.gd` covers the user flow: save exists, main menu
  prompt appears, Continue restores route/snapshot state, New Game clears the
  save, and death/victory clear the save.
- `tests/gameplay_sandbox_scrum976_test.gd` covers settings persistence,
  immutable active snapshots, autosave round-trip and next-run reset semantics.

## Settings schema audit (SCRUM-720)

`game_settings.gd` is schema-disciplined and forward/backward compatible:

- `load_settings()` starts from `DEFAULTS`, reads each known key with a default
  fallback, then **normalises every value** (clamp `resolution_index` to
  `MAX_RESOLUTION_INDEX`, clamp volumes to `0..1`, coerce bools, whitelist
  `aim_mode ∈ {nearest, cursor}`, guard `input_bindings` to a `Dictionary`). A
  missing/older config therefore loads cleanly with defaults; unknown future keys
  are ignored (not persisted back), so the on-disk schema stays bounded.
- `save_settings()` writes only `DEFAULTS` keys and back-fills `master_zero_intent`
  from `master_volume` — the SCRUM-deliberate "muted on purpose vs accidental 0"
  distinction is preserved across load/save.
- `display_resolution.gd` helpers are pure (HiDPI fit/clamp computed from passed
  usable-rect + scale, no `DisplayServer` calls) and remain unit-testable headless.
