# UI Mockup Spec — SCRUM-1063 Hero Select wide controls

Status: implemented / QA-ready

Task/Jira: `docs/tasks/SCRUM-1063.md` / SCRUM-1063

Base resolution: 1920×1080

Responsive targets: 1152×648, 1280×720, 1920×1080, 2560×1440

Runtime entry: `scripts/ui_screens.gd::_build_character_select_v4()`

## Source Request

Widen both carousel controls to exactly two times their current responsive
width without changing height, reuse that same family and geometry for
Ascension `−`/`+`, center exact visible copy `Возвышение N`, move modifiers to
tooltip-only, and restore cyclic first↔last carousel behavior for pointer,
keyboard and gamepad.

## Planning Contract

- `ui_plan.json` inventories the full screen and gives the changed ascension and
  carousel surfaces exact 688×384 planning rectangles.
- Runtime reuses accepted textless PixelLab source `button_asc_minus.png`
  (`132×92`, byte-identical to `button_asc_plus.png`). Its strict empty glyph
  zone is `Rect2(32,22,68,48)`; `StyleBoxTexture` stretches only the calm centre.
- Live controls use `2 × round(height × 0.75)` for exact pre-change-width
  doubling. Verified sizes are `142×94` vs former `71×94` at 1152/720p,
  `150×100` vs `75×100` at 1080p and `202×134` vs `101×134` at 2K.
- The same control size, art, content margins and state tints apply to all four
  buttons. Only runtime glyphs differ.
- Ascension controls are symmetric around the panel center. The label center
  equals the midpoint between button centers with ≤1 px tolerance.
- The visible modifier lane is removed. The full cumulative modifiers remain
  available from the ascension panel/value/button tooltips.
- Button enlargement may reduce the wide-screen carousel window count but must
  never reduce it below three visible slots.

## Responsive Rules

| Viewport | Wide control target | Minimum slots | Ascension policy |
| --- | --- | --- | --- |
| 1152×648 | 142×94 (former 71×94) | 3 × 116 px | 530.11×102 band |
| 1280×720 | 142×94 (former 71×94) | 3 × 132 px | 577.66×104 band |
| 1920×1080 | 150×100 (former 75×100) | 3 × 192.92 px | 878×132 band |
| 2560×1440 | 202×134 (former 101×134) | 3 × 257.4 px | 1251×152 band |

The compact outer gold shell cannot fit three former 180 px cards plus two
doubled controls in the right column. The 1152×648 tier therefore uses 116 px
square hero slots and 1280×720 uses 132 px square slots; portrait/label content
scales uniformly with the complete card. 1080p/2K retain their existing slot
calculation. The dossier is already scroll-safe and absorbs the additional ascension height.
Carousel, portrait, Choose, counter and outer gold-shell borders remain disjoint.

## Interaction Contract

- direct slot click selects that hero without moving the current window;
- normal Previous/Next shifts the visible window one position and preserves the
  selected visible-slot anchor;
- Previous at offset zero wraps to the final window and selects the last hero;
- Next at the final offset wraps to the first window and selects the first hero;
- all paths call the same `select_hero` refresh, synchronizing selection,
  portrait, dossier, stats, counter, ascension value and tooltip;
- Ascension remains clamped to `0..ascension_selectable_max(character_id)` and
  disabled states remain exact.

## Acceptance Checks

- [x] Planning gate is `ready_for_image` before PixelLab generation.
- [x] PixelLab auth/generation attempt and accepted existing source provenance recorded.
- [x] Pre-runtime page mockup and safe-zone debug preview shown in chat.
- [x] No glyph/text enters button ornament at any responsive target.
- [x] All four controls share geometry and normal/hover/pressed/focus/disabled states.
- [x] Visible copy is exactly `Возвышение N`; no `/ max` or long modifier text.
- [x] Pointer, keyboard and gamepad first↔last wrap are synchronized.
- [x] 1152×648, 720p, 1080p and 2K keep at least three slots and no overlap.

## Deviations

PixelLab MCP auth smoke passed, but the prepared `create_ui_asset` request was
rejected by the service with `no generations or credits remaining`. No generic
fallback was used. The task-explicit 9-slice option therefore reuses the already
accepted textless PixelLab Hero Select source `button_asc_minus.png` (identical
to `button_asc_plus.png`) as the universal source. This changes no authored art;
only its calm centre stretches. Compact slot floors changed to 116/132 px so
the doubled hit boxes and three complete cards fit inside the fixed gold shell.
