# SCRUM-778 Combat HUD Scale Evidence

Date: 2026-07-01
Branch: `codex/scrum-778-hud-scale`
Worker: `codex-backend-scrum778-hud-scale`

## Mockup / Art Deviation

No new PixelLab mockup or art layer was generated. This task is a backend/runtime
geometry compaction of the accepted SCRUM-666/SCRUM-671 combat HUD contract: the
same generated frame assets, same essential-only HUD content, and same
frame-safe content-zone model remain live. The change only reduces source-space
runtime rectangles and updates the regression gate.

## 1920x1080 Rects

Before SCRUM-778, Jira/task evidence reported:

- `RunResourceHud`: `[P: (30, 63), S: (1116, 159)]`
- `CombatTimerPanel`: `[P: (1194, 62), S: (318, 164)]`
- `AscensionHudBadge`: `[P: (1624, 41), S: (248, 242)]`
- Top HUD band: `26.20%` of viewport height
- Priority panel area: `14.32%`

After SCRUM-778, `tests/ui_no_overlap_matrix_test.gd` reported:

- `RunResourceHud`: `[P: (30.0, 45.0), S: (938.0, 111.0)]`
- `CombatTimerPanel`: `[P: (1031.0, 44.0), S: (233.0, 108.0)]`
- `AscensionHudBadge`: `[P: (1710.0, 39.0), S: (123.0, 123.0)]`
- `LevelUpPlusButton`: `[P: (1778.0, 936.0), S: (66.0, 78.0)]`
- Top HUD band bottom: `162 px` = `15.00%` of 1080p height
- Pending-level frame footprint: `165x188 px` = `1.50%` of 1080p viewport area

## Matrix Rects

1280x720:

- `RunResourceHud`: `[P: (20.0, 30.0), S: (625.0, 74.0)]`
- `CombatTimerPanel`: `[P: (688.0, 29.0), S: (155.0, 72.0)]`
- `AscensionHudBadge`: `[P: (1140.0, 26.0), S: (82.0, 82.0)]`
- `LevelUpPlusButton`: `[P: (1185.0, 624.0), S: (44.0, 52.0)]`

2560x1440:

- `RunResourceHud`: `[P: (40.0, 60.0), S: (1250.0, 148.0)]`
- `CombatTimerPanel`: `[P: (1375.0, 58.0), S: (310.0, 144.0)]`
- `AscensionHudBadge`: `[P: (2280.0, 52.0), S: (164.0, 164.0)]`
- `LevelUpPlusButton`: `[P: (2370.0, 1248.0), S: (88.0, 104.0)]`

## Verification

- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/design_review_screenshot_capture_test.gd` - BLOCKED for screenshots in headless dummy renderer: every screen reported `viewport image unavailable` from `texture_2d_get` at `_capture_screen()`.

## Regression Guard

`tests/ui_no_overlap_matrix_test.gd` now fails the 1920x1080 combat HUD if:

- the top HUD band exceeds `18%` of viewport height;
- the pending-level frame footprint exceeds `3.5%` of viewport area.
