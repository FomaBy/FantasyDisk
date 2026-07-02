# blast_powder attack VFX — generation evidence (SCRUM-733)

- **Weapon**: Взрывная пыль (`blast_powder`).
- **Mechanical role (unchanged)**: AoE explosion + spark cloud; combo с другим элементом.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a demolitionist's Blast Powder bomb weapon: a large circular
> explosion blast marking an area-of-effect radius. A fiery orange, gold and yellow fireball
> bursting outward with an expanding circular shockwave ring at the edge to show the blast radius,
> a swirling cloud of glowing orange sparks and embers, drifting dark smoke and scattered debris
> chunks and soot around the rim. Faintly embedded in the center, a translucent glowing ghost
> silhouette of a round black gunpowder keg bomb with a skull-and-crossbones emblem and a lit fuse,
> at the moment of detonation. The center of the blast stays somewhat readable so the player
> character underneath remains partly visible. Calm semi-transparent combat overlay, NOT fully
> opaque, soft glowing fire and ember light. Painterly dark fantasy game asset. Fully transparent
> background, no ground texture, no grid, no user interface, no health bars, no characters, no
> text, no watermark. Single centered radial explosion effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_blast_powder_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Глобальный снос по сигнатуре
   `sat<40 & max_channel>170` (bright+desaturated) + feather → чистит фон и промежутки между
   debris-чанками; насыщенный fire/ember, тёмный smoke/soot и ghost сохранены. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_blast_powder.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — side-view взрыв с fire/debris и generic фиолетовыми брызгами, не читался как
  top-down AoE-радиус.
- Новый — **круговой взрыв сверху** с ярким shockwave-ring по краю = читаемый AoE-радиус, огненный
  orange/gold шар, облако искр/эмберов, дым и разлетающиеся debris-чанки, полупрозрачный ghost
  круглого порохового keg-бомбы со skull-and-crossbones и горящим фитилём по центру.
- Уникальная «подрывник/порох» идентичность, зона взрыва читается.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/blast_powder_contact.png`
  (weapon ref | dark | light | mid-grey) — взрыв и ghost читаются на всех фонах, края прозрачны.
- Overall mean alpha ≈ 115: плотный центр = сам взрыв, вокруг прозрачно. Полупрозрачность боевого
  слоя дополнительно даёт рантайм-modulate (как у всех siblings).

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/aoe radius/knockback/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
