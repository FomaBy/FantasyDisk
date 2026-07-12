# SCRUM-1089 Route Map Full Fit + HUD 2× — UI Mockup Spec

Status: ready_for_integration
Role owner: Design + Back-end / Codex
Task: `docs/tasks/backend_scrum1089_route_map_full_fit_hud2x.md`
Jira: SCRUM-1089
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440
Mockup PNG: `docs/design/references/scrum1089_route_map_full_fit_hud2x/pixellab_route_map_full_fit_hud2x_688x384.png`
Preview PNG: `docs/design/previews/scrum1089_route_map_full_fit_hud2x/pixellab_route_map_full_fit_hud2x_688x384.png`
Generated with: PixelLab MCP `create_ui_asset`; source ID `a32def07-33e5-464d-a046-4967feefa4b1`

## Source Request

Reduce empty space, extend the route map vertically and horizontally toward the inner yellow frame, show the full route at once, raise the act/map/progress/current-state block, and make the HP/XP/ULT/gold HUD twice as large.

The PixelLab PNG is a textless layout reference. Runtime continues to render the existing dark backdrop, hollow gold frame, route lines and canonical map icons; the mockup's white background and abstract vertical route placeholders are not production art.

## Screen Elements @ 1920×1080

| ID | Type | Runtime content | Rect | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| route_header | `PanelContainer` | local header art under title + HUD | `224,159,1472,144` | top-left responsive matrix | matrix rect | 50 | static | outer inner zone |
| title_progress | `VBoxContainer` | act, map label, step/strength/next battle/lock state | `240,167,753,128` | left inside header | full rect | 52 | normal/debug | route_header |
| resources | `PanelContainer` | HP, XP, ULT, gold | `1012,167,668,128` | right inside header | exact 2× old visible rect, rounded to canonical HUD aspect | 54 | live values | route_header |
| route_scroll | clipped `ScrollContainer` | viewport only; both scrolling axes disabled | `240,319,1440,586` | fill route field | full rect | 20 | no-scroll | route_field |
| route_canvas | `Control` | all 9 route columns + connections | `240,319,1440,586` | exact viewport fit | exact viewport | 22 | route states | route_scroll |
| route_nodes | `Button` | canonical route icons/tooltips | 76×76 normal; 92×92 boss | distributed over canvas | declared size | 30 | locked/available/focus/selected/completed | route_canvas |
| pending_level_fab | `Button` | pending level-up count | `1584,809,80,80` | lower-right empty map corner | 80×80 | 60 | hidden/default/hover/pressed/focus | outer inner zone |
| outer_shell | hollow `Panel` | existing `meta40/frame_border.png` | full viewport | full rect | viewport | 100 | static | n/a |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture / real ornament margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- | --- |
| outer_shell | `assets/sprites/ui/meta40/frame_border.png` | 1536×1024 | side rails/corners 160; real clear top/bottom center boundary 128 | sides 160 scaled + reserve; top/bottom 128 scaled + reserve; reserve 24, or 32 at 2560×1440 | all rails, flowers, gold bands, bevels, corner transitions | existing hollow StyleBoxTexture; draw center false |
| route_header | existing `chud_resource_panel` style | reused | runtime 9-slice metadata | title/HUD rectangles above | local rail and corners | yes |
| resource_hud | `ui_hud_v2_cluster_bg.png` | existing | existing HUD v2 margins | existing HUD v2 child zones scaled uniformly | leather/gold rim | yes |

The outer shell has an irregular clear center: its corner flowers require the full 160 px source margin on X, while the central top/bottom opening begins after 128 px. Because header/map X already starts beyond the side margin, their Y can use the real 128 px boundary plus reserve without touching corner ornament. This raises content while preserving the hard frame rule.

## Generated Assets

| Asset | Path | Purpose | Size | Alpha | Runtime |
| --- | --- | --- | --- | --- | --- |
| PixelLab layout | `docs/design/references/scrum1089_route_map_full_fit_hud2x/pixellab_route_map_full_fit_hud2x_688x384.png` | textless geometry/style reference | 688×384 | RGBA | no |
| User before reference | `docs/design/references/scrum1089_route_map_full_fit_hud2x/user_reference_before.png` | requested-change evidence | 2556×1432 | RGBA | no |

No new runtime bitmap is promoted.

## Responsive Rules

- 1152×648 / 1280×720 / 1600×900: title/progress is stacked above the centered 2× HUD; node size reduces only as needed for four branches to fit.
- 1920×1080 / 2560×1440: title/progress and HUD share one raised header row.
- Canvas size always equals node viewport size; the fixed nine columns scale across the available width.
- Multi-branch columns expand 55% of the way from the old compact stack toward the maximum safe vertical spread; single nodes remain centred.
- Horizontal and vertical scroll modes are disabled and both scrollbar lanes consume zero layout space.
- All route node hitboxes, line endpoints and focus states stay inside the node viewport.
- The pending level-up FAB stays in the lower-right empty corner and must not intersect any route node.
- Exact machine-readable rectangles are in `responsive_matrix.json`.

## Interaction States

- Route nodes preserve default, locked, available, hover/focus, selected/completed and shop-revisit behavior.
- Drag still crosses the suppression threshold and must not activate a node, but the canvas does not pan because the entire route already fits.
- Mouse wheel/trackpad does not move either axis.
- Keyboard/gamepad focus remains on the current available column; no auto-scroll is needed.
- HUD remains mouse-ignore and live-updated.

## Implementation Notes

- Godot script: `scripts/route_map_screen.gd`.
- Keep `RouteMapScroll` and legacy `VerticalRouteMap` node names for compatibility.
- Publish `route_orientation=horizontal` and new full-fit metadata for focused QA.
- Allow route-only HUD scale above 1.0 so its visible rect fills the authored 2× resource zone; the canonical child geometry remains uniformly scaled.
- Update focused horizontal-route, gold-shell, header-fit and runtime smoke assertions from overflow/auto-scroll to full-fit/no-scroll.

## Acceptance Checks

- [x] Mockup generated through PixelLab MCP.
- [x] Preview shown in chat.
- [x] All visible elements and runtime states listed.
- [x] Frame texture/real ornament and content margins documented.
- [x] No content zone overlaps frame border or ornament.
- [x] Runtime content fits at every responsive target.
- [x] Hover/focus/pressed/disabled states do not shift layout.
- [x] Screenshot comparison completed at all five targets under `docs/design/previews/scrum1089_route_map_full_fit_hud2x/runtime/`.
- [x] Jira/task updated with landed commit `1c9cf28f1` and final QA handoff evidence.

## Deviations From PixelLab Reference

- Runtime retains the accepted dark backdrop instead of the mockup's white surrounding field.
- Abstract vertical placeholders become canonical square route node buttons and connection lines.
- Production shell remains `meta40/frame_border.png`; PixelLab art is not promoted.
