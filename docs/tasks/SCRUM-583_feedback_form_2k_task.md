# SCRUM-583: UI redesign - Feedback Form @2K

Status: done
Contour: Codex
Owner: Design/ui-worker-h
Thread: ui-worker-h
Locked paths: Feedback overlay / FeedbackPanel; scripts/ui_screens.gd feedback section; scripts/ui/ui_theme_paths.gd fb_* registry if needed; assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_fb_*.png; docs/design/mockups/scrum583_feedback_form_2k/; docs/design/previews/scrum583_feedback_*
Jira: SCRUM-583

## Autonomy / Approval

User pre-approved in-repository UI/design work. Jira is authoritative; this file is a local evidence mirror for the claimed issue.

## Scope

Redesign and verify the Feedback overlay for the 2K UI overhaul. Keep the field, screenshot preview, status, and send/cancel buttons inside the modal content zone; no runtime content may touch frame ornament.

## Result Log

- Claimed by `ui-worker-h` through Jira-pull.
- Read `fantasydisk-ui-director` and required UI/process docs.
- Generated OpenAI Images API mockup/reference:
  `docs/design/references/scrum583_feedback_form_2k/feedback_form_2k_mockup.png`.
- Created annotated safe-zone preview:
  `docs/design/previews/scrum583_feedback_form_2k_safe_zones.png`.
- Created UI-director spec:
  `docs/design/mockups/scrum583_feedback_form_2k/spec.md`.
- Connected `FeedbackSendButton` and `FeedbackCancelButton` to exact 2K `fb_btn_send` / `fb_btn_cancel` frame styleboxes.
- Documented the live 2K feedback contract in `docs/design/systems/menus_ui.md`
  and `docs/design/current_game_state.md`.

## Acceptance Criteria

- [x] Coordinates and safe zones are documented at 2560x1440.
- [x] Feedback panel stays inside `FB_PANEL_2K`, content inside `FB_SAFE_2K`.
- [x] Feedback panel and buttons use exact 2K frame assets.
- [x] `tools/build_ui_2k_frame_kit.py --verify` passes.
- [ ] `tests/ui_no_overlap_matrix_test.gd` passes.
- [x] `tests/display_resolution_test.gd` passes.
- [x] Relevant runtime UI smoke passes.

## Verification

- PASS: `python tools/build_ui_2k_frame_kit.py --verify`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- PASS with unrelated resource warnings: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- BLOCKED by pre-existing non-feedback issues: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
  fails on `PatchNotesPanel` expected `pn_panel` and `AttributeShopPanel`
  expected `attr_panel` frame assertions across the matrix, plus local missing
  `.godot/imported` resource cache warnings. No SCRUM-583 feedback assertion was
  identified in the failure set.

## Notes

The current worktree contains unrelated `ELR_*` / elite reward WIP and `project.godot` changes from outside this task. They are not part of SCRUM-583 and must not be staged for this task.
