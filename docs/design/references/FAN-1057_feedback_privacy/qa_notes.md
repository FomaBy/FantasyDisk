# FAN-1057 Feedback Privacy Overlay — QA Notes

## Result

`ready_for_integration`

PixelLab MCP source `6e87754b-e6e0-4c74-8682-46af7fe65ab7` completed at
672x378 RGBA. The source was proportionally resampled to the required
1920x1080 review size; aspect and geometry were not stretched independently.

## Visual Review

PASS:

- no baked letters, words, numbers, pseudo-runes, logos or watermark;
- no screenshot, checkbox state, focus ring or button label baked into raster;
- title, report, screenshot, toggle, disclosure, status and action wells are
  visually distinct and empty;
- decoration is limited to rails/corners/gaps and does not cover an interior;
- dragon/ruby accents are restrained to the four outer corners;
- dark neutral interiors remain suitable for live high-contrast text;
- the modal silhouette matches FantasyDisk dark-fantasy direction while being
  quieter than the older SCRUM-583 ornate reference.

The screenshot-toggle piece was rendered as two adjacent calm sub-wells. This
is accepted for reference: the live implementation still uses one focusable
`FeedbackScreenshotToggle`, with its checkbox/state text placed inside the
combined 500x64 zone.

## Geometry Review

`fit_report.json` is PASS at 1280x720, 1920x1080 and 2560x1440.

- desktop minimum measured gap: 16px;
- compact minimum measured gap: 16px;
- desktop screenshot is exact 496x279 (16:9);
- compact screenshot is exact 544x306 (16:9);
- 1280x720 intentionally scrolls only the middle 420px viewport;
- controller right-stick scrolling reveals the complete compact privacy block
  without adding a fifth focus stop;
- compact title, status and actions remain pinned;
- 18px scrollbar reserve is excluded from disclosure content;
- all four focus targets are unique and the screenshot preview is not a Tab
  stop.
- panel geometry is continuous around 1400/1401 and 1599/1600 widths; the 2K
  runtime scales internal control minima and action plates by 4/3.

## Privacy Review

The design explicitly names:

- report description;
- optional screenshot with include/omit control;
- allowlisted game/OS metadata;
- persistent random installation ID;
- server/edge-observed connection IP used for anti-spam;
- operator and retention values supplied by deployment;
- local-only fallback when online delivery is unavailable.

No operator name or retention period is invented by the Design package. The
online route must fail closed until all deployment-owned public disclosure
values exist; the same action may still save a report locally after explaining
that outcome. This is consistent with the production gate already documented
by the relay service.

## Integration Risks To Guard

- Do not display the 1920x1080 PNG as the live screen.
- Do not bake privacy copy into a texture.
- Do not pass the already captured image to the reporter when screenshot is
  omitted.
- Do not collapse the screenshot block when omitted; that would shift focus
  and scroll positions.
- Do not put status/actions into the scroll body at 720p.
- Do not let a frame's ornament reduce the declared content zone silently;
  intersect this spec with the runtime frame's actual content margins.
- Do not enable an online route when operator/contact/retention/policy copy is
  unresolved; the disclosed local-only action may remain available.

## Evidence

- PixelLab provenance: `manifest.json`
- prompt: `pixellab_prompt.md`
- source: `feedback_privacy_overlay_pixellab_source.png`
- review preview:
  `docs/design/previews/FAN-1057_feedback_privacy_overlay_1920x1080.png`
- exact runtime geometry:
  `docs/design/mockups/FAN-1057_feedback_privacy/ui_plan.json`
- fit report:
  `docs/design/mockups/FAN-1057_feedback_privacy/fit_report.json`
