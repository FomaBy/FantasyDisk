# SCRUM-452 Minimal Metal UI Anchor Spec

Статус: ready_for_integration
Owner: Designer 2 (Codex)
Related task: `docs/tasks/design_ui_minimal_metal_anchor_task.md`

## Generated Inputs

- Style board: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_board.png`
- Frame source sheet: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_source_sheet.png`
- Style guide: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_guide.md`
- Metadata JSON: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
- Contact preview: `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`
- Safe-zone preview: `docs/design/previews/scrum452_minimal_metal_safe_zones.png`

## Runtime Asset Candidates

Root: `assets/sprites/ui/frames/minimal_metal/`

| ID | Path | Size | Texture margins | Content rect |
| --- | --- | ---: | --- | --- |
| `ui_frame_minimal_metal_modal` | `ui_frame_minimal_metal_modal.png` | `986x900` | `[46,62,46,58]` | `[72,92,842,724]` |
| `ui_frame_minimal_metal_panel` | `ui_frame_minimal_metal_panel.png` | `782x716` | `[38,52,38,48]` | `[58,72,666,578]` |
| `ui_frame_minimal_metal_card` | `ui_frame_minimal_metal_card.png` | `426x486` | `[32,42,32,40]` | `[46,58,334,374]` |
| `ui_frame_minimal_metal_tooltip` | `ui_frame_minimal_metal_tooltip.png` | `760x242` | `[46,30,46,28]` | `[66,44,628,158]` |
| `ui_frame_minimal_metal_hud_strip` | `ui_frame_minimal_metal_hud_strip.png` | `1122x288` | `[76,42,76,40]` | `[104,62,914,170]` |
| `ui_frame_minimal_metal_field` | `ui_frame_minimal_metal_field.png` | `616x286` | `[42,38,42,36]` | `[58,52,500,186]` |

Use `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
as source of truth if this table and implementation drift.

## Safe-Zone Contract

All content must fit inside the declared content rect. The following pixels are
forbidden for content placement:

- outer transparent canvas and antialiased shadow
- steel rails and brass hairlines
- bevel/corner plates
- ruby pins
- any texture margin area

Content margins must be greater than texture margins. For example, the modal
uses texture margins `[46,62,46,58]` and content margins `[72,92,72,84]`, giving
at least `22px` reserve beyond the visible metal at source scale.

## Responsive Rules

- `1280x720`: use scaled frame surfaces, but keep content inset after scaling at
  least `8px` away from the content rect line.
- `1920x1080`: default source-space proportional layout target. 9-slice generic
  frames may stretch center/fill only.
- `2560x1440`: expand layout spacing and content grids before increasing text
  size; do not make rails or rubies visually dominant.

## Implementation Notes For Back-end

- Add a distinct minimal-metal frame path set, or promote this kit only after
  accepted review. Do not silently replace SCRUM-273 button assets.
- Keep SCRUM-273 Red & Gold buttons live until SCRUM-450 provides accepted
  button replacements.
- Keep Hero Select v3 authored frames, progression nodes and combat bar fills
  screen-specific unless SCRUM-451 explicitly migrates them.
- Run runtime UI smoke and no-overlap matrix after integration. Design did not
  run those because this package contains source/spec/assets only.

