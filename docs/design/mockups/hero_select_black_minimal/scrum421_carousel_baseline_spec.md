# SCRUM-421 Hero Select Carousel Baseline Amendment

Status: runtime layout amendment to the accepted black minimal Hero Select spec.
No new frame, background, ornament, or PixelLab UI source art is introduced.

Reason: PixelLab character portrait PNGs share a 512x512 canvas but do not all
share the same transparent bottom margin. Centering the full canvas made some
bottom carousel heroes appear higher or lower than others.

Viewport basis:
- 1280x720: carousel slot about 198px.
- 1920x1080: carousel slot about 297px.
- Tall screens: slot capped near 304px.

Carousel portrait rule:
- Each `HS4CarouselSlot_*` remains a clipped square button.
- `HS4CarouselPortrait_*` uses the same static `sprite_path` as the roster
  portrait source.
- Runtime computes the texture alpha-bottom margin and offsets the TextureRect
  so the visible sprite bottom lands at `slot.bottom - max(2px, slot_height * 2%)`.
- TextureRect overflow is allowed only because the slot clips it; visible content
  may not overlap arrows, dossier, ascension controls, or the screen edge.

Acceptance:
- All visible carousel portraits share a bottom baseline within 3px.
- Slots remain at least 180px at tested viewport sizes.
- Selected/unselected tint, cyclic arrows, focus graph, and click behavior remain
  unchanged.
- Biologist uses `full_frame/biologist_pixellab/biologist_idle_south.png` in the
  same carousel path as the other PixelLab playable classes.
