# FAN-3934 sixth-failure test rework (11:56 scope)

## Changes (test-only; no production byte touched)

1. Duration EQUALITY: every frame duration now asserted equal to the
   original authored value (1.0, matching origin/dev's tres), not merely
   positive; the authoritative check parses the committed tres text
   (SpriteFrames has no duration setter) — all 184 durations must equal
   the original.
2. REAL wrong-duration negative fixture: a corrupted duration list
   (one value +0.5) MUST be rejected by the equality rule; the dead
   'if 0.0 > 0.0' branch is deleted.
3. SPATIAL captured-render parity: per animation row and per explicit case
   (unflipped, flipped, scaled), the AnimatedSprite2D frame render is
   compared image-SHA-equal to a reference Sprite2D rendering the SAME
   AtlasTexture under the IDENTICAL transform (centered=false, same
   flip/scale) — position and mirroring differences can no longer pass.
   The old 8th-pixel color histogram is gone.
4. Simultaneous consumers: both consumers render in separate viewport
   quadrants; hiding the second MUST change the capture and re-showing
   MUST restore the exact bytes (render evidence, not is_inside_tree).

## Verification

- Windowed (real renderer) 'render' mode: exit 0, PASS — all 24 animation
  rows x 3 cases spatial-equal; simultaneous-consumer evidence green.
- Headless: exit 0, PASS with the render stage explicitly UNAVAILABLE.
- SubViewport UPDATE_ALWAYS + frame pause/settle required for capture
  determinism (root-caused during this rework: default UPDATE_DISABLED
  starved the second consumer's first captures; animation auto-advance
  caused reference/frame drift — both fixed in the test harness).
