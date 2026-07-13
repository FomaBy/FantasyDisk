# FAN-1047 — Codex And Hero Dossier Button Unification

Status: implemented and verified
Role owner: Codex, combined UI design/runtime scope from the assigned Multica issue
Task: FAN-1047
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2048×1152, 2560×1440 and live resize
PixelLab references: `docs/design/references/FAN-1047_codex_dossier_buttons/`
Generated with: PixelLab MCP `create_ui_asset`; source IDs are recorded in `manifest.json`

## Source Request

Remove the yellow `minimal/codex_tab` exception, make ordinary Codex navigation
and pause-dossier actions visibly belong to the main-menu text-button family,
and keep every state geometrically stable and unclipped.

## Runtime Inventory And Decision

The production family is the existing five-state
`assets/sprites/ui/frames/text_buttons_unique/` kit. No new generated bitmap is
promoted to runtime. Main Menu keeps `main_menu_380x104`; Codex tabs use the
native-height `back_260x104` sibling; the dossier uses the `later_260x72` sibling on
compact tiers and the `260x104` sibling on 1080p/2K tiers. These are one material
and state family with size-appropriate caps, so the source art is not vertically
squeezed or clipped.

Specialized controls remain exceptions because their shape is functional:
content rows/cards, Settings fields/toggles, Route nodes, Atlas sockets,
Hero-carousel arrows, `+/-`, icon-only gratitude and other explicitly tagged
controls.

## Codex Geometry @ 1920×1080

| ID | Type | Rect | Safe/content rule | States |
| --- | --- | --- | --- | --- |
| `CodexTitleFrame` | title well | `72,36,340,112` | 22px+ inner reserve | static |
| `CodexBackButton` | navigation action | `1580,46,268,96` | existing back-family content margins | five states |
| `CodexNavPanel` | navigation frame | `72,172,324,840` | 8px L/R, 38px top, 50px bottom | static |
| `CodexTab_*` | six ordinary navigation actions | `80,222+118n,308,104` | 42px logical L/R label inset inside untouched 54px nine-slice rails | normal/hover/pressed/focus/disabled |
| `CodexContent` | entry list | `420,172,620,840` | unchanged | content rows stay specialized |
| `CodexDetailPanel` | selected-entry dossier | `1064,172,784,840` | unchanged | scroll/detail states unchanged |

The three-column SCRUM-954 stage remains `1920×1080`, uniformly scaled and
letterboxed. No large outer shell is added. At all targets the stage transform,
tab rectangles and button content margins scale without state-dependent size
changes.

## Pause Dossier Geometry

The existing SCRUM-983 safe zones remain authoritative:

| Viewport | Inner content rect | Action row | Plate tier |
| --- | --- | --- | --- |
| 1280×720 | `157,137,966,446` | `168,507,944,72` | shared `later_260x72` sibling |
| 1920×1080 | `224,193,1472,694` | `396,771,1128,104` | shared `260x104` sibling |
| 2560×1440 | `299,257,1962,926` | `660,1063,1240,104` | shared `260x104` sibling |

All four actions use the same sibling at a given viewport. Their controls stay
inside the existing footer rectangle and frame safe zone. Normal, hover,
pressed, focus and disabled use identical margins and control bounds. Live
resize recomputes both the action rectangles and the size-appropriate sibling.

## Interaction And Accessibility

- Codex starts on the first tab; LB/RB and pointer navigation are unchanged.
- Pause starts on Continue; the four-action left/right ring and stat/footer
  focus transfers are unchanged.
- Focus/hover uses neutral bright metal, never the old yellow Codex border.
- Labels stay within the text-family content margins; no baked text is used.

## Generated Assets

| Asset | Path | Runtime use | Size | Alpha |
| --- | --- | --- | --- | --- |
| Codex layout reference | `docs/design/references/FAN-1047_codex_dossier_buttons/pixellab_codex_main_menu_family_688x384.png` | reference only | 688×384 | RGBA |
| Dossier layout reference | `docs/design/references/FAN-1047_codex_dossier_buttons/pixellab_dossier_actions_688x384.png` | reference only | 688×384 | RGBA |

## Acceptance Checks

- [x] PixelLab MCP mockups generated and previewed before runtime edits.
- [x] Exact Codex and dossier bounds/safe zones documented.
- [x] No live `CodexTab_*` uses `minimal/codex_tab` or its yellow textures.
- [x] Codex and dossier ordinary actions resolve inside the shared
      `text_buttons_unique` visual family.
- [x] All five states preserve content margins and control bounds.
- [x] 1152×648 through 2560×1440 plus live resize pass.
- [x] Focused family, Codex, dossier, gamepad, UI and runtime smokes pass.

Metal renderer evidence is committed at
`docs/design/previews/FAN-1047_codex_dossier_buttons/runtime/` for Codex and at
`build/qa/scrum983/` for the dossier.

## Deviations

The PixelLab images are visual/layout evidence only. Runtime deliberately reuses
the accepted production text-button kit so no generated art bypasses its five
state, localization or safe-margin contract.
