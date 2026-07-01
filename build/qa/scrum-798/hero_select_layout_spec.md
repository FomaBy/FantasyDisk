# UI Mockup Spec - Hero Select Large Preview Runtime Layout

Status: implemented
Role owner: Back-end
Task: docs/tasks/SCRUM-798_hero_select_large_preview_attributes_carousel.md
Jira: SCRUM-798
Base resolution: 1920x1080
Responsive targets: 1280x720, 1536x864, 1920x1080, 2560x1440
Mockup PNG: PixelLab generation attempted 2026-07-01, blocked by service rate limit `10/10 jobs`
Generated with: PixelLab MCP `create_ui_asset` attempted for a compact 16:9 layout mockup; no runtime art generated

## Source Request

Rebuild live `_build_character_select_v4()` around a visually dominant selected hero preview, ascension and start controls directly below the preview, a large readable right-side dossier with Line Bars and build guidance, and an enlarged bottom carousel.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HS4Portrait | TextureRect | selected animated/static hero art | approx 160,56,560,560 | left/top | 320x320 | 10 | selected hero refresh | HS4PortraitFrame |
| HS4AscensionFrame | VBoxContainer | ascension level, +/- controls, modifier line, start button | directly under portrait | left/top | 320x84 | 10 | disabled +/- clamp, tooltip | left column |
| HS4DossierFrame | PanelContainer | class title, description, weapons, stat Line Bars, build guidance | right of preview, fills top band | left/top | 420 wide | 10 | scroll if content exceeds height | HS4DossierContentSafe |
| HS4Stat_* | Button row | Line Bar + rich stat tooltip | two-column grid inside dossier | dossier safe | 180x38 | 11 | hover/focus tooltip | HS4DossierContentSafe |
| HS4BuildGuidance_* | Label | primary/secondary/optional data-driven attributes | under stat grid | dossier safe | content-fit | 11 | tooltip full list | HS4DossierContentSafe |
| HS4Carousel | Control | enlarged hero portrait slots and arrows | bottom full-width band | bottom/left/right | 3 visible slots | 10 | selected/hover/focus | HS4CarouselFrame |

## Frames And Safe Zones

This backend task keeps the active black-minimal runtime and does not introduce new frame art. Content is placed inside flat panels or direct control bounds, so there are no decorative frame ornaments to overlap. `HS4DossierFrame` uses an internal `MarginContainer` safe zone; carousel portraits are inset inside each button slot.

## Responsive Rules

- 1280x720: compact top/bottom margins, preview remains at least `320x320`, carousel slots at least `180x180`, dossier scrolls if text exceeds height.
- 1536x864: preview grows toward `440-500px`; carousel grows past old 150px slots.
- 1920x1080: preview target about `560x560`, visually dominant; carousel target about `280x280`.
- 2560x1440: preview caps near `620x620`, carousel slots cap near `304x304`.

## Interaction States

- Carousel arrows and slots preserve cyclic character selection.
- Selected carousel slot uses the existing selected minimal button style and full-opacity portrait.
- Ascension minus/plus preserve clamp behavior and disabled state.
- `HS4ChooseButton` still advances to weapon select.
- Stat Line Bar rows expose tooltip text with description, influences, formula, and class interpretation.

## Deviations

PixelLab MCP mockup generation was attempted as required by the UI skill, but the service returned `rate limit exceeded (10/10 jobs)`. Because SCRUM-798 is explicitly a Back-end runtime implementation with no new final art, the task proceeded with this geometry spec and runtime evidence rather than blocking on new visual art.
