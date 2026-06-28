# SCRUM-654 - Level Up: one compact overhead badge

Jira: SCRUM-654
Role: backend/UI runtime
Status: review

Locked paths:
- `scripts/level_up_effect.gd`
- `scripts/ui_screens.gd`
- `tests/level_up_effect_duration_test.gd`
- `tests/runtime_smoke_ui_test.gd`
- `docs/design/current_game_state.md`
- `docs/design/systems/menus_ui.md`
- `docs/design/mockups/scrum654_level_up_badge/spec.md`

Result:
- Reduced `LevelUpEffect.BADGE_DISPLAY_SIZE` from `224x112` to `160x80`.
- `_spawn_level_up_effect()` now removes older live nodes in the `level_up_effects` group before creating the next one.
- Kept `LevelUpToast` textless; no duplicate procedural `Label` is introduced.
- Added focused assertions for compact badge size and single live effect.

Tests:
- PASS: `tests/level_up_effect_duration_test.gd`
- PASS: `tests/level_up_toast_smoke_test.gd`
- PASS: `tests/runtime_smoke_ui_test.gd`
