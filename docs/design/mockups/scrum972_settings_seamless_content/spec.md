# SCRUM-972 — Settings seamless content surface

## Baseline diagnosis

Metal captures at 1280×720, 1920×1080 and 2560×1440 show an opaque gray-black
`SettingsContentPanel` with a gold outline below three floating tab plates. The
hard rectangle reads as a second frame/layer and visually cuts the tabs away
from the fullscreen Atlas shell. The issue is strongest at 2K, where the panel
has a large unused filled lower half.

## Decision

Keep every responsive rect, native control, safe margin and behavior. Replace
only the panel style with a transparent margin-preserving surface:

- no gray fill;
- no outline, border, bevel, corner ornament or separate panel frame;
- the centered Settings rows render directly over the existing dark sanctum
  background inside the outer frame safe area;
- field, slider, checkbox, tab and action-plate art remain unchanged and provide
  local contrast;
- the transparent style keeps the same content margins, so tabs, controls,
  footer and outer frame geometry do not move.

This is an explicit no-new-asset decision. PixelLab provides the mandatory
textless page mockup/proof; production reuses the existing shell/background and
native styles rather than introducing another frame texture.

PixelLab MCP asset `64eb22c0-35d0-41de-863c-e368c0e7da6f` is the accepted
border-only page layer. Its center is transparent from tab row through footer,
which models the continuous runtime sanctum background. The native compositor
report `settings_seamless_fit_report.json` passes all eight content zones; the
debug overlay confirms that text stays off every frame/plate/track border. The
first generation (`24273b01-5259-4f2a-9e3e-4139eb98d936`) is retained only as
rejected audit evidence because it was a component sheet with baked text.

## Canonical 688×384 zones

- Outer frame: full canvas; safe content `(48,34,592,316)`.
- Header: `(68,61,552,30)`.
- Three floating tabs: `(196,103,296,34)`.
- Seamless content zone: `(154,145,380,154)`, with four rows and status text.
- Footer actions: `(309,307,206,30)`.

No content may touch the outer frame ornament. The seamless content zone is a
layout owner, not a visible panel.

## Responsive acceptance

At 1280×720, 1920×1080 and 2560×1440:

- `SettingsContentPanel` keeps the existing global rect and clipping/safe
  ownership but its rendered style has zero fill alpha and zero border widths;
- all tab pages, rows, controls and status labels remain inside
  `SettingsContentSafe` and the outer frame safe area;
- tabs/Apply/Revert/Back, monitor/resolution/window mode, audio and controls
  behavior remain unchanged;
- screenshots show one continuous dark background from tabs through content,
  with no visible gray inset rectangle.
