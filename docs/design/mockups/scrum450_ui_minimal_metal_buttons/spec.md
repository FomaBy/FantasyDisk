# SCRUM-450 Minimal Metal Button Kit Spec

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/design_ui_minimal_buttons_from_references_task.md`
Jira: SCRUM-450
Base resolution: asset native sizes from SCRUM-273/SCRUM-263/SCRUM-264
Responsive targets: 1280x720, 1920x1080, 2560x1440
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

Create a beautiful minimal-metal FantasyDisk button kit from the existing
button references. Use obsidian/brass and warplate iron as the main style
sources, with rare ruby accents from the crimson/gold reference. Preserve all
button sizes and states needed by the runtime. Do not bake text.

## Mockup / Source PNGs

- Source sheet: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_source_sheet.png`
- Contact preview: `docs/design/previews/scrum450_minimal_metal_button_contact.png`
- Safe-zone preview: `docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`

## Generated Assets

Root: `assets/sprites/ui/frames/minimal_metal_buttons/`

Every type has `normal`, `hover`, `pressed`, `focus` and `disabled` PNG states.
Use
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
as source of truth for exact paths, sizes, texture margins and content rects.

| Type | Size | 9-slice | Texture margins | Content rect |
| --- | ---: | --- | --- | --- |
| `ui_btn_minimal_metal_standard` | `420x104` | yes | `[50,28,50,28]` | `[64,32,292,40]` |
| `ui_btn_minimal_metal_max` | `560x104` | yes | `[58,28,58,28]` | `[72,32,416,40]` |
| `ui_btn_minimal_metal_main_menu` | `380x104` | yes | `[48,28,48,28]` | `[62,32,256,40]` |
| `ui_btn_minimal_metal_hero_confirm` | `320x104` | yes | `[42,28,42,28]` | `[56,32,208,40]` |
| `ui_btn_minimal_metal_reset_audio` | `420x104` | yes | `[50,28,50,28]` | `[64,32,292,40]` |
| `ui_btn_minimal_metal_reset_bindings` | `440x104` | yes | `[50,28,50,28]` | `[64,32,312,40]` |
| `ui_btn_minimal_metal_codex_tab` | `170x104` | yes | `[34,28,34,28]` | `[48,32,74,40]` |
| `ui_btn_minimal_metal_back_s` | `170x104` | yes | `[34,28,34,28]` | `[48,32,74,40]` |
| `ui_btn_minimal_metal_back_m` | `280x104` | yes | `[42,28,42,28]` | `[56,32,168,40]` |
| `ui_btn_minimal_metal_back_l` | `380x104` | yes | `[48,28,48,28]` | `[62,32,256,40]` |
| `ui_btn_minimal_metal_attr_selector` | `560x104` | yes | `[58,28,58,28]` | `[72,32,416,40]` |
| `ui_btn_minimal_metal_fab` | `50x50` | fixed | `[12,12,12,12]` | `[15,15,20,20]` |
| `ui_btn_minimal_metal_utility` | `54x42` | fixed | `[12,10,12,10]` | `[15,12,24,18]` |
| `ui_btn_minimal_metal_pause` | `280x60` | yes | `[34,16,34,16]` | `[46,18,188,24]` |
| `ui_btn_minimal_metal_rebind` | `420x62` | yes | `[34,16,34,16]` | `[46,18,328,26]` |

## Safe-Zone Contract

Runtime text, icons, focus hit areas and click affordances must stay inside
`content_rect_xywh`. Button side caps, bevels, rails, center ruby pins, side
ruby pins and back-arrow ornaments are forbidden content zones.

Hover/focus/pressed/disabled states must not change runtime min size, anchors or
container layout. Focus may use `_focus` if Back-end exposes a dedicated state;
otherwise keep current runtime focus tint semantics and treat `_focus` as a
future-ready candidate.

## Responsive Rules

- 1280x720: preserve existing SCRUM-263/SCRUM-264 min heights. Do not squeeze
  104px action buttons below their accepted height.
- 1920x1080: use native source sizes or 9-slice center stretch for wide buttons.
- 2560x1440: cap wide visual buttons at current runtime maximums; do not stretch
  caps/rubies into long strips.

## Implementation Notes

- Add a distinct minimal-metal button path set, or promote it only after review.
- Keep SCRUM-273 Red & Gold buttons available as backup/rollback until QA passes.
- Existing hover/focus behavior after SCRUM-318 uses neutral tint and no yellow
  glow. If the runtime continues tint-based hover, use normal PNG + tint rather
  than forcing `_hover` everywhere.
- Do not apply action-button art to route nodes, shop item hit areas, hero
  thumbnails, weapon cards or reward cards that intentionally behave as cards.

## Acceptance Checks

- [x] OpenAI source sheet generated.
- [x] 75 transparent RGBA production PNGs generated.
- [x] All assets audit at `white_opaque_pixels=0`.
- [x] Texture/content margins are documented.
- [x] Runtime integration and smokes are handed off to Back-end.

