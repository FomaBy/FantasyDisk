# SCRUM-1057 Route Map Horizontal — UI Director Mockup Spec

Status: ready for Back-end integration; Design visual QA PASS
Role owner: Design/Codex
Jira: SCRUM-1057
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440
PixelLab source ID: `0a5d3c83-3592-430d-b733-82128c86aa5b`
PixelLab source: `docs/design/references/scrum1057_route_map_horizontal/pixellab_route_map_horizontal_688x384.png`
Preview: `docs/design/previews/scrum1057_route_map_horizontal/route_map_horizontal_composited_688x384.png`

## Source Request And Design Decision

Route Map changes from a vertical bottom-to-top route to a horizontal left-to-right journey. The start column is on the left, the boss column is on the right, steps advance by increasing X, and branches in the same step are distributed vertically. The title/progress and resource HUD are lifted 12 px at 1920×1080 relative to the accepted SCRUM-981 text baselines while remaining inside the real hollow gold-shell interior.

This Design delivery defines the art/reference layer and exact content contract only. Runtime geometry, scrolling, focus, route generation, input and tests belong to a separate Back-end handoff.

Planning gate: `ready_for_image`, `ok: true`, zero errors and warnings.
Vertical scroll: forbidden (`scroll_vertical = 0`, vertical scrollbar disabled).
Horizontal scroll: `auto`, only when authored route content width exceeds the visible node viewport.
Frame rule: every label, node, line, tooltip, scrollbar, focus outline and button stays inside the empty inner zone; no content touches the ornate outer shell or local panel rails.

## Content Inventory

- hollow outer gold shell, reused in production from SCRUM-981;
- raised Route Map header;
- live act/progress title;
- live HP / XP / gold resource HUD;
- horizontal scroll/canvas viewport;
- route connection lines behind nodes;
- dynamic battle, elite, event, shop, rest, chest and boss nodes;
- node default, available, focused/hovered, selected/completed and locked states;
- clamped hover/focus tooltip;
- bottom horizontal scrollbar lane;
- upgrade FAB with default/hover/pressed/focus/disabled states;
- drag suppression after the existing threshold;
- mouse, keyboard and gamepad focus/navigation states;
- loading/empty safeguard: calm route viewport with header/HUD retained.

## Frames And Safe Zones

The production outer frame remains `assets/sprites/ui/meta40/frame_border.png`, source size 1536×1024, `draw_center=false`. Its texture margins are 160 px on every source edge. Runtime content margins are the scaled texture margins plus the responsive internal reserve below. The PixelLab 688×384 image is a layout/style reference, not a replacement runtime 9-slice.

| Target | Frame safe rect | Inner content rect | Reserve beyond scaled frame rail |
| --- | --- | --- | --- |
| 1152×648 | `120,101,912,446` | `140,121,872,406` | 20 px |
| 1280×720 | `133,113,1014,494` | `157,137,966,446` | 24 px |
| 1600×900 | `167,141,1266,618` | `191,165,1218,570` | 24 px |
| 1920×1080 | `200,169,1520,742` | `224,193,1472,694` | 24 px |
| 2560×1440 | `267,225,2026,990` | `299,257,1962,926` | 32 px |

Forbidden zones are everything outside `frame safe rect` plus the full reserve band between `frame safe` and `inner content`. For local header/map/FAB art, their own decorative rails are also forbidden; content uses only the rectangles declared below.

## Exact Responsive Geometry

| Target | Header | Title / progress | Resource HUD | Route scroll | Node viewport | Bottom horizontal lane | FAB |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1152×648 | `140,121,872,76` | `154,125,416,54` | `666,125,332,54` | `140,209,872,318` | `158,227,740,258` | `158,497,740,14` | `922,437,72,72` |
| 1280×720 | `157,137,966,80` | `173,141,450,58` | `731,141,376,58` | `157,229,966,354` | `175,249,834,286` | `175,549,834,14` | `1033,493,72,72` |
| 1600×900 | `191,165,1218,84` | `211,169,580,62` | `965,169,424,62` | `191,265,1218,470` | `215,289,1074,392` | `215,701,1074,16` | `1313,639,72,72` |
| 1920×1080 | `224,193,1472,88` | `248,197,700,64` | `1128,197,544,64` | `224,297,1472,590` | `248,321,1328,500` | `248,845,1328,18` | `1600,791,72,72` |
| 2560×1440 | `299,257,1962,104` | `331,263,940,80` | `1557,263,672,80` | `299,385,1962,798` | `331,417,1786,694` | `331,1139,1786,20` | `2149,1071,80,80` |

Exact machine-readable values are in `responsive_matrix.json`. At 1920×1080 the old SCRUM-981 text top was y=209; the new title/HUD top is y=197, raising both by 12 px without entering the y=169..192 frame/reserve band.

## Route Topology Contract

- step/column index is the primary X axis; for every edge to a later step, destination center X is greater than source center X;
- columns are ordered start → intermediate steps → boss, left to right;
- nodes sharing a step use the same center X and separate center Y values;
- normal node authored size is 56 / 60 / 68 / 72 / 88 px for the five responsive targets; boss node size is 64 / 68 / 76 / 88 / 104 px;
- line endpoints are the exact node centers and lines render behind node art with `mouse_filter=IGNORE`;
- map content width may exceed the visible node viewport; horizontal scrollbar uses only the dedicated bottom lane;
- the rectangular node viewport intentionally ends before the FAB keep-out, so nodes, lines, tooltips and focus outlines cannot sit under the action well;
- tooltips clamp to the node viewport, never to the outer frame bounding box.

The base-plan sample uses eight columns. Its exact sample rectangles live in `ui_plan.json`; they demonstrate left-to-right monotonic X and vertically separated branches without prescribing the runtime route generator's branch count.

## Anchors, Z-Order And Node Structure

| ID | Suggested Godot node | Anchors / behavior | Z |
| --- | --- | --- | --- |
| backdrop | `TextureRect` | full rect, cover; existing Route Map backdrop | 0 |
| route_scroll | `ScrollContainer` | exact responsive rect; horizontal auto, vertical disabled | 10 |
| route_lines | mouse-ignoring `Control` draw layer | child of horizontal route canvas | 20 |
| route_nodes | `Control`/buttons | child of horizontal route canvas; above lines | 30 |
| tooltip | `PanelContainer` | clamped inside node viewport | 40 |
| route_header | `PanelContainer` | fixed above scroll; never scrolls | 50 |
| upgrade_fab | `Button` | fixed in reserved lower-right well; never scrolls | 60 |
| outer_shell | hollow `Panel`/`StyleBoxTexture` | full rect, 160 px source margins, drawn last, mouse ignore | 100 |

The Back-end implementation may use containers or direct Control rects, but the visible content rectangles, keep-outs and z-order contract must remain exact. Any necessary geometry deviation requires updating this spec first.

## Input And Interaction Contract

- default focus: first available node in the current available column;
- Left/Right: previous/next reachable step column; Up/Down: nearest node inside the current column;
- mouse drag/pan changes only horizontal scroll; after the existing drag threshold, release cannot activate a node;
- mouse wheel/trackpad should pan horizontally when pointer is over the map, without changing vertical scroll;
- focus change and map reopen auto-scroll the current available column into view with at least the local node/focus reserve;
- live resize recomputes zones and recenters the current available column without rebuilding route data;
- hover/focus/pressed/disabled art must not change node or FAB geometry;
- focus outline is inside the node/FAB safe rect and never expands onto local ornament.

## Generated Assets And Provenance

| Asset | Purpose | Size / alpha | Runtime promotion | Notes |
| --- | --- | --- | --- | --- |
| `pixellab_route_map_horizontal_688x384.png` | accepted PixelLab textless style/layout layer | 688×384 RGBA; alpha audit in manifest | no | reference only; source ID above |
| `route_map_horizontal_composited_688x384.png` | content-composited Design preview | 688×384 RGB/RGBA | no | sample live title/HUD/FAB and horizontal route topology |
| `route_map_horizontal_composited_688x384_debug.png` | content-zone QA overlay | 688×384 | no | verifies all inserted content stays inside declared zones |
| `rejected_v1_checkerboard_4f25f4c6.png` | rejected provenance | 688×384 RGBA | no | rejected because the map interior baked a checkerboard |

No new runtime bitmap is promoted by this Design phase. Back-end must continue to reuse the accepted production shell/backdrop/node icons unless a separate Design ticket explicitly replaces them.

## Responsive Acceptance Matrix

At all five targets, Back-end and QA must verify:

- title, progress and HUD remain fully inside their empty header wells;
- route nodes, lines, tooltips, focus outlines and scrollbar remain inside the map/node zones;
- `scroll_vertical == 0` and no vertical scrollbar is visible or allocated;
- horizontal scrollbar is hidden when content fits and occupies only the bottom lane when needed;
- current available column is visible on open, return and live resize;
- route data (`next_branches`, node types, rewards and act order) is unchanged;
- no overlap, clipping, ornament coverage or pointer interception by line art;
- 1152×648 remains fully usable without shrinking controls below the declared tier.

## Design Verification

- `validate_ui_layout_plan.py`: PASS, `decision=ready_for_image`, zero errors/warnings.
- `render_content_zones.py` guide fit: PASS, `ok=true`, no text overflow.
- PixelLab MCP config smoke: PASS (`get_balance`, active subscription; secrets not printed).
- PixelLab visual QA: v1 rejected for baked checkerboard; v2 PASS after full-resolution inspection — solid calm map interior, exact two header wells, bottom horizontal lane, no vertical lane or content-zone ornament intrusion.
- Runtime/Godot tests: not run by Design; required in the Back-end handoff after implementation.

Back-end handoff: Jira `SCRUM-1079`, mirror `docs/tasks/backend_scrum1079_route_map_horizontal_integration.md`.

## Deviations From SCRUM-981

- Route direction changes from vertical to horizontal.
- Header text/HUD baselines move 12 px upward at 1920×1080.
- Right-side vertical scrollbar lane is removed.
- A bottom horizontal scrollbar lane is authored.
- Node viewport ends before a dedicated lower-right FAB keep-out.
- Production outer shell and general FantasyDisk material family remain unchanged.
