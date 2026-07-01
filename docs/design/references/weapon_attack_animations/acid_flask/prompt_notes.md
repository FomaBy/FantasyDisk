# acid_flask attack VFX — generation evidence (SCRUM-727)

- **Weapon**: Кислотная колба (`acid_flask`), класс Химик.
- **Mechanical role (unchanged)**: Большая poison/acid pool; combo explosion с другим элементом.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Chemist's Acid Flask weapon: a large circular
> corrosive acid pool splashed on the ground, marking an area-of-effect zone. Vivid toxic
> acid-green and yellow-green corrosive liquid with a clearly readable round pool radius and
> irregular sizzling dripping edges, bubbling caustic froth, small rising green corrosive fume
> wisps, tiny fizzing bubbles. Faintly embedded in the center, a translucent ghost silhouette
> of a round bulbous green glass potion flask with a dark stopper and a small skull charm,
> glowing softly. The pool center stays semi-transparent and readable so the player character
> underneath remains visible. Calm semi-transparent combat overlay, NOT opaque, soft glowing
> edges. Painterly game asset, dark fantasy alchemical style. Fully transparent background, no
> ground texture, no grid, no user interface, no health bars, no characters, no text, no
> watermark. Single centered effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_acid_flask_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard в PNG (alpha=255 везде). Border-connected
   flood-fill (numpy+PIL BFS, bg = low-saturation & bright, 4-connectivity + 1px feather) →
   `vfx_weapon_acid_flask_cleaned.png`. Размер НЕ менялся → флуд-филл валиден.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_acid_flask.png`
   (256×256, matches all 50 sibling VFX, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — generic зелёно-магентовый всплеск с силуэтом колбы, читался как recolor.
- Новый — крупный **круглый кислотный пул (AoE-зона)**, видимый радиус, шипящие капающие края,
  поднимающиеся токсичные испарения, полупрозрачный ghost колбы со skull-charm по центру.
- Уникальная кислотно-зелёная идентичность колбы Химика, зона действия читается.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/acid_flask_contact.png`
  (weapon ref | dark bg | light bg | mid-grey bg) — эффект читается на всех фонах, края прозрачны.
- Overall mean alpha ≈ 109 (много прозрачной площади); плотность только в самом пуле.
- Полупрозрачность боевого слоя обеспечивается рантайм-modulate (как у всех siblings); PNG
  непрозрачен по центру аналогично 50 соседним VFX.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/aoe radius/knockback/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS (51 plates).
- `attack_vfx_smoke_test.gd` — PASS.
