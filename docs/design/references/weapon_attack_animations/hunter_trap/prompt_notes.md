# hunter_trap attack VFX — generation evidence (SCRUM-750)

- **Weapon**: Охотничий капкан (`hunter_trap`).
- **Mechanical role (unchanged)**: Deploy trap: burst + knockback; stance charge усиливает.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt (final, saturated-blue regen)
> Top-down video game attack VFX for a Hunter Trap weapon: a heavy steel bear-trap snapping shut and
> triggering a burst with knockback. A circular ring of jagged sharp dark steel trap jaws clamping
> together around a central spot, with a bright expanding circular shockwave ring of VIVID SATURATED
> ELECTRIC-BLUE and CYAN energy (deep vibrant blue, NOT white, NOT pale) blasting outward radially to
> show the knockback radius pushing enemies away, bright blue energy spikes and crackling arcs,
> metallic snap sparks and dark debris chunks flung out, and glowing blue sapphire gems on the trap.
> A small blue-glowing hunter paw-print emblem at the center of the trap. ... Use strong deep-blue
> saturation for all the energy so it stands out clearly. ... Fully transparent background, no ground
> texture, no grid, no UI, no health bars, no characters, no text, no watermark.

- **Note**: первая генерация дала БЕЛО-голубой shockwave (sat≈3-5) — почти неотличимый от запечённого
  checkerboard (sat≈0-1), не поддавался alpha-key. Перегенерил с явным «vivid saturated electric-blue,
  NOT white» → shockwave стал насыщенно-синим (sat≈33-246) и чисто отделяется от фона.

## Pipeline
1. `generate_asset.py` (2-я генерация) → `vfx_weapon_hunter_trap_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: `sat<30 & max_channel>152` (bright+desaturated) + feather → checkerboard и
   низконасыщенные frost/ghost-силуэты убраны (center-remnant 13.3%→6.8%), насыщенный синий shockwave,
   молнии, gem-акценты и тёмные steel jaws (mx ниже порога) сохранены. Размер НЕ менялся. Слабый
   остаточный frost-спекл в центре — низкая альфа, в игре скрыт аддитивным BLEND_MODE_ADD.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_hunter_trap.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — фиолетовый магический круг с шипами, generic recolor, без trap-burst/knockback.
- Новый — **стальной капкан, захлопывающийся кольцом зубьев** + яркий синий **shockwave-ring наружу**
  (knockback-радиус), разлетающиеся debris-чанки, blue-gem акценты, светящаяся paw-эмблема в центре,
  ghost капкана. Читается как «поставлен капкан → burst + knockback».
- Уникальная «охотничий капкан / trap burst» идентичность; захлоп + отбрасывание читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/hunter_trap_contact.png`
  (weapon ref | dark | light | mid-grey) — капкан, синий burst и debris читаются на всех фонах.
- Overall mean alpha ≈ 105; плотность в капкане/burst.

## Balance / runtime
- НЕ менялись deploy/trap/burst/knockback/stance/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
