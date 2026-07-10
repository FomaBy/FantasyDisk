# SCRUM-1026 — HS4 Ascension Full-Text Responsive Amendment

Status: implemented, pending independent QA
Role owner: Back-end UI
Jira: SCRUM-1026
Base visual source: `docs/design/mockups/hero_select_black_minimal/spec.md`
Runtime entry: `scripts/ui_screens.gd` → `_build_character_select_v4()`
Targets: 1280×720, 1920×1080, 2560×1440

## Mockup / Art Decision

This is a bounded layout correction to the already accepted HS4/Atlas page,
not a redraw. It reuses the current runtime art, plain clipped content zones,
typography, stepper, dossier, carousel and CTA unchanged. No new bitmap asset or
PixelLab generation is required; generating a different page mockup would
change the accepted visual direction and exceed the Backend-owned bug scope.

## Failure Evidence

At 1920×1080 the valid level-3 delta renders at 84 px, while
`HS4AscensionDescriptionScroll` exposes only 71.33 px. The third line is
therefore clipped and the vertical scrollbar remains active. The former test
seeded only level 2 (55 px), so it did not cover the maximum supported content.

## Geometry Contract

- `HS4AscensionFrame` remains in the right column between
  `HS4DossierFrame` and `HS4CarouselFrame`.
- Its bottom edge stays anchored at `carousel_top - vertical_gap`; increasing
  the band height moves only its top edge upward.
- The increase consumes only `HS4DossierFrame` height. The dossier is already a
  dedicated vertical `ScrollContainer`; its safe margins and two-column
  contract remain intact.
- `HS4AscensionActionRow` keeps its current left safe segment.
- `HS4AscensionDescriptionScroll` keeps its current right safe segment and all
  frame padding. Its viewport must be at least the rendered height of the
  longest currently selectable `ascension_level_change_line(level)` plus 1 px
  at 1920×1080 and 2560×1440.
- At 1280×720 the compact band may overflow internally, but the complete text
  must be reachable by wheel, keyboard and D-pad and focus must transfer to
  `HS4ChooseButton` only after the scroll boundary.
- The compact band must be at least the utility row's real combined minimum
  plus both style content margins (`59 + 5 + 5 = 69 px` in the current runtime),
  so the stepper never touches the decorative border.
- At 720p the two external gaps around the band are 1 px each instead of the
  normal responsive gap. They remain positive/disjoint and reclaim the added
  frame-safe height without shrinking the fixed eight-row stats column.
- Manual horizontal geometry uses the StyleBox's real `pad × 1.4` left/right
  content margins for both the stepper and description scroll; the smaller
  vertical pad is not reused as a horizontal inset.
- No text/control may overlap the stepper, dossier, carousel counter, carousel,
  Choose button, outer screen frame or any ornament/content margin.

## Responsive Matrix

| Viewport | Required description behavior | Band behavior |
| --- | --- | --- |
| 1280×720 | Internal vertical overflow is allowed; first line visible and full text scroll-reachable | 69 px minimum = 59 px utility row + 5 px top/bottom content margins; 1 px disjoint outer gaps preserve dossier height |
| 1920×1080 | Every selectable level 0…`selectable_max()` fully visible; vertical overflow ≤ 1 px tolerance | Enforce a full-text minimum band height; grow upward only |
| 2560×1440 | Every selectable level fully visible; vertical overflow ≤ 1 px tolerance | Preserve the same full-text minimum and responsive cap |

## Interaction Contract

- Exercise actual viewport pointer motion/down/up on `−` and `+` instead of
  emitting button signals directly.
- Every level change and hero switch resets description scroll to the first
  line and preserves the exact cumulative tooltip.
- Focused Down scrolls first; at the bottom/no-overflow boundary it transfers to
  Choose. Up follows the reciprocal declared neighbor.
- Default Hero Select focus, carousel navigation and full gamepad flow stay
  unchanged.

## Verification Contract

The focused test must enumerate every valid selectable level rather than a
single seed. It records frame/scroll/label rectangles, scrollbar range and
viewport-bounded input results at all three target resolutions. The normal UI
no-overlap, dark-theme, runtime UI and full runtime gates remain mandatory.

## Assets / Safe Zones

Generated assets: none.
Runtime assets changed: none.
Frame/texture margins changed: none.
Content margins changed: none; the fix allocates more vertical content-zone
height without placing content on the frame border.
