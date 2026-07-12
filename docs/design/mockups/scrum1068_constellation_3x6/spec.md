# SCRUM-1075 — Atlas schema-6 3×6 UI Director spec

Status: `ready_for_integration`
Role owner: Design
Jira: SCRUM-1075; implementation parent: SCRUM-1068
Base geometry: 1920×1080
PixelLab source request: 688×384, seed 1075
Responsive targets: 1152×648, 1280×720, 1366×768, 1600×900,
1920×1080, 2560×1440, 3840×2160 and same-instance live resize
PixelLab source: `fde7794d-9f82-404c-8006-213e281a931a`,
`scrum1075_constellation_3x6_atlas_mockup`, seed `1075`, 688×384.
Mockup base: `atlas_schema6_base_1920x1080.png`.
Preview/debug: `../../previews/scrum1068_constellation_3x6/atlas_schema6_preview_1920x1080.png`
and adjacent debug overlay.

## Source decision

SCRUM-1068 continues to reuse the accepted Meta40 production art kit. This
Design task requests a new PixelLab source-only page mockup because the accepted
SCRUM-832/SCRUM-971 images do not define the schema-6 topology. No production
redraw or runtime asset promotion is required.

Planning was complete before art generation. `ui_plan.report.json` says
`ready_for_image`, with 47 elements and no errors or warnings. The exact MCP
request remains frozen in `pixellab_request.json`; the accepted PixelLab job
used it without geometry changes.

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

## PixelLab source and assembly

The replenished account reported 2836 generations before the run. PixelLab MCP
completed source ID `fde7794d-9f82-404c-8006-213e281a931a` for 40 generations.
The raw 688×384 export is retained unchanged for provenance. PixelLab baked its
checker matte into the export, so `postprocess_pixellab_source.py` removes only
the light neutral matte connected to the canvas edge, preserves the generated
panels, and assembles them over the accepted Meta40 `bg_sky.png` underlay.

MCP `agent_help` confirms that `create_ui_asset` produces individual UI
elements rather than a true full-screen compositor and recommends assembling
those generated elements in an editor. The deterministic postprocess follows
that contract: it adds no new frame, card, border or ornament. All visible UI
surfaces remain PixelLab-generated; runtime copy is added only through
`preview_layout.json` inside measured calm interiors.

## QA result

- planning gate: 47 elements, 0 errors, 0 warnings;
- preview renderer: 15/15 zones fit, report `ok: true`;
- responsive fit: 7/7 PASS at 1152×648 through 3840×2160;
- full repository runtime smoke through `tools/godot_gate.py`: PASS on Godot
  4.7;
- no content/frame intersection in the debug overlay;
- exact topology visible: one core, three equal six-socket rays, two side
  spurs, no keystone toggle;
- no runtime or production asset changes.
