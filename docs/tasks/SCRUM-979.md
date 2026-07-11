# SCRUM-979 — Hero Select carousel window scrolling

Статус: done
Версия: 0.2.1
Jira: SCRUM-979
Контур: Codex
Owner: Backend+UI/Codex `/root`
Thread/Worker: `root-next8`
Branch: `codex/scrum979-carousel-window`

## Scope And Locks

Hero Select carousel hunk in `scripts/ui_screens.gd`; focused SCRUM-979 test
and only necessary Hero Select/runtime assertions; PixelLab-first mockup/source
evidence; this mirror and Hero Select carousel contract paragraphs. Existing
portraits, animations, dossier/ascension logic, full-screen frame assets and
unrelated screens remain read-only.

## Baseline

At 1920×1080 the existing navigation plates are only `54x42` next to roughly
`192x192` hero slots. Arrows select the adjacent roster entry cyclically and
`keep_selected_visible` moves the offset only after selection escapes the
window; the visible window itself is not the primary navigation state.

## Planned Contract

- non-wrapping window offset shifts by one per arrow press;
- selected visible-slot anchor is preserved when possible and clamped at roster
  edges;
- Berserk in the first slot + Next produces Soldier / Thief / Elementalist /
  Sniper with Soldier selected;
- direct slot click still selects that exact hero and refreshes all detail data;
- existing vertical PixelLab arrows preserve their 0.75 aspect; height is 52%
  of slot side with an 84–140 px clamp and width follows the source aspect;
- pointer, keyboard and gamepad focus paths remain valid.

## UI Director Result

- Content-zone plan: `ready_for_image`, zero errors/warnings.
- PixelLab MCP was called after the gate and returned no remaining credits; no
  new image was created. Jira records the explicit `PixelLab unavailable +
  existing source reuse` exception; no generic fallback was used.
- Existing accepted PixelLab `button_carousel_left/right.png` sources were
  applied with their authored `Rect2(36,42,60,92)` empty content interiors.
  Deterministic pre-runtime mockups at 1920×1080 and 2560×1440 are committed
  beside the spec; compositor fit is green for all seven content zones.

## Implementation Result

The visible carousel offset is now the primary, non-wrapping navigation state.
Each arrow shifts it by exactly one, preserves the selected visible-slot anchor,
and selects the hero newly occupying that slot; at roster edges the focusable
arrow is a no-op. Direct slot clicks retain the window and refresh the exact
clicked hero. Runtime slot metadata exposes the canonical `character_id` for a
strict oracle. Arrow plates scale from slot height at the accepted 0.75 aspect:
about `63x84`, `75x100`, `105x140` at 720/1080/1440.

## Verification

PASS with isolated `HOME`, `XDG_DATA_HOME` and `user://` roots:

- `tests/hero_select_scrum979_carousel_window_test.gd`, headless and real Metal
  at 1280×720, 1920×1080 and 2560×1440: exact roster slices, first-click
  +1, left/center anchors, reverse movement, both no-wrap edges, direct detail
  refresh, pointer, physical keyboard arrows/Enter, raw D-pad, A/focus graph,
  arrow rect/content zones;
- `tests/hero_select_pixellab_layout_test.gd` with the former retry-loop false
  green replaced by an exact first-press assertion;
- `tests/hero_select_scrum980_ascension_layout_test.gd`;
- `tests/ui_no_overlap_matrix_test.gd`;
- `tests/gamepad_menu_focus_test.gd`;
- `tests/gamepad_full_flow_smoke_test.gd`;
- `tests/runtime_smoke_ui_test.gd`;
- full `tests/runtime_smoke_test.gd`.

Metal captures were visually inspected at all targets: arrow ornaments remain
inside `HS4Carousel`, their glyphs/counts remain inside the authored empty
interiors, and no arrow overlaps a hero card or the outer frame. The known
dummy-renderer null-texture diagnostic remains non-fatal.

Independent pre-land review found a cyclic outward focus edge, premature local
status and stale square-arrow wording. All were corrected: outward focus clamps
to its edge arrow, physical keyboard coverage is explicit, and this mirror stays
`in_progress` until commit/push.

Implementation commit `2a9e329bf` is in `origin/dev`; Jira QA routing and disk
cleanup are recorded by the follow-up routing result.

Thread cleanup: not a disposable worker thread.
