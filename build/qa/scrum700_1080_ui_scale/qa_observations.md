# SCRUM-700 QA 1080p UI Scale Evidence Start

Worker: QA subagent
Date: 2026-06-30
Scope: evidence only under `build/qa/scrum700_1080_ui_scale/`

## Commands

- PASS: `python3 tools/godot_gate.py --path . --script res://build/qa/scrum700_1080_ui_scale/scrum700_focused_capture.gd > build/qa/scrum700_1080_ui_scale/capture_1920.log 2>&1`
  - Notes: scoped wrapper around the existing `tests/design_review_screenshot_capture_test.gd` approach because the original harness hardcodes `build/qa/design_review/`, outside this subagent write scope.
- PASS: `sips -g pixelWidth -g pixelHeight build/qa/scrum700_1080_ui_scale/screenshots/*.png`
  - Notes: all generated screenshots are `1920x1080`.
- BLOCKER/NOT USEFUL: `python3 tools/godot_gate.py --headless --path . --script res://tests/main_menu_title_no_overlap_test.gd > build/qa/scrum700_1080_ui_scale/main_menu_title_no_overlap.log 2>&1`
  - Notes: failed before a useful overlap assertion with `Could not preload resource script "res://scripts/ui_screens.gd"`.
- BLOCKER/NOT USEFUL: `python3 tools/godot_gate.py --path . --script res://tests/main_menu_title_no_overlap_test.gd > build/qa/scrum700_1080_ui_scale/main_menu_title_no_overlap_windowed.log 2>&1`
  - Notes: same loader/parse failure as the headless run.

## Evidence Files

- `manifest.md`
- `priority_rects_1920x1080.md`
- `preliminary_verdicts.md`
- `capture_1920.log`
- `main_menu_title_no_overlap.log`
- `main_menu_title_no_overlap_windowed.log`
- `screenshots/main_menu_1920x1080.png`
- `screenshots/settings_display_1920x1080.png`
- `screenshots/hero_select_1920x1080.png`
- `screenshots/weapon_select_1920x1080.png`
- `screenshots/codex_1920x1080.png`
- `screenshots/level_up_1920x1080.png`
- `screenshots/shop_1920x1080.png`
- `screenshots/event_1920x1080.png`
- `screenshots/pause_stats_1920x1080.png`
- `screenshots/victory_1920x1080.png`
- `screenshots/death_1920x1080.png`
- `screenshots/combat_hud_1920x1080.png`

## Preliminary Verdict

- Main/start menu 1920x1080: FAIL. `MainMenuTitleLabel` rect is `(72, 56, 640, 267)`. First button starts at y=`203`, second at y=`317`, so the title/logo overlaps two menu controls; nearest vertical gap is `-120 px`. Screenshot confirms the top button covers the lower logo/emblem area.
- Combat HUD 1920x1080: geometry PASS but visual WARN. Priority panel area is `14.32%` of viewport and the top HUD band reaches `26.20%` of viewport height. Screenshot does not show literal half-screen coverage, but the resource/timer/ascension frames are very wide/tall and mostly empty, so the HUD reads heavy on 1080p.

## Next For Main Agent

- Create/route a bug for main menu logo/menu overlap with `main_menu_1920x1080.png` and `priority_rects_1920x1080.md`.
- Review whether combat HUD should become a bug or design/back-end tuning task; likely candidates are shrinking the top resource frame, timer frame, and ascension frame or reducing empty frame interiors at 1080p.
- Continue SCRUM-700 with the remaining required screens/resolutions and Jira/local mirror updates from the main claimed worker, not this QA subagent.
- Disk cleanup: none outside evidence; intentional evidence folder size is about `22M`.
