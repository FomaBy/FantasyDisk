# SCRUM-981 Unified Gold Menu Shell — Design Specification

Status: ready for Back-end integration; PixelLab references accepted
Role owner: Design subtask under combined `/root` ownership
Jira: SCRUM-981
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2560×1440
Production frame: `assets/sprites/ui/meta40/frame_border.png`
Inventory: `screen_inventory.md`

## Source decision and provenance

The production frame geometry is unchanged, so runtime must reuse the accepted
`meta40/frame_border.png`; SCRUM-981 does not promote a new runtime bitmap.
Exact live provenance must not be mislabeled: the current 1536×1024
`frame_border.png` is the accepted SCRUM-832 `gpt-image-2` product-override
output (`SHA-256 a593321bd5f732d70814a35dc9f98af31a09818b6452ded1a37fba521b937c85`).
The earlier SCRUM-826 PixelLab family/source pack was accepted and then
superseded for production geometry by SCRUM-832. New SCRUM-981 page references
are generated through PixelLab MCP because Main Menu and Route Map materially
change layout. The accepted transparent sources, IDs, hashes, rejected attempts
and alpha/visual QA are recorded in the reference manifest.

## Canonical frame and safe zones

Frame source: 1536×1024. Runtime 9-slice texture margins are 160px on every
source edge. The safe rect is calculated exactly like
`_unified_safe_margins()`: X and Y are scaled independently and rounded.
An additional internal reserve is applied to content zones; it is not painted
over the frame.

| Viewport | Texture/content margins L/T/R/B | Frame safe rect | Inner content rect after reserve |
| --- | --- | --- | --- |
| 1280×720 | 133 / 113 / 133 / 113 | `Rect2(133,113,1014,494)` | `Rect2(157,137,966,446)` (24px reserve) |
| 1920×1080 | 200 / 169 / 200 / 169 | `Rect2(200,169,1520,742)` | `Rect2(224,193,1472,694)` (24px reserve) |
| 2560×1440 | 267 / 225 / 267 / 225 | `Rect2(267,225,2026,990)` | `Rect2(299,257,1962,926)` (32px reserve) |

Forbidden zones are the entire area outside the frame safe rect plus the first
internal reserve band. No label, button, icon, portrait, route node, hitbox,
scrollbar, focus outline or tooltip anchor may enter those zones. The frame is
drawn last, `draw_center=false`, `mouse_filter=IGNORE`, with 9-slice rendering;
never scale the source image as a whole.

## Shared shell template

| Viewport | Header zone | Body/scroll zone | Footer zone | Scrollbar lane |
| --- | --- | --- | --- | --- |
| 1280×720 | `157,137,966,72` | `157,225,966,255` | `157,496,966,72` | last 14px of body |
| 1920×1080 | `224,193,1472,88` | `224,301,1472,458` | `224,779,1472,88` | last 16px of body |
| 2560×1440 | `299,257,1962,104` | `299,385,1962,650` | `299,1059,1962,104` | last 18px of body |

Headers and footers never scroll. A screen without long content may omit the
scrollbar while preserving its lane as empty reserve. Local panels/cards keep
their own content margins inside the body zone.

## Main Menu authored geometry

The existing layout is unsafe for a new frame: logo `(56,44,720,270)` and
actions at `x=72` sit under the border. Integration must move them, not merely
overlay art.

| Viewport | Logo zone | Six actions | Version |
| --- | --- | --- | --- |
| 1280×720 | `157,137,460,110` | 2×3 grid: columns x=157/553, rows y=263/349/435, each 380×72, gaps 16×14 | `995,543,112,24` |
| 1920×1080 | `224,193,620,170` | 2×3 grid: columns x=224/624, rows y=387/509/631, each 380×104, gaps 20×18 | `1546,839,126,24` |
| 2560×1440 | `299,257,720,220` | 2×3 grid: columns x=299/699, rows y=509/631/753, each 380×104, gaps 20×18 | `2105,1127,124,24` |

Buttons use the existing global text-button kit; the PixelLab page reference is
textless. Focus/hover/pressed/disabled must not change these rectangles.

## Route Map authored geometry

The existing 28px edge offset is unsafe. Route nodes, lines, header, HUD and FAB
must be rebuilt inside these zones while retaining vertical pan/scroll and no
horizontal scroll.

| Viewport | Header | Title/progress | Resources | Route scroll | FAB |
| --- | --- | --- | --- | --- | --- |
| 1280×720 | `157,137,966,92` | `173,149,520,68` | `731,149,376,68` | `157,245,966,322` | `1035,479,72,72` |
| 1920×1080 | `224,193,1472,104` | `248,209,700,70` | `1128,209,544,70` | `224,317,1472,550` | `1584,779,72,72` |
| 2560×1440 | `299,257,1962,112` | `323,273,960,80` | `1573,273,664,80` | `299,393,1962,766` | `2165,1063,72,72` |

The scrollbar occupies 14/18/18px at the right edge of the route-scroll zone.
Map nodes and lines remain inside the remaining width. The HUD is contained in
the resource zone instead of starting below the header at the old 28px origin.

## Specialist/exclusion rules

- Codex remains the SCRUM-954 no-outer-frame exception; its authored stage must
  not be squeezed into this shell.
- Level Up remains the SCRUM-985 no-outer-frame exception.
- Active combat, Combat HUD, transient victory/level-up/combat-title overlays
  remain unframed.
- Event, Shop, Attribute Shop and artifact rewards stay with their more specific
  accepted/child-task contracts listed in the inventory.
- Pause dossier already uses the full frame; do not add a duplicate.
- Settings Game-tab files from SCRUM-975/SCRUM-1030 are read-only here.

## Interaction states

- Outer frame: visual only; never catches mouse or focus.
- Buttons/cards: existing global default/hover/pressed/focus/disabled art;
  geometry stays fixed.
- Main Menu focus is row-major: Start↔Settings, Atlas↔Patch Notes,
  Codex↔Exit on left/right; up/down stays in the same column and wraps. Initial
  focus remains Start; Escape/B still opens Quit confirmation.
- Scroll: vertical only where declared; scrollbar stays in its reserved lane.
- Tooltips: may extend above content only when clamped inside the frame safe rect.
- Gamepad focus: never moves a focused control under the ornament; Route Map
  follows the focused row vertically.

## Planning and validation

The five pre-generation plans all report `decision: ready_for_image`, `ok:true`,
with zero errors/warnings:

- common shell at 1280×720, 1920×1080 and 2560×1440;
- Main Menu base layout;
- Route Map base layout.

Deterministic layout guides and fit reports are under the adjacent mockup and
preview directories. No runtime files or tests are changed by this Design pass.

## PixelLab acceptance evidence

| Screen | Accepted PixelLab UI asset | Transparent source | Visual contract |
| --- | --- | --- | --- |
| Main Menu | `7d9c5262-5448-40c0-beaf-2b7d4b6b1f58` | `docs/design/references/scrum981_gold_menu_shell/pixellab_main_menu_gold_shell_reference_688x384.png` | PASS: one logo well and exactly six rectangular action wells in a 2×3 grid; no extra/circular panel. |
| Route Map | `1df5105f-5469-4a93-b93c-ebe839831ed0` | `docs/design/references/scrum981_gold_menu_shell/pixellab_route_map_gold_shell_reference_688x384.png` | PASS: two header wells, calm map interior and dedicated scrollbar lane. |

Both sources are 688×384 RGBA with real transparency (`alpha 0..255`) and no
baked checkerboard. Their deterministic content-zone overlays report `ok:true`.
The first Main Menu/Route revisions were rejected because `no_background=false`
baked a checkerboard into an opaque bitmap. Main Menu v2 was also rejected after
alpha passed because it had only four action wells plus an unrelated circular
panel. These rejected IDs and reasons remain in `manifest.json` as provenance.
