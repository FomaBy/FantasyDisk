# SCRUM-983 / SCRUM-1056 / FAN-1047 Runtime Acceptance Test Plan

Status: implemented and green. The focused oracle and capture helper exercise
the real pause dossier; the repository-wide runtime smoke passed after the
Priest worker pushed and released its test file.

## Focused geometry oracle

`tests/scrum983_escape_dossier_test.gd` instantiates the real pause dossier. For
1152×648, 1280×720, 1600×900, 1920×1080 and 2560×1440 it must instantiate the real pause dossier
with a configured player and assert:

1. `EscapeStatsPanelFrame` uses `meta40/frame_border.png`, 160 source margins,
   `draw_center=false`, mouse-ignore decorative frame and the exact frame safe
   rects from `spec.md`.
2. Every visible label, icon, stat chip, button hitbox and focus outline is
   inside the inner content rect.
3. No two sibling hitboxes overlap; both dossier scroll owners have horizontal
   and vertical modes disabled and their content minimum height fits the viewport.
4. All 8 base stats and every currently displayed derived stat have exactly one
   localized visible name, one compact value and a non-empty tooltip.
5. Visible stat cards contain no description/formula paragraph; tooltip text
   contains the full stat name, current value, explanation and formula/source.
6. `attack_speed` renders per-second, `crit_chance` as percent and
   `crit_damage_multiplier` as multiplier; values match the configured player.
7. Continue, Settings, End Run and Main Menu resolve the size-fit
   `later_260x72` (compact) or `back_260x104` (104px) sibling with white tint
   and stable content margins for all five states.
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

Windowed capture must save real 648p/720p/900p/1080p/2K screenshots and a rect/focus dump
under `build/qa/scrum983/`. Visual QA fails on any content touching frame
ornament, clipped numeric value, non-main-menu action state, hidden/unreachable
stat chip or any dossier scrollbar/hidden overflow.

## Result — 2026-07-10

- Focused geometry/content/tooltip/focus/live-resize gate: PASS.
- UI no-overlap matrix: PASS at its complete resolution matrix.
- Dark-fantasy theme: PASS.
- Gamepad in-run: PASS three consecutive runs; full-flow smoke: PASS.
- Runtime UI smoke: PASS (known headless dummy-renderer capture warning only).
- Windowed Metal capture: PASS at 1280×720, 1920×1080 and 2560×1440;
  `build/qa/scrum983/escape_dossier_visual_matrix.md` records exact rectangles.
- Every derived compact alias and value fits its actual rendered lane at all
  three targets; every base/survival/derived focus target was exercised and its
  actual tooltip remained within 430×288 and the inner rect.
- A real pointer motion proves hover uses the same bounded internal panel with
  the generic engine popup disabled; mouse wheel and physical gamepad shoulder
  events reach long tooltip tails. A separate focus-only/pointer-outside case
  proves wheel scrolls Hero content without moving tooltip scroll. A Druid
  `summon_amulet` fixture covers the
  summoner-only `summon_amount` row.
- After both content columns are physically scrolled, every footer Up neighbor
  is rebuilt/clipped-visible and a pushed `ui_up` event lands on that target;
  fixture `Main` and `SubViewport` WeakRefs clear after `queue_free`.
- Full repository runtime smoke: PASS after the Priest test-lock release;
  duplicate-artifact guard scanned 14,628 files PASS. Godot emitted existing
  freed-lambda and dummy-renderer diagnostics, but the suite returned zero and
  reported `Runtime smoke test passed.`
