# UI Mockup Spec - SCRUM-332 Shop And Economy Nodes

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/art_ui_overhaul_shop_economy_task.md`
Jira: SCRUM-332
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/scrum332_shop_economy/scrum332_economy_cluster_mockup.png`
Reference mockup PNG: `docs/design/references/ui_overhaul_shop_economy/scrum332_economy_cluster_mockup.png`
Frame kit preview: `docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

SCRUM-332 covers the economy node UI cluster: merchant shop, attribute shop,
rest/campfire, upgrade selection, and event choices. The visual direction is a
unified D&D + Dark Fantasy Dragon UI family with dark metal, leather/parchment,
ruby gems, restrained gold accents, and strict empty content zones inside every
frame.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| shop_backdrop | TextureRect | `screen_shop_background` / merchant archive | `0,0,1920,1080` | full | `1280x720` | 0 | default | viewport |
| shop_header | Label group | title + short hint | `580,96,760,92` | top center | `520x72` | 20 | default | viewport |
| shop_item_zone | Control | four item slots | `384,356,1152,500` | center | `720x320` | 20 | default | backdrop calm center |
| shop_slot_0 | Button/card | item icon + affinity mark + price | `484,392,256,256` | zone relative | `184x184` | 30 | default/hover/disabled/purchased/focus | shop_item_zone |
| shop_slot_1 | Button/card | item icon + affinity mark + price | `788,392,256,256` | zone relative | `184x184` | 30 | default/hover/disabled/purchased/focus | shop_item_zone |
| shop_slot_2 | Button/card | item icon + affinity mark + price | `484,672,256,256` | zone relative | `184x184` | 30 | default/hover/disabled/purchased/focus | shop_item_zone |
| shop_slot_3 | Button/card | item icon + affinity mark + price | `788,672,256,256` | zone relative | `184x184` | 30 | default/hover/disabled/purchased/focus | shop_item_zone |
| shop_tooltip_region | Tooltip frame | hovered item description/effects | `1076,666,640,260` | bottom/right of item zone | `480x210` | 35 | hidden/visible | economy_tooltip |
| shop_leave_button | Button | back/leave action | `780,930,360,104` | bottom center | `260x104` | 40 | default/hover/pressed/focus | red_gold_back_m |
| attribute_panel | PanelContainer | title, money, 2 stat offers, reroll, skip | `520,190,880,700` | center | `720x560` | 20 | default | economy_panel |
| attribute_offer_0 | Choice card/button | stat icon, class interpretation, price | `648,320,250,330` | panel grid | `210x270` | 30 | default/hover/disabled/focus | economy_choice_card |
| attribute_offer_1 | Choice card/button | stat icon, class interpretation, price | `1022,320,250,330` | panel grid | `210x270` | 30 | default/hover/disabled/focus | economy_choice_card |
| attribute_reroll_button | Button | reroll action + remaining count | `690,710,540,92` | panel bottom | `360x82` | 30 | default/hover/disabled | red_gold_standard |
| attribute_skip_button | Button | skip action | `780,824,360,92` | panel bottom | `260x82` | 30 | default/hover/pressed | red_gold_back_m |
| rest_panel | PanelContainer | campfire title + 2 choices | `480,182,960,716` | center | `720x560` | 20 | default | economy_dragon_panel or economy_panel |
| rest_choice_heal | Choice card/button | heal option | `610,318,300,390` | panel grid | `240x300` | 30 | default/hover/focus | economy_choice_card |
| rest_choice_guard | Choice card/button | guard option | `1010,318,300,390` | panel grid | `240x300` | 30 | default/hover/focus | economy_choice_card |
| upgrade_panel | PanelContainer | upgrade title + 3 rewards | `420,180,1080,730` | center | `820x560` | 20 | default | economy_panel |
| upgrade_choice_0 | Choice card/button | reward icon/title/description | `530,310,260,400` | panel grid | `220x310` | 30 | default/hover/focus | economy_choice_card |
| upgrade_choice_1 | Choice card/button | reward icon/title/description | `830,310,260,400` | panel grid | `220x310` | 30 | selected/hover/focus | economy_choice_card_hover |
| upgrade_choice_2 | Choice card/button | reward icon/title/description | `1130,310,260,400` | panel grid | `220x310` | 30 | default/hover/focus | economy_choice_card |
| event_panel | PanelContainer | event art/story + 2-3 choices | `360,150,1200,780` | center | `860x600` | 20 | default | economy_panel |
| event_story_art | TextureRect | event illustration/backdrop crop | `550,246,820,210` | panel top | `560x150` | 25 | default | event_panel content |
| event_choice_0 | Choice card/button | option 1 | `490,538,270,315` | panel grid | `220x260` | 30 | default/hover/focus | economy_choice_card |
| event_choice_1 | Choice card/button | option 2 | `825,538,270,315` | panel grid | `220x260` | 30 | default/hover/focus | economy_choice_card |
| event_choice_2 | Choice card/button | option 3 | `1160,538,270,315` | panel grid | `220x260` | 30 | default/hover/focus | economy_choice_card |
| upgrade_fab | Button | open attribute shop when allowed | `1790,900,64,64` | bottom right | `50x50` | 60 | default/hover/disabled | existing FAB |
| run_hud | HUD strip | HP/XP/gold summary | `28,28,560,70` | top left | `420x58` | 60 | default | existing HUD |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| economy_panel | `assets/sprites/ui/frames/economy/ui_frame_economy_panel.png` | `1024x640` | `80,80,84,82` | `112,112,116,118` | corner gems, top/bottom crests, side metal | yes |
| economy_choice_card | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card.png` | `512x768` | `72,106,72,112` | `104,152,104,164` | top crest/gem, side gems, bottom jewel | proportional or vertical 9-slice only after QA |
| economy_choice_card_hover | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_hover.png` | `512x768` | `76,110,76,116` | `110,158,110,170` | glow border, top crest/gem, side gems, bottom jewel | proportional or vertical 9-slice only after QA |
| economy_dragon_panel | `assets/sprites/ui/frames/economy/ui_frame_economy_dragon_panel.png` | `1024x512` | irregular | content rect `Rect2(258,92,646,308)` | left dragon head/neck/wing, right wing, crest, bottom gem | no full-frame 9-slice |
| economy_price_badge | `assets/sprites/ui/frames/economy/ui_frame_economy_price_badge.png` | `256x96` | `44,28,44,28` | `66,34,66,34` | ruby center ornaments and side caps | proportional |
| economy_tooltip | `assets/sprites/ui/frames/economy/ui_frame_economy_tooltip.png` | `640x320` | `58,58,58,70` | `82,74,82,92` | corner gems, pointer notch, top crest | yes |

For existing shop item slots, Back-end may either keep the current
`assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` / `_hover.png` pair or
map square slots to a future dedicated square frame. SCRUM-332 generated
`economy_choice_card` for modal choices; do not squash it into a square shop slot.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cluster_mockup | `docs/design/mockups/scrum332_shop_economy/scrum332_economy_cluster_mockup.png` | five-screen layout reference | `1920x1088` | opaque mockup | n/a | n/a | Use as visual direction, not runtime asset |
| frame_asset_sheet | `docs/design/references/ui_overhaul_shop_economy/scrum332_economy_frame_asset_sheet.png` | OpenAI source sheet | `1792x1024` | opaque with baked checkerboard | n/a | n/a | Alpha-cleaned by `tools/build_scrum332_shop_economy_assets.py` |
| economy_panel | `assets/sprites/ui/frames/economy/ui_frame_economy_panel.png` | modal panel | `1024x640` | RGBA transparent outside | `80,80,84,82` | `112,112,116,118` | Reference copy under `docs/design/references/ui_overhaul_shop_economy/runtime_assets/` |
| economy_choice_card | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card.png` | choice card | `512x768` | RGBA transparent outside | `72,106,72,112` | `104,152,104,164` | For attribute/rest/upgrade/event choices |
| economy_choice_card_hover | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_hover.png` | choice card hover/focus | `512x768` | RGBA transparent outside | `76,110,76,116` | `110,158,110,170` | Keep same runtime rect as base |
| economy_dragon_panel | `assets/sprites/ui/frames/economy/ui_frame_economy_dragon_panel.png` | campfire/rest feature panel | `1024x512` | RGBA transparent outside | irregular | `Rect2(258,92,646,308)` | Whole-image/proportional only |
| economy_price_badge | `assets/sprites/ui/frames/economy/ui_frame_economy_price_badge.png` | gold/price badge | `256x96` | RGBA transparent outside | `44,28,44,28` | `66,34,66,34` | Small numeric labels only |
| economy_tooltip | `assets/sprites/ui/frames/economy/ui_frame_economy_tooltip.png` | shop/event tooltip | `640x320` | RGBA transparent outside | `58,58,58,70` | `82,74,82,92` | Pointer notch is forbidden content zone |

## Responsive Rules

- 1280x720: scale panel/card grids by `0.6667`; keep minimum card content text
  inside content margins. If three choice cards do not fit with at least `24px`
  gaps, use a horizontal `ScrollContainer` or reduce card display size
  proportionally, never overlap frame ornaments.
- 1920x1080: use the base rectangles above. Cards have `40px`+ gaps; bottom
  buttons remain `104px` high for Red & Gold action buttons.
- 2560x1440: scale whole layouts by `1.3333` up to max panel width `1440px`.
  Keep backgrounds full-cover and increase gaps rather than stretching individual
  ornate assets on only one axis.

## Interaction States

- Button/slot hover: swap to hover frame when available or use neutral-bright
  tint per SCRUM-318. Hover state must keep the same rect as default.
- Button/slot pressed: use existing Red & Gold pressed states for action buttons;
  choice cards may use hover frame plus slight tint, no layout shift.
- Disabled/locked: desaturate icon/content and keep price badge red/disabled;
  do not hide the frame.
- Selected/focus: use hover frame or thin inner highlight within content zone.
- Empty/loading: use dark inner field and a small center icon/text only inside
  content rect.

## Implementation Notes

- Godot scene/script owner: Back-end UI (`scripts/ui_screens.gd`).
- Design-owned paths are ready under `assets/sprites/ui/frames/economy/`.
- Suggested mapping:
  - `_show_attribute_shop`, `_show_rest_screen`, `_show_upgrade_screen`,
    `_show_event_screen`: use `economy_panel` + `economy_choice_card`.
  - `_show_shop_screen`: keep direct-on-background item layout; optional tooltip
    uses `economy_tooltip`, price badge uses `economy_price_badge`.
  - `RestScreen`: may use `economy_dragon_panel` as a feature panel only if
    content starts at x>=258 source-space.
- Runtime text, icons, prices, and click/focus hitboxes must be separate Godot
  nodes, never baked into art.
- If Back-end needs square item slots in the new family, create a follow-up
  Design generation for a dedicated `256x256` shop slot rather than squeezing
  `economy_choice_card`.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible cluster elements are listed in the elements table.
- [x] Every generated frame has texture margins and content margins.
- [x] Generated assets are alpha-cleaned into runtime `assets/` and reference copies.
- [x] No UI content is assigned to frame borders, ornaments, gems, metal, or decorative corners.
- [x] Responsive target rules are documented for `1280x720`, `1920x1080`, `2560x1440`.
- [ ] Runtime screenshot comparison is pending Back-end integration.
- [ ] UI no-overlap/runtime smoke is pending Back-end integration.

## Deviations

- The OpenAI mockup was auto-corrected to `1920x1088`; treat the bottom 8px as
  bleed and implement against `1920x1080`.
- The generated source sheet baked a checkerboard background; the deterministic
  builder removes light low-saturation checker pixels and writes transparent
  PNGs. This is recorded in the generated assets table.
- SCRUM-332 is Design-scope in this pass. Runtime wiring is intentionally left
  for Back-end because `scripts/ui_screens.gd` owns live layouts, focus, escape
  actions, shop purchase behavior, and route advancement.
