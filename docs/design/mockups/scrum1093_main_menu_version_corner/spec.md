# UI Mockup Spec — Main Menu compact lower-right utility cluster

Status: implemented
Role owner: Back-end source-reuse geometry follow-up
Task: `docs/tasks/bug_scrum1093_main_menu_version_corner_spacing_task.md`
Jira: SCRUM-1093
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2048×1152, 2560×1440
Mockup PNG: `docs/design/previews/scrum1093_main_menu_version_corner/main_menu_bottom_corners_1920x1080.png`
Generated with: accepted PixelLab-lineage Main Menu/gold-shell/gratitude sources reused from SCRUM-1081; Gratitude PixelLab source object `c1c1c353-e56e-405b-9adf-f1e6bd993152`; no new production art

## Source request

The user's large-resolution screenshot shows the version floating too far from
the lower-right yellow frame and an oversized visual gap between the Gratitude
icon and the visible version glyphs. Move the compact cluster closer to the real
frame opening while keeping it entirely off the ornament.

## Geometry contract

- `utility_anchor = frame_safe.end - Vector2(8, 8)`.
- The version rect is sized from the actual rendered version string plus 6 px
  horizontal effect reserve; it is not a fixed 128–184 px placeholder.
- `MainMenuVersionLabel` remains right/bottom aligned.
- The bounded glow ends 4 px before the version rect; the icon remains centered
  inside the glow. The visible icon-to-text gap therefore contains only the
  4 px cluster gap, glow inset and the label's 6 px effect reserve.
- The measurable hitbox-to-version-glyph gap is constrained to `0..20 px` at
  every tier, including a future prerelease string (`v0.2.10-beta`).
- The general page `inner_rect` remains unchanged for logo/actions. The utility
  cluster uses the tighter frame-safe anchor because it is a small corner
  control with its own measured 8 px reserve.

## Elements at 1920×1080

| ID | Type | Runtime content | Rect | Z | Safe-zone parent |
| --- | --- | --- | --- | --- | --- |
| `MainMenuGratitudeGlow` | decorative `TextureRect` | procedural aura | generated `96×96`, immediately left of version | below icon | frame-safe opening |
| `MainMenuCreditsButton` | icon-only `Button` | accepted gratitude PNG | generated `80×80`, centered in glow | controls | glow rect |
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

- Icon/glow/font tiers remain the accepted SCRUM-1081 tiers.
- Version width follows the live string on every layout and live resize.
- Hover/focus/pressed change glow alpha only; geometry is invariant.
- Callback, tooltip/accessibility metadata, UI SFX and focus graph are unchanged.
- At every target, the version right/bottom edge is exactly 8 px inside the
  frame-safe boundary and the Gratitude control sits immediately to its left.

## Assets

No new runtime asset is introduced. The existing PixelLab-lineage background,
gold shell and Gratitude icon are reused unchanged. Gratitude provenance is
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
- [x] Focused and full runtime tests pass.

## Runtime evidence

- `docs/design/previews/scrum1093_main_menu_version_corner/runtime/main_menu_2048x1152.png`
- `docs/design/previews/scrum1093_main_menu_version_corner/runtime/main_menu_2560x1440.png`
- Windowed Metal capture passed at all six responsive targets.
