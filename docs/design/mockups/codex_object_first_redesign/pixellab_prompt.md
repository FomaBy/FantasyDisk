# SCRUM-849 PixelLab Mockup Prompt

Jira: SCRUM-849
PixelLab UI asset id: `e55602bb-9328-4427-bbad-f3df60aa1e82`
Mode: `ui-panel`
Output: `688x384`, 16:9 reference scaled to `1920x1080` in `spec.md`
Seed: `84901`

## Prompt

Textless full-screen pixel-art game UI mockup for FantasyDisk Codex redesign,
Dungeons and Dragons dark fantasy dragon library style, object-first layout. One
unified dark library background with restrained dragon-scale texture. Left
vertical category navigation with six empty ornate button capsules, no letters.
Center overview panel with one prominent object image frame and short-summary
parchment zone, no text. Right detail panel with the largest object image frame
on screen above a scroll-safe parchment reading zone, no text. Minimal
meaningful frames only, no nested decorative clutter, thin aged brass
separators, smoky parchment interiors, empty content zones clearly separated
from borders, dragon claw corner accents outside content zones, no watermark, no
baked labels, no readable text.

Palette: obsidian black, smoked parchment, aged brass, muted ruby accents, dark
leather.

Elements: window, panel, button, tab.

## Piece Plan

Virtual canvas: `512x288`.

| ID | Kind | Rect / Shape | Purpose |
| --- | --- | --- | --- |
| screen_shell | rounded_rect | `8,8,496,272 r10` | full-screen Codex shell |
| title_strip | rounded_rect | `28,18,456,24 r6` | empty top title strip |
| left_nav_panel | rounded_rect | `22,50,104,206 r7` | category rail |
| nav_btn_1..6 | rounded_rect | `34,66/96/126/156/186/216,80,22 r6` | six empty category buttons |
| center_panel | rounded_rect | `142,50,158,206 r7` | selected/list overview |
| center_image_frame | rounded_rect | `162,66,118,92 r6` | center object image safe zone |
| center_summary_zone | rounded_rect | `156,172,130,58 r6` | short summary safe zone |
| right_detail_panel | rounded_rect | `316,50,174,206 r7` | full detail panel |
| right_large_image_frame | rounded_rect | `338,64,130,102 r6` | largest object image safe zone |
| right_text_scroll_zone | rounded_rect | `334,178,138,56 r6` | detail text scroll safe zone |
| back_button | rounded_rect | `32,260,76,18 r5` | back button |

## Notes

- The first generation attempt at `688x387` was rejected by PixelLab because the
  maximum 16:9 height for width `688` is `384`.
- Runtime text must not be baked into the mockup or production assets.
