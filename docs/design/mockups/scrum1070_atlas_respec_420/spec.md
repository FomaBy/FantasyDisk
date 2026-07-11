# SCRUM-1070 — Atlas reset footer 420 px UI Director spec

Status: accepted implementation contract  
Jira: SCRUM-1070  
Owner: Back-end UI / Codex  
Base resolution: 2560×1440  
Responsive matrix: 1152×648, 1280×720, 1600×900, 1920×1080,
2048×1152, 2560×1440, 3840×2160 and live resize.

## Accepted visual sources

No new art is needed and no fallback image pipeline is used.

- Atlas page composition: `docs/design/previews/meta40_atlas_mockup.png`. The
  accepted existing SCRUM-832 OpenAI composition already places the reset action as a wide
  plate at the left of the empty footer band and the four-state legend to its
  right. SCRUM-1070 restores runtime parity with that accepted hierarchy.
- Exact action plate: the accepted existing OpenAI per-size source
  `text/standard_420x104`, documented by
  `docs/design/references/ui_text_buttons_unique_size_redraw/button_family_metadata.json`.
  It has distinct normal/hover/pressed/focus/disabled exports, fixed ornamental
  caps and a 9-slice center rail.
- PixelLab redraw exception: `existing source reuse`. SCRUM-1070 changes only
  runtime sizing and reuses two already accepted production sources; it does
  not redraw either the Atlas page or the button family.
- Outer Atlas frame: the accepted `assets/sprites/ui/meta40/frame_border.png`
  package and its existing frame-safe runtime margins remain unchanged.

## Scope decision

Only `AtlasRespecButton` and its relationship to `AtlasFooter`/`AtlasLegend`
change. Constellation/Guild topology, schema, currency, refund logic, node
geometry, header, dossier, art and every other screen remain unchanged.

## Button contract

- Visible and hit width: exactly `420 px` at every tier.
- Height: `72 px` when viewport height `<760`, `88 px` when `<1000`, otherwise
  `104 px`.
- Family: explicitly pinned to `text/standard_420x104`; width/height inference
  must not route compact tiers to `later_260x72` or any Back family.
- Texture margins: `54/21/54/21` (left/top/right/bottom).
- Content margins: `71/21/71/21`, stricter than texture margins. At the compact
  `420×72` tier the native label zone is therefore `278×30`; at `420×88` it is
  `278×46`; at `420×104` it is `278×62`.
- Semantic font: the final SCRUM-1061 `action` compatibility binding, explicitly
  `21 px` at the 72px compact tier (above the 16px action minimum) and `23 px`
  at the medium/large tiers. Both `Сброс умений` and
  `Сброс умений Атласа` must fit in the 278 px content width with glyph reserve.
- One line, no wrap, clip, ellipsis or fit-downscale. All five states keep the
  same control rect, texture/content margins and hit target.

## Frame-safe footer geometry

The footer stays inside `AtlasSafeArea`; the outer frame and its margins do not
move. Coordinates below are design targets derived from the accepted source
frame (`1536×1024`, source margin `160`, vertical safe factor `0.86`). Fractional
runtime rounding within 1.5 px is accepted.

| Viewport | Atlas safe rect x/y/w/h | Footer target x/y/w/h | Reset size |
| --- | --- | --- | --- |
| 1152×648 | 120.0 / 87.1 / 912.0 / 473.9 | 120.0 / 488.9 / 912.0 / 72 | 420×72 |
| 1280×720 | 133.3 / 96.8 / 1013.3 / 526.5 | 133.3 / 551.2 / 1013.3 / 72 | 420×72 |
| 1600×900 | 166.7 / 120.9 / 1266.7 / 658.1 | 166.7 / 691.1 / 1266.7 / 88 | 420×88 |
| 1920×1080 | 200.0 / 145.1 / 1520.0 / 789.8 | 200.0 / 830.9 / 1520.0 / 104 | 420×104 |
| 2048×1152 | 213.3 / 154.8 / 1621.3 / 842.4 | 213.3 / 893.2 / 1621.3 / 104 | 420×104 |
| 2560×1440 | 266.7 / 193.5 / 2026.7 / 1053.0 | 266.7 / 1142.5 / 2026.7 / 104 | 420×104 |
| 3840×2160 | 400.0 / 290.3 / 3040.0 / 1579.5 | 400.0 / 1765.8 / 3040.0 / 104 | 420×104 |

`AtlasRespecButton` is the left footer child. `AtlasFooterSpacer` absorbs spare
width; `AtlasLegend` remains right-aligned. Neither may overlap the other or
leave the safe rect. On compact widths the spacer may collapse to zero, but the
button may not shrink below 420 and the legend may not enter the frame rail.

## Interaction invariants

- Pointer hit rect equals the visible 420 px plate.
- Existing tooltip remains non-empty.
- Focus neighbours and LB/RB/Tab behaviour remain live.
- Constellation text is `Сброс умений`; Guild text is
  `Сброс умений Атласа`.
- Press opens the existing confirmation popup; Cancel changes nothing; Confirm
  performs the existing scope-specific full refund and closes the popup.

## Acceptance evidence

- focused SCRUM-1070 seven-viewport plus same-instance live-resize test: exact size, family, state geometry,
  content margins, real Cyrillic fit, footer/legend/frame containment,
  pointer/focus and both reset scopes;
- `meta40_atlas_screen_smoke_test.gd`;
- `atlas_scrum970_clickability_test.gd` with isolated user data;
- semantic typography test, Metal/button-family tests, gamepad menu focus,
  `ui_no_overlap_matrix_test.gd` and `runtime_smoke_test.gd`.
