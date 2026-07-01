# homunculus_vial attack VFX — generation evidence (SCRUM-749)

- **Weapon**: Склянка гомункула (`homunculus_vial`).
- **Mechanical role (unchanged)**: Temporary minion scaling from magic damage.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Homunculus Vial summoning weapon: the moment a temporary minion
> is conjured. A glowing circular arcane summoning rune-circle on the ground with green alchemical glyphs
> marks the spawn point, and rising from it a small translucent green homunculus creature (a tiny
> goblin-like alchemical familiar with glowing eyes) is materializing out of swirling toxic-green
> alchemical smoke and violet-purple magic energy, with bubbling green potion splashes, purple arcane
> sparks and floating glyphs spiraling up. A faint translucent ghost silhouette of the brass homunculus
> vial hovers above the circle as the source. The summoning circle clearly reads as a minion spawn zone.
> The center stays semi-transparent and readable. Calm semi-transparent combat overlay, NOT opaque, soft
> green and purple glow. Painterly dark fantasy alchemy style. Fully transparent background, no ground
> texture outside the rune circle, no grid, no UI, no health bars, no player character, no human, no
> text, no watermark. Single centered summoning effect.

- **Note**: показ маленького гомункула допустим и уместен — это САМ призванный миньон (часть эффекта),
  а не игрок; VFX не подменяет игрока. (В отличие от holy_flail, где фигура = игрок и её убирали.)

## Pipeline
1. `generate_asset.py` → `vfx_weapon_homunculus_vial_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Много низконасыщенной фиолетовой дымки + brass
   vial-ghost блендятся с checkerboard → спекл-ореол. Усиленный `sat<34 & max_channel>150`
   (bright+desaturated) + feather убирает checkerboard и нейтральную дымку (center-remnant 18.7%→4.3%),
   сохраняя насыщенный зелёный summoning-circle, гомункула, зелёную энергию и фиолетовые искры.
   Остаточный слабый спекл только в диффузном верхнем дым-плюме (низкая альфа; часть — собственные
   particle/bubble детали эффекта; в игре скрыт аддитивным BLEND_MODE_ADD). Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_homunculus_vial.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — склянка с зелёно-фиолетовым всплеском, generic recolor, без читаемого «призыва
  миньона».
- Новый — **аркан-круг призыва** (spawn zone) с материализующимся зелёным гомункулом-фамильяром из
  зелёной алхимической дымки + фиолетовой магии, bubbling potion, парящие глифы, ghost брасс-склянки
  сверху. Читается как призыв временного миньона.
- Уникальная «призыв гомункула» идентичность; спавн-зона и сам миньон видны.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/homunculus_vial_contact.png`
  (weapon ref | dark | light | mid-grey) — круг, гомункул и энергия читаются на всех фонах.
- Overall mean alpha ≈ 76; плотность в круге/фигуре, центр частично прозрачен.

## Balance / runtime
- НЕ менялись summon/minion-stats/scaling/duration/targeting/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
