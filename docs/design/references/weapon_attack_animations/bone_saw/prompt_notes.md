# bone_saw attack VFX — generation evidence (SCRUM-734)

- **Weapon**: Костяная пила (`bone_saw`).
- **Mechanical role (unchanged)**: Ближний saw arc/flurry, DoT и lifesteal от урона.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Bone Saw melee weapon: a wide sweeping crescent slash arc
> showing the melee swing area in front of the wielder. The arc has a jagged serrated saw-tooth
> inner edge to read as a bone saw cut, bone-white and pale bone-grey with sharp crimson blood-red
> highlights, a spray of crimson blood droplets and flying bone shards trailing off the arc
> (lifesteal), and faint sickly poison-green wisps of decay along the cut to hint at
> damage-over-time. Faintly embedded along the arc, a translucent glowing ghost silhouette of the
> serrated bone saw weapon (bone handle, long serrated steel blade) sweeping through. The area
> behind the arc stays semi-transparent and readable so the player character remains visible. Calm
> semi-transparent combat overlay, NOT opaque, soft glowing edges, strong sense of a slashing
> sweep. Painterly dark fantasy game asset. Fully transparent background, no ground texture, no
> grid, no user interface, no health bars, no characters, no text, no watermark. Single centered
> crescent slash effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_bone_saw_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Глобальный снос по сигнатуре
   `sat<40 & max_channel>170` (bright+desaturated) + feather → фон убран, насыщенные blood-red /
   green-DoT / bone shards и ghost сохранены. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_bone_saw.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — пила с фиолетовой дугой-слэшем, generic recolor, без явной зоны замаха и без
  DoT/lifesteal-читаемости.
- Новый — широкая **серповидная дуга-слэш** = зона ближнего замаха/flurry, зубчатый saw-tooth
  внутренний край (распил), bone-white + crimson highlights, брызги крови и осколки кости
  (lifesteal), болезненно-зелёные wisps гнили (DoT), полупрозрачный ghost костяной пилы вдоль дуги.
- Уникальная «мясник/распил» идентичность, направление и охват замаха читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/bone_saw_contact.png`
  (weapon ref | dark | light | mid-grey) — дуга и ghost читаются на всех фонах, внутренняя область
  серпа прозрачна (игрок виден).
- Overall mean alpha ≈ 41: очень прозрачно вне самой дуги. Полупрозрачность боевого слоя
  дополнительно даёт рантайм-modulate.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/DoT/lifesteal/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
