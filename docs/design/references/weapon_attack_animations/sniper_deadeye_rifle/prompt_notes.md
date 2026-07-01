# SCRUM-763 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 removed the stale OpenAI Images-only blocker and requested continuing through PixelLab MCP via `fantasydisk-asset-generator`. This task therefore uses PixelLab MCP, despite the older mirror text that described the unavailable OpenAI helper. No OpenAI Images, `image_gen`, manual drawing pipeline, gameplay edit, scene edit, or shared runtime logic change was used.

Selected PixelLab object ID/job: `574b078d-d81f-4ccd-aa7c-c7edda19d5ba`
Unused first candidate: `7c6e6f3e-11f1-4919-b81b-8f15b6711f03`
Tool: `create_map_object`
Canvas: `256x256`, transparent metadata, low top-down, high detail, detailed shading, lineless.

Selected prompt:

```text
Transparent 256x256 pixel art combat VFX sprite, NOT a weapon icon and NOT a full solid gun item. Dark fantasy D&D Dead Eye Rifle lockshot effect: mostly transparent empty corners, a thin horizontal cursed white-red sniper beam/corridor across the center, dead-eye circular reticle at center, faint dotted line falloff and tiny spectral muzzle sparks, with only a very faint translucent long rifle ghost silhouette behind the beam. Calm readable alpha, muted crimson, pale bone white, smoky violet, no background, no square border, no text, no letters, no character, no HUD, no opaque disk.
```

Unused first candidate prompt:

```text
Transparent-background pixel art attack VFX plate for a dark fantasy top-down roguelite weapon named Dead Eye Rifle. 256x256 square canvas, no text, no letters, no numbers. Centered spectral long sniper rifle ghost silhouette in deep gunmetal and smoky violet, very translucent. A precise narrow cursed crimson aiming beam/corridor runs horizontally through the rifle from left to right, with a small dead-eye reticle at center and subtle line falloff sparks toward the far end. Calm semi-transparent D&D dark fantasy style, readable in combat, not neon, not opaque, no character, no HUD, no background, soft alpha edges, empty transparent corners.
```

Postprocess:

- Raw selected PixelLab download saved as `sniper_deadeye_rifle_pixellab_source_raw.png`.
- Unused first candidate saved as `sniper_deadeye_rifle_pixellab_candidate_a_raw.png` for audit only.
- Alpha-clean accepted source saved as `sniper_deadeye_rifle_pixellab_source.png`; the raw download reported transparent metadata but contained a flat preview background, so border color was used for alpha cleanup.
- Tiny bottom-right preview/noise island was removed during alpha cleanup.
- Runtime exported to `assets/sprites/effects/vfx_weapon_sniper_deadeye_rifle.png` as `256x256` transparent RGBA.
- Existing canonical weapon art `assets/sprites/weapons/sniper_deadeye_rifle.png` was composited at low opacity as a spectral ghost silhouette under the PixelLab-generated lockshot beam.
- Final visible layer was padded inside the canvas so the muzzle flare is not clipped after runtime rotation/scale.
- Final alpha was capped for combat readability; no gameplay, balance, targeting, cooldown, scene, or shared runtime logic changed.
