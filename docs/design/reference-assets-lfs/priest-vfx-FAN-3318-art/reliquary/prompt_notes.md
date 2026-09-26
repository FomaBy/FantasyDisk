## Суд Светлого Святилища — `priest_reliquary`

PixelLab source brief for FAN-3771 / FAN-3318. The effect is a portable
ivory-gold gothic reliquary with blue crystal, cross finial, open sanctify
window, ceremonial chain and a contained halo/burst. It is centered on
transparent 256×256 frames, with no text, border or background.

Animation prompt: keep the same reliquary silhouette and camera; brighten the
blue crystal, open the shrine window with a contained ivory beam, bloom a gold
sanctify sigil and expand/contract a soft halo, while the chain sways slightly.
Keep the shrine centered with a clear readable center, unclipped edges and
transparent background.

- PixelLab object: `fa8c5297-4bdd-497e-9916-cda2e7b40285`
- PixelLab animation group: `030f22d8-2e59-4de7-b7fb-dd415fb00ac4`
- Generator manifest: `pixellab_generation_manifest.json`
- Raw frames: `raw/priest_reliquary_f00.png` … `raw/priest_reliquary_f08.png`
- Accepted/runtime frames: 9 at 3 fps, one-shot 3 second flipbook
- Canonical weapon reference for the ghost silhouette: `assets/sprites/weapons/priest_reliquary.png`
- Accepted post-process: normalized to a 224 px safe box, 16 px minimum gutter,
  effect alpha 68%, canonical weapon silhouette behind it at 20% opacity.
