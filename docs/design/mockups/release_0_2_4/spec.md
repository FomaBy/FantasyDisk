# Release 0.2.4 Announcement Image

## Player-facing focus

- Updates are available to every player without a GitHub login.
- The public binary-only release catalog contains the current stable DMG, Windows Setup and SHA-256 sums.
- Telegram receives the release poster, both installers and checksums; Discord links players to the Telegram download channel.

## Content inventory

- release badge and FantasyDisk logo;
- one short channel headline and one explanation;
- two fixed benefit columns;
- one fixed platform/channel footer.

No scrolling, controls, dynamic state, lists or player-sensitive data are required.

## Accepted art and content zones

PixelLab source `a3df8aa6-2e0a-492f-a57e-949cb67cd742` is the accepted 632×424
integrated frame. It has no baked text, pseudo-text, logo or watermark. Its
checker matte was removed, then the frame was scaled to the final 1350×1350
canvas before compositing. The final exact rectangles are in `ui_plan.json` and
`layout.json`: three top zones, intro, two body columns and footer. Decorations
remain outside those content interiors.

Planning gate must be `ready_for_image`; compositor output must have `ok: true`.
Only the declared logo and text may be placed after generation.
