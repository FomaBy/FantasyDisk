# dark_book attack VFX — generation evidence (SCRUM-738)

- **Weapon**: Книга тьмы (`dark_book`).
- **Mechanical role (unchanged)**: Два AoE-снаряда в две ближайшие цели.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Dark Book grimoire weapon: an open dark spellbook casting
> TWO separate arcane projectiles that split and fly outward to two different targets. From a glowing
> open book at the center, two diverging streams of violet-purple arcane energy arc out in two
> different directions, each ending in its own small circular area-of-effect burst marked by a glowing
> purple rune-circle with teal-cyan glyphs to show the two impact zones. Floating magic runes, purple
> sparks and dark energy wisps around the book, teal-cyan rune highlights matching the tome. The two
> clearly separate projectile trails and twin blast zones read as two AoE shots at once. Faintly at
> the center, a translucent glowing ghost silhouette of the open dark spellbook. The area stays
> semi-transparent and readable so the player character remains visible. Calm semi-transparent combat
> overlay, NOT opaque, soft arcane glow. Painterly dark fantasy arcane style. Fully transparent
> background, no ground texture, no grid, no user interface, no health bars, no characters, no text,
> no watermark. Single centered twin-projectile effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_dark_book_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Всё содержимое насыщенное (violet/teal), низко-
   насыщенных фич нет → стандартный глобальный снос `sat<40 & max_channel>170` (bright+desaturated) +
   feather: checkerboard убран, purple-болты, teal-глифы, rune-circle бёрсты и ghost книги сохранены.
   Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_dark_book.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — открытая книга с фиолетовой энергией, generic recolor, без читаемых «двух снарядов
  в две цели».
- Новый — открытая книга в центре кастует **два расходящихся arcane-болта** в две стороны, каждый
  завершается своим **rune-circle AoE-бёрстом** (две цели), teal-cyan глифы под палитру тома,
  полупрозрачный ghost книги по центру.
- Уникальная «гримуар / два AoE-снаряда» идентичность, число целей и зоны читаются напрямую.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/dark_book_contact.png`
  (weapon ref | dark | light | mid-grey) — книга, оба болта и оба AoE-бёрста читаются на всех фонах;
  фон прозрачен.
- Overall mean alpha ≈ 59; плотность в болтах/бёрстах, между лучами прозрачно.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/count/aoe radius/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
