# SCRUM-768 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 and the SCRUM-768
dispatcher unblock require PixelLab MCP through `fantasydisk-asset-generator`,
despite the older mirror text that referenced the unavailable OpenAI helper.
No OpenAI Images, `image_gen`, or legacy generation helper was used.

Selected PixelLab object ID/job: `e259ff57-39e2-42d5-992b-fab02387b59b`
Tool: `create_map_object`
Canvas: `256x256`, high top-down, medium detail/shading, lineless.

Prompt:

```text
Transparent 256x256 top-down pixel art combat attack VFX sprite for soldier_rifle, "Аркебуза строя" / formation arquebus, dark fantasy D&D roguelite. No text, no UI, transparent background. Must read as suppression burst: three short rifle muzzle flashes along a straight firing lane, small sequential impact sparks and powder-smoke wisps, a narrow tactical line of fire, not a large explosion. Muted brass gold, warm amber, dull steel blue smoke, soft translucent alpha, readable at combat scale. Leave center mostly transparent for player/enemy readability. Include a faint long arquebus rifle ghost silhouette impression behind the firing lane, but no modern assault rifle, no bullets as UI icons, no square border, no opaque disk, no neon laser.
```

Postprocess:

- Raw PixelLab download saved as `soldier_rifle_pixellab_source_raw.png`.
- Alpha-clean accepted source saved as `soldier_rifle_pixellab_source.png`; the
  raw download reported transparent metadata but contained an opaque gray preview
  matte, so corners were used for background alpha cleanup.
- The generated modern-looking firearm silhouette was faded; the live weapon
  ghost uses canonical `assets/sprites/weapons/soldier_rifle.png` at low opacity.
- Runtime exported to `assets/sprites/effects/vfx_weapon_soldier_rifle.png` as
  `256x256` transparent RGBA.
- Final alpha is capped for combat readability. Gameplay, balance, targeting,
  cooldown, scene files, and shared runtime logic were not changed.
