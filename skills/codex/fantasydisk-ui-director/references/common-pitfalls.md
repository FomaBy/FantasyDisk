# Common Pitfalls & Exception Handling

Hard-won lessons. Check these before generating UI art or integrating frames so
the same mistakes do not repeat.

## OpenAI image generation (gpt-image-2)

The bundled `generate_asset.py` now auto-handles these, but know them anyway:

- **Minimum pixel budget.** Requests below ~1.0 MP fail with "below the current
  minimum pixel budget". Use >= 1024x1024-area sizes. Tiny frames (512x512,
  512x768, 1536x256) are rejected — the script auto-bumps them; do not hand-pick
  sub-MP sizes.
- **Aspect limit 1:3..3:1.** A very wide bar (e.g. 6:1 carousel) is rejected.
  Generate at <=3:1 and let 9-slice stretch the middle, or compose the final
  thin strip from a taller source.
- **Divisible by 16.** Each side must be a multiple of 16.
- **API key.** The key lives in `~/.codex/.env` (`export OPENAI_API_KEY=...`),
  not the shell env. `generate_asset.py` now sources it automatically; if you
  call the API another way, load it yourself.
- **Real failures (billing/quota/moderation) => block or handoff.** Never
  silently replace an API mockup with a hand-drawn substitute (SKILL rule 4).
- **Batch frame sets with `--no-task`.** Each plain run creates a
  `design_integrate_generated_*` task; a 4-frame batch spawns 4+ near-duplicate
  tasks. Pass `--no-task` for all but one, or delete the duplicates afterward.

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
