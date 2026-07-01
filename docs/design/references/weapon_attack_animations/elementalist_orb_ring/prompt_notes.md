# SCRUM-742 Elementalist Orb Ring Attack VFX Prompt Notes

Pipeline: PixelLab MCP via `fantasydisk-asset-generator`.

Direct user directive 2026-07-01 supersedes the stale local mirror line that requested OpenAI Images. This pass did not use OpenAI Images, `image_gen`, manual drawing, or shared runtime changes.

PixelLab object:

- Tool: `create_map_object`
- Object ID: `0deb7121-dd70-4040-a79a-6dce484b20c2`
- Canvas: `256x256`
- View: `high top-down`

Prompt:

```text
transparent top-down dark fantasy D&D combat attack VFX sprite for a weapon signature: Ring of Three Elements / elemental orb ring. A short circular orbit of three distinct magic spheres around an empty readable center: ember fire red-orange, frost blue-white, storm violet-cyan lightning. Include faint circular arc trails and tick sparks showing AoE pulses, restrained semi-transparent magical energy, no background, no floor, no text, no UI frame, no watermark. Must read as a 256x256 game effect plate with calm transparent center for player/enemy visibility.
```

Postprocess:

- PixelLab reported transparent background, but the downloaded PNG contained an opaque dark matte; the runtime source was alpha-keyed deterministically from the matte color.
- The canonical weapon reference `assets/sprites/weapons/elementalist_orb_ring.png` was composited as a low-opacity ghost behind the PixelLab orbit to satisfy the weapon-silhouette requirement.
- The baked lower-left PixelLab mark was masked out of cleaned/runtime deliverables.
- Final runtime alpha is capped at `190`; center mean alpha is `0.04`, leaving the player/enemy center readable.

Outputs:

- Source: `elementalist_orb_ring_pixellab_source.png`
- Clean source: `elementalist_orb_ring_pixellab_alpha_clean.png`
- Runtime: `assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png`
- Preview/contact: `docs/design/previews/weapon_attack_animations/elementalist_orb_ring_contact.png`
- Alpha evidence: `docs/design/references/weapon_attack_animations/elementalist_orb_ring/alpha_report.json`
