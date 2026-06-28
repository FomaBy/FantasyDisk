# SCRUM-556 In-game Pause + Character Stats HUD

Status: implementation contract
Mockup: `docs/design/references/scrum556_ingame_pause_stats/mockup.png`
Generation: OpenAI Images API through `fantasydisk-asset-generator`, 1920x1088, quality high

## Goal

Move the in-run Escape pause menu to the upper-left gameplay area and add a compact character stats strip to the main gameplay HUD.

## Runtime Layout

Base matrix: 1280x720, 1600x900, 1920x1080, 2560x1440.

- `RunResourceHud`: top-left, `x=18`, `y=18`, width responsive `650..820`, compact 690 max on 1280px viewports.
- `CharacterStatsHud`: top-left, directly below `RunResourceHud`, `x=18`, `y=110`, same width as resource HUD, height `58`.
- `CharacterStatChip_<stat_id>`: four compact chips inside `CharacterStatsHud`, each `132x38`, icon + numeric value only.
- `RunPauseMenuPanel`: opens over the game after Escape at top-left, margin `18..28` from viewport edges, using the existing `pm_panel` frame and content safe margins.

## Safe Zones

- Runtime labels/icons stay inside existing minimal-metal HUD strip/field/card safe zones.
- `CharacterStatsHud` uses a field frame with explicit content margins `16/12/16/12`.
- Pause title, subtitle and buttons keep the existing pause panel internal box; only the outer panel anchor changes from centered to top-left.
- The middle and right side of gameplay must remain visible while paused.

## Responsive Notes

- On narrow 1280x720 and 1152x648 screens, `CharacterStatsHud` keeps the same width as the compact resource HUD.
- If the combat timer/ascension/artifact row need space, they continue using the existing `_layout_combat_hud` collision rules.
- The stats strip lives below the top HUD band and should not overlap the timer, ascension badge, artifact row, or level-up button.

## Verification

- `tests/runtime_smoke_test.gd`: assert `RunPauseMenuPanel` is top-left and `CharacterStatsHud` exists with stat chips.
- `tests/ui_no_overlap_matrix_test.gd`: include `CharacterStatsHud` in `combat_hud`.
- Run `runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd`, and `runtime_smoke_test.gd`.
