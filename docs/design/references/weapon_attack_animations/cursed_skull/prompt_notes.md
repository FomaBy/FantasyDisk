# cursed_skull attack VFX — generation evidence (SCRUM-737)

- **Weapon**: Проклятый череп (`cursed_skull`).
- **Mechanical role (unchanged)**: Самонаводящееся проклятие, DoT и небольшой splash по цели.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Cursed Skull amulet weapon: a homing curse projectile shaped
> like a ghostly flaming skull that seeks its target. A spectral bone-white skull wreathed in sickly
> necrotic green flames with glowing purple curse-fire in the eye sockets, flying along a curving
> S-shaped homing trail of green and purple wisps that shows the projectile tracking and curving
> toward the target. At the leading tip, a small splash burst of green necrotic energy and purple
> curse sparks where it strikes, with faint drifting green damage-over-time mist. Faintly along the
> trail, a translucent glowing ghost silhouette of the skull. The trail and area stay semi-transparent
> and readable so the player character remains visible. Calm semi-transparent combat overlay, NOT
> opaque, soft eerie green and purple glow. Painterly dark fantasy necromancy style. Fully transparent
> background, no ground texture, no grid, no user interface, no health bars, no characters, no text,
> no watermark. Single centered homing curse effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_cursed_skull_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Костяной череп — низконасыщенный (sat≈30),
   близок к checkerboard, поэтому обычный `sat<40` его бы съел. Использован **строгий** порог
   `sat<18 & max_channel>150`: checkerboard (sat≈1-5) убран, костяной череп (sat>18) и насыщенные
   green/purple пламя+трейл сохранены. Размер НЕ менялся. Остаточные нейтральные пиксели вдоль трейла
   (~7%) — это сам эфемерный дым проклятия; рантайм рендерит plate аддитивно (BLEND_MODE_ADD), так
   что слабый тёмно-серый край в игре не виден.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_cursed_skull.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — статичный череп в зелёном пламени с фиолетовыми брызгами, без самонаведения и без
  splash-удара.
- Новый — **самонаводящийся curse-bolt**: призрачный череп с S-образным seeking-трейлом (читается
  «доводка до цели»), некротическое зелёное пламя (DoT) + фиолетовый curse-fire в глазницах (палитра
  оружия), маленький green/purple **splash** на ведущем конце (удар по цели), ghost черепа по трейлу.
- Уникальная «самонаводящееся проклятие» идентичность, доводка/DoT/splash читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/cursed_skull_contact.png`
  (weapon ref | dark | light | mid-grey) — череп, трейл и splash читаются на всех фонах; трейл
  полупрозрачен → игрок виден.
- Overall mean alpha ≈ 47: очень прозрачно; плотность в черепе/splash.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/homing/DoT/splash/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
