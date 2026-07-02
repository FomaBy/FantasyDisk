# UI Mockup Spec - Level-Up Toast

Status: implemented
Role owner: Design
Task: SCRUM-588
Jira: SCRUM-588
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/mockups/scrum588_levelup_toast/mockup.png`
Preview PNG: `docs/design/previews/scrum588_levelup_toast_safe_zone.png`
Generated with: OpenAI Images API via fantasydisk-ui-director / fantasydisk-asset-generator

## Source Request

Redesign the transient level-up toast as an @2K UI element. The toast must be
compact, generated before integration, and must not place text, icons, sparkles,
or other content on frame ornament. Current runtime places the single `Level Up`
text callout inside this HUD toast frame; the world-space `LevelUpEffect` is only
a sparkle/ring burst and does not draw a separate plaque.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| level_up_toast_overlay | Control | transient full-rect root | 0,0,2560,1440 | full rect | viewport | hud layer | visible/fading | viewport |
| level_up_toast_frame | PanelContainer | generated toast frame | centered 190px above player screen position, 480x300 | player position + `Vector2(0,-190)`; fallback viewport center | 480x300 | first child | visible/fading at max alpha 0.70 | viewport |
| level_up_toast_label | Label | `Level Up` text | inside frame content rect `70,112,340,76` | top-left within toast root | content rect | above sparkles | visible/fading | level_up_toast_frame safe rect |
| toast_flash | Sprite2D | small additive gold flash | center of frame content rect | center | 54x54 approx | over frame | pop/fade | level_up_toast_frame |
| toast_ring | Sprite2D | small additive cyan ring | center of frame content rect | center | 76x76 max | over frame | expand/fade | level_up_toast_frame |
| toast_sparks | Sprite2D[] | small additive sparkles | start at content center, travel <=46px diameter | radial inside content rect | 6x6 approx | over frame | travel/fade | level_up_toast_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| level_up_toast_frame | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` | 480x300 | L58 T48 R58 B48 | L70 T112 R70 B112 | outer metal border, side blades, top/bottom ruby crests, gold rails, corner claws | yes |

The safe content rect is `Rect2(70, 112, 340, 76)` in the visible frame band.
The label rect, sprite center, and initial sparkle positions must stay inside
this rect. No runtime text or badge is drawn by `LevelUpEffect`.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lut_mockup | `docs/design/mockups/scrum588_levelup_toast/mockup.png` | OpenAI mockup/source board | 2560x1440 | opaque mockup | n/a | visual safe-zone intent | Shows compact framed toast near combat focus |
| lut_frame_source | `docs/design/references/scrum588_levelup_toast/ui_frame_2k_lut_toast_source.png` | OpenAI frame source | 1536x1024 | generated source | source-scaled | source-scaled | No baked text/icons |
| lut_frame_alpha | `docs/design/references/scrum588_levelup_toast/ui_frame_2k_lut_toast_alpha.png` | alpha-cleaned source/runtime copy | 480x300 | transparent RGBA | L58 T48 R58 B48 | L70 T112 R70 B112 | Checkerboard/matte removed |
| lut_frame_runtime | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` | runtime StyleBoxTexture frame | 480x300 | transparent RGBA; edge alpha 0 | L58 T48 R58 B48 | L70 T112 R70 B112 | Registered as `lut_toast` |

## Responsive Rules

- 1280x720: root remains full-rect; frame is centered on the player screen position in logical UI space and must remain within the viewport.
- 1920x1080: same logical layout, scaled by the project canvas rules.
- 2560x1440: base @2K target; `LevelUpToastFrame` is 480x300 with content rect `340x76`, centered above the player by `190px`.
- 3840x2160: uniform upscale; no `TextureRect STRETCH_SCALE` is used because the frame is a `StyleBoxTexture`.
- If no player is available, the toast falls back to viewport center.

## Interaction States

- Visible: spawned by `_show_level_up_toast()` when the player levels up; max opacity is `0.70` so the callout is about 30% transparent.
- Hidden: self-cleans after fade-out and emits `finished`.
- Input: `mouse_filter = IGNORE`; no hover/pressed/focus states.
- Text/badge: one runtime `LevelUpToastLabel` with `Level Up` centered inside
  the frame safe rect. `LevelUpEffect` remains textless.

## Implementation Notes

- Godot scene: `scenes/LevelUpToast.tscn`.
- Runtime script: `scripts/level_up_toast.gd`.
- Theme registry: `scripts/ui/ui_theme_paths.gd::OVERHAUL_2K_FRAME_*["lut_toast"]`.
- Tests: `tests/level_up_toast_smoke_test.gd`, plus `level_up_toast` section in `tests/ui_no_overlap_matrix_test.gd` and runtime UI smoke coverage.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner by spec/test.
- [x] Runtime content fits inside safe zones at every responsive target.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [x] Screenshot/preview comparison completed after implementation.
- [x] Task/Jira updated when applicable.

## Deviations

The generated source frame is extremely wide, so the runtime asset preserves it
inside a 480x300 transparent slot. The visible safe rect is intentionally narrow:
the `Level Up` label is centered in this band and the separate world-space badge
path is disabled to avoid duplicate plaques.
