# UI Mockup Spec - Weapon Select Redraw From Scratch

Status: implemented
Role owner: Back-end
Task: `docs/tasks/codex_weapon_select_redraw_from_scratch_task.md`
Jira: SCRUM-870
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/weapon_select_redraw_from_scratch/pixellab_weapon_select_redraw_mockup.png`
Preview PNG: `docs/design/previews/weapon_select_redraw_from_scratch_pixellab_mockup.png`
Generated with: PixelLab MCP `create_ui_asset`; source UI asset ID `ecd9f24e-b8a6-4a54-a824-f0f4d5a59505`

## Source Request

The user rejected the SCRUM-868 live result and asked to redraw Weapon Select from scratch: the previous screen was too dark, unreadable, visually confused, and relied on a stretched full-screen image layer behind live text.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `MenuPanel_weapon_select` | PanelContainer | live Weapon Select shell | `360,120,1840,1200` | center | `1840x1200` | 20 | static | viewport |
| `MenuTitle_weapon_select` | Label | `Выбор оружия` | inside panel top | fill width | one line | 30 | static | `MenuPanel_weapon_select` |
| `MenuSubtitle_weapon_select` | Label | selected class prompt | under title | fill width | one line | 30 | static | `MenuPanel_weapon_select` |
| `WeaponOption_*` | Button card | one weapon option | `443,350,1674,260`, step `274` | stacked vertical | `1674x260` | 30 | normal/hover/focus/pressed | `MenuPanel_weapon_select` |
| `WeaponSelectIconWell_*` | PanelContainer | icon well frame | card left | left center | `204x204` | 35 | static | `WeaponOption_*` |
| `WeaponSelectSprite_*` | TextureRect | weapon PNG | inside icon well | centered | `176x176` | 40 | static | `WeaponSelectIconWell_*` |
| `WeaponSelectTitle_*` | Label | weapon title | card center top | fill center | one line | 45 | static | `WeaponOption_*` |
| `WeaponSelectIdentity_*` | Label | `Отличие: ...` | card center | fill center | two lines | 45 | static | `WeaponOption_*` |
| `WeaponSelectDescription_*` | Label | concise mechanic summary | card center | fill center | two lines | 45 | static | `WeaponOption_*` |
| `WeaponSelectRole_*` | Label | archetype + mode + scaling | card center bottom | fill center | one line | 45 | static | `WeaponOption_*` |
| `WeaponSelectStatsPanel_*` | VBoxContainer | stat chips | card right | right center | `310x204` | 40 | static | `WeaponOption_*` |
| `WeaponSelectStats_*` | Label | compact stat lines | inside stat panel | fill | `280x0` | 45 | static | `WeaponSelectStatsPanel_*` |
| `WeaponSelectBackButton` | Button | `Назад` | bottom center | center bottom | `280x60` | 30 | normal/hover/focus/pressed | `MenuPanel_weapon_select` |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| `weapon_select_panel` | runtime `StyleBoxFlat` dark shell | runtime | `3px border` | `56/44/56/40` | outer bevel/border | no |
| `weapon_select_card` | runtime `StyleBoxFlat` dark card | runtime | `2px border` | `22/18/22/18` | card border/glow | no |
| `weapon_select_icon_well` | runtime `StyleBoxFlat` icon well | runtime | `2px border` | `12/12/12/12` | well border/corners | no |
| `weapon_select_stat_chip` | runtime `StyleBoxFlat` stat chip | runtime | `1px border` | `12/8/12/8` | chip border | no |
| `WeaponSelectBackButton` | existing text button style | `280x60` | existing button metadata | existing button safe zone | button border/ornament | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `scrum870_weapon_select_redraw_mockup` | `docs/design/mockups/weapon_select_redraw_from_scratch/pixellab_weapon_select_redraw_mockup.png` | page/layout reference | `688x384` | RGBA | n/a | visual safe zones only | PixelLab source `ecd9f24e-b8a6-4a54-a824-f0f4d5a59505`; not used as a stretched runtime layer |

## Responsive Rules

- 1280x720: panel/card geometry scales through the existing centered menu-box path; cards keep `1674x260` source-space proportions scaled by viewport. Text uses `_readable_font_size` caps and concise mechanic summary to avoid clipping.
- 1920x1080: same source-space layout, with larger readable labels and `176x176` source-space weapon art scaled with the UI.
- 2560x1440: base geometry is exact source-space layout.

## Interaction States

- Button/card hover: brighter gold border and warmer dark fill, no layout shift.
- Button/card pressed: darker fill, no layout shift.
- Disabled/locked: not used on Weapon Select; if introduced, use muted dark fill and gray-gold border.
- Selected/focus: same geometry as hover, stronger gold border.
- Empty/loading: not expected; no card is shown without a weapon config.

## Implementation Notes

- Godot scene: runtime-built in `scripts/ui_screens.gd::_show_weapon_select()`.
- Node structure: `MenuPanel_weapon_select` -> title/subtitle -> three `WeaponOption_*` cards -> `WeaponSelectBackButton`.
- Runtime text/icon containers: every label/icon is a live Godot Control. No player-facing text is baked into image assets.
- The bad SCRUM-868 `WeaponSelectPixelLabRuntimeLayer` must not be created, rendered, or asserted by tests.

## Acceptance Checks

- [x] Mockup generated through PixelLab MCP.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner.
- [x] Runtime content fits inside safe zones at every responsive target covered
  by `tests/ui_no_overlap_matrix_test.gd`.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [x] Screenshot capture attempted after implementation; current headless dummy
  renderer reports `viewport image unavailable`, so automated rect/style
  assertions are the acceptance evidence.
- [x] Task/Jira updated when applicable.

## Deviations

- The PixelLab mockup is a visual contract and provenance artifact, not a live full-screen runtime layer. The previous SCRUM-868 approach used a stretched art layer behind text and produced unreadable output; SCRUM-870 intentionally rebuilds the live screen as native Godot controls with textless, high-contrast runtime surfaces.
