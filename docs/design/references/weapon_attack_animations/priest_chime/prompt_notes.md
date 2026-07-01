# SCRUM-755 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 removed the stale OpenAI Images `billing_hard_limit_reached` blocker and requested continuing without blockers. This task therefore uses PixelLab MCP through `fantasydisk-asset-generator`, despite the older mirror text that required the unavailable OpenAI helper. No OpenAI Images, `image_gen`, or manual drawing pipeline was used.

Selected PixelLab object ID/job: `b5ef3873-53d2-4f45-bb1a-3f274c6186a7`
Tool: `create_map_object`
Canvas: `256x256`, transparent metadata, high top-down, medium detail/shading, lineless.

Prompt:

```text
Transparent 256x256 high top-down pixel art combat attack VFX sprite for priest_chime, Prayer Chime, dark fantasy D&D roguelite. No text, no UI, no square border, transparent background. Must read as a holy prayer-chain sustain attack: thin luminous chain arcs and bead-like prayer links jump between 3-4 target points, then curve back toward the caster in a circular return loop. Include a faint ghost silhouette of a small ornate hand chime or bell cluster behind the effect, not a large solid bell icon. Calm translucent alpha, muted candle gold, ivory, pale blue, tiny sacred motes, soft edges, mostly transparent center for combat readability. Avoid opaque disk, neon magenta, thick smoke cloud, UI frame, watermark, letters, or solid background.
```

Postprocess:

- Raw PixelLab download saved as `priest_chime_pixellab_source_raw.png`.
- Alpha-clean accepted source saved as `priest_chime_pixellab_source.png`; the raw download reported transparent metadata but contained a flat preview background, so corners were used for background alpha cleanup.
- Runtime exported to `assets/sprites/effects/vfx_weapon_priest_chime.png` as `256x256` transparent RGBA.
- Existing canonical weapon art `assets/sprites/weapons/priest_chime.png` was composited at low opacity as a ghost silhouette under the PixelLab-generated prayer-chain ring.
- Center alpha was softened and final alpha capped for combat readability; no gameplay, balance, targeting, cooldown, scene, shared runtime logic, broad documentation, or other weapon VFX files changed.
