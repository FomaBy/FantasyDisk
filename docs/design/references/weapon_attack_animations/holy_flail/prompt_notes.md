# holy_flail attack VFX — generation evidence (SCRUM-748)

- **Weapon**: Освященный кистень (`holy_flail`).
- **Mechanical role (unchanged)**: Medium circular heavy swing + сильнее counter damage.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt (final, no-character regen)
> Top-down video game attack VFX ONLY, an abstract effect with NO character and NO person: a heavy
> spiked flail ball swung in a full 360-degree circular sweep, marking a circular melee swing zone.
> Show ONLY a complete glowing ring-shaped motion trail of radiant divine golden and warm white holy
> light, with a single spinning heavy spiked iron morning-star ball and its short chain sweeping along
> the ring, small holy gold cross-shaped light glints and sparks scattered along the arc, and one
> brighter divine flash burst at a point on the ring for the counter strike. The very center of the
> ring is COMPLETELY EMPTY and fully transparent, no figure, no hand, no body, no wielder, no knight,
> no armor, no cloth. Just the golden circular light trail, the spiked ball, the chain and sparks.
> Translucent glowing ghost of the spiked ball along the trail. Calm semi-transparent combat overlay,
> NOT opaque, soft holy golden glow. Painterly heroic fantasy style. Fully transparent background,
> no ground texture, no grid, no UI, no health bars, no characters, no people, no text, no watermark.
> Single centered circular swing light-trail effect.

- **Note**: первая генерация нарисовала в центре целую фигуру паладина (нарушение «no characters» —
  VFX накладывается на реального игрока). Перегенерил с усиленным no-character/no-figure/empty-center
  негативом → центр пустой.

## Pipeline
1. `generate_asset.py` (2-я генерация) → `vfx_weapon_holy_flail_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard (sat≈0-1, mx≈231). Металл шипованного шара —
   низконасыщенный, поэтому строгий порог `sat<15 & max_channel>170`: checkerboard убран, золотое
   кольцо (sat≈58), divine flash (sat≈23) и тёмный металл шара (mx≈101, ниже порога) сохранены.
   Центр кольца остаётся пустым/прозрачным (opaque frac ≈0.002). Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_holy_flail.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — кистень с розовой дугой-замахом, generic recolor, без полного кругового замаха.
- Новый — **полный круговой золотой замах** (360° ring) = радиус тяжёлого кругового удара, золотой
  divine light-trail, шипованный шар + цепь по кольцу, gold cross/star glints, divine flash-burst
  (намёк на усиленный counter), ghost шаров по трейлу; центр пуст → игрок виден.
- Уникальная «святой круговой замах + counter» идентичность; 360° радиус читается.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/holy_flail_contact.png`
  (weapon ref | dark | light | mid-grey) — кольцо, шар и flash читаются на всех фонах; центр
  прозрачен → игрок под замахом виден.
- Overall mean alpha ≈ 71; плотность в кольце, центр пуст.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/swing-radius/counter/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
