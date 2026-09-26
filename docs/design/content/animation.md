<!-- content-registry-section -->

# FantasyDisk Content Registry — Анимации И Rig-Профили

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Анимации И Rig-Профили

Канонический контроллер cutout-анимации: `scripts/cutout_rig_2d.gd`.

SCRUM-298 зафиксировал Design standard для будущих full-frame playable character
sheets: `docs/design/references/character_animation_style_sheet_0_1_5.md`.
Персонажные redraw-задачи должны класть unarmed sheet по пути
`assets/sprites/characters/<class_id>_sheet.png`, cell `384x384`, 5 кадров
`walk` и 5 кадров `attack_primary` минимум; preferred sheet — `1920x1152` с
дополнительной строкой `idle`. Runtime wiring готов: `Player` автоматически
подхватывает этот путь при наличии sheet, добавляет runtime alias `attack` для
`attack_primary` и сохраняет static/cutout fallback для неперерисованных классов.
SCRUM-283 Design pass подготовил первый принятый playable source sheet:
`assets/sprites/characters/berserk_sheet.png` (`1920x768`, `384x384` cells,
5 `walk` + 5 `attack_primary`, transparent, unarmed). Animator pass подключил
runtime `assets/sprites/characters/berserk_spriteframes.tres` с отдельными
кадрами `assets/sprites/characters/full_frame/berserk/`, `walk` 5f loop,
`attack_primary`/`attack` 5f one-shot, manifest/contact/GIF в
`build/qa/scrum283/`; animation/runtime smoke PASS.

| ID | Тип | Где используется | Назначение | Статус |
| --- | --- | --- | --- | --- |
| `idle` | Animation state | Игрок, враги, элитки, боссы | Спокойная поза с малым body sway | Реализовано |
| `walk` | Animation state | Игрок и наземные враги | Движение от таза с противофазой ног | Реализовано |
| `hover` | Motion profile | `winged_spark` / `EnemyFlyingRunner.tscn` | Летающее движение без walking legs | Реализовано как rig-профиль |
| `attack` | Animation state | Берсерк, melee-враги, элитные dash/slam действия | Anticipation и follow-through атаки | Реализовано |
| `shoot` | Animation state | Ranged-враги, Темный маг, Гитарист, boss volley | Recoil/aim pose | Реализовано |
| `cast` | Animation state | Маги, summoner, elites, bosses | Ритуальная поза рук / подготовка способности | Реализовано |
| `hit` | Animation state | Игрок, враги, элитки, боссы | Короткий hit flash и pose interruption | Реализовано |
| `death` | Animation state | Игрок, враги, элитки, боссы | Clean fallback перед удалением сущности | Реализовано |
| `directional_pose` | Motion layer | Игрок, враги, элитки, боссы | Head/full-art offset для движения вверх, вниз и вбок; Berserk additionally selects explicit 8-direction full-frame rows by movement vector | Реализовано |
| `soft_turn` | Transition layer | Игрок, враги, элитки, боссы | Короткий turn squash при смене horizontal facing | Реализовано |
| `foot_lift` | Motion layer | Наземные игроки и враги | Alternating foot lift / weight shift против скольжения | Реализовано |
| `wing_flap` | Motion layer | `winged_spark` и будущие flying-существа | Зеркальный flap вместо walking legs | Реализовано |

Rig-профили выбираются по ID/имени сущности:
- `berserk`, `soldier`, `dark_mage`, `guitarist`, `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` - игроки с `VisualRoot/RigRoot` и `WeaponSocketMount`.
- `runner`, `biter`, `stalker`, `spark` - быстрый низкий stride.
- `shooter`, `marksman`, `mage`, `spitter` - осторожная малая амплитуда.
- `bruiser`, `shield`, `armored`, `bastion` - тяжелый медленный sway.
- `summoner`, `caller`, `shaman`, `prophet` - ritual/cast arm motion.
- `warden`, `devourer` - boss heavy motion с action anticipation.

Source-спрайты для rig должны сохранять читаемые torso/head области, которые режет `scripts/cutout_rig_2d.gd`. Фактические конечности анимируются rig-ом, а исходные PNG также остаются пригодными как menu/fallback-изображения.

С 2026-06-11 активный боевой визуал — cutout-части, нарезанные из polished full-art спрайтов инструментом `tools/slice_rig_cutouts.py` (манифест `scripts/sliced_rig_manifest.gd`). Канонические папки:
- `assets/sprites/characters/cutout/`
- `assets/sprites/enemies/cutout/`
- `assets/sprites/elites/cutout/`
- `assets/sprites/bosses/cutout/`

Схема имен: `<entity_id>_torso.png`, `<entity_id>_arm_l.png`, `<entity_id>_arm_r.png`, `<entity_id>_leg_l.png`, `<entity_id>_leg_r.png`; по необходимости `<entity_id>_wing_l/r.png`, `<entity_id>_weapon.png`, `<entity_id>_shield.png`, `<entity_id>_tail.png`, `<entity_id>_vortex.png`. В покое сборка пиксель-в-пиксель совпадает с исходным full-art спрайтом; конечности анимируются rig-ом. Исходные PNG остаются для меню/нарезки. Старые папки `assets/sprites/*/rig_parts/` — устаревший каркас, в runtime не используются. Ранее устаревший `assets/sprites/visual_redesign_preview.png` вынесен в `build/cleanup_backup_2026_06_12/` чисткой 2026-06-12.

Sprite quality audit 2026-06-11 (`tools/sprite_quality_audit.py`): по всем активным папкам спрайтов вычищены грязные полупрозрачные пиксели и невидимые островки; в cutout-конечностях 21 части устранены «летающие» обрезки соседних частей тела (фрагменты возвращены в слой торса автопостобработкой `fix_detached_fragments` в `tools/slice_rig_cutouts.py` — повторные нарезки остаются чистыми). Оторванные элементы дизайна (искры иконок, парящие орбы/руны мага) сохранены. Запрещено возвращать активный боевой визуал к квадратным blocky-заглушкам.

Разрешения source-спрайтов: персонажи 512x512, стандартные монстры 192x192, активные элитки 512x512 после SCRUM-135, боссы 512x512 для текущего boss roster/source set. Mini-elite source sprites из SCRUM-156 также 512x512.

Спрайт `dark_mage` переработан 2026-06-11 под walk-анимацию: нейтральная стойка с двумя читаемыми симметричными ногами (просвет между ними, стопы на одной линии, низ мантии не скрывает колени/стопы). Инструмент: `tools/rework_dark_mage_legs.py` (оригинал в `build/bg_backup/dark_mage_original.png`). Cutout-части ног (`assets/sprites/characters/cutout/dark_mage_leg_l.png` / `dark_mage_leg_r.png`) пересобраны с полными голень+бедро крупами и пивотами у бедер.

SCRUM-286 (2026-06-14) добавил Design-ready unarmed full-frame sheet
`assets/sprites/characters/dark_mage_sheet.png`: `1920x1152`, 3 rows
(`idle`, `walk`, `attack_primary`) x 5 frames, `384x384` cells, transparent
RGBA, bottom-center pivot guide `[192,348]`. Source/reference files live under
`docs/design/references/characters/dark_mage/`; QA contact/GIF/manifest files
live under `docs/design/previews/` and `build/qa/scrum286_dark_mage/`. Animator
pass подключил runtime `assets/sprites/characters/dark_mage_spriteframes.tres`
через отдельные кадры `assets/sprites/characters/full_frame/dark_mage/`, чтобы
live SpriteFrames не резали соседние клетки source sheet; animation/runtime smoke
PASS.

SCRUM-291 (2026-06-14) добавил unarmed Guitarist sheet
`assets/sprites/characters/guitarist_sheet.png`: `1920x1152`, 3 rows
(`idle`, `walk`, `attack_primary`) x 5 frames, `384x384` cells, transparent
RGBA, bottom-center pivot guide `[192,348]`. Animator pass подключил runtime
`assets/sprites/characters/guitarist_spriteframes.tres` через отдельные кадры
`assets/sprites/characters/full_frame/guitarist/`, чтобы live SpriteFrames не
резали соседние клетки source sheet. Source/reference files live under
`docs/design/references/characters/guitarist/`; Design QA files live under
`build/qa/scrum291_guitarist/`, Animator manifest/contact/GIF under
`build/qa/scrum291/`. Manifest validation, Godot import, animation smoke and
runtime smoke PASS after SCRUM-409.

SCRUM-289 (2026-06-14) добавил unarmed Elementalist sheet
`assets/sprites/characters/elementalist_sheet.png`: `1920x1152`, 3 rows
(`idle`, `walk`, `attack_primary`) x 5 frames, `384x384` cells, transparent
RGBA, bottom-center pivot guide `[192,348]`. Source/reference files live under
`docs/design/references/characters/elementalist/`; QA contact preview:
`docs/design/previews/scrum289_elementalist_sheet_contact.png`; Design
manifest/report/GIF previews live under `build/qa/scrum289_elementalist/`.
Character is unarmed: no staff, wand, orb, focus, weapon or held object; only
close hand fire/ice/lightning energy remains. Animator pass подключил runtime
`assets/sprites/characters/elementalist_spriteframes.tres` через отдельные
кадры `assets/sprites/characters/full_frame/elementalist/`; Animator
manifest/contact/GIF previews live under `build/qa/scrum289/`. Manifest
validation, Godot import, animation smoke and runtime smoke PASS.

SCRUM-282 / SCRUM-294 (2026-06-14) подключили accepted unarmed Assassin and
Ranger sheets through runtime SpriteFrames:
`assets/sprites/characters/assassin_spriteframes.tres` and
`assets/sprites/characters/ranger_spriteframes.tres`. Both expose `idle` 5f
loop, `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, with
per-frame runtime PNGs in `assets/sprites/characters/full_frame/assassin/` and
`assets/sprites/characters/full_frame/ranger/`; QA manifests/contact/GIFs live
under `build/qa/scrum282/` and `build/qa/scrum294/`. Manifest validation,
animation smoke and runtime smoke PASS.
