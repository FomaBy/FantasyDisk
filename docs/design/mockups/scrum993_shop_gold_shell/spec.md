# UI Mockup Spec — SCRUM-993 Shop Gold Shell

Status: Stage 1 ready for review; runtime integration waits for SCRUM-981 lock release
Role owner: combined Design + Back-end `/root/scrum993_shop_design`
Task: `docs/tasks/SCRUM-993_shop_gold_shell.md`
Jira: SCRUM-993
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2560×1440
Production frame reuse: `assets/sprites/ui/meta40/frame_border.png`
Production background reuse: `assets/backgrounds/ui/ui_backdrop_merchant_archive.png`
PixelLab reference: `docs/design/references/scrum993_shop_gold_shell/pixellab_shop_gold_shell_688x384.png`

## Source request

Join `ShopScreen` to the accepted SCRUM-981 gold-edge family while preserving
the complete merchant archive illustration. The result must remain an illustrated
shop, not a large opaque modal. Four products, captions, icons, prices,
purchased/unaffordable states, tooltip, run resources, upgrade FAB and Back must
stay readable, clickable and outside every frame ornament.

## Production asset decision

This task deliberately reuses two accepted production assets rather than
redrawing them:

- `frame_border.png` is the exact shared shell required by SCRUM-981. Source
  1536×1024; runtime 9-slice texture margins and content margins are 160px on
  every source edge; center is not drawn (`draw_center=false`). Its historical
  provenance is the accepted SCRUM-832 `gpt-image-2` product override. This is
  existing-source reuse, not a new OpenAI generation in SCRUM-993.
- `ui_backdrop_merchant_archive.png` is the canonical Shop art, RGBA 2560×1440,
  fully opaque and exact 16:9. SCRUM-993 must not replace, repaint or crop it.

The new PixelLab asset is a textless full-page layout/style reference for this
exact composition. It is not promoted to `assets/` and cannot replace either
canonical production image.

## Frame, background and safe rectangles

The shell geometry is inherited exactly from SCRUM-981. Texture/content margins
are independently scaled from the 1536×1024 source and rounded. Runtime content
uses an additional 24px reserve at 720p/1080p and 32px at 1440p.

| Viewport | Frame safe rect | Inner content rect | Non-cropped visible backdrop rect |
| --- | --- | --- | --- |
| 1280×720 | `Rect2(133,113,1014,494)` | `Rect2(157,137,966,446)` | `Rect2(201,113,878,494)` |
| 1920×1080 | `Rect2(200,169,1520,742)` | `Rect2(224,193,1472,694)` | `Rect2(300,169,1320,742)` |
| 2560×1440 | `Rect2(267,225,2026,990)` | `Rect2(299,257,1962,926)` | `Rect2(400,225,1760,990)` |

Background rule:

1. Clip the background layer to the frame safe rect.
2. Use aspect-preserving **contain** (`STRETCH_KEEP_ASPECT_CENTERED`), never
   cover-crop and never one-axis stretch.
3. The source remains complete at every target. The centered dark side gutters
   are 68px / 100px / 133px per side at 720p / 1080p / 1440p (rounding within
   one pixel is allowed). They reveal the root dark underlay and need no new
   opaque panel.
4. The outer frame draws last at z=100 with `MOUSE_FILTER_IGNORE`; all content
   and hit areas remain inside the inner content rect. Nothing may be placed in
   the frame-safe reserve, rails, corner flowers or scrollwork.

## Responsive geometry

### 1280×720

| Element | Rect |
| --- | --- |
| Header zone | `157,137,966,70` |
| Run HUD | `181,147,480,50` |
| Title | `675,137,330,34` |
| Subtitle | `675,173,330,24` |
| Upgrade FAB | `1057,147,50,50` |
| Item slots 0..3 | x=`340/496/652/808`, y=`219`, each `132×140` |
| Tooltip frame/content | `430,371,420,128` / `450,383,380,104` |
| Back | `500,511,280,64` |

### 1920×1080

| Element | Rect |
| --- | --- |
| Header zone | `224,193,1472,100` |
| Run HUD | `248,209,720,72` |
| Title | `996,193,560,52` |
| Subtitle | `996,251,560,32` |
| Upgrade FAB | `1622,220,50,50` |
| Item slots 0..3 | x=`572/776/980/1184`, y=`325`, each `164×164` |
| Tooltip frame/content | `690,513,540,200` / `718,533,484,160` |
| Back | `780,795,360,72` |

### 2560×1440

| Element | Rect |
| --- | --- |
| Header zone | `299,257,1962,120` |
| Run HUD | `323,273,930,88` |
| Title | `1281,257,700,64` |
| Subtitle | `1281,327,700,40` |
| Upgrade FAB | `2187,292,50,50` |
| Item slots 0..3 | x=`810/1058/1306/1554`, y=`421`, each `196×196` |
| Tooltip frame/content | `980,649,600,240` / `1016,677,528,184` |
| Back | `1100,1059,360,88` |

The four products stay in one horizontal row at all three targets. This avoids
scrolling, keeps the complete archive visible, produces deterministic left/right
focus navigation and leaves a dedicated tooltip band below the products.

## Item slot content contract

Each slot remains one whole clickable/focusable hit area and keeps the existing
shop visual vocabulary: Atlas choice-card surface, canonical item icon, caption
plate, economy price badge and purchased/unaffordable overlay. Internal layout
scales with slot size:

- caption: top band, one line with ellipsis; the full title remains in tooltip;
- icon: centered contain, never cropped;
- price badge: bottom band, money icon plus up to four digits;
- purchased: disabled overlay (`снято`), still visible, removed from focus;
- unaffordable: focusable for explanation, desaturated icon/red price, purchase
  is a no-op and tooltip includes `Не хватает монет`;
- foreign class affinity `!` remains inside the slot's upper-right content
  corner and never outside the slot/frame safe zone.

## Tooltip contract

`ShopTooltipPanel` is hidden until mouse hover or focus. It uses the existing
shop/economy tooltip style and the dedicated rect in the table, rather than
following the cursor into the frame ornament. It shows the full item title,
description/effect, price, class/affinity, tier when applicable, and purchased
or insufficient-money reason. It is `MOUSE_FILTER_IGNORE`, does not cover the
four item hit areas, and is hidden/reset when focus leaves the products.

## Focus and interaction contract

- Default focus: first not-purchased product; Back only when all four products
  are purchased/unavailable.
- Left/right: cycle through not-purchased product slots in visual order.
- Down from any product: Back. Up from Back: nearest not-purchased product.
- A/Enter: attempt the focused purchase once; no duplicate spend.
- B/Escape and Back: invoke the same existing leave callable.
- Normal shop node: preserve stock/purchased state on re-entry and call
  `_return_to_map_after_shop_visit()`.
- Event shop: consume `event_shop_exit_action` exactly once, preserve optional
  discount, and continue its event/combat route flow.
- Mouse hover/click remains hybrid with gamepad/keyboard focus.

## Z order

| Layer | z |
| --- | ---: |
| Dark root underlay | 0 |
| Clipped, non-cropped merchant backdrop | 1 |
| HUD/title/products/Back | 20 |
| Tooltip | 30 |
| Shared gold outer frame, mouse-ignore | 100 |

## PixelLab prompt contract

Textless 688×384 full-page shop layout; one outer worn-gold/blackened-iron shell;
complete merchant archive at left/right/top/bottom; calm dark center; exactly
four equal empty square item wells in one horizontal row; one tooltip well
below; one Back well; HUD/title/FAB reserves; no opaque modal, circles, portraits,
characters, extra cards, extra buttons, text, pseudo-text, logos or watermark.

## Acceptance checks

- [x] UI plans validate `ready_for_image` at all three target resolutions.
- [x] Content-fit reports return `ok: true` for worst-case HUD, captions,
  four-digit prices, tooltip copy and Back.
- [x] Background mapping contains the full 2560×1440 source at all targets.
- [x] Frame and all live content/hit areas have exact non-overlapping rects.
- [x] PixelLab source accepted after visual/provenance inspection.
- [ ] Runtime screenshots match this spec after Stage 2.

## Deviations

None at Stage 1. Any implementation-bound change must update this spec before
runtime code is changed.
