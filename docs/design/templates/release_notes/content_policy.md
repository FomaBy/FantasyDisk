# FantasyDisk release-notes image template

Этот пакет — один переиспользуемый source-template и один export profile для
одного квадратного PNG на выпуск. Визуальный слой уже принят в проекте как
textless PixelLab frame (`release_0_2_4_base_clean.png`); новый шаблон не рисует
поверх него карточки, рамки или непрозрачные подложки.

## Content contract

| Zone | Rectangle (x, y, w, h) | Safe margin | Text budget |
| --- | --- | ---: | --- |
| `game_title` | `(110, 125, 330, 125)` | 24 px | one line, min 28 px |
| `version` | `(510, 125, 330, 125)` | 24 px | one line, min 28 px |
| `release_date` | `(910, 125, 330, 125)` | 24 px | one line, min 20 px |
| `key_changes` | `(125, 575, 500, 425)` | 24 px | heading + up to five bullets, max 12 rendered lines, min 18 px |
| `fixed_bugs` | `(725, 575, 500, 425)` | 24 px | heading + up to five bullets, max 12 rendered lines, min 18 px |

The three upper zones are independent: game name, version, and ISO date never
share a rectangle. The two lower zones are independent columns: key changes are
on the left and fixed bugs are on the right. Their source rectangles have a
100 px horizontal gap, and no content may be placed in the frame's central
ornament, border, or unused strips.

## Text preparation and deterministic shortening

`render_release_notes.py` accepts `game_title`, `version`, `release_date`,
`key_changes`, and `fixed_bugs`. The latter two fields are lists of bullet
strings. The renderer applies the same rules for every release:

1. Collapse repeated whitespace and remove an input bullet marker.
2. Trim each bullet at a word boundary to 84 characters and add `…` when it
   was shortened.
3. Keep at most four original bullets. If more are supplied, add one fifth
   deterministic summary item (`Ещё N пунктов свернуты в краткое резюме.`).
4. Insert the fixed section heading, wrap at the zone width, and allow the
   compositor to shrink only down to the documented 18 px minimum.
5. If the normalized content still fails the minimum size or any geometry
   check, fail closed. The script never clips, scrolls, moves zones, or draws a
   replacement panel.

The short, boundary, and intentionally overflowing fixtures all pass through
this exact normalization → planning gate → compositing → bounding-box check.
The overflow case proves the shortening rule; it is not a second release
format.

## Export contract

Run one command per release:

```bash
python3 docs/design/templates/release_notes/render_release_notes.py \
  --content path/to/release.json --output-dir build/release-notes/<version>
```

`final/final.png` is the only publishable image in the output's final folder.
`qa/final.debug.png` and `qa/layout.guide.png` are QA-only overlays;
`fit_report.json` records their
planning decision, zone rectangles, actual text bounding boxes, and the
single publishable output. The fixed 1350×1350 RGB PNG profile is in
`export_profile.json`; changing the release text never changes the source
structure or the five zone rectangles.

The source-template is editable in an SVG-capable editor: the frame layer is a
named linked image and the hidden `content-zone-guides` layer contains the five
named rectangles. Runtime/release text is deliberately not baked into that
source file.
