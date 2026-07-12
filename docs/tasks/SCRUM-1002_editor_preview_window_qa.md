# SCRUM-1002 — Godot preview: launch in resizable windowed mode

Статус: done
Приоритет: p1
Роль: Back-end / QA
Версия: 0.2.1
Jira: SCRUM-1002
Контур: Codex
Owner: QA/Codex
Thread/Worker: `/root/audit_ready`
Implementation commit: `38139d5c`
QA base: `origin/dev` `35301aa4`
Locked paths: implementation read-only; this QA mirror only.

## Scope

Independently verify that a game launched by the installed Godot editor/runtime
on macOS ignores a persisted Fullscreen startup choice only for the editor
preview session. The preview must open as a normal bordered, resizable window,
fit the usable desktop, support edge resize and macOS zoom/restore, and leave the
persisted video settings unchanged. The exported/runtime settings path must
remain separate and continue to apply saved settings.

## Read-only implementation audit

- `38139d5c` is an ancestor of the tested `origin/dev` head.
- `scripts/main.gd::_load_game_settings()` routes editor-feature runs to
  `_apply_editor_preview_video_settings()` and non-editor/exported runs to
  `_apply_video_settings()`.
- `scripts/ui_screens.gd::_apply_editor_preview_video_settings()` selects
  `WINDOW_MODE_WINDOWED`, disables borderless mode, enables resize, selects the
  current screen, computes a 16:9 size inside the usable screen with a 96 px
  reserve, and centers the window.
- The preview helper does not mutate `resolution_index`, `window_mode_index`, or
  persist settings. The normal `_apply_video_settings()` path is unchanged.
- `tests/video_settings_apply_test.gd` covers the preview sizing calculation and
  proves that the saved resolution/window-mode indices are not rewritten.

## macOS Computer Use evidence

Executed 2026-07-09/10 EEST through Computer Use (`node_repl` + Sky) against the
installed binary `/Users/sergeyfomin/Downloads/Godot.app`, project window
`FantasyDisk (DEBUG)`, with isolated HOME/userdata under
`/tmp/fantasydisk-qa-scrum1002-userdata`.

| Check | Observation | Verdict |
| --- | --- | --- |
| Persisted configuration | `resolution_index=0` (2560x1440), `window_mode_index=2` (Fullscreen) | Loaded test precondition |
| Startup | Bordered macOS window with title-bar controls, `1280x752`; no fullscreen takeover or clipping | PASS |
| In-game Settings | Still displayed `2560x1440` and `Fullscreen` while the preview remained windowed | PASS |
| Edge resize | `1280x752` → `1052x650` | PASS |
| Zoom/maximize | `1052x650` → `1180x768` | PASS |
| Restore | `1180x768` → `1052x650` | PASS |
| Persistence | Settings SHA-256 remained `b91ac1a9da16fb2d6254c53ea0e8b02870bdb7042bbba2431973f9fd3eb37852`; mtime remained `2026-07-09 23:58:16 +0300`, size 381 bytes | PASS |

Temporary screenshots used during the live review:

- `01_windowed_start.jpg` — 1280x752 bordered startup.
- `02_saved_fullscreen_selection.jpg` — saved 2560x1440 + Fullscreen still shown.
- `03_edge_resized.jpg` — 1052x650.
- `04_zoom_maximized.jpg` — 1180x768.
- `05_zoom_restored.jpg` — 1052x650.

The screenshots were kept in the isolated QA userdata only and removed with the
disposable QA environment after the verdict; the measurements and hash above
are the committed evidence record.

## Automated verification

All commands ran through `python3 tools/godot_gate.py` with Godot 4.7 stable.

- `tests/video_settings_apply_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS; expected dummy-renderer null-texture
  warning appeared after the assertions and did not affect exit code 0.
- `tests/animation_smoke_test.gd` — PASS.
- `tests/meta_progression_smoke_test.gd` — PASS.
- `tests/melee_weapon_targeting_test.gd` — PASS.
- After fast-forwarding from QA base `2440529e` to current `origin/dev`
  `1d4eb8c5`, repeated `video_settings_apply_test.gd`,
  `animation_smoke_test.gd`, and `runtime_smoke_test.gd` — all PASS.
- After the final fast-forward to `35301aa4` (unrelated SCRUM-898 changes),
  repeated the two overlapping regression gates `runtime_smoke_test.gd` and
  `melee_weapon_targeting_test.gd` — both PASS.

## QA-Вердикт (2026-07-10)

Статус: PASSED

SCRUM-1002 acceptance criteria are satisfied on the latest tested `origin/dev`.
The editor preview starts windowed, bordered, resizable and fitted; resize and
zoom/restore work; the saved Fullscreen/2560x1440 choice is neither overwritten
nor lost; and the exported/runtime settings application path remains intact.
No production/runtime files were changed by QA. No follow-up bug is required.

Disk cleanup: remove the isolated userdata/evidence directory, generated
`.godot` cache, disposable worktree, and local QA branch after commit/push.
