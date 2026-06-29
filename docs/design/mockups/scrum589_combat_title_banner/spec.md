# SCRUM-589 Combat Title Banner 2K Frame Spec

Jira: SCRUM-589
Screen/node: `CombatTitleBanner` / `CombatIntroBanner`
Runtime entry: `scripts/ui_screens.gd::_show_combat_title_banner()`

## Goal

Replace the bare combat title text with a dedicated D&D + Dark Fantasy Dragon frame while preserving the SCRUM-487 2K combat coordinate grid and keeping runtime title text strictly inside the empty content zone.

## 2K Layout

Base viewport: `2560x1440`.

| Variant | Const | Frame rect | Texture margins | Content margins | Content rect |
|---|---|---:|---:|---:|---:|
| Boss/elite big | `CTB_BIG_2K` | `Rect2(100, 120, 2360, 90)` | `70,20,70,20` | `86,10,86,10` | `Rect2(86, 10, 2188, 70)` |
| Small combat title | `CTB_SMALL_2K` | `Rect2(100, 92, 2360, 56)` | `56,12,56,12` | `72,8,72,8` | `Rect2(72, 8, 2216, 40)` |

The frame is anchored top-center and scales with Godot's existing `canvas_items`/`aspect=keep` behavior for 1080p, 2K, and 4K. The title label is a child of `PanelContainer`, so the StyleBox content margins are the runtime layout boundary.

## Assets

Generated exact-size transparent frame assets:

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_big.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_small.png`

The frame layer contains only ornament/border pixels and no baked text. Runtime text is centered inside the safe content rect and must not overlap the top/bottom ornament, side caps, or corner details.

## Implementation Notes

- `scripts/ui/ui_theme_paths.gd` registers both `ctb_big` and `ctb_small` frame paths, source sizes, texture margins, and content margins.
- `scripts/ui_screens.gd` now builds `CombatIntroBanner` as a `PanelContainer` with a child `CombatIntroBannerLabel`.
- Runtime metadata stores `combat_title_slot`, `combat_title_content_margins`, and `combat_title_content_rect` for QA assertions.
- `tools/build_ui_2k_frame_kit.py` includes both CTB slots in the deterministic exact-slot 2K frame kit. This was used instead of a free-form image mockup pass because the banner needs exact 2360-pixel-wide transparent 9-slice-safe sources; preserving pixel-exact margins is the higher acceptance constraint for this narrow HUD element.

## QA Plan

- `python tools\build_ui_2k_frame_kit.py --all`
- `python tools\godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python tools\godot_gate.py --headless --path . --script res://tests/display_resolution_test.gd`
- `python tools\godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

Acceptance: `CombatIntroBannerLabel` global rect must remain inside the scaled safe content rect for every checked viewport; ornament pixels remain visible and unblocked.
