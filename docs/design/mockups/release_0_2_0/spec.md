# Release 0.2.0 Announcement Image

Status: accepted for release publication.

## Output

- Final: `assets/marketing/fantasydisk_020_announcement_telegram_discord.png`
- Base layer: `docs/design/mockups/release_0_2_0/release_0_2_0_base.png`
- Layout: `docs/design/mockups/release_0_2_0/layout.json`
- Guide: `docs/design/mockups/release_0_2_0/layout_guide.png`
- QA overlay: `docs/design/previews/release_0_2_0/release_0_2_0_debug.png`
- QA report: `docs/design/previews/release_0_2_0/release_0_2_0_report.json`

## Content Zones

The poster uses the accepted 0.2.0 main-menu background and title logo as the
visual base. Text is composited only inside declared left-side zones:

- version badge: `x=120 y=82 w=560 h=74`
- subtitle: `x=120 y=430 w=860 h=118`
- highlights: `x=120 y=588 w=905 h=310`
- footer: `x=120 y=950 w=770 h=70`

Planning gate: ready_for_image. The content-zone renderer report returned
`ok: true`; all text fits inside the declared zones. No cards, panels, frames or
opaque backing boxes were drawn over the poster after the base layer.
