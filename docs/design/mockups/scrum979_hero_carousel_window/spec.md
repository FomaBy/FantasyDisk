# SCRUM-979 Hero Select Carousel Window Mockup Spec

Jira: SCRUM-979

Base: 1920×1080

Responsive targets: 1280×720, 1920×1080, 2560×1440

Runtime entry: `scripts/ui_screens.gd` → `_build_character_select_v4()`

## UI Director Decision

The content-zone plan is `ready_for_image` with zero errors/warnings. PixelLab
MCP was called after that gate, but returned `no generations or credits
remaining`; no new image was created and no generic image fallback is allowed.
The explicit Jira exception is `PixelLab unavailable + existing source reuse`.

The mockup therefore reuses the already accepted PixelLab Hero Select sources
`button_carousel_left.png` and `button_carousel_right.png`, preserving their
authored `132x176` aspect and empty content rectangles `Rect2(36,42,60,92)`.
The deterministic Godot capture tool applies those sources to the live page
before any production edit. No new production bitmap or visual direction is
introduced.

`carousel_content_fit_report.json` is green for all seven runtime text zones;
the guide/debug images prove that counter, arrow glyph/counts and hero labels
fit their declared empty interiors before runtime composition.

## Layout And Content Zones

- Existing Hero Select outer frame, portrait, dossier, ascension, hero slots,
  counter and CTA remain unchanged.
- Arrow display aspect is `0.75`; height is `52%` of the live hero-slot side,
  clamped to `84..140 px`; width follows the source aspect.
- Runtime measurements are about `63x84 px` at 1280×720, `75x100 px` at
  1920×1080 and `105x140 px` at 2560×1440. All are materially larger than
  the `54x42` baseline.
- Glyph and hidden-count text stay inside the scaled source content rectangle;
  no text or hitbox crosses the arrow ornament.
- Arrow plates stay inside `HS4Carousel` and outside every hero slot. The hero
  slot label/portrait zones remain unchanged.

## Interaction Contract

- Next/Previous shifts the non-wrapping visible offset by exactly one.
- Selected visible-slot index is the anchor. The newly occupying hero is
  selected at the same slot whenever the roster edge permits.
- At either edge the corresponding arrow is a focusable no-op; navigation never
  wraps the roster.
- Direct slot click selects the clicked hero without moving the window.
- Pointer, keyboard and gamepad focus order remains
  Previous ↔ visible slots ↔ Next.

## Verification Contract

The focused test must assert exact visible roster slices and exact one-step
counter changes after the first physical action; looping until any change is a
false green. It covers left/center anchors, reverse movement, both clamped edges,
direct click, detail refresh, arrow content-zone geometry and focus paths at all
three target resolutions.
