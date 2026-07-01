# SCRUM-766 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 kept this attack-VFX redraw on the PixelLab-first path after the old OpenAI Images helper was blocked by `billing_hard_limit_reached`. This task uses PixelLab MCP only for source generation. No OpenAI Images, `image_gen`, or manual VFX drawing pipeline was used.

PixelLab object ID: `0c10ba57-becc-4a2e-bfcd-9d6f6e8e7a71`
Tool: `create_1_direction_object`
Canvas: `256x256`, top-down, transparent RGBA source.

Prompt:

```text
FantasyDisk transparent 256x256 top-down pixel-art combat attack VFX plate for soldier_bayonet / Bayonet Brace / Штык-стойка. Dark fantasy D&D roguelite style, calm semi-transparent effect, no character, no person, no UI, no text, no watermark, no border, no square frame. Shape: a defensive forward bayonet brace corridor, vertical from lower center toward upper center: one long narrow steel-blue thrust line with a sharp bayonet-tip spark at the far end, two faint parallel brass/steel guard rails showing corridor width, a subtle crossed guard glint near the base, sparse backward shock motes and tiny impact sparks. Keep the middle readable and translucent for gameplay; avoid solid smoke, opaque disk, huge explosion, neon colors, or decorative frame.
```

Postprocess:

- Raw PixelLab download saved as `soldier_bayonet_pixellab_source_raw.png`.
- Accepted source saved as `soldier_bayonet_pixellab_source.png`; the PixelLab PNG already had transparent corners, so cleanup only removed near-invisible alpha dust.
- Runtime exported to `assets/sprites/effects/vfx_weapon_soldier_bayonet.png` as `256x256` transparent RGBA.
- The generated vertical brace was rotated to +X/right because `AttackVfx.weapon_signature()` rotates the plate by `direction.angle()`.
- Existing canonical weapon art `assets/sprites/weapons/soldier_bayonet.png` was composited at low opacity as a ghost silhouette under the PixelLab-generated brace corridor.
- Final alpha was capped at `170` for combat readability; no gameplay, balance, targeting, cooldown, scene, or shared runtime logic changed.
