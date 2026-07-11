# UI Mockup Spec — SCRUM-1059 Main Menu single left column

Status: ready_for_integration
Role owner: Back-end/Codex
Task: `docs/tasks/SCRUM-1059_main_menu_single_left_column.md`
Jira: SCRUM-1059
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440
Mockup PNG: `docs/design/previews/scrum1059_main_menu_column/main_menu_single_column_1920x1080.png`
Generated with: accepted PixelLab/runtime source reuse + deterministic content-zone compositor; no new art generation

## Source request

Replace the 2×3 Main Menu action grid with six actions in one left vertical
column while preserving the accepted background, logo, gold shell, button
family, callbacks/states and separate icon-only gratitude button.

## Content inventory

- accepted FantasyDisk logo;
- six action buttons, in canonical top-to-bottom order;
- patch-notes unread dot inside the fourth button label;
- separate gratitude icon-only button with tooltip/accessibility;
- version label;
- hollow gold frame drawn last;
- no scroll surface and no scrollbar.

## Authored geometry

All coordinates are viewport pixels. `Inner` is the real content zone after the
scaled 160px frame rail plus an additional 24px reserve (32px at 2K).

| Viewport | Inner | Logo | Action column | Each button / gap | Gratitude | Version |
| --- | --- | --- | --- | --- | --- | --- |
| 1152×648 | `144,125,864,398` | `144,125,160,60` | `144,189,320,334` | `320×54 / 2` | `944,125,64,64` | `320,146,112,18` |
| 1280×720 | `157,137,966,446` | `157,137,192,72` | `157,215,340,361` | `340×56 / 5` | `1059,137,64,64` | `365,164,112,18` |
| 1600×900 | `191,165,1218,570` | `191,165,267,100` | `191,273,360,424` | `360×64 / 8` | `1337,165,72,72` | `474,205,126,20` |
| 1920×1080 | `224,193,1472,694` | `224,193,331,124` | `224,329,380,506` | `380×76 / 10` | `1624,193,72,72` | `571,245,126,20` |
| 2560×1440 | `299,257,1962,926` | `299,257,480,180` | `299,457,380,646` | `380×96 / 14` | `2173,257,88,88` | `795,335,124,24` |

## Frames and safe zones

| Frame/asset | Source | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- |
| Fullscreen shell | `assets/sprites/ui/meta40/frame_border.png`, 1536×1024 | 160 each source px, scaled independently to viewport | texture-safe rect + 24px reserve; +32px at 2K | complete gold rail, corners, dragon ornaments | yes, center transparent/draw-center false |
| Action plate | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_main_menu_380x104_*.png` | registered main-menu family margins | runtime family text insets | caps, bevel, corner gems | yes |
| Gratitude icon | `assets/sprites/ui/icons/credits/ui_icon_gratitude.png`, 256×256 | n/a | source safe box 48,48,160,160 | transparent source padding remains intact | no; proportional only |

## Responsive and interaction rules

- Column x and logo x always equal the authored inner-zone left edge.
- Height tiers are exact: `<700`, `<800`, `<1000`, `<1200`, `≥1200`; compact
  widths 320/340/360 keep the compact column readable while the hero faces and
  silhouettes remain visible to the right.
- Six buttons remain visible without scrollbars; labels never enter end caps.
- Normal/hover/focus/pressed/disabled keep identical rectangles.
- Up/Down wraps through the six actions in order. Right from any action reaches
  gratitude; Left/Down from gratitude returns to Start; Up on gratitude returns
  to Exit. The graph has no dead end or self-only trap.
- Mouse, keyboard, gamepad, callbacks, SFX and unread-dot behavior are unchanged.
- Live resize recomputes logo, column, button tier, gratitude and version.

## Source/provenance

- Background: accepted production `main_menu_epic_battle_v3.png`.
- Logo: accepted production `main_menu_title_fantasy_disk.png`.
- Gold shell: accepted PixelLab source lineage from SCRUM-981, source ID
  `7d9c5262-5448-40c0-beaf-2b7d4b6b1f58` and production `frame_border.png`.
- Gratitude: PixelLab object `c1c1c353-e56e-405b-9adf-f1e6bd993152` from
  SCRUM-1050, production `ui_icon_gratitude.png`.
- Action family: accepted production `main_menu_380x104` five-state kit.
- PixelLab account lacked enough panel generations during SCRUM-1050. This
  task therefore follows its recorded `existing source reuse` exception;
  no OpenAI Images, built-in generation, legacy generator or hand-drawn art.

## Acceptance checks

- [x] Geometry planned before runtime implementation.
- [x] Five plan reports are `decision: ready_for_image`, `ok: true`.
- [x] No scrollbars are required.
- [x] All content zones fit inside the real authored inner zone.
- [x] Mockups use only accepted existing art and add no new decorative frames.
- [x] Runtime Metal screenshots match materially at all five targets.
- [x] Focus/state/live-resize tests pass.

## Deviations

The previously accepted 2×3 action wells are intentionally not reused as a
page layout because SCRUM-1059 supersedes that geometry. The underlying
production background, logo, shell, action plates and gratitude icon are reused
unchanged.
