# SCRUM-983 Runtime Acceptance Test Plan

This is a Design-stage oracle only. It does not lock or edit shared runtime
tests before SCRUM-981 releases its UI paths.

## Focused geometry oracle

Create `tests/scrum983_escape_dossier_test.gd` after runtime lock release. For
1280×720, 1920×1080 and 2560×1440 it must instantiate the real pause dossier
with a configured player and assert:

1. `EscapeStatsPanelFrame` uses `meta40/frame_border.png`, 160 source margins,
   `draw_center=false`, mouse-ignore decorative frame and the exact frame safe
   rects from `spec.md`.
2. Every visible label, icon, stat chip, button hitbox, focus outline and both
   scrollbar lanes are inside the inner content rect.
3. No two sibling hitboxes overlap; no horizontal scrollbar exists.
4. All 8 base stats and every currently displayed derived stat have exactly one
   localized visible name, one compact value and a non-empty tooltip.
5. Visible stat cards contain no description/formula paragraph; tooltip text
   contains the full stat name, current value, explanation and formula/source.
6. `attack_speed` renders per-second, `crit_chance` as percent and
   `crit_damage_multiplier` as multiplier; values match the configured player.
7. Continue, Settings and Main Menu resolve neutral state textures/tints for
   normal/hover/focus/pressed/disabled; End Run alone resolves danger red.
8. D-pad/keyboard traversal from initial Continue reaches all four actions and
   every stat tooltip target; focus-follow scroll keeps the focused rect inside
   its viewport; B/Escape resumes.
9. Live resize 2560×1440 → 1280×720 relayouts the existing screen without
   rebuilding and still satisfies all bounds/focus assertions.

## Regression gates after integration

Run through `python3 tools/godot_gate.py`:

- `tests/scrum983_escape_dossier_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/dark_fantasy_ui_theme_test.gd`
- `tests/gamepad_inrun_ui_test.gd` three consecutive passes
- `tests/runtime_smoke_ui_test.gd`
- `tests/runtime_smoke_test.gd`

Windowed capture must save real 720p/1080p/2K screenshots and a rect/focus dump
under `build/qa/scrum983/`. Visual QA fails on any content touching frame
ornament, clipped numeric value, red Continue/Main Menu state, hidden/unreachable
stat chip or scrollbar entering a content lane.
