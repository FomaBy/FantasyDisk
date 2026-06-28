# SCRUM-590: UI redesign - Victory banner 2K frame

Jira: SCRUM-590
Role: Design/UI
Owner: codex-design-loop2-20260628_172833
Статус: done
Locked paths:

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tools/build_ui_2k_frame_kit.py`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_vbn_frame.png`
- `docs/design/mockups/scrum590_victory_banner/spec.md`
- `docs/design/ui_screens_inventory.md`
- `tests/ui_no_overlap_matrix_test.gd`

## Scope

Redesign the transient victory banner (`VictoryBanner`) with an exact 2K frame asset and runtime-safe content zone. The short victory text must stay inside the inner empty area and never overlap decorative frame pixels.

## Design Decision

Used the exact-slot `overhaul_2k` frame kit builder for the victory banner because the accepted asset needs a transparent, pixel-exact `1440x240` source with stable 9-slice margins. The runtime text remains separate from the frame asset and is constrained by StyleBox content margins.

## Evidence

- Spec: `docs/design/mockups/scrum590_victory_banner/spec.md`
- Asset:
  - `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_vbn_frame.png`
- QA:
  - PASS: `python tools\build_ui_2k_frame_kit.py --verify`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

## Result

Victory banner now uses a dedicated exact-size 2K frame asset and runtime text is constrained to verified content margins. `ui_no_overlap_matrix_test.gd` asserts the frame path, slot metadata, safe content rect, and label containment.
