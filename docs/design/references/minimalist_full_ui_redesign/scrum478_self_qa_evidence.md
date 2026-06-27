# SCRUM-478 Self-QA Evidence And Plan

Status: Design-source QA complete; runtime render QA handed off to Back-end.
Task: `docs/tasks/design_minimalist_full_ui_redesign_exact_size_anchor_task.md`
Jira: SCRUM-478

## Generated Source Audit

The required OpenAI image-generation path was used through
`fantasydisk-asset-generator`:

- `scrum478_bright_minimal_button_anchor_sheet.png`
- `scrum478_exact_size_frame_source_sheet.png`
- `scrum478_full_screen_mockup_board.png`

The two asset-source sheets initially came back with an opaque model-drawn
checkerboard matte. They were not accepted as runtime/source alpha assets in
that raw form. Postprocessed transparent source candidates were created and are
the approved Design-source references:

| Asset-source file | Size | Transparent pixels | Opaque pixels | Result |
| --- | ---: | ---: | ---: | --- |
| `scrum478_bright_minimal_button_anchor_sheet_transparent.png` | `1792x1024` | `967901` | `867107` | PASS for transparent Design-source |
| `scrum478_exact_size_frame_source_sheet_transparent.png` | `1792x1024` | `652761` | `1182247` | PASS for transparent Design-source |

`scrum478_full_screen_mockup_board.png` is intentionally opaque because it is a
full-screen mockup board rather than a runtime UI asset.

## Visual Self-QA

Manual visual review:

- Button anchor: PASS. Five visible state variants are clearly distinct:
  normal, cyan hover, magenta pressed/accent, disabled gray and focus/blue.
- Frame source sheet: PASS. Modal, side panel, compact panel, tooltip, HUD
  strip, rounded field and chip are present with thin borders and empty dark
  interiors.
- Content-zone rule: PASS for Design-source. Cyan guide rectangles stay inside
  empty interiors; no guide is drawn over outer borders or corner ticks.
- Style direction: PASS. The package moves away from old beige/parchment and
  heavy metal into obsidian, silver, cyan/magenta and small gold ticks.

Known limitation:

- The PNG sheets are source/reference material, not final sliced runtime assets.
  Final per-size slicing, import metadata and runtime no-overlap screenshots are
  Back-end integration scope.

## Required Runtime QA Handoff

Back-end must add a render verifier after wiring:

1. Render every listed screen at `1280x720`, `1600x900`, `1920x1080`.
2. Dump every frame rect, content rect, text rect, icon rect, focus rect and
   interactive hit rect.
3. Assert `text/icon/focus/hit rect <= content_rect_xywh` for the owning frame.
4. Assert sibling interactive controls do not overlap unless the spec explicitly
   marks them as stacked/overlay-only.
5. Assert exact-size assets render 1:1; if any StyleBoxTexture/NinePatchRect is
   used, only the flat center may stretch and texture/content margins must match
   `scrum478_minimalist_full_ui_metadata.json`.
6. Save screenshot/contact evidence under `build/qa/scrum478_minimalist_full_ui/`.

Design will treat any content on border rails, accent diamonds, gold ticks or
glow caps as QA failed.
