# SCRUM-778 QA Dev Verification

Date: 2026-07-01
Worker: `codex-qa-scrum778-verify-20260701`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk-QA-SCRUM-778`
Branch: `codex/qa-scrum-778-verify`
Source of truth: `origin/dev`
Verified dev base: `75d9b444acd2ec24dba8b24b3bc84093ea13a1f3`
Integration commit: `245dcdaf Merge SCRUM-778 HUD scale into dev`

## Verdict

PASSED.

The previous QA failure was a strand. This verification used current `origin/dev`,
not the old feature branch. `245dcdaf` is an ancestor of the rebased QA evidence
commit, and the focused runtime UI/no-overlap gates were rerun after rebasing on
`origin/dev` base `75d9b444`.

## Combat HUD 1920x1080 Evidence

From `build/qa/ui_no_overlap_matrix.md` after running
`tests/ui_no_overlap_matrix_test.gd`:

- `RunResourceHud`: `[P: (30.0, 45.0), S: (938.0, 111.0)]`
- `CombatTimerPanel`: `[P: (1031.0, 44.0), S: (233.0, 108.0)]`
- `AscensionHudBadge`: `[P: (1710.0, 39.0), S: (123.0, 123.0)]`
- `LevelUpPlusButton`: `[P: (1778.0, 936.0), S: (66.0, 78.0)]`

The SCRUM-778 matrix gates passed:

- top HUD band at 1920x1080 is within the `<= 18%` viewport-height guard;
- pending-level frame footprint is within the `<= 3.5%` viewport-area guard;
- visible combat HUD controls do not overlap;
- content stays inside frame-safe zones.

Visual evidence:

- `build/qa/scrum778_dev_verify/combat_hud_1920x1080.png`
- Source capture set generated under ignored `build/qa/design_review/` for
  1280x720, 1920x1080, and 2560x1440.

## Commands

- PASS: `git merge-base --is-ancestor 245dcdaf origin/dev`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd`

After rebasing the QA evidence commit on `origin/dev` base `75d9b444`, rerun:

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- NOTE: second full visual screenshot refresh was interrupted after several minutes
  with no HUD failure output; the committed 1920x1080 screenshot remains from the
  successful visual capture pass in the same QA worktree.

Final-base rerun before push:

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`

## Bugs

None.
