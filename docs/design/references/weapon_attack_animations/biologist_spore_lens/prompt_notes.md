# SCRUM-731 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 removed the stale OpenAI Images `billing_hard_limit_reached` blocker and requested continuing without blockers. This task therefore uses PixelLab MCP through `fantasydisk-asset-generator`, despite the older mirror text that required the unavailable OpenAI helper. No OpenAI Images, `image_gen`, or manual drawing pipeline was used.

Selected PixelLab object ID/job: `3e336a3b-d5cf-4bf6-b0f5-ab8ee64392ea`
Unused first candidate: `8cbe4e4e-5b08-4ee1-8e23-0b588f5201cd`
Tool: `create_map_object`
Canvas: `256x256`, transparent metadata, high top-down, medium detail/shading, lineless.

Prompt:

```text
Transparent 256x256 top-down pixel art combat attack VFX sprite for biologist_spore_lens, Spore Lens, dark fantasy D&D roguelite. No text, no UI, transparent background. Must read as three separate expanding spore rings, not a flower: outer broken fungal ring, middle dotted spore ring, inner luminous lens ring, all concentric around a mostly transparent center. Subtle fungal glass lens impression and faint ghost silhouette of a circular handheld lens weapon behind the rings. Calm translucent alpha, muted poisonous green, teal, pale cream spores, mycelium speckles, soft edges. Keep combat readability: no solid smoke cloud, no opaque disk, no square border, no petals, no leaves.
```

Postprocess:

- Raw PixelLab download saved as `biologist_spore_lens_pixellab_source_raw.png`.
- Alpha-clean accepted source saved as `biologist_spore_lens_pixellab_source.png`; the raw download reported transparent metadata but contained a flat dark preview background, so corners were used for background alpha cleanup.
- Runtime exported to `assets/sprites/effects/vfx_weapon_biologist_spore_lens.png` as `256x256` transparent RGBA.
- Existing canonical weapon art `assets/sprites/weapons/biologist_spore_lens.png` was composited at low opacity as a ghost silhouette under the PixelLab-generated rings.
- Center alpha was softened and final alpha capped for combat readability; no gameplay, balance, targeting, cooldown, scene, or shared runtime logic changed.
