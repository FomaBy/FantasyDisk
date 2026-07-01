# SCRUM-773 Thief Coin Pouch Attack VFX Prompt Notes

Issue: SCRUM-773
Weapon ID: `thief_coin_pouch`
Runtime asset: `assets/sprites/effects/vfx_weapon_thief_coin_pouch.png`
Source path: `docs/design/references/attack_vfx/thief_coin_pouch/`
Preview: `docs/design/previews/attack_vfx/thief_coin_pouch_contact.png`

## PixelLab Source

PixelLab MCP was used through the `fantasydisk-asset-generator` skill. The old
OpenAI-only helper path in the original task mirror remained blocked by
`billing_hard_limit_reached`; the 2026-07-01 Jira/task unblock switched this
issue to PixelLab.

Tool: `mcp__pixellab.create_map_object`
PixelLab object ID: `cb77b5fe-3669-4fdf-a269-42f2d999f9d5`
Canvas: `256x256`
View: `low top-down`
Detail/shading: `high detail` / `detailed shading`
Outline: `selective outline`

## Prompt

```text
FantasyDisk dark fantasy D&D top-down 2D game attack VFX source plate for the Thief weapon 'thief_coin_pouch' / Ricochet Coin Pouch. Transparent background PNG, no text, no watermark, no UI. A small worn leather coin pouch ghost silhouette sits faintly behind the effect, while bright gold coins ricochet in a chained zig-zag arc between four small target glints. The chain should show diminishing damage by making each successive coin trail smaller and fainter. Calm semi-transparent painterly magical VFX, readable empty center, soft alpha edges, gold and muted violet shadow accents, not a solid explosion, not a full background, suitable as a 256x256 weapon signature attack effect.
```

## Postprocess Notes

- PixelLab metadata reported a transparent background, but the downloaded source
  had an opaque neutral gray preview matte. The raw file is kept as source
  evidence.
- `thief_coin_pouch_pixellab_source_alpha_clean.png` removes the gray matte and
  clamps live alpha for combat readability.
- The accepted runtime PNG composites the cleaned PixelLab coin-chain effect
  with a very faint silhouette derived from
  `assets/sprites/weapons/thief_coin_pouch.png`, so the exact weapon identity
  remains visible without covering the player/world.
- The runtime plate keeps transparent corners, no fully opaque pixels, sparse
  visible coverage, and a readable center.
- No gameplay code, damage values, cooldowns, targeting, attack range, AoE
  radius, balance, or shared runtime API changed.

## Runtime Visual Contract

- Canvas: `256x256` RGBA, existing `vfx_weapon_<weapon_id>.png` contract.
- Visual direction: chained gold coins ricochet through a curved path with
  smaller/fainter follow-up hits.
- Area read: target glints and coin trail communicate the chain/nearest-target
  behavior of `coin_ricochet`.
- Readability: alpha max `218`, visible coverage `14.15%`, corner alpha `0`,
  center alpha mean `30.13`, no text or watermark.
