# dark_wand attack VFX — generation evidence (SCRUM-739)

- **Weapon**: Темная палочка (`dark_wand`).
- **Mechanical role (unchanged)**: Два pierce-луча веером.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Dark Wand weapon: TWO long straight piercing energy beams
> fired in a fan spread from a single origin point. Two distinct narrow lance-like beams of bright
> cyan-white arcane light cored energy with a violet-purple outer glow, spreading apart in a shallow
> V fan, each beam long and straight with a sharp piercing arrowhead tip and a faint after-streak to
> show it pierces straight through everything in a line. Small sparks and purple arcane wisps along
> the beams, a bright cyan flash at the shared origin where the wand fires. The two clearly separate
> straight beams read as a twin piercing fan attack. Faintly at the origin, a translucent glowing
> ghost silhouette of the dark wand with its cyan crystal tip. The area between and behind the beams
> stays semi-transparent and readable so the player character remains visible. Calm semi-transparent
> combat overlay, NOT opaque, soft glowing cyan and violet light. Painterly dark fantasy arcane style.
> Fully transparent background, no ground texture, no grid, no user interface, no health bars, no
> characters, no text, no watermark. Single centered twin-beam fan effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_dark_wand_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard, причём здесь он ТЁМНЫЙ (~140, sat≈1), ниже
   обычного порога mx>170. Лучи — насыщенно-циановые (sat 57-107), даже бело-горячее ядро cyan-tinted
   (sat≈76). Использован `sat<20 & max_channel>120`: тёмный neutral checkerboard убран, оба cyan/violet
   луча, origin-flash и ghost палочки сохранены. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_dark_wand.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — палочка с фиолетовым всплеском, generic recolor, без читаемых «двух pierce-лучей».
- Новый — **два прямых пронзающих луча веером** (shallow V), cyan-white ядро + violet glow, piercing
  arrowhead-тип и after-streak (пробитие насквозь по линии), cyan-вспышка в origin, ghost палочки с
  cyan-кристаллом. Два раздельных прямых луча = twin pierce-fan.
- Уникальная «двойной pierce-веер» идентичность, число лучей и линия пробития читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/dark_wand_contact.png`
  (weapon ref | dark | light | mid-grey) — оба луча, вспышка и ghost читаются на всех фонах; фон
  прозрачен, между лучами прозрачно.
- Overall mean alpha ≈ 29: очень прозрачно; плотность только в самих лучах/вспышке.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/pierce/beam-count/range/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
