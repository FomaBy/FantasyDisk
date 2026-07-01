# SCRUM-741 PixelLab Prompt Notes

Weapon ID: `elementalist_meteor_core`
Runtime target: `assets/sprites/effects/vfx_weapon_elementalist_meteor_core.png`
Accepted PixelLab source: 1-direction object `65fde13a-773c-421e-a7e5-06f4b2606001`
Alternate PixelLab attempt: map object `fcffda75-dde7-4d59-907e-9744ae2bbec1`

Active directive 2026-07-01 superseded the older OpenAI mirror text. Production
source was generated with PixelLab MCP only; no OpenAI Images, `image_gen`, manual
drawing, shared runtime logic, gameplay, or balance changes were used.

Accepted PixelLab prompt summary:

> FantasyDisk transparent 256x256 top-down attack VFX object for weapon_id
> elementalist_meteor_core / Ядро Метеора. Dark fantasy D&D meteor-core spell
> plate, no text, no background: central cracked meteor impact ring, ember-gold
> molten core, arcane violet rim cracks, three smaller secondary shard burst
> marks around it, faint translucent ghost silhouette of the meteor-core weapon
> behind the spell. Calm semi-transparent center and soft alpha edges for combat
> readability, not opaque, not too bright, unique meteor shard delayed impact
> identity.

Alternate map-object prompt summary:

> FantasyDisk attack VFX plate for weapon_id elementalist_meteor_core, Ядро
> Метеора. Transparent PNG, no text, no UI, no background. Top-down dark fantasy
> D&D spell effect: central meteor-core impact telegraph ring with ember-gold and
> arcane violet cracks, three smaller secondary shard explosion marks orbiting
> nearby, faint translucent ghost silhouette of a round meteor core weapon behind
> the effect, calm semi-transparent center so enemies and player remain readable.
> Shape communicates delayed impact at target plus secondary shard bursts, unique
> from generic fireball. Soft alpha edges, readable 256x256 game VFX, not too
> bright, no full opaque fill.

Postprocess:
- Used the true-transparent PixelLab 1-direction object as the production source.
- Capped opacity for combat readability (`alpha` max 165).
- Kept a readable semi-transparent center and soft edge opacity.
- Composited the accepted weapon reference
  `assets/sprites/weapons/elementalist_meteor_core.png` as a faint ghost
  silhouette above the PixelLab VFX source.
- Exported final runtime PNG as 256x256 RGBA with transparent background.
