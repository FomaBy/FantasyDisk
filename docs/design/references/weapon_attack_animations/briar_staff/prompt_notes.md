# briar_staff attack VFX — generation evidence (SCRUM-735)

- **Weapon**: Посох терний (`briar_staff`).
- **Mechanical role (unchanged)**: Thorn zone, AoE DoT, crowd control.
- **Generator override (user 2026-06-30)**: OpenAI `gpt-image-2` через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `--quality high`, `--size 1024x1024`. НЕ PixelLab.

## Prompt
> Top-down video game attack VFX for a Briar Staff druid weapon: a circular thorn zone of tangled
> brambles bursting up from the ground to mark an area-of-effect trap. A ring of gnarled brown
> thorny vines and sharp curved thorns radiating outward and inward around the zone perimeter to
> show crowd-control roots snaring enemies, glowing acid-green and emerald magical energy climbing
> the vines, small green leaves, and a faint sickly green poison mist hovering over the zone for
> damage-over-time. Faintly embedded in the center, a translucent glowing ghost silhouette of the
> briar staff (twisted thorny wooden staff topped with a bright green gem) as the source. The
> center of the zone stays semi-transparent and readable so the player character underneath remains
> visible. Calm semi-transparent combat overlay, NOT opaque, soft green magical glow. Painterly
> dark fantasy nature style. Fully transparent background, no ground texture, no grid, no user
> interface, no health bars, no characters, no text, no watermark. Single centered circular
> thorn-zone effect.

## Pipeline
1. `generate_asset.py` → `vfx_weapon_briar_staff_source.png` (1024×1024, RGBA).
2. **Alpha cleanup**: gpt-image-2 запёк checkerboard. Кольцо терний ЗАМЫКАЕТ центр, где мглистая
   зелёная дымка смешалась с checkerboard → давало видимую grid-сетку по альфе. Использован
   усиленный глобальный снос `sat<45 & max_channel>150` (bright+desaturated) + feather: убирает и
   checkerboard, и нейтральную дымку → центр становится читаемым (частично прозрачным), при этом
   насыщенная green-энергия, тёмные лозы-тернии и зелёный gem-ghost сохранены. Центровой
   neutral-remnant: 11.4% → 0.7%. Размер НЕ менялся.
3. Downscale LANCZOS 1024→256 → runtime `assets/sprites/effects/vfx_weapon_briar_staff.png`
   (256×256, matches siblings, `.import` UID сохранён).

## Design intent vs. prior asset
- Прежний ассет — фиолетовый терновый всплеск с посохом, generic recolor, без круговой зоны и
  без DoT/crowd-control-читаемости.
- Новый — **круговая зона терний** (bramble ring) = AoE-ловушка, изогнутые тернии наружу/внутрь
  (crowd control «корни-захваты»), emerald-энергия по лозам, зелёная ядовитая дымка (DoT),
  полупрозрачный ghost посоха с зелёным кристаллом по центру.
- Уникальная «друид/тернии» идентичность, радиус зоны и роль контроля читаются.

## Readability
- Contact sheet: `docs/design/previews/weapon_attack_animations/briar_staff_contact.png`
  (weapon ref | dark | light | mid-grey) — кольцо, дымка и ghost читаются на всех фонах; центр
  частично прозрачен → игрок под зоной остаётся виден. Grid-артефакт устранён.
- Overall mean alpha ≈ 101; плотность в кольце терний, центр разрежён.

## Balance / runtime
- НЕ менялись damage/cooldown/targeting/range/DoT/crowd-control/баланс и shared runtime scripts.
- Изменён только один runtime PNG + evidence. Один task = один `weapon_id`.

## Green-gate
- `unique_weapon_vfx_assets_test.gd` — PASS.
- `attack_vfx_smoke_test.gd` — PASS.
