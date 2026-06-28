# SCRUM-582: UI redesign - Continue run dialog 2K frame

Jira: SCRUM-582
Role: Design/UI
Owner: codex-design-loop2-20260628_172833
Статус: done
Locked paths:

- `scripts/ui_screens.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/mockups/scrum582_continue_run/spec.md`
- `docs/design/ui_screens_inventory.md`

## Scope

Finish the continue-run dialog 2K redesign integration. The dialog must use the exact `cr_panel` frame and exact `cr_btn` button assets, with all runtime text/buttons inside `CR_SAFE_2K`.

## Design Decision

Reused existing exact-size `overhaul_2k` assets (`cr_panel`, `cr_btn`) instead of generating new PNGs because they already match the SCRUM-582 metrics and pass the frame-kit verifier. This keeps the visual system consistent with the rest of the menu/navigation block.

## Evidence

- Spec: `docs/design/mockups/scrum582_continue_run/spec.md`
- QA:
  - PASS: `python tools\build_ui_2k_frame_kit.py --verify`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

## Result

Continue-run dialog now uses the exact `cr_panel` panel frame and `cr_btn` action frames. The UI no-overlap matrix opens a temporary autosave-backed dialog and asserts panel metadata, safe content rect, and both button frame paths.
