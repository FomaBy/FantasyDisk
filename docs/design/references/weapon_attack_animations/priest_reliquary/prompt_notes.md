# SCRUM-756 Priest Reliquary Attack VFX Prompt Notes

Weapon: `priest_reliquary` / Светлый Реликварий.

Runtime target: `assets/sprites/effects/vfx_weapon_priest_reliquary.png`, 256x256 RGBA transparent PNG.

PixelLab MCP tool: `create_map_object`

PixelLab object ID: `722346d1-554d-4ecd-8970-b2a6e154b543`

Prompt:

```text
FantasyDisk priest_reliquary attack VFX plate, transparent background, high top-down view. A sacred golden-white reliquary sanctify seal: circular halo ring, soft cross/starburst sigil, small relic-window silhouette embedded in the glow, gentle radial healing burst and faint motes. Calm semi-transparent D&D dark fantasy combat effect, readable empty center, no text, no numbers, no UI, no background, no full character, no solid opaque disk, not neon, not cartoonish. Designed as a 256x256 Godot top-down attack effect that will later be alpha-capped and composited with the weapon ghost silhouette.
```

PixelLab settings:

- Canvas: `256x256`
- View: `high top-down`
- Detail: `high detail`
- Outline: `selective outline`
- Shading: `detailed shading`
- Background: transparent requested; downloaded PNG had an opaque flat gray preview fill, so the accepted source removes that fill.

Postprocess:

- Raw source saved as `priest_reliquary_pixellab_source_raw.png`.
- Alpha-clean PixelLab source saved as `priest_reliquary_pixellab_source.png`.
- Runtime VFX composites `assets/sprites/weapons/priest_reliquary.png` as a low-opacity golden ghost silhouette inside the sanctify seal.
- Final runtime alpha is capped at `170`; center `64x64` mean alpha is `88.78`.
- Gameplay, cooldowns, targeting, damage, balance, scene files and shared runtime scripts were not changed.

Evidence:

- Static report: `docs/design/references/weapon_attack_animations/priest_reliquary/static_alpha_readability_report.json`
- Contact sheet: `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`
