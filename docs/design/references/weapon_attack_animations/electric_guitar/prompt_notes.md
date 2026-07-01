# electric_guitar attack VFX — generation evidence (SCRUM-740)

- **Weapon**: Электрогитара (`electric_guitar`).
- **Mechanical role (unchanged)**: Звуковая волна вперед.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for an Electric Guitar weapon: a powerful directional sound wave
> blasted straight forward in a cone. A widening cone or wedge of concentric curved sound-wave ripples
> and shockwave arcs projected forward from a single origin, showing the forward blast direction and
> its spreading reach, made of vibrant teal-cyan and hot magenta-pink electric energy with crackling
> purple lightning bolts and audio-waveform ripples riding the wave. A bright flash at the origin where
> the guitar strikes the chord. The clearly directional forward-facing cone of stacked sound arcs reads
> as a forward sonic blast, NOT a circular pulse. Faintly at the origin, a translucent glowing ghost
> silhouette of the jagged electric guitar. The area stays semi-transparent and readable so the player
> character remains visible. Calm semi-transparent combat overlay, NOT opaque, soft neon glow. Painterly
> energetic punk-rock style. Fully transparent background, no ground texture, no grid, no user interface,
> no health bars, no characters, no musical notes text, no watermark. Single centered forward
> sound-wave cone effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_electric_guitar_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard (sat≈0, mx≈234). Дуги насыщенные (teal/pink
   sat>40), но заполняющая конус дымка местами почти нейтральная и смешалась с checkerboard → давала
   спекл. Использован `sat<24 & max_channel>150` (bright+desaturated) + feather: убирает checkerboard
   и нейтральную дымку (спекл center-remnant 16.1%→10.7%, конус стал читаемее/прозрачнее по центру),
   насыщенные teal/pink дуги, central waveform-ось и lightning сохранены. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_electric_guitar.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — гитара с фиолетовой молнией, generic recolor, без направленной звуковой волны.
- Новый — **направленный конус звуковой волны вперёд**: расширяющийся веер concentric sound-arcs,
  teal-cyan + hot-pink electric + purple lightning, central audio-waveform ось, вспышка в origin,
  ghost гитары. Явно НАПРАВЛЕННЫЙ вперёд (не круговой пульс — отличие от bass_guitar).
- Уникальная «forward sonic blast» идентичность под палитру teal/pink гитары; направление читается.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/electric_guitar_contact.png`
  (weapon ref | dark | light | mid-grey) — конус, дуги и ось читаются на всех фонах; фон прозрачен.
- Overall mean alpha ≈ 71; плотность в дугах/оси, направление вперёд явное.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/cone-angle/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
