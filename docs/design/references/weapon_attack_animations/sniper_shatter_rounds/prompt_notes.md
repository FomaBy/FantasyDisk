# SCRUM-764 Sniper Shatter Rounds Attack VFX

## Pipeline

- Required production path: PixelLab MCP via `fantasydisk-asset-generator`.
- Runtime target: `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds.png`.
- Canvas: 256x256 RGBA, transparent runtime background, no text.
- Reference weapon: `assets/sprites/weapons/sniper_shatter_rounds.png`.

## Accepted PixelLab Prompt

Transparent pixel art gameplay attack VFX plate only, no text, no background.
Draw a LONG DIAGONAL SNIPER SPLIT ROUND TRAIL from lower left toward upper
right: one narrow cyan-white bullet streak through the center that forks into
exactly two thinner shard trails near the upper right. Include a faint ghost
silhouette of three brass shatter cartridges behind the trail at 25 percent
opacity, small icy crystal fragments around the fork, calm soft edges, lots of
empty transparent space. FantasyDisk dark fantasy D&D style, steel blue and icy
cyan with tiny violet sparks. Do NOT draw a radial explosion, do NOT draw a
centered starburst, do NOT draw a circular magic glyph, do NOT fill the whole
canvas.

## PixelLab Results

- Accepted object: `cfd56c4b-35e0-4dfd-88ef-de0e1f7fc462`.
- Rejected candidate: `5f80744f-01e0-47be-a100-68d940669ead` because it read as
  a centered burst instead of a directional sniper split-round trail.
- PixelLab download metadata reported a transparent background, but both source
  downloads arrived fully opaque. The committed runtime PNG uses alpha cleanup
  from the accepted PixelLab source.

## Runtime Treatment

- Directional identity: long lower-left to upper-right icy shot trail.
- Weapon identity: existing `sniper_shatter_rounds.png` composited as a faint
  cyan ghost silhouette under the PixelLab trail.
- Combat readability: mean runtime alpha is `36.006`, below the previous
  runtime mean alpha of about `71.55`; alpha cap is `238`.
- Gameplay parameters, scenes, weapon balance, shared VFX scripts, and runtime
  hooks were not changed.

## Evidence

- Source: `sniper_shatter_rounds_pixellab_source.png`.
- Alpha-clean source: `sniper_shatter_rounds_pixellab_alpha_clean.png`.
- Contact sheet: `docs/design/previews/weapon_attack_animations/sniper_shatter_rounds_contact.png`.
- Static report: `static_alpha_readability_report.json`.
