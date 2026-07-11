# SCRUM-972 — Settings seamless content surface

Статус: done
Версия: 0.2.1
Jira: SCRUM-972
Контур: Codex
Owner: Backend+UI/Codex `/root`
Thread/Worker: `root-next6`
Branch: `codex/scrum972-settings-seamless-content`

## Scope And Locks

Only the Settings content-surface style hunk in `scripts/ui_screens.gd`, a new
focused test, SCRUM-972 mockup/reference evidence, this mirror and Settings
system/state paragraphs are writable. Existing frame/tab/field/action/slider/
checkbox/icon assets, all Settings geometry and unrelated screens are read-only.

## Baseline

Windowed Metal matrix captures at 1280×720, 1920×1080 and 2560×1440 confirm the
opaque `_atlas_chip_style(0.88)` surface and gold edge form a distracting second
frame below the tab row. Existing controls are readable and frame-safe; this is
a surface-layer problem, not a layout or behavior defect.

## Architecture

Keep `SettingsContentPanel` as the responsive/clip owner but give it a fully
transparent `StyleBoxFlat` with the same content margins and zero border. This
removes the gray rectangle without reparenting controls or weakening the global
outer-frame safe zone. No asset or content geometry changes.

## UI Director gate

- Current Metal baseline captured before runtime edits.
- `ui_plan.report.json`: `ready_for_image`, no errors or warnings.
- Accepted PixelLab MCP page layer:
  `64eb22c0-35d0-41de-863c-e368c0e7da6f`; source/provenance are under
  `docs/design/references/scrum972_settings_seamless_content/`.
- `settings_seamless_fit_report.json`: all eight native content zones fit;
  visual debug-overlay review confirms no content/frame overlap.
- Runtime implementation is now unblocked.

## Result

- `SettingsContentPanel` keeps its responsive width, clipping and positive
  content margins but draws no fill or border.
- The hidden `SettingsTabs` inherited panel is also transparent; its original
  theme margins are copied before the override, so native tab layout is stable.
- Existing tabs, fields, sliders, scroll areas, Back, Apply and Revert are
  unchanged. No generated image was added to runtime.
- Metal review accepted all three tabs at 1280×720, 1920×1080 and 2560×1440:
  one continuous sanctum background, readable controls and uncovered outer
  ornaments. Captures are transient under `build/qa/scrum972/`.

## Verification

- `tests/settings_scrum972_seamless_content_test.gd`: headless PASS; Metal PASS
  across three resolutions and all three tabs.
- `tests/runtime_smoke_ui_test.gd`: PASS.
- `tests/ui_no_overlap_matrix_test.gd`: PASS.
- `tests/gamepad_menu_focus_test.gd`: PASS.
- `tests/gamepad_settings_rebind_test.gd`: PASS.
- `tests/gamepad_full_flow_smoke_test.gd`: PASS.
- `tests/video_settings_apply_test.gd`: PASS.
- `tests/monitor_selector_behavior_test.gd`: PASS.
- `tests/runtime_smoke_test.gd`: PASS (known dummy-renderer screenshot
  diagnostic only).

Implementation disk cleanup: removed the task worktree, 446 MiB `.godot`
cache, 35 MiB captures and scratch roots after the direct-to-dev push.

Thread cleanup: not a disposable worker thread.

## QA-Вердикт (2026-07-11)

Статус: PASSED

- Independent QA verified `origin/dev` implementation commit `6f41ed648` with
  production code, assets and implementation docs read-only.
- PixelLab source `64eb22c0-35d0-41de-863c-e368c0e7da6f` matches the committed
  provenance SHA-256; planning is `ready_for_image` and all eight compositor
  zones fit.
- Focused SCRUM-972 test passed headless and on windowed Metal without lifecycle
  leak diagnostics. All three tabs were visually inspected at 1280×720,
  1920×1080 and 2560×1440: the sanctum background is continuous, no gray
  inset or inner border remains, and no content touches the outer ornament.
- UI/no-overlap, Settings rebind, menu focus, video Apply/Revert, monitor
  selector and two consecutive gamepad full-flow runs passed.
- Isolated full runtime, animation, meta-progression and melee-targeting smoke
  suites passed. The known headless dummy-renderer screenshot diagnostic is
  unchanged and non-fatal.

Баги: нет.

QA disk cleanup: disposable captures, `.godot`, isolated HOME/XDG roots,
worktree and local QA branch are removed after the evidence push; completion is
recorded in the final Jira comment.
