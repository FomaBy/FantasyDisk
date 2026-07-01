# SCRUM-743 Prompt Notes

- Weapon ID: `elementalist_prism_focus`
- Runtime target: `assets/sprites/effects/vfx_weapon_elementalist_prism_focus.png`
- Source folder: `docs/design/references/weapon_attack_animations/elementalist_prism_focus/`
- Preview folder: `docs/design/previews/weapon_attack_animations/`
- PixelLab selected object/job: `d5ef1e3e-12d7-4f67-9ac0-7ba6a2b4c579`
- Production path: PixelLab MCP through `fantasydisk-asset-generator`.
- Unblock rationale: the old OpenAI Images-only wording is superseded by the 2026-07-01 dispatcher PixelLab path after `billing_hard_limit_reached`.

## Prompt

Transparent top-down game attack VFX plate for FantasyDisk weapon elementalist_prism_focus, a dark fantasy Dungeons and Dragons prism rift: two crossing violet-cyan crystalline beams slash diagonally through a quiet transparent center, short telegraph ring shards, soft arcane cracks, readable X-shaped area of effect, subtle ghost silhouette of a small prism focus weapon in the background, semi-transparent painterly magic, no text, no UI frame, no watermark, no solid background, no character, combat-readable at small scale.

## Result Notes

- PixelLab produced a strong crossed-prism composition but returned it on an opaque floor plate.
- Runtime postprocess alpha-cleans the luminous beams/crystal focus, removes the generated lower-right mark, and preserves a transparent 256x256 RGBA canvas.
- A subtle ghost silhouette from the existing `assets/sprites/weapons/elementalist_prism_focus.png` is composited into the accepted runtime effect.
- No damage, cooldown, targeting, range, radius, balance, scene contract, or shared runtime logic changed.
