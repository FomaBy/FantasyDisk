# SCRUM-584 Rebind Conflict UI 2K

Jira: SCRUM-584
Status: done
Executor: Codex
Lane: Codex
Role: Design/UI
Owner/worker: design-loop-1
Branch/worktree: codex/design-loop-1-20260628_210258

## Scope

Finish the 2K-first layout and visual redesign for the settings key-rebind
conflict modal in `scripts/ui_screens.gd::_show_rebind_conflict`.

Locked paths:

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tools/build_ui_2k_frame_kit.py`
- `tests/ui_no_overlap_matrix_test.gd`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_*.png`
- `docs/design/references/scrum584_rebind_conflict_2k/`
- `docs/design/mockups/scrum584_rebind_conflict_2k/`
- `docs/design/previews/scrum584_rebind_conflict_2k_*`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/content_registry.md`
- `docs/design/ui_screens_inventory.md`
- `docs/process/jira_sync_map.json`

## Result

SCRUM-584 now has a completed OpenAI-generated, textless mockup reference plus a
dedicated runtime 2K frame/button pair for the key-rebind conflict modal.

Runtime changes:

- `_show_rebind_conflict` now builds `RebindConflictDialog` with a centered
  `RebindConflictPanel`.
- The panel uses dedicated `rc_panel` instead of borrowing `cr_panel`.
- The retry/back buttons use dedicated `rc_btn` instead of borrowing `cr_btn`.
- Title, message, buttons, hit areas, and focus navigation stay inside the
  `Rect2(58,72,564,242)` panel safe zone.
- Verifier coverage checks 1080p/2K/4K+ containment, frame paths, metadata, and
  button frame routing.

## Deliverables

- Accepted OpenAI mockup:
  `docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference_v2.png`
- Rejected first attempt retained as evidence:
  `docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference.png`
- Safe-zone preview:
  `docs/design/previews/scrum584_rebind_conflict_2k_safe_zones.png`
- Spec:
  `docs/design/mockups/scrum584_rebind_conflict_2k/spec.md`
- Runtime assets:
  `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png`
  `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_btn.png`

## Verification

- PASS: OpenAI Images API generation through `fantasydisk-asset-generator`.
- PASS: `python tools\build_ui_2k_frame_kit.py --all`
- PASS: direct Godot import before UI tests.
- PASS: direct Godot `display_resolution_test.gd`
- PASS: direct Godot `ui_no_overlap_matrix_test.gd`
- PASS: direct Godot `runtime_smoke_test.gd`
- PASS: `git diff --check`

`tools/godot_gate.py` remains unavailable on this Windows worker because it
imports Unix-only `fcntl`, so direct Godot console runs are used.

Disk cleanup: remove `.godot/` and Python `__pycache__` before final handoff if
they were created by verification.
