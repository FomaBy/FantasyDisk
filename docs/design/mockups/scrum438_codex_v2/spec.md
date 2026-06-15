# UI Mockup Spec - Codex V2

Status: ready_for_integration_review  
Role owner: Design -> Back-end  
Task: `docs/tasks/design_codex_rebuild_from_scratch_mockup_task.md`  
Jira: SCRUM-438  
Base resolution: 1920x1080  
Responsive targets: 1280x720, 1920x1080, 2560x1440  
Mockup PNG: `docs/design/mockups/scrum438_codex_v2/codex_v2_mockup_1920x1080.png`  
Preview PNG: `docs/design/previews/scrum438_codex_v2_mockup_preview.png`  
Safe-zone overlay: `docs/design/mockups/scrum438_codex_v2/codex_v2_safe_zones_annotated_1920x1080.png`  
Layout metadata: `docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json`  
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

Rebuild the FantasyDisk Codex window from scratch by mockup/spec. The screen must
keep all current data sections and navigation, but move to a denser library-style
D&D + Dark Fantasy Dragon layout where every runtime text/icon/portrait/click
zone is inside explicitly reserved safe content areas, never on frame ornament.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| codex_root | Control | Fullscreen Codex overlay | `0,0,1920,1080` | full rect | `1280x720` | 0 | default | viewport |
| codex_main_frame | Panel/NinePatch | Main window frame | `24,20,1872,1040` | full rect with scaled margins | `1248x694` | 1 | default | outer_safe |
| header_title_zone | Label container | `Кодекс`, active section subtitle | `112,74,1120,64` | top-left inside main | `747x43` | 5 | default | outer_safe |
| codex_back_button | Button | Back to menu | `1684,60,126,96` | top-right inside main | `84x64` | 6 | normal/hover/pressed/focus | back_button_safe |
| section_nav_panel | Panel | Six section tabs | `72,170,304,872` | left, vertical fill | `203x581` | 4 | default | nav_safe |
| section_tabs | Buttons | Characters, monsters, artifacts, stats, glossary, ascensions | see `tab_button_safe_each` | left stack | `167x57` each | 6 | normal/hover/pressed/selected/focus/disabled | nav_safe |
| content_list_panel | Panel/ScrollContainer | Current section list/cards | `388,170,835,872` | center, vertical fill | `557x581` | 4 | default | list_safe |
| content_scrollbar | Scroll rail | Vertical scroll | `1176,198,34,812` | right edge of list | `23x541` | 7 | default/drag/focus | scroll_rail_safe |
| entry_card | Panel/Button optional | One codex row/card | `428,214,722,110` | list flow | `481x73` | 8 | normal/hover/focus/selected | list_safe |
| entry_icon_slot | TextureRect frame | Character/monster/artifact/stat icon | `452,235,92,76` | left inside card | `61x51` | 9 | empty/loaded/fallback | entry_card |
| entry_text_block | VBox labels | Title, description, tags | `568,232,540,70` | fills card | `360x47` | 9 | default | entry_card |
| detail_panel | Panel | Selected entry detail | `1242,170,606,872` | right, vertical fill | `404x581` | 4 | default | detail_safe |
| detail_portrait_slot | TextureRect frame | Large portrait/icon/monster art | `1396,226,320,300` | top-center in detail | `213x200` | 8 | empty/loaded/fallback | portrait_safe |
| detail_chip_row | HBox/Grid | Stat chips, tags, element icons | `1298,548,486,80` | below portrait | `324x53` | 8 | normal/hover/focus | chip_row_safe |
| detail_text_body | RichText/Labels | Description, mechanics, weapon lines | `1298,660,486,300` | below chips | `324x200` | 8 | default/scroll | detail_text_safe |
| glossary_tooltip | PopupPanel | Glossary term tooltip | `1038,512,230,154` | near hovered term, clamped to viewport | `153x103` | 20 | hidden/hover/focus | tooltip_safe |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| codex_main_frame | TBD by Back-end/asset pass, mockup source in this package | 1920x1080 mockup context | `48,44,72,38` | `72,64,72,36` | outer dragon corners, side thorns, red gems, top/bottom crests | yes for runtime frame, or composed panels |
| section_nav_panel | Use v2 frame derived from mockup or existing codex tab material | proportional | `16,28,30,124` | `16,28,30,124` | left/right metal rails, gems, tab horns | yes |
| content_list_panel | Use parchment list panel from mockup | proportional | `36,34,63,42` | `36,34,63,42` | inner parchment linework, scroll divider, card separators | yes |
| detail_panel | Use parchment detail panel from mockup | proportional | `48,44,44,48` | `48,44,44,48` | corner linework, dragon watermark zones, metal border | yes |
| entry_card | Use card frame from mockup | proportional | `28,22,32,22` | `36,26,40,24` | card metal outline, red center gem, corner trim | yes |
| portrait_slot | Use square portrait frame from mockup | proportional square | `28,28,28,28` | `42,42,42,42` | octagonal rim and inner metal lip | no stretch; keep square |
| tooltip | Use compact tooltip frame from mockup | proportional | `18,24,16,26` | `20,28,18,34` | rim and top gem | yes |

All content margins are stricter than texture margins. Runtime text, portraits,
icons, cards, click/focus hitboxes and tooltips must fit inside the listed
`*_safe` rectangles only. Decorative corners, red jewels, dragon crests, metal
rails, spikes, scroll rail ornaments and parchment flourishes are forbidden.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| codex_v2_mockup_source | `docs/design/references/codex_v2/codex_v2_full_window_mockup_1920x1088.png` | OpenAI source mockup | `1920x1088` | opaque reference | n/a | n/a | Source generated by API, cropped for base spec |
| codex_v2_mockup | `docs/design/mockups/scrum438_codex_v2/codex_v2_mockup_1920x1080.png` | Base mockup | `1920x1080` | opaque reference | see frames | see frames | Do not use as runtime atlas |
| codex_v2_safe_zones | `docs/design/mockups/scrum438_codex_v2/codex_v2_safe_zones_annotated_1920x1080.png` | Geometry overlay | `1920x1080` | opaque QA overlay | n/a | n/a | Safe-zone visualization |
| codex_v2_layout_metadata | `docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json` | Machine-readable rects | n/a | n/a | recorded | recorded | Source for Back-end no-overlap work |

No runtime PNG assets were installed in this Design pass. Back-end should either
derive final frame assets from an accepted follow-up asset pass or reuse existing
Codex/unified frame materials while matching this layout. Do not delete or
backup the old live Codex texture kit until runtime replacement is implemented.

## Responsive Rules

Use a uniform screen scale `s = min(viewport_width / 1920, viewport_height / 1080)`.
For the required matrix, that gives:

| Target | Scale | Main frame | Outer safe | Nav safe | List safe | Detail safe |
| --- | --- | --- | --- | --- | --- | --- |
| 1280x720 | `0.6667` | `16,13,1248,693` | `48,43,1184,653` | `59,132,172,480` | `283,136,491,531` | `860,143,343,520` |
| 1920x1080 | `1.0` | `24,20,1872,1040` | `72,64,1776,980` | `88,198,258,720` | `424,204,736,796` | `1290,214,514,780` |
| 2560x1440 | `1.3333` | `32,27,2496,1387` | `96,85,2368,1307` | `117,264,344,960` | `565,272,981,1061` | `1720,285,685,1040` |

Layout behavior:
- Header remains fixed-height relative to scale; back button anchors to the top
  right inside `outer_safe`.
- Left navigation rail keeps six equal-height tab hitboxes with fixed vertical
  gaps; if labels exceed width, Back-end should use smaller font or two-line
  wrapping inside the tab safe area, never extend text onto trim.
- Center list is the only primary vertical scroll area for section entries.
  Horizontal scrolling stays disabled.
- Right detail panel stays visible at all three targets. At 1280x720, reduce
  portrait safe size first (`213x200` from scale), then chip spacing, but do not
  overlap the detail text body.
- Tooltip popups clamp to `outer_safe`; if a tooltip would overlap a frame
  border or leave the viewport, flip it left/up while preserving `tooltip_safe`
  margins.

## Interaction States

- Section tab normal: dark metal/parchment fill, no label outside inner safe
  area.
- Section tab hover/focus: brighter gold rim and soft ruby socket glow, same
  hitbox size.
- Section tab selected: red parchment fill and stronger left icon accent, same
  hitbox size.
- Entry card hover/focus: card background slightly warmer, thin gold inner
  highlight, no size change.
- Entry card selected: matching detail panel updates; selected marker must sit
  inside card safe area, not over the center red gem.
- Disabled/locked: desaturated card/tab content inside the safe zone; frame
  border remains unchanged.
- Empty/loading: placeholder icon and skeleton text lines remain inside
  `entry_icon_slot` / `entry_text_block`.
- Tooltip: appears above list/detail content at z=20, never on outer frame
  ornament.

## Implementation Notes

- Godot script target: `scripts/ui_screens.gd`, `_show_codex_screen`,
  `_show_codex_section`, `_codex_entry_panel`, `_codex_portrait`,
  `_codex_icon_slot`, `_codex_label`, glossary tooltip creation.
- Recommended structure:
  `CodexScreen > CodexMainFrame > HeaderRow + BodyRow`; body row contains
  `SectionNavPanel`, `ContentListPanel`, `DetailPanel`.
- Existing data sections must remain: characters, monsters, artifacts, stats,
  glossary, ascensions.
- Keep lazy section building and cached section nodes unless Back-end finds a
  performance reason to change it.
- Back button keeps current Escape/back behavior to main menu.
- Keyboard/gamepad focus order: back button, tabs top-to-bottom, list cards,
  detail chips/tooltips.
- Runtime character portraits continue using SCRUM-416 `sprite_path`; character
  portraits use covered scaling inside `portrait_safe`, non-character icons use
  centered scaling.
- Do not wire the full mockup PNG as one runtime texture. Build the layout from
  panels, frames and runtime content containers.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner in the spec.
- [x] Runtime content zones are defined for 1280x720, 1920x1080, and 2560x1440.
- [x] Hover/focus/pressed/disabled states are specified as no-size-shift.
- [ ] Screenshot comparison completed after implementation.
- [ ] Runtime UI smoke/no-overlap matrix completed after Back-end implementation.

## Deviations

This is a Design-first pass. Runtime code, old texture backup/removal, Godot
smokes and no-overlap matrix are intentionally deferred to Back-end after this
mockup/spec is accepted.
