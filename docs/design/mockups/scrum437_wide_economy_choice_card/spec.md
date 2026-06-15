# UI Mockup Spec - SCRUM-437 Wide Economy Choice Cards

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/bug_economy_choice_card_too_narrow_widen_frame_task.md`
Jira: SCRUM-437
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/scrum437_wide_economy_choice_card/scrum437_wide_option_card_mockup.png`
Preview PNG: `docs/design/previews/scrum437_wide_economy_choice_card_safe_zone.png`
Layout preview: `docs/design/previews/scrum437_wide_economy_choice_card_1280_layout_preview.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

SCRUM-437 fixes reward/event/upgrade/rest option-card frames that are too narrow
for long Russian title/description/action text. Design scope prepares a wider
transparent card frame/source and exact safe-zone contract; Back-end owns runtime
layout, constants, smoke and no-overlap matrix.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| economy_panel | PanelContainer | screen title/story/reward context + row | `360,150,1200,780` | center | `960x600` | 20 | default | economy_panel content |
| wide_choice_0 | Button/card | title, description, action label | `294,500,420,300` | centered row | `360x240` | 30 | default/hover/focus/pressed/disabled | wide_choice_card |
| wide_choice_1 | Button/card | title, description, action label | `750,500,420,300` | centered row | `360x240` | 30 | default/hover/focus/pressed/disabled | wide_choice_card |
| wide_choice_2 | Button/card | title, description, action label | `1206,500,420,300` | centered row | `360x240` | 30 | default/hover/focus/pressed/disabled | wide_choice_card |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| wide_choice_card | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` | `960x640` | `96,88,96,96` | `132,118,132,128` | ruby corners, top/bottom crests, side ornaments, metal rails | yes, StyleBoxTexture/NinePatchRect |
| wide_choice_card_hover | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide_hover.png` | `960x640` | `104,96,104,104` | `140,126,140,136` | glow edge, ruby corners, top/bottom crests, side ornaments, metal rails | yes, same runtime rect as base |

The base safe rect is `Rect2(132, 118, 696, 394)`. Runtime title, description,
action label, focus ring and click/focus content must stay inside that rect or
the scaled equivalent. The whole Button hit area may cover the full card, but
visible runtime content may not sit on border art.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mockup | `docs/design/mockups/scrum437_wide_economy_choice_card/scrum437_wide_option_card_mockup.png` | OpenAI full-screen style reference | `1920x1088` | opaque mockup | n/a | n/a | Treat bottom 8px as bleed; exact geometry is in this spec |
| frame_source | `docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_option_card_frame_source.png` | OpenAI generated isolated card source | `1344x896` | opaque source | n/a | n/a | Alpha-cleaned into runtime-ready assets |
| wide_choice_card | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` | wide option-card frame | `960x640` | RGBA transparent exterior | `96,88,96,96` | `132,118,132,128` | Do not replace old path until Back-end updates constants |
| wide_choice_card_hover | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide_hover.png` | hover/focus card frame | `960x640` | RGBA transparent exterior with glow | `104,96,104,104` | `140,126,140,136` | Same display size as base |
| metadata | `docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_economy_choice_card_metadata.json` | source/margins contract | json | n/a | n/a | n/a | Back-end integration source of truth |
| validation | `build/qa/scrum437/scrum437_asset_validation.md` | Design QA notes | md | n/a | n/a | n/a | Confirms alpha-clean, sizes, backup |

Old narrow economy card PNGs are backed up in
`docs/design/backups/scrum437_economy_choice_card/` as PNG-only copies with
`.gdignore`; no `.import` sidecars were copied.

## Responsive Rules

- 1280x720: use `360x240` cards with `24px` row gap. Three cards total
  `1128px`, leaving `76px` side slack in a 1280 viewport. If event text still
  needs more vertical space, use a horizontal `ScrollContainer` or increase card
  height up to `280px`; do not reduce content margins.
- 1920x1080: use `420x300` cards with `36px` row gap. Three cards total
  `1332px`, leaving generous panel/context space.
- 2560x1440: use `480x340` cards with `48px` row gap. Three cards total
  `1536px`; increase gaps/background breathing room before stretching ornament.
- For 2-card rest screens, cards may be `420x300` at 720p and `480x340` at
  1080p+ because the row has more horizontal budget.

## Interaction States

- Hover/focus: swap to `ui_frame_economy_choice_card_wide_hover.png` or use the
  same path with neutral-bright tint. The card rect must not resize.
- Pressed: use hover frame with a subtle darker tint; no layout shift.
- Disabled: desaturate content and tint the base frame, keeping text inside
  safe rect and preserving readability.
- Selected/focus ring: draw inside the content safe rect or use hover frame.

## Implementation Notes

- Godot owner: Back-end UI in `scripts/ui_screens.gd`.
- Suggested new constants:
  - `ECONOMY_CHOICE_WIDE_CARD_PATH`
  - `ECONOMY_CHOICE_WIDE_CARD_HOVER_PATH`
  - `ECONOMY_CHOICE_WIDE_SOURCE_SIZE := Vector2(960.0, 640.0)`
  - `ECONOMY_CHOICE_WIDE_TEXTURE_MARGINS := Vector4(96.0, 88.0, 96.0, 96.0)`
  - `ECONOMY_CHOICE_WIDE_CONTENT := Vector4(132.0, 118.0, 132.0, 128.0)`
  - `ECONOMY_CHOICE_WIDE_HOVER_TEXTURE_MARGINS := Vector4(104.0, 96.0, 104.0, 104.0)`
  - `ECONOMY_CHOICE_WIDE_HOVER_CONTENT := Vector4(140.0, 126.0, 140.0, 136.0)`
- Apply to `_show_rest_screen`, `_show_upgrade_screen`, `_show_event_screen` and
  attribute offers that need long interpretation text. Existing reward frames in
  `assets/sprites/ui/frames/rewards/` remain separate and should not be replaced
  by this economy card.
- Replace the old narrow `Vector2(250..300, 300..390)` economy card display
  sizes with responsive wide sizes. Use containers/scroll fallback on 1280x720
  rather than squeezing the frame.
- Runtime labels remain Godot nodes; do not bake text into art.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview generated for safe-zone and 1280 layout.
- [x] Every frame has texture margins and content margins.
- [x] Old narrow card PNGs backed up without `.import` sidecars.
- [x] No Design/runtime content is assigned to frame borders, ornaments, gems,
  metal, or decorative corners.
- [ ] Back-end updates `scripts/ui_screens.gd` constants/display sizes.
- [ ] Back-end verifies event/rest/upgrade/attribute screens on
  `1280x720`, `1920x1080`, `2560x1440`.
- [ ] Back-end runs `tests/ui_no_overlap_matrix_test.gd`,
  `tests/runtime_smoke_ui_test.gd` and `tests/runtime_smoke_test.gd`.

## Deviations

The generated full-screen mockup is used as a visual family reference, not exact
geometry, because the isolated generated frame source provided the cleaner
wide-card contract. The exact runtime geometry is defined by the preview/spec
above and the metadata JSON.
