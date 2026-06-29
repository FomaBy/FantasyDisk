# SCRUM-678 Codex/Glossary UI Design Spec

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/SCRUM-678_codex_glossary_ui_design.md`
Jira: SCRUM-678
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/references/codex_glossary_scrum678/codex_glossary_2k_mockup_v2.png`
Preview PNG: `docs/design/previews/codex_glossary_scrum678_safe_zones.png`
Generated with: OpenAI Images API via `$fantasydisk-asset-generator`; slot-exact assets generated after geometry planning.

## Source Request

Rebuild the Codex/Glossary screen in the shared D&D + Dark Fantasy Dragon style:
cleaner panels, category switches, larger unframed central icons, less description
noise, a readable right detail panel, and a consistent Back button style.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| main_frame | Panel frame | screen shell | `32,27,2496,1387` | uniform center | `1248x694` | 0 | n/a | n/a |
| header_title | Label | `Кодекс · <section>` | `128,74,1660,110` | top-left in frame | `830x55` | 10 | n/a | main_frame |
| back_button | Button | back arrow/text by runtime | `2172,74,260,104` | top-right | `130x52` | 20 | normal/hover/pressed/disabled | main_frame |
| category_panel | Panel frame | left navigation | `96,220,430,1130` | left | `215x565` | 5 | n/a | main_frame |
| category_safe | VBox lane | six category buttons | `148,290,326,990` | inside category_panel | `163x495` | 15 | n/a | category_panel |
| category_button | Button | Characters/Monsters/Artifacts/Stats/Glossary/Ascension | `326x118` | stacked | `163x59` | 20 | normal/hover/pressed/active | category_safe |
| grid_panel | Panel frame | central icon/list sector | `552,220,1120,1130` | center-left | `560x565` | 5 | n/a | main_frame |
| grid_safe | Grid/List | larger icons + compact names | `626,290,972,990` | inside grid_panel | `486x495` | 15 | scroll/hover/selected | grid_panel |
| grid_icon_cell | Selection glow only | unframed icon cell | `144x144` | grid/list item | `72x72` | 20 | hover/selected | grid_safe |
| detail_panel | Panel frame | right info/description | `1700,220,764,1130` | right | `382x565` | 5 | n/a | main_frame |
| detail_safe | VBox content | title, portrait, chips, text | `1776,294,612,980` | inside detail_panel | `306x490` | 15 | scroll | detail_panel |
| detail_portrait_zone | TextureRect | selected art/icon | `1830,318,504,360` | centered top | `252x180` | 20 | n/a | detail_safe |
| detail_chip_row | HBox | tags/stat chips | `1788,704,588,88` | below portrait | `294x44` | 20 | n/a | detail_safe |
| detail_text_zone | Scroll text | description/body | `1788,824,588,430` | bottom detail | `294x215` | 20 | scroll | detail_safe |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | ---: | ---: | ---: | --- | --- |
| cg_main | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_main.png` | `2496x1387` | `70/82/70/76` | `96/106/96/92` | outer rails, corner claws, ruby pins | yes |
| cg_nav | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_nav.png` | `430x1130` | `42/58/42/54` | `52/70/52/70` | side rails, corner pins | yes |
| cg_grid | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_grid.png` | `1120x1130` | `42/58/42/54` | `74/70/74/70` | side rails, top/bottom ornaments | yes |
| cg_detail | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_detail.png` | `764x1130` | `42/58/42/54` | `76/74/76/76` | side rails, top/bottom ornaments | yes |
| cg_category_button | `assets/sprites/ui/frames/codex_glossary/ui_btn_cg_category_<state>.png` | `326x118` | `34/30/34/30` | `50/34/50/34` | caps and active left marker | yes |
| cg_back_button | `assets/sprites/ui/frames/codex_glossary/ui_btn_cg_back_<state>.png` | `260x104` | `34/26/34/26` | `48/30/48/30` | caps and bevel | yes |
| cg_grid_hover | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_grid_hover_glow.png` | `144x144` | `18/18/18/18` | `20/20/20/20` | bracket corners only | no; proportional |
| cg_entry_separator | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_entry_separator.png` | `972x6` | `8/0/8/0` | `0/0/0/0` | decorative line only | horizontal tile |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | ---: | --- | ---: | ---: | --- |
| cg_main | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_main.png` | screen shell | `2496x1387` | RGBA | `70/82/70/76` | `96/106/96/92` | replaces noisy outer shell when integrated |
| cg_nav | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_nav.png` | category panel | `430x1130` | RGBA | `42/58/42/54` | `52/70/52/70` | left column |
| cg_grid | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_grid.png` | central icon/list panel | `1120x1130` | RGBA | `42/58/42/54` | `74/70/74/70` | no item sub-card frame |
| cg_detail | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_detail.png` | right detail panel | `764x1130` | RGBA | `42/58/42/54` | `76/74/76/76` | clean text interior |
| cg_category_* | `assets/sprites/ui/frames/codex_glossary/ui_btn_cg_category_*.png` | category switch states | `326x118` | RGBA | `34/30/34/30` | `50/34/50/34` | normal/hover/pressed/active |
| cg_back_* | `assets/sprites/ui/frames/codex_glossary/ui_btn_cg_back_*.png` | shared Back button states | `260x104` | RGBA | `34/26/34/26` | `48/30/48/30` | normal/hover/pressed/disabled |
| cg_grid_hover | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_grid_hover_glow.png` | selected/hover icon glow | `144x144` | RGBA | `18/18/18/18` | `20/20/20/20` | bracket/glow only, not a heavy frame |
| cg_entry_separator | `assets/sprites/ui/frames/codex_glossary/ui_frame_cg_entry_separator.png` | subtle row divider | `972x6` | RGBA | `8/0/8/0` | `0/0/0/0` | optional for list mode |

## Responsive Rules

- Scale the complete 2560x1440 contract uniformly with `min(viewport.x / 2560, viewport.y / 1440)` and center the result.
- At 1280x720, category buttons become `163x59`, grid icon cells become `72x72`, and detail text must scroll.
- At 1920x1080, use 0.75 scale; no panel should reflow horizontally.
- At 2560x1440, use the rectangles above exactly.
- At 3840x2160, use 1.5 scale; keep frame art proportional or 9-slice only the declared centers.

## Interaction States

- Category buttons: `normal`, `hover`, `pressed`, `active`; active uses a ruby left marker.
- Back button: `normal`, `hover`, `pressed`, `disabled`.
- Central entries: no heavy framed card; use `cg_grid_hover` behind the icon and `cg_entry_separator` or runtime spacing between rows.
- Detail panel: scroll long descriptions inside `detail_text_zone`.
- Empty/loading: show placeholder icon silhouettes inside grid cells, never on frame ornament.

## Implementation Notes

- Godot scene: `CodexScreen` in `scripts/ui_screens.gd`.
- Suggested runtime theme keys: `cg_main`, `cg_nav`, `cg_grid`, `cg_detail`, `cg_category_btn`, `cg_back_btn`, `cg_grid_hover`, `cg_entry_separator`.
- Keep runtime labels/icons/portraits separate from PNG art. The generated assets contain no baked text.
- Backend should replace the current entry-card-heavy central list with a grid/list mode that uses larger `96-112px @2K` icons and compact title lines.
- Existing data builders can remain lazy/cached; this is a visual/layout handoff, not a data rewrite.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No runtime content zone overlaps frame border, ornament, gem, metal, or decorative corner.
- [x] Runtime content fits inside safe zones at every responsive target by uniform scaling.
- [x] Hover/focus/pressed/disabled states keep stable dimensions.
- [ ] Runtime screenshot comparison after Back-end integration.

## Deviations

The first generated mockup `codex_glossary_2k_mockup.png` was retained as source evidence but not accepted as the contract because the center placeholders could read as individual icon frames. The accepted contract is `codex_glossary_2k_mockup_v2.png`, which uses standalone unframed icons separated by spacing lines.

Runtime GDScript integration is intentionally not part of this Design ticket. The design package provides mockup, frame/button assets, safe-zone geometry, and backend handoff notes.
