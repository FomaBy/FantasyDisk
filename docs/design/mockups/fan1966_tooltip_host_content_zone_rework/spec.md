# UI Mockup Spec — FAN-1969 production tooltip host contract

Status: implemented
Role owner: Back-end/UI
Task: FAN-1969 (descendant rework of FAN-1967)
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2560×1440
Mockup PNG: none — geometry-only corrective package; accepted live visuals and existing assets are reused unchanged.
Generators: background=existing; non-background UI=existing.
Sources: `assets/sprites/ui/meta40/frame_border.png`, existing Atlas buttons, Shop `_atlas_chip_style(…, 10)`, and Pause `_chip_style(…, 12)`.

## Source request

The Attribute Shop and Pause/Codex use their production disclosure hosts. Full
copy remains in those hosts, never in a test-owned panel or engine tooltip
popup. The contract records the actual live geometry, input routing, safe
content zones, and clipping rules without changing art, gameplay, or attribute
semantics.

## Frame, content, and clip contract

`frame_border.png` is 1536×1024 with texture rails `160/160/160/160` source
px. `TextureSafe` clears those scaled rails. `StrictInner` is the only usable
content zone: `TextureSafe.grow(-24)` at 720p/1080p and
`TextureSafe.grow(-32)` at 1440p. The space between those rectangles is an
ornament reserve; the viewport outside `TextureSafe` is also forbidden.

| Viewport | TextureSafe | StrictInner | Ornament reserve |
| --- | --- | --- | --- |
| 1280×720 | `Rect2(133,113,1014,494)` | `Rect2(157,137,966,446)` | 24 px |
| 1920×1080 | `Rect2(200,169,1520,742)` | `Rect2(224,193,1472,694)` | 24 px |
| 2560×1440 | `Rect2(267,225,2026,990)` | `Rect2(299,257,1962,926)` | 32 px |

Shop panel chrome is `14/10/14/10` (L/T/R/B); its scroll content adds
`3/2/3/2`. Pause tooltip chrome is `16.8/12/16.8/12`; its scroll content adds
`3/2/3/2`. A long-copy glyph is valid only inside the strict effective scroll
viewport: the `ScrollContainer` rect minus its visible vertical-scrollbar lane,
not merely inside the outer panel chrome.

## Production geometry

| ID | Runtime node | 1280×720 | 1920×1080 | 2560×1440 | Z / mouse contract |
| --- | --- | --- | --- | --- | --- |
| `AS.TooltipHost` | `AttributeShopDetailDrawer` | `Rect2(169,218,210,262)` | `Rect2(470,698,980,79)` | `Rect2(630,938,1300,114)` | z=0; passive host `IGNORE`; below final frame |
| `AS.TooltipScroll` | `AttributeShopDetailScroll` scroll viewport | `Rect2(183,228,182,242)` | `Rect2(484,708,952,59)` | `Rect2(644,948,1272,94)` | z=0; interactive child `STOP`; its visible right scrollbar lane is not a glyph zone |
| `AS.Offers` | `AttributeOffers` full band | `Rect2(397,218,714,258)` | `Rect2(350,330,1220,360)` | `Rect2(470,430,1620,500)` | wrapper `PASS`, offer controls `STOP`; protected in full |
| `AS.Actions` | `AttributeShopActions` full band | `Rect2(300,500,680,64)` | `Rect2(500,785,920,72)` | `Rect2(650,1060,1260,88)` | wrapper `PASS`, controls `STOP`; protected in full |
| `Pause.TooltipHost` | `DossierFocusTooltip` | `Rect2(418,291,430,288)` | `Rect2(1266,487,430,288)` | `Rect2(1831,751,430,288)` | z=100; passive host `IGNORE`, above decorative frame |
| `Pause.TooltipScroll` | `DossierFocusTooltipScroll` outer clip | `Rect2(435,303,396,264)` | `Rect2(1283,499,396,264)` | `Rect2(1848,763,396,264)` | z=0; interactive child `STOP`; effective clip excludes visible scrollbar lane |
| `Pause.Actions` | `PauseControlButtons` full band | `Rect2(860,227,263,312)` | `Rect2(296,787,1328,88)` | `Rect2(490,1063,1580,104)` | wrapper `PASS`, controls `STOP`; protected in full |

`AttributeShopDetailContentMargin` and `DossierFocusTooltipContentMargin` are
passive `IGNORE` wrappers; both labels are `IGNORE`. `AttributeShopFrame` and
`EscapeStatsPanelFrame` are final visual `IGNORE` layers. `DossierContentRoot`
is the input-passing production content wrapper. Engine popup content is
suppressed: Shop keeps its semantic `tooltip_text`, but the installed
`GlobalTooltipControl` returns empty content for `production_tooltip_host` and
the full disclosure is shown by `AS.TooltipHost`; Pause keeps an empty
`tooltip_text` and renders `dossier_tooltip_text` only in `Pause.TooltipHost`.

The three `AS.TooltipScroll` rectangles above are the authored effective
`ScrollContainer` viewports. When long copy makes the native 8 px scrollbar
visible, the strict glyph clip is respectively `Rect2(183,228,174,242)`,
`Rect2(484,708,944,59)`, and `Rect2(644,948,1264,94)`: that scrollbar lane is
excluded from every readable-glyph and terminal-sentinel assertion.

## Responsive and interaction rules

- At 720p, the Shop reserves the left `AS.TooltipHost` lane before laying out
  the full `AS.Offers` band. At 1080p and 1440p, the existing drawer occupies
  the band below offers and above actions.
- Pause uses the lower-right of the real `StrictInner` body rect. Compact
  layouts use a vertical action rail; 1080p and 1440p use the footer band.
- Real coordinate input enters the production offer/chip. Its normal
  `mouse_entered` wiring opens the production host; wheel input changes the
  production scroll range. The passive host and wrappers cannot intercept
  action/control input.
- Engine tooltip popups are suppressed: Shop's `production_tooltip_host` route
  has the installed `GlobalTooltipControl` return empty content, while Pause
  controls have empty `tooltip_text`; full disclosure is rendered only by the
  documented production host.
- At true maximum scroll, the terminal sentinel occurs exactly once, ends the
  disclosure, and every currently visible glyph — including the sentinel — is
  wholly inside the effective clipped viewport and outside the scrollbar lane.

## Validation and negative probes

- Headless and native matrices cover 48 states, 48 PNGs, and 12 unique
  sentinels across the three target viewports.
- The oracle fails for an incorrect 24/32 px reserve, a host moved into a full
  protected band, broken physical hover wiring or a restored engine-tooltip
  route, a duplicate sentinel, and a glyph/clip rectangle that includes the
  scrollbar lane.
- Existing test-owned-host, forbidden-zone, top-clipped-sentinel, and
  preload-bypass negative probes remain forbidden.

## Deviations

No art or visual-family deviation. The previous 2560×1440 `Pause.Actions`
specification started at x=1042 and extended beyond the viewport; this contract
records the production rect `Rect2(490,1063,1580,104)`.
