# SCRUM-571 QA Recheck 2026-07-03

Status: PASSED
Worker: codex-qa-loop-20260703
Commit under test: 03d9657e
Pre-commit dev base: d636814e

## Evidence

- Current dev contains the SCRUM-648 fix commits: `7f999ed5` and `7a093b3d`
  are ancestors of HEAD. Tests ran at `03d9657e`; before commit the worktree
  fast-forwarded to `d636814e`, which only changed docs/process/task metadata
  outside SCRUM-571 mockup/runtime paths.
- `ui_plan_report.json`: `ok=true`, `decision=ready_for_image`.
- `layout_guide_report.json`: `ok=true`.
- `reward_ordinary_2k_mockup_report.json`: `ok=true` for all 15 zones.
- Regenerated final/debug PNGs are byte-identical to committed evidence:
  final `cmp=0`, debug `cmp=0`.
- `png_audit.json` confirms base, final, debug and preview files are 2560x1440.
- Manual final/debug inspection passed the global frame rule for the rendered
  content. The title zone is wide, but actual title glyphs are centered away
  from side ornaments.

## Commands

```bash
python3 skills/codex/content-zone-image-compositor/scripts/validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output build/qa/scrum571_reqacheck_20260703/ui_plan_guide.png --report build/qa/scrum571_reqacheck_20260703/ui_plan_report.json
python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output build/qa/scrum571_reqacheck_20260703/layout_guide.png --report build/qa/scrum571_reqacheck_20260703/layout_guide_report.json
python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --input docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png --layout docs/design/mockups/scrum571_reward_2k/layout.json --output build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup.png --debug-output build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup_debug.png --report build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup_report.json
git diff --check -- docs/design/mockups/scrum571_reward_2k docs/design/previews docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
```

## Bugs

None.
