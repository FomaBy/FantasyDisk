# SCRUM-971 — selected class label in Atlas/Guild

## Decision

Reserve a lightweight native-text row above the central constellation canvas.
Do not add a new ornamental frame or put the label into the already occupied
header. The class strip, right dossier, footer, outer PixelLab frame, and all
existing controls keep their current ownership and visual hierarchy.

## Canonical 688×384 mockup geometry

- Outer frame: full canvas; live content remains inside `(72, 52, 544, 283)`.
- Header: `(72, 52, 544, 37)`, unchanged.
- Body: `(72, 93, 544, 196)`.
- Center column: `(125, 93, 365, 196)`.
- Selected-class content zone: `(225, 93, 165, 20)`.
- Constellation canvas begins at `y=117`, below the label and a 4 px gap.
- Right node dossier and footer remain unchanged.

The runtime label is localized from the same `ProgressionData.character_config`
title used by the class medallions. It must update during `_atlas_refresh()` so
selection changes are visible immediately in both Constellation and Guild tabs.

## Responsive mapping

The central column is a `VBoxContainer`: the label receives a compact minimum
height scaled by the existing Atlas UI scale, while the canvas remains
`SIZE_EXPAND_FILL`. At 1280×720 this reserves approximately 34–38 px and leaves
more than 330 px of canvas height; at 1920×1080 and above it reserves 48–56 px.
The label is clipped/wrapped by neither the outer frame nor the node dossier.

## Acceptance boundaries

- No content may cover frame ornament.
- The label must not overlap tabs, currency badges, Back, class medallions,
  constellation nodes/canvas, node dossier, footer, or tooltips.
- Text is native Godot UI, mouse-pass-through, centered, gold, with a dark
  outline for contrast; no new heavy panel or decorative texture.
- Existing allocation, reset, tab, gamepad, pointer, and Back flows remain live.

## PixelLab evidence

- UI asset ID: `d17b4090-9c7c-4e98-91e8-b788be339530`.
- Source: `docs/design/references/scrum971_atlas_class_label/`.
- `layout.report.json`: title fits at 15 px, one line, bounding box fully inside
  `(225, 93, 165, 20)`.
- The generated source keeps frame ornament, plates, socket art and graph lines
  outside the title zone. Only the low-detail starfield surface remains behind
  the native outlined title; no additional runtime texture is introduced.
