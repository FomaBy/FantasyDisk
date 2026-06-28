# SCRUM-589: UI redesign - Combat title banner 2K frame

Jira: SCRUM-589
Role: Design/UI
Owner: codex-design-loop2-20260628_172833
Статус: done
Locked paths:

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tools/build_ui_2k_frame_kit.py`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_big.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_small.png`
- `docs/design/mockups/scrum589_combat_title_banner/spec.md`
- `docs/design/ui_screens_inventory.md`
- `tests/ui_no_overlap_matrix_test.gd`

## Scope

Redesign the combat title banner (`CombatTitleBanner` / `CombatIntroBanner`) with exact 2K frame assets and runtime-safe content zones. The title text must stay inside the inner empty area and never overlap decorative frame pixels.

## Design Decision

Used the existing exact-slot `overhaul_2k` frame kit builder for this narrow HUD banner because the accepted asset needs transparent, pixel-exact `2360x90` and `2360x56` sources with stable 9-slice margins. The runtime text remains separate from the frame asset and is constrained by StyleBox content margins.

## Evidence

- Spec: `docs/design/mockups/scrum589_combat_title_banner/spec.md`
- Assets:
  - `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_big.png`
  - `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_small.png`
- QA:
  - PASS: `python tools\build_ui_2k_frame_kit.py --verify`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
  - PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

## Result

Combat title banner now uses dedicated exact-size 2K frame assets and runtime text is constrained to verified content margins. `ui_no_overlap_matrix_test.gd` asserts the big banner frame path, slot metadata, safe content rect, and label containment.
