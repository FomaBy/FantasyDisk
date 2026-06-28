# SCRUM-621 - Codex unlock tracking

РЎС‚Р°С‚СѓСЃ: done 2026-06-28. Result: persistent Codex unlock tracking implemented and ready for QA.
Jira: SCRUM-621
Role: Backend/progression
Lane: Codex
Branch: `codex/scrum-621-codex-unlock-tracking`
Worktree: `D:\FantasyDisk_worktrees\scrum-621-codex-unlock-tracking`

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

- Added persistent meta fields `discovered_monsters`, `discovered_bosses` and
  `discovered_artifacts`.
- Added normalized/deduplicated MetaProgression helpers for Codex discovery
  lookup and recording.
- Wired gameplay hooks to record monster/boss encounters and artifact rewards.
- Kept Codex UI projection unchanged; this task only provides the unlock state.

## Verification

- `tests/codex_unlock_tracking_test.gd` covers default state, duplicate
  handling, invalid categories, save/load roundtrip and malformed save
  normalization.

## Backend-loop-2 restart: QA blocker fix (2026-06-28)

Claimed from Jira after auto-claim returned none because SCRUM-621 has no
`backend` label but is backend/progression scope.

Changes on top of the feature-branch implementation:
- Cherry-picked `86806ed2 feat(SCRUM-621): track Codex discoveries` onto fresh
  `origin/dev`.
- Added canonical Codex id validation in `MetaProgression` for monsters,
  bosses and artifacts. Unknown non-empty ids are now ignored at record time
  and scrubbed during load/save normalization, closing the SCRUM-636 QA blocker.
- Extended `tests/codex_unlock_tracking_test.gd` with unknown monster/boss/
  artifact ids in both runtime state and malformed saved data.

Verification in
`C:\Users\FomaE\OneDrive\Documents\FantasyDisk_agents\backend_loop_2_20260628210405`:
- PASS: `tests/codex_unlock_tracking_test.gd`.
- PASS: `tests/codex_data_smoke_test.gd`.
- PASS: `tests/run_autosave_persistence_test.gd` with isolated user data.
- PASS with known clean-import asset noise: `tests/meta_progression_smoke_test.gd`
  printed `Meta progression smoke test passed.` and exited 0.
