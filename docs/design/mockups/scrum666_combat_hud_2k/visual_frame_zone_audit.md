# SCRUM-666 Visual Frame-Zone Audit

Date: 2026-06-29
Worker: codex-design-fix-scrum666

Purpose: record the QA-red geometry revision that moves accepted content zones
off generated ornament/rails and into empty HUD interiors.

Evidence image:
`docs/design/previews/scrum666_combat_hud_2k_debug_overlay.png`

## Zone Review

| Zone | Revised rect @ 2560x1440 | Visual placement |
| --- | --- | --- |
| `hp_zone` | `150,140,300,58` | Inside the red metric card dark interior; clear of the outer rail, corner bevels and top crest. |
| `xp_zone` | `520,140,260,58` | Inside the purple/blue metric card dark interior; clear of card bevels. |
| `gold_zone` | `850,140,235,58` | Inside the gold metric card dark interior; clear of card rim and top rail. |
| `ult_zone` | `1138,140,296,58` | Inside the blue metric card dark interior; clear of card bevels and resource-strip rail. |
| `timer_zone` | `1690,145,232,62` | Inside the timer frame's central dark field; clear of side gems and bottom crest. |
| `ascension_zone` | `2265,150,128,94` | Inside the ascension badge center; clear of compass tips, outer ring and ruby sockets. |
| `level_button_zone` | `2308,1148,124,104` | Inside the bottom-right lower dark button field; clear of side spikes, lower rim and bottom gem. |
| `level_badge_zone` | `2442,1079,48,40` | Inside the upper circular count badge center; clear of the red rim and gold bevel. |

## QA-Red Fixes

- Removed the old top-row content zones that sat over the generated resource
  strip rail instead of the card interiors.
- Removed the old bottom-right plus zone that sat below the generated button
  interior and crossed ornament.
- Separated `level_button_zone` and `level_badge_zone`; their revised rectangles
  do not overlap at 2560x1440.
- Kept rejected drift images as historical evidence, but the accepted overlay,
  plan and layout now match clean visual interiors.
