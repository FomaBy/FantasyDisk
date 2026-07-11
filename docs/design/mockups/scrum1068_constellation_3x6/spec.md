# SCRUM-1075 — Atlas schema-6 3×6 UI Director spec

Status: `blocked_before_generation`  
Role owner: Design  
Jira: SCRUM-1075; implementation parent: SCRUM-1068  
Base geometry: 1920×1080  
PixelLab source request: 688×384, seed 1075  
Responsive targets: 1152×648, 1280×720, 1366×768, 1600×900,
1920×1080, 2560×1440, 3840×2160 and same-instance live resize  
Mockup/preview: unavailable until PixelLab credits/generations are replenished.

## Source decision

SCRUM-1068 continues to reuse the accepted Meta40 production art kit. This
Design task requests a new PixelLab source-only page mockup because the accepted
SCRUM-832/SCRUM-971 images do not define the schema-6 topology. No production
redraw or runtime asset promotion is required.

Planning is complete before art generation. `ui_plan.report.json` says
`ready_for_image`, with 47 elements and no errors or warnings. The exact MCP
request is frozen in `pixellab_request.json`.

## Content inventory and base rectangles

| Region | Rect @ 1920×1080 | Contract |
| --- | --- | --- |
| real Atlas safe area | 200,145,1520,790 | all live content stays here |
| header | 220,160,1480,56 | class `x/20` and Guild tab |
| class selector rail | 220,232,120,570 | existing scrollable class list |
| graph | 360,232,890,570 | one core, three rays, 20 purchasable nodes |
| dossier | 1280,232,400,400 | weapon final title/body/cost/buy |
| progress/legacy | 1280,642,400,160 | `20/20`, optional compact badge, hidden status |
| footer | 200,831,1520,104 | fixed reset plate left, separate legend right |

The graph uses the exact rectangles in `ui_plan.json`: one 80×80 free core;
three weapon-owned rays named `МЕЧ`, `СЕКИРА`, `МОЛОТ`; six sockets per ray,
with a 64×64 final at each endpoint; and two 56×56 optional hidden side-spur
sockets attached to the outer rays. All three finals have equal hierarchy and
remain simultaneously active for their owning weapons. There is no keystone
activation control.

## Safe zones and forbidden ornament

- Outer source frame: accepted `assets/sprites/ui/meta40/frame_border.png`,
  1536×1024, source rail 160 px.
- Runtime content inset: horizontal `160 × viewport_w / 1536`; vertical
  `160 × viewport_h / 1024 × 0.86`.
- No label, socket, connector hitbox, tooltip, dossier content, progress badge,
  legend or reset action may touch the frame rails, corner rosettes, gold trim,
  gems or any PixelLab ornament.
- Tooltip is transient and clipped to the graph interior; it never expands the
  graph or covers the outer frame.
- PixelLab must leave every named panel interior and socket center empty, calm
  and text-free. Runtime text remains separate.

## Responsive rules

1. Recompute the accepted frame-safe rect from viewport dimensions on every
   resize; never scale from a stale previous rect.
2. Header, selector, graph, dossier and progress panels use normalized anchors
   relative to the real safe rect. The graph keeps its three-ray aspect and
   equal final hierarchy; node centers scale, socket hit targets have a 44 px
   minimum.
3. The class rail remains scrollable. The graph, dossier and footer never gain
   a scrollbar.
4. SCRUM-1070 reset plate remains exactly 420 px wide and uses heights 72 when
   viewport height `<760`, 88 when `<1000`, otherwise 104. Family remains
   `text/standard_420x104`, texture margins 54/21/54/21 and content margins
   71/21/71/21.
5. Footer bounds remain the accepted safe-rect bottom band. The spacer absorbs
   width; legend stays right-aligned and never intersects the reset plate.
6. Compact 1152×648/1280×720 tiers reduce graph/dossier typography to declared
   minima, not below; optional legacy badge may collapse to an icon+tooltip.
7. Same-instance live resize must update safe margins, frame 9-slice margins,
   graph node centers, label rects, dossier width and footer tier without
   rebuilding the focused reset button.

## Interaction states

- Socket: hidden, revealed-available, purchased, final-ready and focus states;
  revealed hidden nodes are not active until explicitly purchased.
- Click selects a preview only; the dossier Buy action performs the purchase.
- All three purchased finals display ready state simultaneously; no toggle.
- Reset keeps pointer/gamepad focus, tooltip, confirmation Cancel/Confirm and
  class-vs-Guild full-refund scopes from SCRUM-1070.

## PixelLab blocker

PixelLab MCP is reachable and authenticated. At generation attempt the account
reported `$0.00` credits and 3 subscription generations remaining. The MCP
describes `create_ui_asset` as a 20–40-generation job and rejected this request
for insufficient generations or credits. Per UI Director policy no OpenAI,
built-in, manual or legacy fallback was used.

Resume only after PixelLab capacity is replenished. A successful continuation
must add source asset ID/name/seed/export, source PNG, composited preview, debug
overlay and seven-size fit report before this spec may become
`ready_for_integration`.
