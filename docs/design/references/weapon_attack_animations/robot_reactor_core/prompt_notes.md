# SCRUM-761 PixelLab Prompt Notes

Production path override: direct user directive on 2026-07-01 superseded the stale
OpenAI Images-only mirror text for attack VFX work. This task therefore uses
PixelLab MCP through `fantasydisk-asset-generator`. No OpenAI Images, `image_gen`,
or manual drawing pipeline was used.

Selected PixelLab object ID/job: `a5e165f2-6609-45f7-b099-71361a68a0d0`.
Tool: `create_map_object`.
Canvas: `256x256`, high top-down, medium detail/shading, lineless.

## Prompt

```text
Transparent 256x256 top-down pixel art combat attack VFX sprite for robot_reactor_core, Reactor Core weapon, dark fantasy D&D roguelite. No text, no UI, transparent background. Must read as four separate reactor vent bursts around a mostly transparent center: north, east, south, west directional teal-blue plasma exhaust jets pushing outward from a compact circular reactor core ghost silhouette. Show the area of effect as a cross-shaped close-range knockback zone with four short bright vent corridors and a faint circular heat ring. Calm translucent alpha, cyan teal reactor glow, pale blue hot steam, tiny sparks, subtle metal/arcane energy, soft painterly pixel edges. Include a faint low-opacity ghost silhouette of a round mechanical reactor core weapon behind the effect. Keep combat readability: no opaque disk, no smoke cloud covering the center, no square border, no characters, no health bars, no ground texture, no watermark.
```

## Postprocess

- Raw PixelLab download saved as `robot_reactor_core_pixellab_source_raw.png`.
- PixelLab returned transparent metadata but the downloaded PNG had alpha 255
  everywhere with baked flat preview colors; dominant corner/field colors were
  removed to reconstruct transparency.
- Accepted source saved as `robot_reactor_core_pixellab_source.png`.
- Existing canonical weapon art `assets/sprites/weapons/robot_reactor_core.png`
  was composited at low opacity as a ghost silhouette under the PixelLab-generated
  exhaust arms.
- Center alpha was softened, final alpha capped, and the accepted runtime PNG was
  exported to `assets/sprites/effects/vfx_weapon_robot_reactor_core.png`.
- Gameplay, balance, targeting, cooldown, scene files, shared runtime scripts and
  other weapon VFX files were not changed.

## Design Intent

The previous runtime plate read as a generic magenta/orange magic ring. The new
plate reads as a reactor vent burst: four teal plasma exhaust arms, a faint
mechanical reactor-core weapon ghost, a close-range cross-shaped knockback zone,
and transparent corners/center for combat readability.

## Readability

- Contact sheet: `docs/design/previews/weapon_attack_animations/robot_reactor_core_contact.png`
  (weapon reference, raw PixelLab source, runtime on dark/light/mid backgrounds).
- Static report: `static_alpha_readability_report.json`.
- Runtime PNG metrics: `256x256` RGBA, `max_alpha=172`,
  `visible_pixel_ratio_alpha_gt_8=0.3309`, `center_64_mean_alpha=118.27`,
  transparent corner alpha `[0, 0, 0, 0]`.

## Green-Gate

- Static JSON validation — PASS:
  `python3 -m json.tool manifest.json` and
  `python3 -m json.tool static_alpha_readability_report.json`.
- Static PNG validation — PASS: runtime/source PNGs are `256x256` RGBA with
  alpha, preview is `1280x284` RGBA.
- `unique_weapon_vfx_assets_test.gd` — attempted through `tools/godot_gate.py`;
  gate/import path exited `143` with no test output while this disposable
  worktree had no `.godot` import cache.
- Direct `Godot --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`
  reached the script but failed before the asset assertion because required
  `.godot/imported/*.ctex` resources were absent; the process was interrupted
  after hanging post-diagnostic.
- `attack_vfx_smoke_test.gd` — not re-launched after the same import-cache
  failure, because it preloads the same texture set through `scripts/attack_vfx.gd`.
