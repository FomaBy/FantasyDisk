# SCRUM-974 — Settings Audio: useful options without clutter

Статус: done
Версия: 0.2.1
Jira: SCRUM-974
Контур: Codex
Owner: Backend+UI/Codex `/root`
Thread/Worker: `root-next7`
Branch: `codex/scrum974-settings-audio`

## Scope And Locks

Settings Sound hunk in `scripts/ui_screens.gd`; SCRUM-974-specific audio
settings/runtime changes in `scripts/game_settings.gd`, `scripts/main.gd` and
`scripts/audio_manager.gd`; focused tests; SCRUM-974 mockup/reference evidence;
this mirror and related Settings/audio/current-state documentation. Existing
audio/visual assets and unrelated Settings tabs are read-only.

## Baseline

Metal captures at 1280×720, 1920×1080 and 2560×1440 show three volume rows and
Reset with ample room at 1080p/2K but insufficient safe height for naïvely
stacking three more full rows at 720p. Current runtime has only Master, Music and
SFX buses; low-HP pulse exists on SFX; no dynamic music layer or separate
ambience stream exists.

## Architecture

Implement `ui_volume`, `mute_when_unfocused` and
`low_hp_warning_enabled` exactly as specified in
`docs/design/mockups/scrum974_settings_audio/spec.md`. Use `UI -> SFX -> Master`
to preserve existing SFX semantics, separate requested/effective low-HP loop
state, and use two compact option rows inside a follow-focus `AudioScroll`. No
placeholder controls.

## UI Director gate

- Baseline Metal matrix captured before runtime edits.
- Plan validation: `ready_for_image`, no errors/warnings.
- Accepted PixelLab MCP source: `11178250-472a-4f22-84bf-85f1e45d8ea7`;
  rejected v1/v3 evidence and the exhausted-credit v4 result are documented in
  spec/provenance.
- `settings_audio_fit_report.json`: all native zones fit; final compositor debug
  review confirms text is disjoint from crest/tab/track/toggle/frame ornament.
- UI Director gate passed; runtime implementation is unblocked.

Disk cleanup: active task worktree; pending final gates and push.

Thread cleanup: not a disposable worker thread.

## Implementation Result

- Added persisted `ui_volume` (default `1.0`), `mute_when_unfocused`
  (default `false`) and `low_hp_warning_enabled` (default `true`).
- Added the real `UI -> SFX -> Master` bus chain. Only `ui_click`, `ui_back`
  and `ui_error` route to UI; economy, reward and gameplay cues stay on SFX.
- Application focus-out can hard-mute Master without changing the saved volume;
  focus-in restores it. The low-HP warning keeps requested/effective loop state
  separate, so disabling it stops the pulse and re-enabling it while HP remains
  low resumes the pulse immediately.
- Sound now uses four volume rows, two compact backed toggle rows and Reset in a
  vertical-only follow-focus `AudioScroll`. Reset restores all eight audio keys.
  The scrollbar is visible/reachable only at 1280×720 and hidden at
  1920×1080 / 2560×1440.

## Verification

PASS with isolated `HOME`, `XDG_DATA_HOME` and `user://` roots:

- `tests/settings_audio_scrum974_test.gd`;
- `tests/settings_audio_scrum974_ui_test.gd`, headless and Metal windowed at
  1280×720, 1920×1080 and 2560×1440;
- `tests/game_settings_smoke_test.gd`;
- `tests/audio_manager_smoke_test.gd`;
- `tests/audio_integration_test.gd`;
- `tests/audio_qa_969_test.gd`;
- `tests/runtime_smoke_ui_test.gd`;
- `tests/ui_no_overlap_matrix_test.gd`;
- `tests/gamepad_menu_focus_test.gd`;
- `tests/gamepad_settings_rebind_test.gd`;
- `tests/gamepad_full_flow_smoke_test.gd`;
- full `tests/runtime_smoke_test.gd`.

Metal captures in transient `build/qa/scrum974/` were visually inspected: all
controls stay inside the empty Settings content zone and remain disjoint from
the footer/frame ornament; compact Reset is revealed by focus-scroll. The known
dummy-renderer null-texture diagnostic remains non-fatal.

Commit/push and independent production QA: pending.
