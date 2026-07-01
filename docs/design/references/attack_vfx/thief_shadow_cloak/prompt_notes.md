# SCRUM-774 Thief Shadow Cloak Attack VFX Prompt Notes

Issue: SCRUM-774
Weapon ID: `thief_shadow_cloak`
Runtime asset: `assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png`
Source path: `docs/design/references/attack_vfx/thief_shadow_cloak/`
Mirror path: `docs/design/references/weapon_attack_animations/thief_shadow_cloak/`
Preview: `docs/design/previews/weapon_attack_animations/thief_shadow_cloak_contact.png`

## PixelLab Source

PixelLab object ID: `35360c9c-d67b-4f84-8fc5-6041c87db9e9`
Tool: `create_1_direction_object`
Output: `256x256` RGBA source PNG
Cost: `20` PixelLab generations

No OpenAI Images, `image_gen`, or legacy generic image-generation fallback was used.
This follows the 2026-07-01 Jira unblock/delegation directive for PixelLab-first
redraw work after the stale OpenAI billing blocker.

## Prompt

```text
FantasyDisk attack VFX plate for the thief weapon 'Shadow Cloak' / 'Плащ Захода':
a calm semi-transparent dark fantasy top-down backstab effect on transparent
background. Show a crescent-shaped violet-black shadow slash path that arcs from
behind a target, with a smoky cloak silhouette sweeping diagonally, a small splash
impact ring near the center-right, faint gold rim accents, and a ghostly empty
hooded cloak shape. No character body, no UI frame, no text, no solid background,
no square tile, no opaque fill. The center must stay readable/transparent for
gameplay; edges should fade into alpha. Square 256x256 standalone VFX sprite,
D&D dark fantasy dragon-adjacent style, polished but calm.
```

## Postprocess Notes

- The PixelLab source was preserved as `thief_shadow_cloak_pixellab_source_raw.png`.
- The raw source contained baked neutral checkerboard pixels inside the VFX; the
  accepted source `thief_shadow_cloak_pixellab_source.png` removes those pixels.
- The runtime PNG composites a low-opacity ghost silhouette from
  `assets/sprites/weapons/thief_shadow_cloak.png` under the PixelLab cloak sweep.
- A violet backstab trajectory and small center-right splash ring were reinforced
  deterministically for gameplay readability.
- Alpha is capped for calm combat readability; static metrics are recorded in
  `static_alpha_readability_report.json`.
- No gameplay code, scene file, damage, cooldown, targeting, attack shape, or
  shared VFX runtime API changed.

## Runtime Visual Contract

- Canvas: `256x256` RGBA at the existing weapon-signature path.
- Visual direction: lower-left shadow entry into a center-right backstab splash.
- Readability: transparent corners, softened center, no text/watermark/UI frame.
- Weapon identity: the canonical cloak PNG is visible as a low-opacity ghost.
