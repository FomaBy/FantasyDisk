# SCRUM-452 Minimal Metal UI Anchor

Статус: ready_for_integration
Владелец: Designer 2 (Codex)
Дата: 2026-06-17

## Цель

SCRUM-452 задаёт опорный визуальный язык серии упрощения интерфейса: строгий
минимал-металлик вместо тяжёлого орнамента. Направление использует тёмную
сталь, обсидиановую внутреннюю плоскость, тонкие латунные рейки и редкие
рубиновые пины. Рубины являются точечным акцентом, а не декором по периметру.

SCRUM-273 Red & Gold buttons не заменяются этим пакетом. Кнопки остаются
отдельным каноном до SCRUM-450.

## Источники

- OpenAI style board: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_board.png`
- OpenAI frame source sheet: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_source_sheet.png`
- Production RGBA frame candidates: `assets/sprites/ui/frames/minimal_metal/`
- Source-candidate copies: `docs/design/references/ui_minimal_metal/frames_raw/`
- Metadata: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
- Alpha audit: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_alpha_audit.md`
- Contact preview: `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`
- Safe-zone preview: `docs/design/previews/scrum452_minimal_metal_safe_zones.png`
- UI-director spec mirror: `docs/design/mockups/scrum452_ui_minimal_metal/spec.md`

The OpenAI source sheets are visual direction references. The production
candidates are deterministic RGBA redraws derived from that direction so the
runtime handoff has strict alpha, margins and safe-zone metadata.

## Visual Rules

- Palette: graphite/obsidian fill, dark steel rails, aged brass hairlines, rare
  deep ruby pins. No white trim, no cream glow, no opaque white source pixels.
- Ornament density: almost none. Corner plates and gems must read as functional
  metal hardware, not fantasy filigree.
- Frame shape: rectangular/chamfered dark metal surfaces with thin rails.
- Center: quiet dark readable surface with enough contrast for text but no
  decorative texture competing with content.
- Ruby usage: one top-center pin for compact frames, two top-corner pins for
  large frames, or side pins on horizontal strips. Do not repeat rubies around
  the whole perimeter.

## Hard Content Rule

Runtime content, text, icons, portraits, controls, hit areas, hover highlights
and focus outlines may live only inside `content_rect_xywh` from metadata.
Texture margins, brass rails, bevels, dark corner plates and ruby pins are
forbidden zones. If a surface is non-rectangular or authored as a whole image,
Back-end must use the declared safe rects rather than the PNG bounding box.

## Production Frame Atoms

| ID | Size | Texture margins L/T/R/B | Content rect x/y/w/h | Role |
| --- | ---: | --- | --- | --- |
| `ui_frame_minimal_metal_modal` | `986x900` | `[46,62,46,58]` | `[72,92,842,724]` | Large modal/window frame |
| `ui_frame_minimal_metal_panel` | `782x716` | `[38,52,38,48]` | `[58,72,666,578]` | Generic inner panel |
| `ui_frame_minimal_metal_card` | `426x486` | `[32,42,32,40]` | `[46,58,334,374]` | Reward/event/upgrade card |
| `ui_frame_minimal_metal_tooltip` | `760x242` | `[46,30,46,28]` | `[66,44,628,158]` | Tooltip/small message panel |
| `ui_frame_minimal_metal_hud_strip` | `1122x288` | `[76,42,76,40]` | `[104,62,914,170]` | Long HUD/resource strip |
| `ui_frame_minimal_metal_field` | `616x286` | `[42,38,42,36]` | `[58,52,500,186]` | Field/selector/tab slot |

All six PNGs are RGBA and audit at:

- `white_opaque_pixels=0`
- `pale_visible_pixels_after_cleanup=0`
- `pale_edge_visible_pixels=0`

## Responsive Guidance

- Use `StyleBoxTexture` or `NinePatchRect` with the declared texture margins for
  generic panels/cards/tooltips/HUD strips.
- Use content margins equal to or greater than the declared content margins.
- At `1280x720`, reserve at least `8px` additional runtime spacing between a
  content node and the content rect edge after scale.
- At `1920x1080`, keep the same normalized layout and scale frame surfaces
  proportionally or through 9-slice; do not stretch authored corner/gem areas.
- At `2560x1440`, add whitespace to content layout before scaling text beyond
  established UI sizes; frame rails remain thin and calm.

## Series Split

- SCRUM-452: this anchor, style guide, generic minimal-metal frame candidates
  and Back-end integration handoff.
- SCRUM-450: beautiful minimal-metal buttons from user references, including
  idle/hover/pressed/disabled states.
- SCRUM-451: rollout pass for all non-button frames after SCRUM-452 and
  SCRUM-450 are accepted.

