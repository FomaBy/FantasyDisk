# chakrams attack VFX — generation evidence (SCRUM-736)

- **Weapon**: Чакрамы (`chakrams`).
- **Mechanical role (unchanged)**: Boomerang-коридор туда и обратно; критовые попадания дают shadow burst у цели без перемещения героя.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for dual spinning Chakrams thrown weapons: a boomerang corridor
> showing two razor-edged steel chakram discs hurled out and curving back along a straight lane,
> marking a there-and-back attack corridor. Two circular saw-bladed metal chakram rings with bright
> magenta-pink gem accents, spinning fast with sharp circular motion-blur trails and silver slash
> streaks tracing an elongated out-and-back path down the corridor to show the travel lane and
> reach. A burst of dark violet-purple shadow energy popping at the far end where a critical strike
> lands (shadow burst). Faintly along the trails, translucent glowing ghost silhouettes of the
> spinning bladed chakram discs. The corridor lane stays semi-transparent and readable so the player
> character remains visible. Calm semi-transparent combat overlay, NOT opaque, soft glowing steel
> and magenta light. Painterly dark fantasy game asset. Fully transparent background, no ground
> texture, no grid, no user interface, no health bars, no characters, no text, no watermark. Single
> centered boomerang-corridor effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_chakrams_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Глобальный снос `sat<42 & max_channel>165`
   (bright+desaturated) + feather → чистит фон и разреженный интерьер коридора-петли; насыщенные
   magenta-трейлы, тёмные стальные диски, gem-акценты и violet shadow-burst сохранены. Размер НЕ
   менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_chakrams.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — два чакрама с фиолетовым круговым swirl, статичный, без читаемого коридора и без
  crit-shadow-burst.
- Новый — **бумеранг-коридор**: удлинённая петля «туда-обратно» с двумя лезвийными дисками на концах,
  circular motion-blur трейлы + silver slash streaks по полосе (travel lane/reach), violet-purple
  **shadow burst** на дальнем конце (крит-попадание), полупрозрачные ghost вращающихся дисков.
- Magenta/violet оправданы палитрой оружия (magenta gems) и механикой (shadow = violet), не generic
  recolor: это направленная композиция-коридор.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/chakrams_contact.png`
  (weapon ref | dark | light | mid-grey) — коридор, диски и shadow-burst читаются на всех фонах;
  интерьер петли прозрачен → игрок виден.
- Overall mean alpha ≈ 42: очень прозрачно; плотность только в дисках/burst и вдоль трейлов.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/crit/shadow-burst/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
