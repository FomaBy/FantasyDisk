# Release 0.3.0 Announcement Image

## Player-facing focus

- The ultimate now belongs to the weapon, not the class: 51 distinct ultimates instead of 17.
- The combat HUD gained a dedicated ultimate widget with charge, readiness and the Codex description.
- Manual aiming with mouse cursor and right stick is available for all 51 weapons.
- Early route battles carry captains, a marked target, a next-phase offer and a fleeing reward carrier.
- The macOS build is Developer ID signed and Apple notarized.

## Content inventory

- release badge and FantasyDisk logo;
- one short release headline and one explanation;
- two fixed benefit columns;
- one fixed platform/channel footer.

No scrolling, controls, dynamic state, lists or player-sensitive data are required.

## Accepted art and content zones

PixelLab source `375fde3b-7e30-4c15-acf3-76083e15c71c` (`create_image_pro`) is the
accepted 512×512 integrated poster frame: one continuous dark stone field behind a
single worn-gold dragon-forged border on the outer edges, with no baked text,
pseudo-text, runes, logo or watermark and no inner panels. Two earlier
`create_ui_asset` attempts were rejected because that tool returns a component kit
rather than one integrated frame, and its second result baked rune-like pseudo-text
into the border.

The accepted source was passed through `postprocess_pixellab_source.py` (no checker
matte was present; it cropped to the opaque bbox and scaled to the final 1350×1350
canvas over a near-black backing) and only then composited. The final exact
rectangles are in `ui_plan.json` and `layout.json`: three top zones, intro, two body
columns and footer. Decorations remain outside those content interiors.

Planning gate must be `ready_for_image`; compositor output must have `ok: true`.
Only the declared logo and text may be placed after generation.
