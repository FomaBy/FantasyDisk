# UI Mockup Spec — SCRUM-1081 Main Menu bottom-corner utilities

Status: ready_for_integration
Role owner: Design main / Codex
Task: `docs/tasks/SCRUM-1081.md`
Jira: SCRUM-1081 (parent SCRUM-1080)
Base resolution: 1920×1080
Responsive matrix: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440 + live resize
Mockup PNG: `docs/design/previews/scrum1081_main_menu_bottom_corners/main_menu_bottom_corners_1920x1080.png`
Annotated PNG: `docs/design/previews/scrum1081_main_menu_bottom_corners/main_menu_bottom_corners_1920x1080_debug.png`
Generated with: accepted PixelLab/runtime source reuse + deterministic content-zone compositor; no new bitmap art

## Source request

Move the icon-only gratitude action into the lower-right utility cluster, make
it slightly larger, give it a restrained glow, and place it immediately left
of the current game version.

## Source and scope decision

This package deliberately reuses the accepted Main Menu visual family:

- Main Menu background: `assets/backgrounds/main_menu_epic_battle_v3.png`;
- title: `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png`;
- five-state action family: `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_main_menu_380x104_*.png`;
- PixelLab-lineage gold shell: `assets/sprites/ui/meta40/frame_border.png`;
- PixelLab gratitude object `c1c1c353-e56e-405b-9adf-f1e6bd993152`:
  `assets/sprites/ui/icons/credits/ui_icon_gratitude.png`.

No production bitmap is generated or modified. The preview's soft aura is only
an illustration of a bounded runtime glow. The accepted gratitude icon remains
unchanged and must be scaled proportionally; 9-slice is forbidden.

## Geometry decision

The accepted SCRUM-1059 action column and logo return to their original X at
`inner.x`; neither is shifted. The bottom-right utility cluster is composed
right-to-left: the dynamic version is right-aligned to `inner.end.x`, then a
12/16/20 px clear gap, then the bounded gratitude glow and centered icon. This
keeps both utilities visually related without covering Exit, frame ornament,
logo, or the action column.

All rectangles are viewport pixels in `(x,y,w,h)` form.

| Viewport | Inner content rect | Logo | Shifted action column | Glow bounds | Gratitude hitbox/icon | Runtime version | Version font |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1152×648 | `144,125,864,398` | `144,125,160,60` | `144,189,320,334` | `784,439,84,84` | `790,445,72,72` | `880,501,128,22` | 14 px |
| 1280×720 | `157,137,966,446` | `157,137,192,72` | `157,215,340,361` | `891,499,84,84` | `897,505,72,72` | `987,559,136,24` | 14 px |
| 1600×900 | `191,165,1218,570` | `191,165,267,100` | `191,273,360,424` | `1153,639,96,96` | `1161,647,80,80` | `1265,709,144,26` | 15 px |
| 1920×1080 | `224,193,1472,694` | `224,193,331,124` | `224,329,380,506` | `1424,791,96,96` | `1432,799,80,80` | `1536,859,160,28` | 16 px |
| 2560×1440 | `299,257,1962,926` | `299,257,480,180` | `299,457,380,646` | `1941,1067,116,116` | `1951,1077,96,96` | `2077,1151,184,32` | 18 px |

The action column is the unchanged SCRUM-1059 scenic-safe left column. Utility
cluster gaps are exactly 12 px at 648/720p, 16 px at 900/1080p, and 20 px at 2K.

## Screen elements @ 1920×1080

| ID | Type | Runtime content | Rect | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `MainMenuTitleLabel` | TextureRect | accepted FantasyDisk logo | `224,193,331,124` | inner top-left | 331×124 tier | 20 | static | authored inner |
| `MainMenuActions` | GridContainer | six accepted actions | `224,329,380,506` | inner top-left | 380×506 tier | 20 | five stable states | authored inner |
| `MainMenuGratitudeGlow` | runtime effect/style | restrained warm aura | `1424,791,96,96` | immediately left of version | 96×96 tier | 18 | normal/hover/focus/pressed/disabled | authored inner |
| `MainMenuCreditsButton` | icon-only Button | accepted gratitude icon, no face text | `1432,799,80,80` | centered in glow bounds | 80×80 tier | 20 | normal/hover/focus/pressed/disabled | gratitude glow |
| `MainMenuVersionLabel` | Label | dynamic project version | `1536,859,160,28` | inner bottom-right | 160×28 tier | 20 | static | authored inner |
| `MainMenuGoldFrame` | 9-slice visual only | accepted shell | viewport | full rect | viewport | 100 | static, mouse-ignore | root |

## Frames and safe zones

| Frame/asset | Source size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- |
| Gold shell | 1536×1024 | 160 source px per side, scaled independently | scaled rail + 24 px reserve; 32 px at 2K | entire gold rail, rosettes, corners, first reserve band | yes, `draw_center=false` |
| Gratitude icon | 256×256 RGBA | n/a | accepted source safe box `48,48,160,160`; measured alpha bbox `55,48,146,160` | source transparent padding must remain | no; proportional scale only |

The glow, hitbox, focus ring, tooltip anchor, and version glyph effects must
remain entirely inside the listed `inner` rect. Frame art is drawn last and
never receives mouse/focus input.

## Gratitude scale and glow contract

- Previous authored hitboxes were 64 / 72 / 88 px at 720p / 1080p / 2K.
- New hitboxes are 72 / 80 / 96 px: a modest +8 px at every primary tier.
- Glow bounds add 6 px per side at compact sizes, 8 px at 900–1080p, and 10 px
  at 2K. Nothing may render outside those bounds.
- Resting glow: warm muted gold, peak alpha no more than `0.18`, soft falloff,
  no hard ring and no opaque backing disc.
- Hover: peak alpha no more than `0.26`; focus keeps the existing neutral-light
  accessibility outline inside the same bounds; pressed drops to `0.13`;
  disabled drops to `0.05` and desaturates.
- State changes never resize, translate, or pulse the control. Tooltip remains
  `Благодарности`; accessibility metadata and the existing Credits callback/UI
  SFX are preserved.

## Runtime version contract

- The label text is always resolved at runtime as
  `v%s % ProjectSettings.get_setting("application/config/version", "0.0.0")`.
  A literal release number must not be baked into art or hardcoded in layout.
- `vX.Y.Z` in the deterministic preview is a placeholder for dynamic content.
- Typography is a restrained readable caption: 14 px at 648/720p, 15 px at
  900p, 16 px at 1080p, 18 px at 2K.
- Right and bottom alignment are required. Use warm-neutral silver/parchment
  `#D8D0BD` at approximately 93% opacity with a 2 px near-black outline or
  equivalent shadow. Do not add a plate, badge, ornament, or new frame.
- The label is mouse-ignoring and never receives focus.

## Responsive and live-resize rules

- Derive the gold-shell safe margins from the 1536×1024 source using half-up
  rounding, then shrink by 24 px; use 32 px reserve for height ≥1200.
- Select existing SCRUM-1059 logo/button tiers by height. Do not change button
  width, height, row gap, label fit, callbacks, or order.
- Keep action X at `inner.x`, exactly matching SCRUM-1059.
- Bottom-align glow bounds and version rect to `inner.end.y`; right-align
  version to `inner.end.x`; place glow immediately left of version by the
  tiered 12/16/20 px cluster gap.
- Recalculate all five rectangles on every live resize. No stale 2K minimum
  sizes may survive a shrink to 720p/648p.
- No scrollbar is needed.

## Focus graph

- Up/Down continues to wrap through the six action buttons in canonical order.
- Gratitude is a separate bottom-right utility: `Right` from every action enters
  Gratitude; `Gratitude.Left -> Exit`, `Gratitude.Up -> Exit`, and
  `Gratitude.Down -> Start`. `Gratitude.Right` stays on Gratitude. This preserves
  a deterministic, closed, trap-free keyboard/gamepad graph.
- Existing mouse behavior, tooltip, accessibility name/description, Credits
  callback and UI SFX do not change.

## Planning and preview evidence

- Base plan: `docs/design/mockups/scrum1081_main_menu_bottom_corners/ui_plan.json`.
- Base runtime-text layout: `docs/design/mockups/scrum1081_main_menu_bottom_corners/layout.json`.
- Per-resolution plans, reports, layout guides and reports live beside them as
  `ui_plan_<WxH>.*` and `layout_<WxH>.*`.
- All five plan reports: `decision: ready_for_image`, `ok: true`.
- All five layout guide reports: `ok: true`; the dynamic version placeholder
  fits at the fixed font tier.
- Source-reuse previews and debug overlays live in
  `docs/design/previews/scrum1081_main_menu_bottom_corners/`.

## Back-end handoff

Runtime integration belongs to SCRUM-1082. It should:

1. reuse the current `MainMenuCreditsButton`, icon, callback, tooltip,
   accessibility metadata and SFX;
2. change the size/placement and add only a bounded runtime glow;
3. keep `MainMenuActions` at its original SCRUM-1059 X and retain its accepted
   vertical tier geometry;
4. move the existing dynamic `MainMenuVersionLabel` to the bottom-right and
   apply the listed responsive typography;
5. update focus neighbors for the new spatial relationship;
6. validate the full matrix and live 2K→720p resize with no overlap.

## Acceptance checks

- [x] Content inventory and exact zones defined before preview composition.
- [x] Five planning reports are `ready_for_image / ok=true`.
- [x] Five layout guide reports are `ok=true`.
- [x] Gratitude sits immediately left of the version in a lower-right cluster.
- [x] Icon is modestly larger and glow stays inside explicit bounds.
- [x] Version is readable, dynamic, right/bottom-aligned and not baked into art.
- [x] Action column, logo, gratitude, version and frame ornament do not overlap.
- [x] Actions retain the original SCRUM-1059 X at every target.
- [x] Only accepted source assets were reused; no new bitmap art was created.
- [ ] Back-end runtime implementation and screenshot comparison.

## Deviations

SCRUM-1059 placed Gratitude in the top-right and version beside the logo. This
spec supersedes only those utility placements: Gratitude now sits immediately
left of the bottom-right version. All accepted art, action geometry, state
semantics and callbacks remain unchanged. The earlier SCRUM-1081 left-rail
proposal is superseded and must not be implemented.
