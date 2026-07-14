# UI Mockup Spec — Codex (Atlas/Settings family redesign)

Status: ready_for_integration
Role owner: Design (Lane: Claude)
Task: Multica FAN-1066 (parent FAN-1065)
Base resolution: 1920x1080
Responsive targets: 1152x648, 1280x720, 1920x1080, 2048x1152, 2560x1440
Mockup PNG: `docs/design/mockups/fan1065_codex_atlas_settings_redesign/codex_atlas_settings_redesign_1920x1080.png`
Annotated PNG: `docs/design/previews/fan1065_codex_atlas_settings_redesign/codex_atlas_settings_redesign_annotated_1920x1080.png`
States sheet: `docs/design/previews/fan1065_codex_atlas_settings_redesign/codex_states_reference.png`
Machine layout: `docs/design/mockups/fan1065_codex_atlas_settings_redesign/layout.json`
Provenance: `docs/design/references/fan1065_codex_atlas_settings_redesign/manifest.json`
Generated with: PixelLab MCP (config bridge). Source IDs in manifest.json.

## Source Request

Prepare a new visual pack for the Codex that keeps the accepted SCRUM-954/FAN-1047
geometry unchanged and joins the current Atlas/Settings family: shared fullscreen
shell, dark sanctum backdrop, calm content surfaces, metal/gold/dragon accents,
one typography and scrollbar language. The Codex may keep a restrained
lore/parchment accent inside the dossier, but must not read as a separate old
frame set.

## Visual Direction (matches Atlas/Settings)

- Backdrop: dark painted sanctum/archive with dragon-carved architecture
  (`_unified_add_background`, STRETCH_KEEP_ASPECT_COVERED equivalent).
- Panels: warm near-black translucent surfaces (runtime `_atlas_chip_style`
  bg `#15120E` @ ~0.9, border muted bronze `#856A3D` 2px, radius 10) — the
  PixelLab `panel_9slice` art carries the same warm-black body + thin bronze
  corner brackets.
- Headings/gold text: `#F5E6AE`; bronze chip text `#C7A870`.
- Buttons: existing main-menu button family (`minimal_metal`), unchanged.
- Codex-only accent: aged parchment inside the dossier image well and lore scroll.

## Screen Elements

| ID | Type | Runtime content | Rect @1920x1080 | Anchors | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CodexTitleFrame | Panel | "КОДЕКС" | 72,36,340,112 | stage TL | 3 | static | panel_9slice |
| CodexCrest | Texture | crest art | 908,24,104,104 | stage top-center | 4 | static | backdrop (no panel) |
| CodexBackButton | Button | "НАЗАД" | 1580,46,268,96 | stage TR | 3 | default/hover/pressed/focus/disabled | main_menu family |
| CodexNavPanel | Panel | — | 72,172,324,840 | stage left | 2 | static | panel_9slice |
| CodexTab x6 | Button | six section names | x=104, y=[234,352,470,588,706,824], 260x72 | inside nav | 3 | default/hover/pressed/focus/disabled/selected | codex_tab family |
| CodexContent | Panel | — | 420,172,620,840 | stage center | 2 | static | panel_9slice |
| CodexCenterTitle | Label | active section | 540,222,380,44 | inside content | 5 | static | content zone |
| CodexCenterListHost | Scroll | entry cards | 452,278,556,690 | inside content | 5 | scroll/empty/loading | content zone |
| CodexEntryCard | Button+row | portrait 88x96 + name | 460,290,516,154 (stride 170, ~4 visible) | list VBox | 6 | default/hover/pressed/focus/selected/locked | entry_card |
| CodexDetailPanel | Panel | — | 1064,172,784,840 | stage right | 2 | static | panel_9slice |
| CodexDetailTitle | Label | entry title | 1200,216,508,60 | inside detail | 5 | static | detail zone |
| CodexDetailWell | Panel+Texture | entry image 236x248 | 1108,284,300,300 (image 1140,310,236,248) | inside detail | 5 | empty/filled | dossier well frame |
| CodexDetailChip1 | Panel | affinity/semantic | 1432,310,330,70 | inside detail | 5 | default/selected | chip_bar |
| CodexDetailChip2 | Panel | second/«Заперто» | 1432,396,330,70 | inside detail | 5 | default/locked | chip_bar |
| CodexDetailParchment | Panel+Scroll | lore text + related | 1108,606,684,356 | inside detail | 5 | scroll/empty | parchment frame |

## Frames And Safe Zones

| Frame ID | Asset | Asset size | 9-slice margins | Content margins (L,T,R,B) | Forbidden zones |
| --- | --- | --- | --- | --- | --- |
| panel_9slice | derived/panel_9slice.png | 295x231 | 46/46/46/46 | title 36/22/36/22; nav 32/38/32/50; content & detail 32/36/32/44 | bronze corner brackets, outer bevel |
| entry_card | derived/entry_card_516x154.png | 516x154 | resized whole (aspect-matched, no stretch of ornament) | reserve 20/20/30/20 (left image well 122x114, image 88x96) | bronze bevel edge, left-well rim |
| dossier well | source/dossier_parchment_kit.png | 512x512 | fit to 236x248 image inside 300x300 rail | slot 32/26/32/26 | dragon-scale corners, parchment mat |
| chip_bar | derived/chip_bar.png | 297x60 | 40/20/40/20 | 18/14/18/14 | bronze ends |
| parchment | source/dossier_parchment_kit.png | 512x512 | 96/96/96/96 (wide) | 32/26/42/26 | dragon-scale corners |

All content margins are >= texture/ornament margins + reserve. No runtime content
(text, portrait, name, icons) sits on any bronze bracket, bevel, dragon-scale
corner, or parchment rim — content lives only in the empty inner zones (AGENTS.md
global frame rule / SKILL rules 6-7).

## Generated Assets

See `docs/design/references/fan1065_codex_atlas_settings_redesign/manifest.json`
for PixelLab IDs, prompts, seeds, and export dimensions. Source PNGs in
`references/.../source/`, cropped/resized clean pieces in `references/.../derived/`.

## Responsive Rules

The Codex renders on a fixed 1920x1080 `CodexStage` that scales **uniformly** by
`min(vw/1920, vh/1080)` and centers with letterbox bars
(`_codex_update_stage_transform`). Therefore every rect above scales identically
at every target — no reflow, no per-breakpoint layout, and every safe-zone/margin
ratio (`border_px / source_px`) is preserved automatically.

- 1152x648 (0.60x), 1280x720 (0.667x), 1920x1080 (1.0x), 2048x1152 (1.067x),
  2560x1440 (1.333x): identical composition, uniform scale, centered.
- Fonts: semantic typography clamps keep visual size in band
  (`_codex_bind_stage_font`, body floor 17px, section ceiling 30px) so small
  targets stay readable and large targets do not overgrow.

## Interaction States

- Tab/Back hover: main-menu `*_hover` art (warm glow); no size/pos change.
- Tab/Back pressed: `*_pressed` art (inset).
- Tab selected: `*_focus`/gold-edge — the active section tab.
- Disabled: `*_disabled` (desaturated); layout unchanged.
- Entry card hover/focus: `_unified_apply_row_theme` highlight; selected = gold
  edge (shown in mockup, first card/tab).
- Chip locked: «Заперто» chip variant (chip2 slot).
- Empty/loading: section host shows empty calm interior; dossier well shows the
  empty parchment recess; parchment scroll shows empty inner mat. No new frames
  are drawn over the art for any state.

## Implementation Notes (for Back-end child issue)

- Godot scene: procedural, `scripts/ui_screens.gd` `_show_codex_screen` /
  `_codex_update_detail` — geometry already matches; this pack only supplies the
  new **art skin**. Do not change rects.
- Recommended integration: promote `panel_9slice.png` (StyleBoxTexture, texture
  margins 46, content margins per table), `entry_card_516x154.png`,
  `dossier_well_236x248.png`/dossier frame, `chip_bar.png`, `codex_crest.png`,
  and the cropped sanctum backdrop into `assets/sprites/ui/atlas_style/` (or a
  codex subfolder) and swap the flat StyleBox panels for these textures where a
  richer surface is wanted. StyleBoxFlat fallbacks may remain.
- Keep runtime text/portraits in the existing content containers (outside baked
  art). Round frames are absent here, so all frames are 9-slice-safe except the
  entry card and dossier well which are aspect-matched (do not 9-slice the
  entry-card divider or the round-ish well corners).

## Acceptance Checks

- [x] Mockup generated through PixelLab MCP (config bridge; smoke PASS).
- [x] Preview shown in issue evidence.
- [x] All visible elements listed in the elements table.
- [x] Every frame has texture (9-slice) margins and content margins.
- [x] No UI content overlaps frame border, ornament, bracket, or corner.
- [x] Runtime content fits inside safe zones at every responsive target (uniform stage).
- [x] Hover/focus/pressed/disabled/selected/locked/empty states documented; none resize layout.
- [x] SCRUM-954/FAN-1047 geometry unchanged (rects copied from runtime source).
- [x] Codex reads as part of the Atlas/Settings family with a restrained dossier parchment accent.

## Deviations

- None from the locked geometry. The mockup is a **skin/art layer** over the
  existing SCRUM-954 layout; no rect, size, tab count, or scroll lane changed.
- `create_ui_asset` returns a coherent panel *kit*; the named single pieces used
  by the composite are cropped/resized from those kits (documented in manifest
  `derived_assets`). This is layout-only compositing of PixelLab art — no
  hand-drawn or non-PixelLab art was introduced.
