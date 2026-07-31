# UI Mockup Spec — FAN-1966 tooltip host content-zone rework

Status: ready_for_integration
Role owner: Back-end/UI
Task: FAN-1967
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2560×1440
Mockup PNG: none — geometry-only corrective package; accepted live visuals are reused unchanged.
Generators: background=existing; non-background UI=existing.
Sources: `assets/backgrounds/ui/ui_backdrop_arcane_lab.png`, `assets/sprites/ui/meta40/frame_border.png`, existing Atlas buttons and `GlobalTooltip.make_atlas_chip_panel_style()` / Pause `_chip_style()`.

## Source request

Replace the QA-owned tooltip panel with the production Attribute Shop detail host and Pause/Codex dossier host. Long disclosure must scroll inside a declared empty host zone without covering action/menu controls or the gold-frame ornament. No art, text baked into art, or gameplay semantics change.

## Frame and forbidden zones

`frame_border.png` is 1536×1024; texture margins are `160/160/160/160` source px.
The runtime texture-safe rect is the scaled margin inset. The gold-shell content rect adds a reserve of 24 px at 720p/1080p and 32 px at 1440p. Everything outside the listed content rect is a forbidden ornament zone. Tooltip panel chrome uses existing StyleBoxFlat only (no texture): Shop `10/10/10/10` and Pause `16.8/12/16.8/12` (L/T/R/B). Each production scroll child adds a real glyph-safety inset of `3/2/3/2`.

| Surface / viewport | Texture-safe rect | Content rect / tooltip-safe parent | Forbidden ornament zone |
| --- | --- | --- | --- |
| Attribute Shop 1280×720 | `Rect2(133,113,1014,494)` | `Rect2(157,137,966,446)` | viewport minus content rect |
| Attribute Shop 1920×1080 | `Rect2(200,169,1520,742)` | `Rect2(224,193,1472,694)` | viewport minus content rect |
| Attribute Shop 2560×1440 | `Rect2(267,225,2026,990)` | `Rect2(299,257,1962,926)` | viewport minus content rect |
| Pause/Codex 1280×720 | `Rect2(133,113,1014,494)` | body `Rect2(157,187,691,392)` inside inner `Rect2(157,137,966,446)` | viewport minus inner rect; action band is separately forbidden |
| Pause/Codex 1920×1080 | `Rect2(200,169,1520,742)` | body `Rect2(224,277,1472,498)` inside inner `Rect2(224,193,1472,694)` | viewport minus inner rect; action band is separately forbidden |
| Pause/Codex 2560×1440 | `Rect2(267,225,2026,990)` | body `Rect2(299,385,1962,654)` inside inner `Rect2(299,257,1962,926)` | viewport minus inner rect; action band is separately forbidden |

## Production elements

| ID | Runtime host | Rect @ 1280×720 | Rect @ 1920×1080 | Rect @ 2560×1440 | Z | Contract |
| --- | --- | --- | --- | --- | --- | --- |
| `AS.TooltipHost` | `AttributeShopDetailDrawer` | `Rect2(169,218,210,262)` | `Rect2(470,698,980,79)` | `Rect2(630,938,1300,114)` | above offers, below frame | Existing scroll/label host. 720p reserves the left empty column; larger tiers use the existing band beneath offers. |
| `AS.TooltipScroll` | `AttributeShopDetailScroll` | `Rect2(179,228,190,242)` | `Rect2(480,708,960,59)` | `Rect2(640,948,1280,94)` | host content | Vertical lane is part of the host and stays inside the safe parent. |
| `AS.Offers` | `AttributeOffers` | `Rect2(397,218,714,258)` — 3-card slots are `223×258`, 22px gap | `Rect2(350,330,1220,360)` | `Rect2(470,430,1620,500)` | below host/frame | At 720p the left 210px is intentionally empty for the tooltip host; two-card rows remain centered in the remaining offer lane. |
| `AS.Actions` | `AttributeShopActions` | `Rect2(300,500,680,64)` | `Rect2(500,785,920,72)` | `Rect2(650,1060,1260,88)` | below host | Forbidden to the tooltip host, scrollbar lane, and visible glyphs. |
| `Pause.TooltipHost` | `DossierFocusTooltip` | `Rect2(418,291,430,288)` | `Rect2(1266,487,430,288)` | `Rect2(1831,751,430,288)` | 100 | Fixed lower-right of the body content zone; not a viewport-clamped engine popup. |
| `Pause.TooltipScroll` | `DossierFocusTooltipScroll` | `Rect2(435,303,396,264)` | `Rect2(1283,499,396,264)` | `Rect2(1848,763,396,264)` | host content | Existing 16.8/12px content margins, vertical scrollbar lane included. |
| `Pause.Actions` | `PauseControlButtons` | `Rect2(860,227,263,312)` | `Rect2(296,787,1328,88)` | `Rect2(1042,1063,1580,104)` | normal controls | Forbidden to the tooltip host, scrollbar lane, and visible glyphs. |

## Responsive and interaction rules

- Shop at 720p reserves the host first, then fits the same two/three offers in the remaining row. At 1080p/1440p the existing under-offer drawer remains the host. Hover on the actual offer opens the compact host; `tooltip_text` remains semantic payload for the existing contract, while its custom popup adapter has no visible disclosure content.
- Pause/Codex positions the existing dossier host at the fixed lower-right of its real body zone. Artifact chips use the same hover/focus route as stat chips; their engine popup path is disabled.
- The tooltip hosts are above information content but below the existing decorative frame. They ignore mouse input; hover/focus, pressed, disabled, and selected states do not resize any control.
- The long-copy oracle sets the real scroll container to its maximum. Its terminal sentinel must occur once, end the text, and have measurable character bounds fully enclosed by the clipped scroll viewport. The whole host, scrollbar viewport, and glyph rect must be disjoint from protected controls and within the declared safe parent.

## Validation and negative probes

- Native matrix: 48 PNGs, 12 distinct sentinels, normal/long semantic hashes differ.
- The test must not create `FAN1927MountedTooltip` or any test-owned `PanelContainer` tooltip host.
- Moving the real host to a forbidden frame/action rect must make the geometry oracle fail.
- Resetting the real scroll to the top after proving end-scroll must make the sentinel-glyph oracle fail; restoring true end-scroll must pass.

## Deviations

No art deviation. The only layout change is a 720p Attribute Shop left reserve (`210px`) so the existing production disclosure can be hosted without covering offers, actions, or the frame.
