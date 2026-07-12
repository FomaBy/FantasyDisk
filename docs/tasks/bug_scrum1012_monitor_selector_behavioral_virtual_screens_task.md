# SCRUM-1012 — Behavioral virtual multi-screen coverage for Settings

Статус: done
Приоритет: p1
Роль: Back-end (UI behavior/testability)
Версия: 0.2.1
Jira: SCRUM-1012
Контур: Codex
Owner: Backend/Codex
Thread/Worker: `/root/audit_ready`
Branch: `codex/scrum-1012-monitor-selector-behavior`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1012-monitor-selector-codex-20260710`
Locked paths: `scripts/display_resolution.gd`; monitor-option adapter/call-site only in `scripts/ui_screens.gd`; `tests/display_resolution_test.gd`; `tests/monitor_selector_behavior_test.gd`; this mirror; scoped `docs/process/jira_sync_map.json` if changed.

## Context

Independent QA of SCRUM-973 found a false-green: the focused monitor selector
test asserted multi-monitor count/order/labels by searching source text with
`source.contains(...)` / `source.find(...)`, rather than exercising an actual
virtual monitor option model. Headless CI therefore could not detect a broken
multi-monitor option collection.

SCRUM-1002 is QA PASSED / Jira `Готово`; its read-only lock on
`scripts/ui_screens.gd` is released. Existing Settings v5 and SCRUM-674
mockup/spec remain the visual contract. This task changes no art, frame,
content-zone, control bounds, or layout.

## Architecture

- Add pure `DisplayResolution.sanitize_screen_index(screen_sizes,
  requested_index)` and `DisplayResolution.monitor_options(screen_sizes,
  requested_index)` helpers.
- Add `_current_monitor_sizes()` as the only `DisplayServer` adapter used by the
  Settings monitor-option call-site.
- Have the runtime selector consume the returned option model for visibility,
  exact ordered labels, selected index and stale-index fallback.
- Replace source-string assertions in the focused test with behavioral virtual
  one-screen, three-screen and zero/disappeared-screen cases.
- Preserve pending Apply/Revert, persistence/restart, 2560x1440 + 1920x1080
  policy, window modes, and all existing UI bounds.

## Acceptance Criteria

- One virtual screen returns a hidden selector model.
- Three virtual screens return exactly three ordered labels in the form
  `Экран N (WxH)` and the clamped selected index.
- Negative, oversized, disappeared and zero-screen requests fall back safely.
- Runtime Settings uses the pure option model via the DisplayServer adapter.
- Apply/Revert/persistence/restart remain behavioral assertions.
- Focused monitor/display/settings/video/UI/runtime/animation/meta/melee gates
  requested in the Jira handoff pass through `tools/godot_gate.py`.
- Result is pushed to `origin/dev` and handed to independent QA; SCRUM-973 stays
  blocked until this bug passes that QA.

## Visual Contract

- Settings v5: `docs/design/settings_v5_vision.md` and
  `docs/design/settings_v5_verification.md`.
- Pending Apply/Revert: `docs/design/mockups/scrum674_settings_ui/spec.md`.
- No new mockup or PixelLab generation is required because the user/dispatcher
  explicitly constrained this fix to behavior/testability without layout/art
  changes.

## Result

- Added pure `DisplayResolution.sanitize_screen_index(screen_sizes,
  requested_index)` and `monitor_options(screen_sizes, requested_index)`.
  The returned model owns selector visibility, clamped selection and exact
  ordered `{index, size, label}` options.
- Added `_current_monitor_sizes()` as the narrow `DisplayServer` adapter.
  `_show_settings_menu()` now consumes `_settings_monitor_model(...)`; labels
  and selected index are no longer assembled independently in the UI call-site.
- Replaced `source.contains(...)` / `source.find(...)` proof in
  `monitor_selector_behavior_test.gd` with behavioral one-screen, three-screen,
  disappeared-screen, negative/oversized-index and zero-screen cases.
- Exact three-screen labels/count/order/selected index, real adapter ordering,
  pending dirty state, Apply/Revert, save/restart and the 2K/FHD policy are
  asserted.
- Settings v5 layout, frame content zones, control bounds, window modes and all
  other video behavior are unchanged. Product docs already describe the same
  user-visible contract; this mirror records the new testable architecture.

## Verification

All commands ran through `python3 tools/godot_gate.py` with Godot 4.7. The full
matrix was repeated after fast-forwarding to `origin/dev` `5d584a76`.

- `tests/monitor_selector_behavior_test.gd` — PASS.
- `tests/display_resolution_test.gd` — PASS.
- `tests/game_settings_smoke_test.gd` — PASS.
- `tests/video_settings_apply_test.gd` — PASS.
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/gamepad_menu_focus_test.gd` — PASS.
- `tests/gamepad_settings_rebind_test.gd` — PASS.
- `tests/aim_mode_settings_test.gd` — PASS; existing FakeOwner signature script
  warning is emitted by the test fixture after its assertions.
- `tests/runtime_smoke_test.gd` — PASS; existing dummy-renderer null-texture
  capture warning is non-fatal after assertions.
- `tests/animation_smoke_test.gd` — PASS.
- `tests/meta_progression_smoke_test.gd` — PASS.
- `tests/melee_weapon_targeting_test.gd` — PASS.

## Handoff

Ready for independent QA in Jira `Контроль качества`. SCRUM-973 remains blocked
until SCRUM-1012 receives that independent QA verdict; this executor does not
self-QA.

Disk cleanup: remove generated `.godot` cache and the disposable worktree after
commit/push/Jira handoff.
