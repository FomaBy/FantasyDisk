## Три Колокола Рассвета — `priest_chime`

PixelLab source brief for FAN-3771 / FAN-3318. The effect is a linked set of
three ivory-and-gold prayer bells with blue gemstones, ribbons and staggered
concentric prayer-wave motion. It is centered on transparent 256×256 frames,
with no text, border or background.

Animation prompt: keep the same three-bell silhouette and camera; swing the
bells in staggered arcs, flutter the ribbons, pulse the blue stones one after
another, and shimmer three ivory-gold prayer-wave rings. Keep the bells linked,
centered, readable, unclipped and transparent.

- PixelLab object: `1aa84b6a-5666-437f-9ba0-43e1aa8e72f2`
- PixelLab animation group: `44dda2f3-c433-494e-a89e-e08e004904e9`
- Generator manifest: `pixellab_generation_manifest.json`
- Raw frames: `raw/priest_chime_f00.png` … `raw/priest_chime_f08.png`
- Accepted/runtime frames: 9 at 3 fps, one-shot 3 second flipbook
- Canonical weapon reference for the ghost silhouette: `assets/sprites/weapons/priest_chime.png`
- Accepted post-process: normalized to a 224 px safe box, 16 px minimum gutter,
  effect alpha 68%, canonical weapon silhouette behind it at 20% opacity.
