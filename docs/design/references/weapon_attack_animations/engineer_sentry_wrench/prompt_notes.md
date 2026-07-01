# SCRUM-746 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 and the dispatcher
unblock section supersede the stale OpenAI Images-only wording in the original
task. This task uses PixelLab MCP through `fantasydisk-asset-generator`. No
OpenAI Images, `image_gen`, or manual drawing fallback was used.

Selected PixelLab object ID/job: `ac6f457c-7577-417c-9eb7-02aa143bfb2d`
Unused first candidate: `c7f426c1-ef40-4dc1-bb81-0e0d86456c3c`
Tool: `create_map_object`
Canvas: `256x256`, transparent metadata, high top-down, medium detail/shading,
lineless.

Prompt:

```text
Transparent 256x256 high top-down combat attack VFX sprite, no object icon, no solid medallion, no UI frame. Engineer Sentry Wrench attack: thin clockwork targeting beams and dotted teal-gold sentry link lines, broken brass gear arcs around the outside, four small target pips at beam ends, a faint translucent wrench ghost silhouette crossing behind the beams. Mostly empty transparent center, only light arcane sparks and fine lines. Dark fantasy D&D engineering magic, restrained gameplay opacity, soft alpha edges, transparent background, no text, no square tile, no badge, no central coin, no solid circle.
```

Postprocess:

- Raw PixelLab selected download saved as `engineer_sentry_wrench_pixellab_source_raw.png`.
- Unused first candidate saved as `engineer_sentry_wrench_pixellab_candidate_1_raw.png`.
- Alpha-clean accepted source saved as `engineer_sentry_wrench_pixellab_source.png`; the raw download reported transparent metadata but contained a flat preview matte, so corners were used for background alpha cleanup.
- Runtime exported to `assets/sprites/effects/vfx_weapon_engineer_sentry_wrench.png` as `256x256` transparent RGBA.
- Existing canonical weapon art `assets/sprites/weapons/engineer_sentry_wrench.png` was composited at low opacity as a ghost silhouette over the PixelLab targeting field.
- Center alpha was softened and final alpha capped for combat readability; no gameplay, balance, targeting, cooldown, scene, or shared runtime logic changed.
