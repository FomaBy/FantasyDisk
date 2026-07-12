# UI Mockup Spec — Main Menu compact lower-right utility cluster

Status: implemented — SCRUM-1095 alpha-aware follow-up
Role owner: Back-end source-reuse geometry follow-up
Task: `docs/tasks/SCRUM-1095.md`
Jira: SCRUM-1095 (linked QA bug for SCRUM-1093)
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2048×1152, 2560×1440
Mockup PNG: `docs/design/previews/scrum1093_main_menu_version_corner/main_menu_bottom_corners_1920x1080.png`
Generated with: accepted PixelLab-lineage Main Menu/gold-shell/gratitude sources reused from SCRUM-1081; Gratitude PixelLab source object `c1c1c353-e56e-405b-9adf-f1e6bd993152`; no new production art

## Source request

Independent QA proved that SCRUM-1093 measured the transparent Button rectangle,
not the accepted PNG's real alpha. Its source alpha bbox is exactly
`(55,48)-(201,208)` inside `256x256`, producing visible gaps up to `42.91 px`.
Reuse the same PixelLab object without bitmap edits, crop it at runtime through
an `AtlasTexture`, and constrain the actual alpha-to-version-glyph gap to
`0..20 px` while keeping the cluster entirely off the ornament.

## Geometry contract

- `utility_anchor = frame_safe.end - Vector2(8, 8)`.
- The version rect is sized from the actual rendered version string plus 6 px
  horizontal effect reserve; it is not a fixed 128–184 px placeholder.
- `MainMenuVersionLabel` remains right/bottom aligned.
- The bounded glow ends `2 px` before the version rect; it is mouse-ignoring and
  does not overlap the version. The Button remains inside the glow and is biased
  `3 px` toward the version without touching it.
- Runtime scans the accepted image with `Image.get_used_rect()`, builds a square
  right-facing `AtlasTexture` that preserves all used alpha, and keeps the
  stable `4 px` Button content margin. For the accepted source this produces a
  `160x160` region `(41,48)-(201,208)` and alpha bbox `(14,0)-(160,160)`.
- The measurable **actual alpha edge** to version glyph gap is constrained to
  `0..20 px` at every tier, including `v0.2.10-beta`; target values are
  approximately `15/17/17/19 px` at 1280/1920/2048/2560.
- The general page `inner_rect` remains unchanged for logo/actions. The utility
  cluster uses the tighter frame-safe anchor because it is a small corner
  control with its own measured 8 px reserve.

## Elements at 1920×1080

| ID | Type | Runtime content | Rect | Z | Safe-zone parent |
| --- | --- | --- | --- | --- | --- |
| `MainMenuGratitudeGlow` | decorative `TextureRect` | procedural aura | generated `96×96`, immediately left of version | below icon | frame-safe opening |
| `MainMenuCreditsButton` | icon-only `Button` | accepted gratitude PNG via runtime alpha-aware `AtlasTexture` | generated `80×80`, 3 px right bias inside glow | controls | glow rect |
| `MainMenuVersionLabel` | `Label` | dynamic `v<application/config/version>` | exact text width + 6 px, 28 px high | controls | frame-safe opening |

Exact rectangles for every target are generated in `layout_<resolution>.json`
and `ui_plan_<resolution>.json`. The 2048×1152 target is included because the
user's screenshot exposes the large-resolution tier between 1080p and 2K.

## Frames and safe zones

| Frame | Asset | Source size | Texture margin | Utility reserve | Forbidden zones |
| --- | --- | --- | --- | --- | --- |
| Main Menu gold shell | `assets/sprites/ui/meta40/frame_border.png` | 1536×1024 | authored/scaled 160 px source safety envelope | 8 px after frame-safe opening | all gold rails, corner flowers, stepped corner notches |

The utility controls remain inside the transparent/dark opening. They may not
touch the gold rail or stepped bottom-right corner ornament.

## Responsive and interaction rules

- Icon/glow/font tiers remain the accepted SCRUM-1081 tiers; only transparent
  source padding is removed at draw time.
- Version width follows the live string on every layout and live resize.
- Hover/focus/pressed change glow alpha only; geometry is invariant.
- Callback, tooltip/accessibility metadata, UI SFX and focus graph are unchanged.
- At every target, the version right/bottom edge is exactly 8 px inside the
  frame-safe boundary and the Gratitude control sits immediately to its left.

## Assets

No new runtime asset is introduced and the PNG bytes remain unchanged. The
existing PixelLab-lineage background, gold shell and Gratitude icon are reused.
Gratitude provenance is
PixelLab object `c1c1c353-e56e-405b-9adf-f1e6bd993152`, promoted unchanged as
`assets/sprites/ui/icons/credits/ui_icon_gratitude.png` by SCRUM-1081.

## Acceptance checks

- [x] User screenshot and failure mode recorded.
- [x] Existing PixelLab-lineage page/art sources reused; no new art needed.
- [x] Exact mockup geometry defined before runtime implementation.
- [x] Frame ornament remains forbidden content space.
- [x] All six planning reports are `ready_for_image`, with zero errors/warnings.
- [x] All six runtime-text layout guide reports are `ok=true`.
- [x] Updated preview shown in chat.
- [x] Runtime screenshots match the compact mockup at the responsive matrix.
- [x] Independent alpha-edge oracle passes unchanged at four targets.
- [x] Focused, gold-shell, no-overlap, gamepad, runtime UI and full runtime gates pass.

## Previous SCRUM-1093 runtime evidence

- `docs/design/previews/scrum1093_main_menu_version_corner/runtime/main_menu_2048x1152.png`
- `docs/design/previews/scrum1093_main_menu_version_corner/runtime/main_menu_2560x1440.png`
- Windowed Metal capture passed at all six responsive targets.

## SCRUM-1095 runtime evidence

Six windowed Metal captures and exact geometry/alpha measurements are under
`docs/design/previews/scrum1093_main_menu_version_corner/runtime/`. The report
`runtime_visual_matrix.md` records `15/15/17/17/17/19 px` at
1152/1280/1600/1920/2048/2560. Visual inspection at 1280 and 2560 confirms the
accepted art remains readable, is not stretched, and stays clear of the rail.
