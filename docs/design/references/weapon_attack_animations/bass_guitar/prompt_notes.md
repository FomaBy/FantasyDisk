# bass_guitar attack VFX — generation evidence (SCRUM-729)

- **Weapon**: Бас-гитара (`bass_guitar`), класс Гитарист.
- **Mechanical role (unchanged)**: Частый слабый контроль-пульс с сильным отталкиванием.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Bassist's electric Bass Guitar weapon: a powerful
> concentric sonic shockwave, several expanding circular sound-pulse rings radiating outward from
> the center to show an area knockback pulse pushing enemies away. Rings made of vibrating
> sound-wave ripples and low-frequency bass energy, warm burnt-orange and bright teal-cyan glowing
> accents matching the wooden bass guitar body, with faint audio-waveform texture along the rings.
> Faintly embedded in the center, a translucent glowing ghost silhouette of an electric bass guitar
> (body and long neck) as the pulse source. The center stays semi-transparent and readable so the
> player character underneath remains visible. Calm semi-transparent combat overlay, NOT opaque,
> soft glowing concentric rings, sense of outward push. Painterly game asset, energetic rock style.
> Fully transparent background, no ground texture, no grid, no user interface, no health bars, no
> characters, no musical notes text, no watermark. Single centered radial effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_bass_guitar_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard в PNG. Рисунок — полые кольца, поэтому
   checkerboard оказывается ЗАПЕРТ внутри колец (не связан с бордером) → border-connected
   flood-fill его не убирает. Использован **глобальный** снос по сигнатуре checkerboard
   (`sat<40 & max_channel>170` = bright+desaturated) + 0.8px feather → снимает и внешний, и
   запертый между кольцами фон; насыщенный orange/teal эффект и приглушённый ghost (mx≈142)
   сохранены. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_bass_guitar.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — фиолетовая горизонтальная audio-waveform, generic recolor, без AoE/knockback
  и без силуэта гитары.
- Новый — **концентрические звуковые кольца-пульсы**, расходящиеся наружу = зона действия +
  направление отталкивания (knockback). Тёплый burnt-orange + teal-cyan под цвет корпуса баса,
  waveform-текстура по кольцам, полупрозрачный ghost электро-баса (корпус+гриф) по центру.
- Уникальная «рок/саб-бас» идентичность, зона и вектор отталкивания читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/bass_guitar_contact.png`
  (weapon ref | dark | light | mid-grey) — кольца и ghost читаются на всех фонах, между кольцами
  прозрачно.
- Overall mean alpha ≈ 56: центр и промежутки между кольцами полупрозрачны/прозрачны — игрок под
  эффектом остаётся виден. Полупрозрачность боевого слоя дополнительно даёт рантайм-modulate.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/aoe radius/knockback/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
