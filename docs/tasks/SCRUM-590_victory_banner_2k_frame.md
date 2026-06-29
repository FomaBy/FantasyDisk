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

## QA Verdict (2026-06-28)

Status: PASSED

Checked on fresh `origin/dev` worktree `C:\Users\FomaE\FantasyDisk_agents\qa_563_codex20260628193932` with Godot 4.7 stable after explicit headless import.

- `python tools\build_ui_2k_frame_kit.py --verify` - PASS; `vbn_frame` is `1440x240`.
- PNG dimension/alpha check - PASS; `ui_frame_2k_vbn_frame.png` is exact-size RGBA.
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS.
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd` - PASS.
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS.

Frame/content safe-zone result: `VictoryBannerFrame` uses `vbn_frame` metadata with strict content margins `Vector4(112, 52, 112, 52)` and the matrix test verifies `VictoryBannerLabel` containment inside the scaled safe rect at the checked viewport matrix, including 1080p, 2K, and 4K coverage. No overlap, overflow, or ornament-content collision found.
