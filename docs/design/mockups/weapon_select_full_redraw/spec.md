# UI Mockup Spec - Weapon Select Full Redraw

Status: implemented
Role owner: Design + Back-end combined Codex scope
Task: `docs/tasks/codex_design_weapon_select_full_redraw_task.md`; runtime apply: `docs/tasks/codex_weapon_select_pixellab_runtime_apply_task.md`
Jira: SCRUM-867; SCRUM-868
Base resolution: 2560x1440
Responsive targets: 1152x648, 1280x720, 1536x864, 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_mockup.png`
Preview PNG: `docs/design/previews/weapon_select_full_redraw_pixellab_mockup.png`
Runtime layer PNG: `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_runtime_layer_2560x1440.png`
Generated with: PixelLab MCP `create_ui_asset`; source UI asset ID: `67e5f56a-aaa6-4216-814a-7f5301132fea`

## Source Request

Fully redraw Weapon Select for every character: make the interface larger, make all card copy fit, always show what is distinctive about each weapon, make the differences obvious, and slightly enlarge the weapon image.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WeaponSelectPixelLabRuntimeLayer` | TextureRect | textless PixelLab panel/card/back art | `0,0,2560,1440` | full viewport | `2560x1440` | 9 | static | viewport |
| `MenuPanel_weapon_select` | PanelContainer | screen frame | `360,120,1840,1200` | centered | `1840x1200` | 10 | static | viewport |
| `MenuTitle_weapon_select` | Label | `Выбор оружия` | `443,242,1674,60` | top inside panel | content width | 20 | static | `ws_panel` |
| `MenuSubtitle_weapon_select` | Label | selected class title + instruction | `443,314,1674,32` | below title | content width | 20 | static | `ws_panel` |
| `WeaponOption_*` | Button card | one weapon option | first `443,374,1674,240`; step `254` | stacked vertical | `1674x240` | 30 | normal/hover/focus/pressed | `ws_panel` |
| `WeaponSelectSprite_*` | TextureRect | weapon icon | inside card left well, `150x150` | left center | `150x150` | 40 | static | `ws_card` |
| `WeaponSelectTitle_*` | Label | weapon title | card center top | fill center | one line | 45 | static | `ws_card` |
| `WeaponSelectIdentity_*` | Label | `Отличие: ...` from `ProgressionData.weapon_mechanic_identity` | card center | fill center | two lines | 45 | static | `ws_card` |
| `WeaponSelectDescription_*` | Label | data description | card center | fill center | two lines | 45 | static | `ws_card` |
| `WeaponSelectRole_*` | Label | archetype + mode + class scaling | card center bottom | fill center | one line | 45 | static | `ws_card` |
| `WeaponSelectStats_*` | Label | archetype, range/radius, cooldown, limit/control/damage | card right column | right center | `350px` wide | 45 | static | `ws_card` |
| `WeaponSelectBackButton` | Button | `Назад` | `1140,1234,280,60` | bottom center | `280x60` | 30 | normal/hover/focus/pressed | `ws_panel` |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Runtime size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ws_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_panel.png` | `1720x1060` | `1840x1200` | source `38,52,38,48`, scaled by runtime size | source `78,96,78,66`, scaled by runtime size | outer metal/ornament/corners | yes |
| `ws_card` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_card.png` | `1564x190` | `1674x240` | source `32,42,32,40`, scaled by runtime size | source `48,35,48,32`, scaled by runtime size | card border/corners/gems | yes |
| `ws_btn_back` | text-button family `pause_280x60` | `280x60` | `280x60` | metadata from `TEXT_BUTTON_UNIQUE_MARGINS` | metadata from `TEXT_BUTTON_UNIQUE_CONTENT` | button bevel/border | yes |

SCRUM-868 runtime note: the visible `ws_panel`, `ws_card`, and lower Back
ornament are now supplied by `WeaponSelectPixelLabRuntimeLayer`. The
`MenuPanel_weapon_select`, `WeaponOption_*`, and `WeaponSelectBackButton`
controls use transparent StyleBoxFlat hit areas with hover/focus/pressed tint
overlays to avoid double-framing. The 9-slice assets listed above remain the
SCRUM-867 geometry/source reference and are still used by other/shared flows
where explicitly routed.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `pixellab_weapon_select_mockup` | `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_mockup.png` | page mockup / visual direction | `688x384` | transparent background | n/a | visible empty zones | PixelLab UI asset source `67e5f56a-aaa6-4216-814a-7f5301132fea`; not a runtime asset |
| `pixellab_weapon_select_runtime_layer` | `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_runtime_layer_2560x1440.png` | live textless runtime layer | `2560x1440` | transparent background | n/a | same `WS_*_2K` content zones | SCRUM-868 derived only from accepted PixelLab mockup; no non-PixelLab fallback |

## Responsive Rules

- 1152x648 / 1280x720: same 2K source-space layout scaled by project viewport; card text uses capped readable font sizes and two-line identity/description guards.
- 1536x864 / 1920x1080: readable font scale reaches normal target; card heights remain fixed relative to the panel so focus/hover states cannot shift layout.
- 2560x1440 / 3840x2160: panel remains centered; `ws_card` 9-slice center stretches while borders remain in texture margin bands.

## Interaction States

- Button/card hover and focus reuse `ws_card` with neutral hover tint.
- Pressed card uses the current warm pressed tint.
- Disabled state uses the current desaturated tint.
- Back button keeps the `pause_280x60` text-button family.
- Focus order remains weapon cards top-to-bottom, then Back.

## Implementation Notes

- Godot scene/script: `scripts/ui_screens.gd`.
- Runtime keeps `_show_weapon_select()` flow and `_wire_run_ui_focus()` behavior.
- Runtime text is not baked into the PixelLab art. SCRUM-868 renders the
  derived textless PixelLab layer behind live labels/icons/buttons.
- Distinctive weapon copy is data-driven through `ProgressionData.weapon_mechanic_identity(character_id, weapon_id)`.
- Stats copy is concise and always includes range/radius and cooldown, plus a final context line for summon limit, control or damage multiplier.

## Acceptance Checks

- [x] Mockup generated through PixelLab MCP.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content is intentionally placed on frame border, ornament, gem, metal, or decorative corner.
- [x] Runtime content is designed to fit inside safe zones at every responsive target.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [x] Visual QA evidence captured as accepted textless PixelLab preview; runtime screenshot capture was attempted but is blocked by the current headless dummy renderer (`viewport image unavailable` for all screens).
- [x] Task/Jira updated with final test evidence.

## Deviations

- The PixelLab MCP UI generator exported a 688x384 mockup layer for this aspect
  ratio. SCRUM-868 derives a 2560x1440 runtime layer from that accepted PNG so
  the live screen visibly uses the PixelLab panel/card art while retaining the
  exact SCRUM-867 source-space geometry documented above.
- First PixelLab pass `0b72096d-9f7a-44ef-b29e-f9ad75193e4c` was rejected because it baked readable text into the mockup. Final source `67e5f56a-aaa6-4216-814a-7f5301132fea` is the textless accepted pass.
