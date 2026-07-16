# Common Pitfalls & Exception Handling

Hard-won lessons. Check these before generating UI art or integrating frames so
the same mistakes do not repeat.

## Generator routing and export

- **Classify the layer first.** Full-canvas scenic backgrounds, menu/screen
  backgrounds, loading/splash images, and illustrated underlays must use the
  built-in OpenAI Image Generator through `$fantasydisk-builtin-image-generator`.
  Never use PixelLab for them. Frames, HUD, icons, buttons, panels, and other
  non-background UI art must use PixelLab MCP.
- **Do not confuse alpha with asset type.** An icon or frame that needs a
  transparent background is still a non-background asset and remains on the
  PixelLab route.
- **Tool visibility.** If direct PixelLab tools are not exposed, use tool
  discovery or the configured local MCP bridge. Never print or commit tokens,
  Authorization headers, or raw config containing secrets.
- **Unavailable PixelLab => block/handoff.** Do not silently replace a PixelLab
  mockup with OpenAI Images, `image_gen`, old manual art, or `generate_asset.py`.
- **Unavailable built-in OpenAI => block/handoff.** Do not replace a background
  with PixelLab. Use the OpenAI Images API only after an explicit user request.
- **Record provenance.** Save PixelLab source/project IDs, tags/names, prompts,
  export dimensions, and source filenames for non-background art. Save the
  OpenAI prompt, output path, dimensions, and built-in/API route for backgrounds.
- **Export for the target shape.** Very wide bars and irregular frames should be
  generated/exported at the real panel aspect when possible, or designed as
  9-slice/composed pieces so Godot does not stretch ornament.

## Frame rendering in Godot — avoid distortion

- **`TextureRect` + `STRETCH_SCALE` scales the WHOLE image** (ornament included).
  If the frame's source aspect != the panel's runtime aspect, corners/gems get
  stretched ("rat-like" bars, squashed crests). Two correct fixes:
  1. Generate the frame at the panel's real aspect ratio, or
  2. Use a 9-slice (`NinePatchRect` / `StyleBoxTexture` with patch margins) so
     only the middle stretches and the ornate border stays crisp.
  Round frames (compass/radar) must stay square->square; never 9-slice a round
  frame.

## Verify the asset you replaced is the one actually rendered

- A screen may draw a **single combined "unified" frame** instead of the
  separate per-panel frames. Replacing `*_portrait.png` / `*_dossier.png` then
  changes nothing on screen. Before/after a swap, grep the screen code for which
  `*_TEXTURES[...]` key each visible panel actually loads, and confirm the node
  that draws it (e.g. `unified_frame_art`) is the one you changed.

## Content must sit inside the frame's empty zone

- A frame's content container needs **margins equal to the frame's real inner
  transparent border + reserve**, or the portrait/text/icons overlap the
  ornament (SKILL rules 6-7). Measure the actual inner transparent rectangle of
  the PNG (scan alpha from the centre outwards) — do NOT reuse the previous
  frame's margins; a regenerated frame has a different border geometry.
- Content margins expressed as a fraction of the panel size track the frame's
  border fraction (`border_px / source_px`) and survive resolution changes.

## Validate without a human screenshot when possible

- Run `tests/ui_no_overlap_matrix_test.gd`, `runtime_smoke_ui_test.gd`, and
  `dark_fantasy_ui_theme_test.gd`; they catch content-over-ornament overlap
  across the resolution matrix. Still request a real screenshot for final visual
  sign-off — automated tests confirm geometry, not beauty.
