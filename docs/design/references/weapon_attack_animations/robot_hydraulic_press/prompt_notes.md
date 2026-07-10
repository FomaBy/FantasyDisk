# Гидравлический Пресс attack VFX PixelLab notes

Issue: SCRUM-759
Weapon ID: `robot_hydraulic_press`
PixelLab tool: `create_map_object`
PixelLab object ID: `99b9c7ec-23d3-4110-a22a-912cf8b455b8`
Runtime PNG: `assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png`
Preview: `docs/design/previews/weapon_attack_animations/robot_hydraulic_press_contact.png`

## Production path

Direct user directive on 2026-07-01 superseded the stale OpenAI-only task text and
unblocked attack-VFX work through PixelLab MCP via `fantasydisk-asset-generator`.
This task did not use OpenAI Images, `image_gen`, manual drawing, or the legacy
repo `generate_asset.py` helper.

## PixelLab prompt

```text
Transparent 256x256 top-down RPG attack VFX decal for a dark fantasy D&D robot hydraulic press weapon. Show two heavy blackened-steel piston jaws/clamping plates closing from left and right into a straight central compression corridor, with teal hydraulic pressure glow, brass rivets, faint steam wisps, subtle impact sparks, and a low-opacity ghost/silhouette feel suitable for compositing a weapon reference. Calm semi-transparent combat effect, readable empty center line, no background tile, no floor, no UI frame, no text, no letters, no logo, no character, no projectile, no full weapon item icon. Shape should clearly communicate a horizontal corridor squeeze/press attack area, not a vertical hammer slam.
```

## Visual result

- Two blackened-steel hydraulic jaws close from left/right around a straight teal
  pressure lane, matching the `Compression line` weapon role.
- Runtime alpha is capped and the central corridor is softened so enemies,
  player, pickups, projectiles, HP bars and HUD stay readable at combat scale.
- The canonical `assets/sprites/weapons/robot_hydraulic_press.png` reference is
  composited only as a low-opacity teal/steel ghost silhouette under the
  generated VFX.
- Gameplay, balance, cooldown, targeting, scene files and shared VFX runtime
  logic are unchanged.

## Files

- Raw PixelLab download: `docs/design/references/weapon_attack_animations/robot_hydraulic_press/robot_hydraulic_press_pixellab_source_raw.png`
- Alpha-clean source: `docs/design/references/weapon_attack_animations/robot_hydraulic_press/robot_hydraulic_press_pixellab_source.png`
- Static alpha/readability report: `docs/design/references/weapon_attack_animations/robot_hydraulic_press/static_alpha_readability_report.json`
- Manifest: `docs/design/references/weapon_attack_animations/robot_hydraulic_press/manifest.json`
- Contact sheet: `docs/design/previews/weapon_attack_animations/robot_hydraulic_press_contact.png`

## SCRUM-917 compression animation pass (2026-07-10)

The accepted PixelLab source object `99b9c7ec-23d3-4110-a22a-912cf8b455b8`
was animated in PixelLab v3 as group
`659bdae5-22a9-4319-a3ca-57b972e5a9a3` (animation
`31a9bfff-ee16-4037-a8f5-32477c37a73c`). The 8-frame source now shows the
two plates and teal pressure moving side-to-centre, with frame 5 as the maximum
crush. Runtime playback is 25 fps so frame 5 lands at the existing Back-end hit
delay of exactly `0.20s`.

Raw PixelLab frames are preserved under `pixellab_animation_raw/`. Runtime
frames are mechanically normalized to centred `256x256` transparent canvases
with a stable `(128,128)` pivot, at least `16px` transparent gutter and zero
edge-visible pixels. The live scene rotates the source 90 degrees so the authored
left/right convergence becomes perpendicular to the current attack direction,
then scales it to the actual `430x300` or Calibrator `430x390` corridor.
No gameplay, damage, targeting, displacement, cooldown, balance or shared
`class_weapon.gd` path changed.
