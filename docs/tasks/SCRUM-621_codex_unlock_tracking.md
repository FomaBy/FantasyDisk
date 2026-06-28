# SCRUM-621 - Codex Unlock Tracking

Status: Контроль качества (backend-loop-2 restart 2026-06-28).
Jira: SCRUM-621
Role: Backend/progression
Lane: Codex
Owner: backend-loop-2

## Scope

Track discovered monsters, bosses and artifacts so the runtime Codex can unlock
content from gameplay/progression without changing the Codex visual layout.

Locked paths:
- `scripts/meta_progression.gd`
- `scripts/main.gd`
- `scripts/combat_director.gd`
- `scripts/ui_screens.gd`
- `tests/codex_unlock_tracking_test.gd`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/systems/persistence.md`

## Result

- Cherry-picked `86806ed2 feat(SCRUM-621): track Codex discoveries` onto fresh
  `origin/dev`.
- Added persistent meta fields `discovered_monsters`, `discovered_bosses` and
  `discovered_artifacts`.
- Added normalized/deduplicated MetaProgression helpers for Codex discovery
  lookup and recording.
- Wired gameplay hooks to record monster/boss encounters and artifact rewards.
- Added canonical Codex id validation for monsters, bosses and artifacts.
  Unknown non-empty ids are ignored at record time and scrubbed during load/save
  normalization, closing the SCRUM-636 QA blocker.
- Kept Codex UI projection unchanged; this task only provides the unlock state.

## Verification

- PASS: `tests/codex_unlock_tracking_test.gd`.
- PASS: `tests/codex_data_smoke_test.gd`.
- PASS: `tests/run_autosave_persistence_test.gd` with isolated user data.
- PASS with known clean-import asset noise: `tests/meta_progression_smoke_test.gd`
  printed `Meta progression smoke test passed.` and exited 0.
