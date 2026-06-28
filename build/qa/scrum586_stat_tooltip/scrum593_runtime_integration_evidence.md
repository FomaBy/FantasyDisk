# SCRUM-586 / SCRUM-593 Stat Tooltip Runtime Evidence

Date: 2026-06-28
Worker: design-codex-SCRUM-586
Worktree: `D:\FantasyDisk_worktrees\design-SCRUM-586-stat-tooltip`

## Scope

- Re-verified the SCRUM-586 2K stat tooltip art package and the SCRUM-593 runtime
  integration already present on `origin/dev`.
- Confirmed that `scripts/ui/ui_theme_paths.gd` registers
  `ui_frame_2k_stat_tooltip.png` with 32 px texture margins and content margins
  `Vector4(44, 42, 44, 42)`.
- Confirmed that `scripts/pause_stats_menu.gd` uses the 2K tooltip frame for
  stat tooltips and constrains text to the 342 px safe inner width.

## Asset And Safe Zone

- Frame asset: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`
- Frame dimensions: 430 x 288 px
- Safe content rect: x=44, y=42, w=342, h=204
- Ornament-free rule: content is kept inside the inner zone; the decorative frame
  margins remain uncovered.

## Verification

- `tests/display_resolution_test.gd` passed.
- `tests/ui_no_overlap_matrix_test.gd` passed after Godot headless import cache refresh.
- `tests/runtime_smoke_ui_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed, including duplicate-artifact guard.

`tools/godot_gate.py` was not usable on this Windows worker because it imports
the Unix-only `fcntl` module. The same target scripts were run directly through
the Godot 4.7 console executable instead.
