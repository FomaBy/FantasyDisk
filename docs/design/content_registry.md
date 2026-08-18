# FantasyDisk Content Registry

Обновлено: 2026-06-14

Этот документ задает правило для всех будущих задач: любая игровая сущность должна иметь понятное имя, стабильный ID и место в документации. Рандом в игре может выбирать только из заранее определенных сущностей, а не создавать безымянный контент, на который потом невозможно сослаться.

## Обязательное Правило Для Будущих Тасков

Если задача добавляет, удаляет или меняет функционал, вместе с кодом нужно обновить документацию:

| Что меняется | Что обновить |
| --- | --- |
| Core loop, экраны, карта, камера, пауза, UX | `docs/design/fantasydisk_design_brief.md` и `docs/design/current_game_state.md` |
| Персонажи, оружие, враги, элитки, боссы, артефакты, события | `docs/design/content_registry.md` и `docs/design/current_game_state.md` |
| Характеристики, формулы, награды, баланс, магазин | `docs/design/mechanics_extract.md` и `docs/design/current_game_state.md` |
| Изменение исходного дизайн-решения | `docs/design/gdd_source.md` как актуальное дополнение, не стирая исходный GDD |
| Новые ассеты | `docs/design/content_registry.md` и раздел ассетов в `docs/design/current_game_state.md` |

Нельзя оставлять новую механику только в коде. Если другой агент не может найти ее в документации, задача считается недодокументированной.

## Правило Автономной Работы

Пользователь заранее дает approval на все изменения, которые входят в scope задачи. Агент должен не спрашивать "можно ли делать", а делать:

- самостоятельно принимать разумные решения по реализации;
- вносить изменения в код, сцены, ассеты, тесты и документацию в рамках задачи;
- запускать проверки, указанные в задаче;
- фиксировать принятые решения в документации.

Спрашивать пользователя нужно только если:

- требование невозможно выполнить без отсутствующей информации;
- есть несколько вариантов, которые радикально меняют направление игры;
- нужно выполнить потенциально разрушительное действие;
- требуется доступ/эскалация, которую среда Codex обязана запрашивать отдельно.

Системные правила Codex имеют приоритет: нельзя обходить sandbox approvals, раскрывать секреты, удалять чужие изменения или выполнять destructive git/file operations без явного разрешения.

## Формат Любой Сущности

У каждой сущности должны быть:

| Поле | Требование |
| --- | --- |
| `id` | Стабильный `snake_case` ID для кода и документации |
| Игровое имя | Название, которым можно пользоваться в задачах и обсуждениях |
| Тип | Персонаж, оружие, враг, босс, артефакт, узел карты, событие и т.д. |
| Роль | Зачем сущность нужна в геймплее |
| Источник | Скрипт, сцена, ресурс или таблица, где она определена |
| Ассет | Спрайт/иконка/фон, если применимо |
| Статус | Реализовано, прототип, планируется, устарело |

Процедурная генерация допускается только для экземпляров. Например, можно случайно выбрать врага `rift_cutter`, но нельзя создать “рандомного сильного монстра без имени”. Если нужна новая вариация, сначала добавить ее в реестр.

## Брендинг Проекта

| ID | Игровое имя | Роль | Источник | Ассет | Статус |
| --- | --- | --- | --- | --- | --- |
| `fantasydisk_app_icon` | Иконка FantasyDisk | Project/application icon в fantasy style: золотой диск, фиолетовый разлом, dark fantasy frame | `project.godot` `application/config/icon` | `icon.svg` | Реализовано |
| `fantasydisk_steam_library_logo` | Steam Library Logo FantasyDisk | Маркетинговый PNG-логотип для Steam Library/brand placement: прозрачный фон, золотой fantasy title, disk/rift emblem | `tools/generate_steam_logo.py` | `assets/marketing/steam/fantasydisk_steam_library_logo.png` | Реализовано |

## Персонажи

| ID | Игровое имя | Роль | Источник | Ассет | Статус |
| --- | --- | --- | --- | --- | --- |
| `berserk` | Берсерк | Ближний бой, физический урон, конусы и AoE | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/berserk_spriteframes.tres`, `assets/sprites/characters/full_frame/berserk_pixellab/`, `assets/sprites/characters/pixellab/berserk/`, legacy `assets/sprites/characters/full_frame/berserk/`, `assets/sprites/characters/cutout/berserk_*.png` | Реализовано; SCRUM-703 live runtime uses a new unarmed PixelLab v3 8-direction pack (`8486ce45-f749-4c63-9a6d-f0477d619c2d`) with 6f move/walk rows, directional idle fallbacks, and normalized `245 px` alpha-bbox height on `512x512` frames; legacy art remains fallback/history |
| `soldier` | Солдат | Тактический физический класс: залпы, гранаты и удержание линии | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/soldier_spriteframes.tres`, `assets/sprites/characters/full_frame/soldier_pixellab/`, `assets/sprites/characters/pixellab/soldier/`, legacy `assets/sprites/characters/soldier.png`, `assets/sprites/characters/cutout/soldier_*.png` | Реализовано; SCRUM-434 live runtime uses PixelLab character `72b487d3-feea-4012-b39f-b59ba24f7f11` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy art remains fallback/history |
| `thief` | Вор | Уловки, рикошет монет, backstab и дымовое уклонение | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/thief_spriteframes.tres`, `assets/sprites/characters/full_frame/thief_pixellab/`, `assets/sprites/characters/pixellab/thief/`, legacy `assets/sprites/characters/full_frame/thief/`, `assets/sprites/characters/thief.png`, `assets/sprites/characters/thief_sheet.png`, `assets/sprites/characters/cutout/thief_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/thief/` | Реализовано; SCRUM-800 live runtime uses PixelLab character `02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f` with 8-direction idle rotations and 6-frame directional move/walk rows; SCRUM-435 v2 assets remain fallback/history |
| `elementalist` | Элементалист | Стихийный AoE-контроль: орбиты, призмы и метеорные осколки | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/elementalist_spriteframes.tres`, `assets/sprites/characters/full_frame/elementalist_pixellab/`, `assets/sprites/characters/pixellab/elementalist/`, legacy `assets/sprites/characters/full_frame/elementalist/`, `assets/sprites/characters/elementalist.png`, `assets/sprites/characters/elementalist_sheet.png`, `assets/sprites/characters/cutout/elementalist_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/elementalist/` | Реализовано; FAN-2879 live runtime uses PixelLab character `4b01496c-09c9-4cc8-8913-a9feee4e3a69` (replaces deleted/404 SCRUM-801 `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`) with 8-direction idle rotations and 6-frame directional move/walk rows, all 8 directions from one animate_character job; SCRUM-427 v2 assets remain fallback/history |
| `sniper` | Снайпер | Дальний точный класс: lockshot, kill-zone и split rounds | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/sniper_spriteframes.tres`, `assets/sprites/characters/full_frame/sniper_pixellab/`, `assets/sprites/characters/pixellab/sniper/`, legacy `assets/sprites/characters/full_frame/sniper/`, `assets/sprites/characters/sniper.png`, `assets/sprites/characters/sniper_sheet.png`, `assets/sprites/characters/cutout/sniper_*.png`, v2 source handoff `assets/sprites/characters/v2/sniper/sniper_v2_idle_source.png` | Реализовано; SCRUM-433 live runtime uses PixelLab character `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-296 full-frame art remains fallback/history |
| `priest` | Священник | Священный sustain: sanctify, ward-пульсы и молитвенная цепь | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/priest_spriteframes.tres`, `assets/sprites/characters/full_frame/priest_pixellab/`, `assets/sprites/characters/pixellab/priest/`, legacy `assets/sprites/characters/full_frame/priest/`, `assets/sprites/characters/priest.png`, `assets/sprites/characters/cutout/priest_*.png`, v2 source handoff `assets/sprites/characters/v2/priest/priest_v2_idle_source.png` | Реализовано; SCRUM-431 live Hero Select/runtime SpriteFrames use PixelLab v3 8-direction static rotations + 6-frame directional walk (`walking-6-frames`); legacy full-frame art remains history/fallback |
| `biologist` | Биолог | Биореакции: spore bloom, sample analysis и symbiote web | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/biologist_spriteframes.tres`, `assets/sprites/characters/full_frame/biologist_pixellab/`, `assets/sprites/characters/pixellab/biologist/`, legacy `assets/sprites/characters/full_frame/biologist/`, `assets/sprites/characters/biologist.png`, `assets/sprites/characters/biologist_sheet.png`, `assets/sprites/characters/cutout/biologist_*.png`, v2 source handoff `assets/sprites/characters/v2/biologist/biologist_v2_idle_source.png` | Реализовано; SCRUM-421 live Hero Select/runtime SpriteFrames use PixelLab source `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4` with 8 idle directions and 6-frame directional `move`/`walk`, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-284 full-frame art remains history/fallback |
| `robot` | Робот | Тяжелый tank-control: magnetic anchor, compression line и reactor vent | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/robot_spriteframes.tres`, `assets/sprites/characters/full_frame/robot_pixellab/`, `assets/sprites/characters/pixellab/robot/`, legacy `assets/sprites/characters/robot.png`, `assets/sprites/characters/cutout/robot_*.png` | Реализовано; SCRUM-802 live runtime uses PixelLab character `37c6ccf2-ab40-4c89-83a3-db8365f85257` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-432/v2 scope remains history/fallback |
| `engineer` | Инженер | Механический summoner/support: sentry link, repair drone и pressure mines | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/engineer_spriteframes.tres`, `assets/sprites/characters/full_frame/engineer_pixellab/`, `assets/sprites/characters/pixellab/engineer/`, legacy `assets/sprites/characters/full_frame/engineer/`, `assets/sprites/characters/engineer.png`, `assets/sprites/characters/cutout/engineer_*.png` | Реализовано; SCRUM-428 live runtime uses PixelLab character `c5bd9766-e7de-4316-ace6-e687c951e621` with 8-direction idle rotations and 6-frame directional move/walk rows; legacy art remains fallback/history |
| `dark_mage` | Темный маг | Магический урон, AoE, DoT, лучи | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/dark_mage_spriteframes.tres`, `assets/sprites/characters/full_frame/dark_mage_pixellab/`, `assets/sprites/characters/pixellab/dark_mage/`, legacy `assets/sprites/characters/full_frame/dark_mage/`, `assets/sprites/characters/dark_mage.png`, `assets/sprites/characters/dark_mage_sheet.png`, `assets/sprites/characters/cartoon2/dark_mage/dark_mage_cartoon2_anim_sheet.png`, `assets/sprites/characters/cutout/dark_mage_*.png`, v2 source/runtime assets under `assets/sprites/characters/v2/dark_mage/`, skeleton-source package `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json` | Реализовано; SCRUM-704 live Hero Select/runtime SpriteFrames use a new PixelLab v3 8-direction 240-250px full redraw with 6-frame directional move/walk rows and empty hands; legacy SCRUM-473 cartoon2 and skeleton assets remain history/fallback |
| `guitarist` | Гитарист | Звуковые волны, импульсы, ауры, отталкивание | `scripts/progression_data.gd` | `assets/sprites/characters/guitarist_spriteframes.tres`, `assets/sprites/characters/full_frame/guitarist_pixellab/`, `assets/sprites/characters/pixellab/guitarist/`, legacy `assets/sprites/characters/full_frame/guitarist/`, `assets/sprites/characters/guitarist.png`, `assets/sprites/characters/guitarist_sheet.png`, `assets/sprites/characters/cutout/guitarist_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/guitarist/` | Реализовано; SCRUM-797 live Hero Select/runtime SpriteFrames use PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` with a held-guitar silhouette by direct user override, 8 idle directions and 6-frame directional `move`/`walk`, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-706 empty-hands pack and SCRUM-429 v2 full-frame assets remain history/fallback |
| `assassin` | Ассасин | Возвращающиеся чакрамы, крит-мили, яд и рывки к цели на критах | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd` | `assets/sprites/characters/assassin_spriteframes.tres`, `assets/sprites/characters/full_frame/assassin_pixellab/`, `assets/sprites/characters/pixellab/assassin/`, legacy `assets/sprites/characters/full_frame/assassin/`, `assets/sprites/characters/assassin.png`, `assets/sprites/characters/assassin_sheet.png`, `assets/sprites/characters/cutout/assassin_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/assassin/` | Реализовано; SCRUM-803 live runtime uses PixelLab character `ec73da27-b704-4336-9275-74c8e3e578df` with empty open hands, 8-direction idle rotations and 6-frame directional move/walk rows normalized to 245 px visible height on `512x512` runtime frames; SCRUM-419 v2 art remains fallback/history |
| `ranger` | Рейнджер | Дальний контроль через заряжаемые стойкой выстрелы, арбалет, ловушки | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd` | `assets/sprites/characters/ranger_spriteframes.tres`, `assets/sprites/characters/full_frame/ranger_pixellab/`, `assets/sprites/characters/pixellab/ranger/`, legacy `assets/sprites/characters/full_frame/ranger/`, `assets/sprites/characters/ranger.png`, `assets/sprites/characters/ranger_sheet.png`, `assets/sprites/characters/cutout/ranger_*.png` | Реализовано; SCRUM-804 live runtime uses PixelLab character `1646d83c-f570-4bdd-9065-cb1b46bf13f7` with empty hands, 8-direction idle rotations and 6-frame directional move/walk rows normalized to 245 px visible height on `512x512` frames; legacy SCRUM-294 art remains fallback/history |
| `doctor` | Доктор | Выживание через drain/lifesteal-связи, чума и ближний sustain | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/doctor_spriteframes.tres`, `assets/sprites/characters/full_frame/doctor_pixellab/`, `assets/sprites/characters/pixellab/doctor/`, legacy `assets/sprites/characters/full_frame/doctor/`, `assets/sprites/characters/doctor.png`, `assets/sprites/characters/cutout/doctor_*.png` | Реализовано; SCRUM-705 live Hero Select/runtime SpriteFrames use fresh PixelLab v3 full redraw (`3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`) with 8-direction idle + 6-frame directional move/walk, normalized to 244 px visible height in `512x512`; empty hands, no baked potion/syringe/saw; legacy full-frame art and SCRUM-425 pack remain history/fallback |
| `chemist` | Химик | Газовые/кислотные DoT-зоны и combo explosions от разных облаков | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/chemist_spriteframes.tres`, `assets/sprites/characters/full_frame/chemist_pixellab/`, `assets/sprites/characters/pixellab/chemist/`, legacy `assets/sprites/characters/chemist.png`, `assets/sprites/characters/cutout/chemist_*.png` | Реализовано; SCRUM-423 live Hero Select/runtime SpriteFrames use PixelLab v3 8-direction static rotations + 6-frame directional walk (`walking-6-frames`); legacy art remains fallback/history |
| `knight` | Рыцарь | Танк и тяжелый контроль: копье/щит плюс block/counter | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/knight_spriteframes.tres`, `assets/sprites/characters/full_frame/knight_pixellab/`, `assets/sprites/characters/pixellab/knight/`, legacy `assets/sprites/characters/full_frame/knight/`, `assets/sprites/characters/knight.png`, `assets/sprites/characters/cartoon2/knight/knight_cartoon2_anim_sheet.png`, `assets/sprites/characters/cutout/knight_*.png`, skeleton-source package `docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json` | Реализовано; SCRUM-885 refreshed the SCRUM-430 PixelLab no-shield character `c1a7d633-7353-4861-aea3-8d937b601cba` on 2026-07-08 with 8-direction idle rotations plus 6-frame directional walk/move rows; legacy SCRUM-473 cartoon2 frames remain history/fallback; SCRUM-475 skeleton-source parts package delivered for Animator rig work; SCRUM-919 routes the combat runtime (`scripts/player.gd`) through the accepted PixelLab `knight_spriteframes.tres` full-frame path — the legacy runtime skeletal rig (`scenes/characters/KnightSkeletonRig.tscn` + `assets/sprites/characters/skeleton_parts/knight/`) is detached from combat and kept as history/fallback |
| `druid` | Друид | Командуемые питомцы, природные зоны, тотемы; scaling от Лидерства | `scripts/progression_data.gd`, `scripts/summoner_weapon.gd`, `scripts/ally_minion.gd` | `assets/sprites/characters/druid_spriteframes.tres`, `assets/sprites/characters/full_frame/druid_pixellab/`, `assets/sprites/characters/pixellab/druid/`, legacy `assets/sprites/characters/full_frame/druid/`, `assets/sprites/characters/druid.png`, `assets/sprites/characters/cutout/druid_*.png` | Реализовано; live runtime uses PixelLab 8-direction idle rotations and 6-frame move/walk rows; legacy art remains fallback/history |

SCRUM-416 runtime portrait rule: for most playable classes,
`scripts/progression_data_characters.gd` uses the accepted cleaned full-frame
idle frame as the canonical static UI portrait path:
`assets/sprites/characters/full_frame/<class>/<class>_idle_00.png`. PixelLab
directional classes (`assassin`, `berserk`, `biologist`, `dark_mage`,
`guitarist`, `doctor`, `chemist`, `engineer`, `knight`, `priest`, `druid`,
`elementalist`, `ranger`, `robot`, `sniper`, `soldier`, `thief`) use
`assets/sprites/characters/full_frame/<class>_pixellab/<class>_idle_south.png`
instead.
Hero Select, hero thumbnails, Codex and level-up portrait surfaces read this
single `sprite_path`; legacy `assets/sprites/characters/<class>.png` files remain
historical/fallback asset references and are not the live static portrait source.
Regression coverage: `tests/character_sprite_registry_alignment_test.gd` and
`tests/runtime_smoke_test.gd`; QA dumps under `build/qa/scrum416/`.

FAN-1071 adds one roster-wide runtime placement contract without changing these
canonical IDs or asset paths: every playable SpriteFrames idle/move/walk texture
is grounded from its own visible alpha bottom onto the `Player` gameplay origin.
Legacy `sliced_rig_manifest.foot_y` is now fallback-only for cutout/skeletal
visuals and must not be treated as the footline of a PixelLab runtime pack.
Focused coverage: `tests/feet_anchor_ground_circle_test.gd` iterates all 17
classes, all directional locomotion rows and every frame.

SCRUM-869 refreshes the playable PixelLab source/runtime packs from the live
PixelLab manifests without changing canonical character IDs or portrait paths.
The refreshed complete packs are `assassin`
(`ec73da27-b704-4336-9275-74c8e3e578df`), `biologist`
(`cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`), `chemist`
(`c7fe44d3-1f15-45a1-b762-b2862833b151`), `dark_mage`
(`9bb0eca8-5afe-49d4-8e56-7115a45efdcc`), `druid`
(`4078113b-fece-4087-a035-9ed3714a6514`), `guitarist`
(`d278e753-9885-4550-82ff-81ee3bef297d`), `knight`
(`c1a7d633-7353-4861-aea3-8d937b601cba`), `priest`
(`ed7db59e-0845-4218-b178-a56f948254b5`), `ranger`
(`1646d83c-f570-4bdd-9065-cb1b46bf13f7`), `robot`
(`37c6ccf2-ab40-4c89-83a3-db8365f85257`) and `thief`
(`02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f`). `berserk`, `soldier`,
`elementalist`, `sniper`, `engineer` and `doctor` remain on their existing live
runtime packs because the SCRUM-869 PixelLab audit found incomplete/404 source
packages; exact blockers are recorded in
`build/qa/pixellab_character_animation_refresh/report.json` and the task mirror.

SCRUM-423 promotes Chemist to the PixelLab directional runtime contract:
PixelLab character `c7fe44d3-1f15-45a1-b762-b2862833b151` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/chemist/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/chemist_pixellab/`, and
`assets/sprites/characters/chemist_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-428 promotes Engineer to the same PixelLab directional runtime contract:
PixelLab character `c5bd9766-e7de-4316-ace6-e687c951e621` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/engineer/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/engineer_pixellab/`, and
`assets/sprites/characters/engineer_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-433 promotes Sniper to the same PixelLab directional runtime contract:
PixelLab character `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/sniper/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/sniper_pixellab/`, and
`assets/sprites/characters/sniper_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-803 promotes Assassin to the same PixelLab directional runtime contract:
PixelLab character `ec73da27-b704-4336-9275-74c8e3e578df` provides empty-handed
8-direction idle rotations and `walking-6-frames` movement rows for all
directions. Source PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/assassin/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/assassin_pixellab/`, and
`assets/sprites/characters/assassin_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract. PixelLab
candidate `cdee7e9a-1d04-430e-8fc9-60fafc2cd4a8` was rejected/deleted before
import because it baked a held blade into the body art.

SCRUM-804 promotes Ranger to the same PixelLab directional runtime contract:
PixelLab character `1646d83c-f570-4bdd-9065-cb1b46bf13f7` provides empty-handed
8-direction idle rotations and `walking-6-frames` movement rows for all
directions. Source PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/ranger/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/ranger_pixellab/`, and
`assets/sprites/characters/ranger_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract. Bow,
crossbow, trap and projectile visuals remain separate weapon-owned assets.

SCRUM-422 adds the first 0.1.6 character redraw v2 Design source anchor. The
accepted exemplar for the future per-class v2 rows is Berserk, using a bright,
epic, class-readable unarmed style and transparent RGBA source under
`docs/design/references/characters_v2/bright_epic_anchor/`; the asset-side
accepted source copy is
`assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`. This does not
replace live runtime portraits or combat SpriteFrames yet; it defines the
source-art, size, pivot and handoff contract for the 16 blocked v2 character
tasks.

SCRUM-456 replaces the future character-restyle direction with a cartoon/anime
source anchor after the broad v2 approach was cancelled. The package is
Design-source only and does not replace live portraits or combat SpriteFrames:
style sheet `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md`,
Berserk handoff
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md`,
transparent source/cell
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_clean.png`
and `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png`,
safe-gutter source sheet
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`,
and QA report
`build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json`.
The contract covers all active registry classes with strongly different
silhouette/palette/identity directions, `512x512` cells, pivot `(256,470)`,
`idle` + `walk/move` only, and no attack row. Animator handoff is tracked in
`docs/tasks/animation_chars_cartoon_anime_berserk_anchor_task.md`; SCRUM-456 QA
PASSED on 2026-06-17, so SCRUM-461 may consume the accepted source.

SCRUM-420 adds the first per-class v2 Design-source handoff for `berserk` under
`docs/design/references/characters_v2/berserk/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout and QA report. Asset-side handoff copies live in
`assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png` and
`assets/sprites/characters/v2/berserk/berserk_v2_sheet_source_handoff.png`.
Animator integration now replaces the live Berserk full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/berserk_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/berserk/`. The derived safe sheet is
`assets/sprites/characters/v2/berserk/berserk_v2_anim_sheet.png`; previous live
frames are backed up under `docs/design/backups/scrum420_berserk_v2_pre_anim/`.
Attack animation remains absent by SCRUM-420 scope.

SCRUM-531 adds a new dark-fantasy / D&D dragon Berserk v2 Design-source pack
under `docs/design/references/berserk_v2/` (note: a different folder from the
SCRUM-420 `characters_v2/berserk/`): raw `gpt-image-2` source, alpha-clean RGBA
source, normalized `512x512` idle cell (pivot `256,470`, visible height
`408 px`), `2848x1168` idle/walk×5 placeholder source-sheet handoff (48px
gutters, attack row excluded), and an alpha/size/pivot QA report under
`build/qa/scrum531_berserk_v2/`. Asset-side candidate exports live under
`assets/sprites/characters/berserk_v2/`; Animator handoff is
`docs/design/references/berserk_v2/berserk_v2_design_handoff.md`. The new look is
a brutal painterly dragonslayer (dragon-skull pauldron, horns, scale armor, fur
cloak, oxblood/charcoal palette), intentionally distinct from the live
cartoon-anchor; hands are empty with no weapon baked. This is Design-source only
and is NOT the live runtime — the live Berserk still renders the SCRUM-461
cartoon-anchor SpriteFrames. Animation is the follow-up Animator ticket
SCRUM-532.

SCRUM-461 replaces the live Berserk full-frame runtime resource with the
accepted SCRUM-456 cartoon/anime anchor: `assets/sprites/characters/berserk_spriteframes.tres`
now exposes `idle` (5f, 7fps), `walk` (5f, 9fps), and `move` (walk alias, 5f,
9fps) only. Runtime PNGs remain under
`assets/sprites/characters/full_frame/berserk/`, sliced from
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
with `512x512` cells, `48 px` gutters, transparent RGBA and pivot `(256,470)`.
Previous live Berserk frames are backed up under
`docs/design/backups/scrum461_berserk_cartoon_pre_anim/`. Attack animation
remains absent by SCRUM-461 scope.

SCRUM-473 replaces the Dark Mage/Knight temporary cartoon-trial legacy rig with
live cartoon2 full-frame SpriteFrames. `assets/sprites/characters/dark_mage_spriteframes.tres`
and `assets/sprites/characters/knight_spriteframes.tres` now expose 5-frame
looping `idle`, `walk`, and `move` only, with runtime PNGs under
`assets/sprites/characters/full_frame/dark_mage/` and
`assets/sprites/characters/full_frame/knight/`. Safe-gutter sheets live under
`assets/sprites/characters/cartoon2/{dark_mage,knight}/`; QA artifacts live
under `build/qa/scrum473_cartoon2_dark_mage_knight_anim/`. Attack animation
remains absent by SCRUM-473 scope because weapon visuals own attacks.

SCRUM-430 replaces the live Knight SpriteFrames/portrait source with PixelLab.
Source downloads live under `assets/sprites/characters/pixellab/knight/`,
normalized 512x512 runtime frames under
`assets/sprites/characters/full_frame/knight_pixellab/`, and
`assets/sprites/characters/knight_spriteframes.tres` exposes one-frame
`idle_<direction>` rows plus 6-frame `move_<direction>` / `walk_<direction>` rows
for all 8 directions. The accepted PixelLab pass is explicitly no-shield/no-weapon;
Knight weapons and shield visuals remain separate weapon assets. SCRUM-885
refreshed that same PixelLab character on 2026-07-08, updating the source
manifest, alpha-bbox report and normalized runtime frames while keeping the
canonical SpriteFrames path unchanged. SCRUM-919 (2026-07-09) detaches the
legacy skeletal combat rig from `scripts/player.gd`: Knight combat now renders
the same accepted PixelLab `knight_spriteframes.tres` directional idle/move
loops as Hero Select, while `scenes/characters/KnightSkeletonRig.tscn` and the
`skeleton_parts/knight/` package stay in the repo as history/emergency fallback.

SCRUM-475 adds Design-source skeleton packages for Dark Mage and Knight under
`docs/design/references/chars_cartoon/skeleton_parts/`. Each character has a
transparent accepted source copy, 19 separated PNG parts, documented local
pivots, a `skeleton_source_manifest.json`, alpha report, contact sheet and
dark-background source preview. Both manifests pass
`validate_skeleton_source_manifest.py`. These packages are Animator handoff
sources only; no runtime rig, SpriteFrames or gameplay wiring changed.

SCRUM-424 adds the Dark Mage v2 Design-source handoff under
`docs/design/references/characters_v2/dark_mage/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, handoff note and QA report. Asset-side handoff copies live
in `assets/sprites/characters/v2/dark_mage/dark_mage_v2_idle_source.png` and
`assets/sprites/characters/v2/dark_mage/dark_mage_v2_sheet_source_handoff.png`.
Animator integration now replaces the live Dark Mage full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/dark_mage_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/dark_mage/`. The derived safe sheet is
`assets/sprites/characters/v2/dark_mage/dark_mage_v2_anim_sheet.png`; previous
live frames are backed up under `docs/design/backups/scrum424_dark_mage_v2_pre_anim/`.

SCRUM-419 adds the per-class v2 Design-source handoff for `assassin` under
`docs/design/references/characters_v2/assassin/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, handoff note and QA report. Animator integration now
replaces the live Assassin full-frame runtime resource with v2 `idle` / `walk`
/ `move` loops in `assets/sprites/characters/assassin_spriteframes.tres` and
per-frame PNGs under `assets/sprites/characters/full_frame/assassin/`. The
derived safe sheet is
`assets/sprites/characters/v2/assassin/assassin_v2_anim_sheet.png`; previous
live frames are backed up under
`docs/design/backups/scrum419_assassin_v2_pre_anim/`. Attack animation remains
absent by SCRUM-419 scope; animation/runtime smokes PASS.

SCRUM-429 adds the Guitarist v2 Design-source handoff under
`docs/design/references/characters_v2/guitarist/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Animator integration now replaces the live Guitarist full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/guitarist_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/guitarist/`. The derived safe sheet is
`assets/sprites/characters/v2/guitarist/guitarist_v2_anim_sheet.png`; previous
live frames are backed up under
`docs/design/backups/scrum429_guitarist_v2_pre_anim/`. Attack animation remains
absent by SCRUM-429 scope; animation/runtime smokes PASS.

SCRUM-706 first replaced the live Guitarist PixelLab static placeholder with an
empty-hands production pack. SCRUM-797 then applies a direct user override:
PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` is now the live
Guitarist body because its held-guitar silhouette reads stronger and cooler in
Hero Select/combat. Live source rotations and six-frame movement are stored
under `assets/sprites/characters/pixellab/guitarist/`, normalized runtime frames
under `assets/sprites/characters/full_frame/guitarist_pixellab/` keep every
visible alpha bbox at `245 px` height, and
`assets/sprites/characters/guitarist_spriteframes.tres` exposes `idle`, `move`,
`walk`, plus directional `idle/move/walk_<direction>` rows for all eight
directions. The previous SCRUM-706 empty-hands pack is backed up under
`docs/design/backups/scrum797_guitarist_instrument_pack_pre_swap/`.

SCRUM-435 adds the Thief v2 Design-source handoff under
`docs/design/references/characters_v2/thief/` and promotes the accepted source
into live `assets/sprites/characters/thief_spriteframes.tres` with v2 `idle` /
`walk` / `move` loops, 5 frames each, no attack by scope. Runtime frames live
under `assets/sprites/characters/full_frame/thief/`, the derived safe sheet is
`assets/sprites/characters/v2/thief/thief_v2_anim_sheet.png`, previous live
frames are backed up under `docs/design/backups/scrum435_thief_v2_pre_anim/`,
and QA artifacts live under `build/qa/scrum435_thief_v2_anim/`; animation and
runtime smokes PASS.

SCRUM-427 adds the Elementalist v2 Design-source handoff under
`docs/design/references/characters_v2/elementalist/` and promotes the accepted
source into live `assets/sprites/characters/elementalist_spriteframes.tres` with
v2 `idle` / `walk` / `move` loops, 5 frames each, no attack by scope. Runtime
frames live under `assets/sprites/characters/full_frame/elementalist/`, the
derived safe sheet is
`assets/sprites/characters/v2/elementalist/elementalist_v2_anim_sheet.png`,
previous live frames are backed up under
`docs/design/backups/scrum427_elementalist_v2_pre_anim/`, and QA artifacts live
under `build/qa/scrum427_elementalist_v2_anim/`; animation and runtime smokes
PASS.

Historical Sniper v2 Design-source handoff: SCRUM-433 originally added
`docs/design/references/characters_v2/sniper/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/sniper/sniper_v2_idle_source.png`,
`assets/sprites/characters/v2/sniper/sniper_v2_sheet_source_handoff.png` and
`assets/sprites/characters/v2/sniper/sniper_v2_sheet.png`. These source-handoff
assets are historical now; live Sniper runtime/portrait uses the PixelLab
directional pack under `assets/sprites/characters/full_frame/sniper_pixellab/`.

SCRUM-431 adds the Priest v2 Design-source handoff under
`docs/design/references/characters_v2/priest/`: raw OpenAI source, alpha-clean
source, normalized `512x512` idle cell, `2560x1024` placeholder source-sheet
layout, accepted source sheet copy, handoff note and QA report. Asset-side
handoff copies live in
`assets/sprites/characters/v2/priest/priest_v2_idle_source.png`,
`assets/sprites/characters/v2/priest/priest_v2_sheet_source_handoff.png` and
`assets/sprites/characters/v2/priest/priest_v2_sheet.png`. These are source
handoff assets only; they do not replace current runtime Priest cutout/full-frame
assets until Animator/Back-end integration is accepted.

SCRUM-421 adds the Biologist v2 Design-source handoff under
`docs/design/references/characters_v2/biologist/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/biologist/biologist_v2_idle_source.png`,
`assets/sprites/characters/v2/biologist/biologist_v2_sheet_source_handoff.png`
and `assets/sprites/characters/v2/biologist/biologist_v2_sheet.png`. These
older v2 handoff assets remain source history. SCRUM-421 later finished the live
PixelLab runtime pack from character `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`
under `assets/sprites/characters/pixellab/biologist/` and
`assets/sprites/characters/full_frame/biologist_pixellab/`, with a regenerated
front-facing south movement row and all 56 runtime frames normalized to `245 px`
visible alpha height.

SCRUM-432 adds the Robot v2 Design-source handoff under
`docs/design/references/characters_v2/robot/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/robot/robot_v2_idle_source.png` and
`assets/sprites/characters/v2/robot/robot_v2_sheet_source_handoff.png`. The
source is a bright/epic polished mechanical guardian with cyan/blue sensors and
empty hands, no baked weapon/tool/held object, visible height `376 px`, pivot
`[256,470]`, no edge-visible or floodable neutral/checker pixels after cleanup.
These are source handoff assets only; they do not replace current runtime Robot
assets until Animator/Back-end integration is accepted.

## Расширенный Ростер 0.1.4 (Фундамент, 2026-06-11)

Спрайты всех шести прошли Design art-review (2026-06-11) и приняты как polished dark fantasy full-art (512x512, RGBA). Cutout rig-части нарезаны `tools/slice_rig_cutouts.py` и лежат в `assets/sprites/characters/cutout/` (torso, arm_l, arm_r, leg_l, leg_r для каждого). Манифест обновлён в `scripts/sliced_rig_manifest.gd`. Weapon art v2 pass 2026-06-12 устранил fallback-текстуры в сценах оружия, перерисовал три оружия Рыцаря и заменил `knight.png` на unarmed base sprite без встроенного копья/щита, чтобы все три варианта реально крепились через socket.

| ID | Имя | Архетип | 3 стартовых оружия | «Свой» урон |
| --- | --- | --- | --- | --- |
| `assassin` | Ассасин | Быстрый крит-мили | `chakrams`, `shadow_daggers`, `venom_wire` | damage |
| `ranger` | Рейнджер | Дальний точный | `moon_crossbow`, `storm_longbow`, `hunter_trap` | damage |
| `doctor` | Доктор | Выживание через урон | `restore_potion`, `plague_syringe`, `bone_saw` | magic_damage |
| `chemist` | Химик | AoE + DoT зоны | `blast_powder`, `acid_flask`, `homunculus_vial` | magic_damage |
| `knight` | Рыцарь | Танк/копье | `long_spear`, `tower_shield`, `holy_flail` | damage |
| `druid` | Друид | Призыватель | `summon_amulet`, `briar_staff`, `raven_totem` | magic_damage |

Релевантность атрибутов расширена: strength -> berserk/assassin/ranger/knight; intelligence -> dark_mage/doctor/chemist; energy -> dark_mage/guitarist/doctor/chemist/druid. Вознесение: по 10 уровней на каждый новый класс (ID `<класс>_asc_1..10`, тематические имена в ASCENSION_LEVELS).

Канонические character PNG для новых классов: `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). Канонические weapon PNG для новых 18 вариантов: `chakrams.png`, `shadow_daggers.png`, `venom_wire.png`, `moon_crossbow.png`, `storm_longbow.png`, `hunter_trap.png`, `restore_potion.png`, `plague_syringe.png`, `bone_saw.png`, `blast_powder.png`, `acid_flask.png`, `homunculus_vial.png`, `long_spear.png`, `tower_shield.png`, `holy_flail.png`, `summon_amulet.png`, `briar_staff.png`, `raven_totem.png` (`256x256`, transparent). Первые 9 weapon PNG для Berserk/Dark Mage/Guitarist остаются активными по существующим путям.

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

## VFX-Ассеты Эффектов

Папка: `assets/sprites/effects/`. Генераторы: `tools/generate_attack_vfx.py` (оружие игрока), `tools/generate_elite_vfx.py` (уникальные атаки элиток), `tools/generate_elite_boss_vfx_015.py` (SCRUM-261 elite/boss skill VFX), `tools/generate_unique_weapon_vfx_015.py` (SCRUM-258 unique weapon identity plates). Все PNG с прозрачным фоном.

Опасные зоны врагов/босса (2026-06-12, обновлено SCRUM-261) оформлены через `scripts/hazard_vfx.gd` (`HazardVfx.telegraph`/`detonate`): базовый `hazard_zone.png` остается tint-friendly warning circle, затем `impact_ring`+`impact_flash` дают момент детонации, для яда — бурлящая `poison_pool` лужа. После SCRUM-261 `HazardVfx` выбирает dedicated painterly D&D texture по runtime node name: `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`, а также shield/summon/aura helpers. Тайминги, урон, радиусы и node names не менялись.

Оружие игрока (используются `scripts/attack_vfx.gd`):

| Файл | Назначение | Статус |
| --- | --- | --- |
| `slash_arc.png` | Дуга-слэш меча/топора и конусных атак (тонируемый) | Реализовано |
| `impact_ring.png` | Ударное кольцо (молот, импульсы, взрывы) | Реализовано |
| `impact_flash.png` | Звездная вспышка попадания | Реализовано |
| `dust_puff_0..2.png` | Клубы пыли удара молота | Реализовано |
| `void_orb.png` | Снаряд темной книги | Реализовано |
| `beam_strip.png` | Луч темного жезла | Реализовано |
| `sound_wave.png` | Звуковая волна электрогитары | Реализовано |
| `music_note.png` | Ноты гитарных атак | Реализовано |
| `poison_pool.png` | Растровая пузырящаяся poison/acid pool Химика вместо программного круга | Реализовано |
| `spark_pool.png` | Растровое spark-cloud пятно Взрывной пыли Химика вместо программного круга | Реализовано |
| `briar_pool.png` | Растровая thorn/briar зона Друида вместо программного круга | Реализовано |

VFX pass 2026-06-12: `ClassWeapon._spawn_damage_pool()` больше не рисует видимый `Polygon2D`-диск для persistent pools. Химик/Друид используют эти PNG как `Sprite2D` с мягким scale/rotation pulse; damage radius/tick timing остались из weapon config. QA preview: `docs/design/previews/vfx_pool_assets_contact.png`.

D&D VFX restyle pass 2026-06-12: все 19 PNG в `assets/sprites/effects/` заменены на сдержанный tabletop fantasy style без кислотного неона и пересветов. Размеры/имена/alpha сохранены; `hazard_zone` и `elite_telegraph_circle` оставлены warm-neutral/tintable под кодовую модуляцию. Non-runtime QA preview вынесен из `assets/` в `build/cleanup_backup_2026_06_12/assets/sprites/effects/effects_dnd_preview.png`.

SCRUM-261 elite/boss VFX pass 2026-06-14: добавлены dedicated 512x512/256x256 PNG для новых mechanics SCRUM-259: `boss_gravity_well_zone.png`, `boss_vampiric_bite_zone.png`, `boss_rift_zone.png`, `boss_bone_prison_zone.png`, `boss_brood_web_zone.png`, `boss_ash_ember_zone.png`, `boss_molten_armor_pulse.png`, `enemy_summon_portal.png`, `enemy_shield_block_front.png`, `enemy_reflect_thorns_aura.png`, `enemy_command_aura_pulse.png`, `enemy_shadow_blink_mark.png`, `enemy_shard_fan_burst.png`. QA/contact preview: `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.

SCRUM-258 unique weapon VFX pass 2026-06-14: добавлены 51 dedicated `256x256` RGBA PNG `vfx_weapon_<weapon_id>.png` для всех текущих `ProgressionData.WEAPONS_BY_CLASS` weapon IDs. Это короткие D&D/painterly VFX-пластины под реальные mechanics SCRUM-256/251/254/245: melee execute/cleave/stagger, charged shots/traps, drain/status links, summon/deploy identities, auras and buff/debuff reads. `scripts/attack_vfx.gd::weapon_signature()`, `scripts/class_weapon.gd::_spawn_weapon_signature()` и SCRUM-335 `scripts/berserk_weapon.gd::_show_weapon_signature()` подключают их визуально по `weapon_id` без изменения урона, формул, targeting, cooldowns или таймингов. QA previews: `docs/design/previews/scrum258_unique_weapon_vfx_contact.png`, `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`.

SCRUM-337 attack VFX source regeneration 2026-06-14: весь активный runtime-пак эффектов атак пересобран через `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`) и deterministic sheet-cut pipeline `tools/build_scrum337_attack_vfx_from_sources.py`. Заменены на месте 83 `assets/sprites/effects/*.png` и 2 `assets/sprites/projectiles/*.png`; имена, размеры, alpha/RGBA и runtime-пути сохранены. Source sheets/manifest: `docs/design/references/attack_vfx_realistic_dark_fantasy/`; QA previews: `docs/design/previews/scrum337_attack_vfx_core_contact.png`, `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`. Gameplay timing, damage, targeting, formulas и Back-end runtime logic не менялись.

SCRUM-756 attack VFX targeted redraw 2026-07-01: `vfx_weapon_priest_reliquary.png` заменен через PixelLab MCP / `fantasydisk-asset-generator` как отдельная полупрозрачная sanctify-seal пластина с ghost-силуэтом `assets/sprites/weapons/priest_reliquary.png`. Runtime path, размер `256x256`, alpha/RGBA контракт, gameplay timing, damage, healing, targeting, formulas и Back-end runtime logic не менялись. Evidence: `docs/design/references/weapon_attack_animations/priest_reliquary/manifest.json`, preview `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`.

Иконки артефактов: `assets/sprites/ui/icons/artifacts/artifact_*.png` (71 шт., 256x256; SCRUM-606/609 добавили 10 dedicated icons для новых artifact IDs, SCRUM-619/623 добавили `rift_key`). Финальный Design pass SCRUM-340 от 2026-06-14: все активные артефакты пересозданы через `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`) как realistic epic D&D/dark-fantasy raster magic items с прозрачным фоном. Это не пентаграммы, не плоские UI-symbols и не векторные пиктограммы: каждый файл содержит отдельный нарисованный предмет с объемом, материалами, магическим светом и смысловой привязкой к `ProgressionData.ARTIFACTS`. Source references для SCRUM-606/609 лежат в `docs/design/references/icons/artifacts/<id>/`; QA evidence: `docs/design/previews/artifact_icons_606_609_contact.png` и `docs/design/reports/artifact_icons_606_609_qa.md`. Предыдущие пассы (flat v1, dark fantasy v2, glossy RPG v3, concept-sheet tile/cut pass, per-item pictogram pass, 2026-06-12 raster sheet pass) superseded.

Таймер боя: `assets/sprites/ui/hud/timer_frame.png` и `assets/sprites/ui/hud/timer_frame_alarm.png` (оба 300x90, прозрачный фон) — фэнтези-рамка под цифры (золотая окантовка, темная ниша, самоцветы по бокам, гребень сверху). Для тревоги Back-end просто меняет текстуру на `timer_frame_alarm.png` (красное свечение и красные самоцветы) — программная подсветка не нужна. Генерируются тем же инструментом.

Reward frame kit SCRUM-338 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`,
`ui_frame_reward_card_hover.png`,
`ui_frame_reward_elite_artifact_card.png`,
`ui_frame_reward_elite_artifact_card_hover.png` (`768x1024`, RGBA,
transparent). Source references and safe-zone metadata:
`docs/design/references/rewards/reward_frames_scrum338_metadata.json`; QA preview:
`docs/design/previews/reward_frames_scrum338_contact_safe_zones.png`. Runtime
content must stay inside documented content margins: battle reward card
`Vector4(132, 170, 132, 164)`, elite artifact card
`Vector4(150, 202, 150, 190)`.

Economy node frame kit SCRUM-332 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/economy/ui_frame_economy_panel.png`,
`ui_frame_economy_choice_card.png`, `ui_frame_economy_choice_card_hover.png`,
`ui_frame_economy_dragon_panel.png`, `ui_frame_economy_price_badge.png`,
`ui_frame_economy_tooltip.png`. Mockup/spec:
`docs/design/mockups/scrum332_shop_economy/spec.md`; generated references:
`docs/design/references/ui_overhaul_shop_economy/`; preview:
`docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`. Content
must stay inside the documented safe zones, especially for the irregular dragon
panel.

Wide economy choice-card Design candidate SCRUM-437:
`assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent).
Source/margins contract:
`docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_economy_choice_card_metadata.json`;
spec and previews:
`docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`,
`docs/design/previews/scrum437_wide_economy_choice_card_safe_zone.png`.
Status: Design-ready, Back-end runtime integration pending; visible content must
stay inside `Rect2(132,118,696,394)`.

Progression frame kit SCRUM-331 (Design-ready, Back-end integration handoff):
`assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png`,
`ui_frame_progression_branch_panel.png`, `ui_frame_progression_node_available.png`,
`ui_frame_progression_node_locked.png`, `ui_frame_progression_node_purchased.png`,
`ui_frame_progression_node_focus.png`, `ui_frame_progression_class_panel.png`,
`ui_frame_progression_points_badge.png`, `ui_frame_progression_tooltip.png`.
Mockup/spec: `docs/design/mockups/scrum331_progression_codex/spec.md`;
generated references: `docs/design/references/ui_overhaul_progression_codex/`;
preview: `docs/design/previews/scrum331_progression_frame_kit_contact.png`.
Circular node content must stay within the documented inner circle; the existing
SCRUM-345/SCRUM-403 Codex texture kit remains the live Codex baseline.

Уникальные атаки элиток (имена зафиксированы для Back-end интеграции, не переименовывать):

| Файл | Размер | Назначение | Статус |
| --- | --- | --- | --- |
| `elite_shockwave_ring.png` | 512x512 | Кольцевая ударная волна slam-атаки Железного Оплота | Ассет готов |
| `elite_shadow_trail.png` | 256x128 | Шлейф тени рывка Ночного Сталкера | Ассет готов |
| `elite_poison_lob.png` | 96x96 | Ядовитый снаряд Чумного Пророка | Ассет готов |
| `elite_crystal_shard.png` | 96x96 | Кристальный осколок Маршала Осколков (острие +X) | Ассет готов |
| `elite_telegraph_circle.png` | 512x512 | Универсальный круг-предупреждение зоны атаки | Ассет готов |
| `enemy_shadow_blink_mark.png` | 512x512 | Метка выхода/удара `shadow_strike` Ночного Сталкера | Ассет готов |
| `enemy_shard_fan_burst.png` | 512x512 | Предупреждение веера/кольца осколков `shard_fan` | Ассет готов |
| `enemy_shield_block_front.png` | 256x256 | Короткий фронтальный VFX щита для `shield_block` | Ассет готов |
| `enemy_reflect_thorns_aura.png` | 512x512 | Аура отражающих шипов `reflect_thorns` | Ассет готов |
| `enemy_command_aura_pulse.png` | 512x512 | Аура усиления `aura_buff` Маршала Осколков | Ассет готов |

VFX новых боссовских mechanics SCRUM-259/SCRUM-261:

| Файл | Runtime node/mechanic | Назначение | Статус |
| --- | --- | --- | --- |
| `boss_gravity_well_zone.png` | `BossGravityWell` | Фиолетовая гравитационная воронка Стража Разлома | Ассет готов |
| `boss_vampiric_bite_zone.png` | `BossVampiricBite` | Кровавый круг укуса/вампиризма Пожирателя Диска | Ассет готов |
| `boss_rift_zone.png` | `BossRiftZone` | Разломная зона Стража/волны разлома | Ассет готов |
| `boss_bone_prison_zone.png` | `BossRiftZone` + `boss_behavior=bone_archon` | Костяная тюрьма/стена Архонта | Ассет готов |
| `boss_brood_web_zone.png` | `BroodWebZone` | Паутинная зона Матери Роя | Ассет готов |
| `boss_ash_ember_zone.png` | `AshEmberZone` | Тлеющая зона Пепельного Колосса | Ассет готов |
| `boss_molten_armor_pulse.png` | `BossMoltenArmorPulse` | Раскаленный импульс брони Колосса | Ассет готов |
| `enemy_summon_portal.png` | summon/retinue helper | Портал призыва свиты | Ассет готов |

## Оружие

| ID | Игровое имя | Класс | Роль | Источник | Статус |
| --- | --- | --- | --- | --- | --- |
| `sword` | Двуручный меч | Берсерк | Узкий сектор 100 градусов радиуса 350 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `axe` | Двуручный топор | Берсерк | Широкий сектор 180 градусов радиуса 250 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `hammer` | Двуручный молот | Берсерк | Круговой AoE 150px с Radius scaling и diminishing по плотной толпе | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `soldier_rifle` | Аркебуза строя | Солдат | Suppression burst: 3 коротких выстрела по линии; основная цель полный урон, соседи reduced damage | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierRifle.tscn` | Реализовано |
| `soldier_grenade` | Граната с фитилем | Солдат | Delayed ground explosion: телеграф, короткий фитиль, falloff урона к краю | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierGrenade.tscn` | Реализовано |
| `soldier_bayonet` | Штык-стойка | Солдат | Defensive brace corridor: каждый враг в стойке получает один укол и knockback | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierBayonet.tscn` | Реализовано |
| `thief_coin_pouch` | Кошель Рикошета | Вор | Coin ricochet (SCRUM-897): цепь 6 прыжков (кап 8), спад до 50% к последнему, мгновенное золото с первых 3 целей | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefCoinPouch.tscn`, `assets/sprites/weapons/thief_coin_pouch.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_shadow_cloak` | Отравленный Кинжал | Вор | Shadow backstab (SCRUM-897): фантомный кинжал без движения героя, паралич-яд и удар в спину ×1.35 | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefShadowCloak.tscn`, `assets/sprites/weapons/thief_shadow_cloak.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_smoke_bomb` | Дымовая Бомба | Вор | Smoke bomb (SCRUM-897): бросок → AoE-взрыв → недамажащее облако с позиционным dodge (кап 0.90 в дыму) | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefSmokeBomb.tscn`, `assets/sprites/weapons/thief_smoke_bomb.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_orb_ring` | Кольцо Четырёх Стихий | Элементалист | SCRUM-948 square field: квадратная AoE в точке каста, тики трёх каналов (магия+физика+ожог) с отбросом от центра | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistOrbRing.tscn`, `assets/sprites/weapons/elementalist_orb_ring.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_prism_focus` | Призматический Фокус | Элементалист | SCRUM-949 full-map X: диагональный разлом во всю арену через точку фокуса + центр-AoE | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistPrismFocus.tscn`, `assets/sprites/weapons/elementalist_prism_focus.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_meteor_core` | Ядро Метеора | Элементалист | SCRUM-950 heavy meteor: самое медленное оружие игрока — телеграф+падение, тяжёлый удар, догорающая DoT-зона | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistMeteorCore.tscn`, `assets/sprites/weapons/elementalist_meteor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `sniper_deadeye_rifle` | Винтовка Мертвого Глаза | Снайпер | Sniper lockshot: короткий прицел/телеграф, затем точный дальний луч по locked target и line falloff | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperDeadeyeRifle.tscn`, `assets/sprites/weapons/sniper_deadeye_rifle.png`, `assets/sprites/effects/vfx_weapon_sniper_deadeye_rifle_endpoint_impact.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 endpoint VFX готов к SCRUM-931 |
| `sniper_spotter_scope` | Прицел Наводчика | Снайпер | Sniper kill-zone: маркирует область у цели и вызывает несколько точных sky-beam попаданий по врагам внутри | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperSpotterScope.tscn`, `assets/sprites/weapons/sniper_spotter_scope.png`, `assets/sprites/effects/vfx_weapon_sniper_spotter_scope_{telegraph,impact}.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 telegraph/impact готовы к SCRUM-932 |
| `sniper_shatter_rounds` | Осколочные Патроны | Снайпер | Sniper split round: основной дальний выстрел раскалывается веером; отдельный SCRUM-934 projectile component рассчитан на многократный spawn без визуального шума | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperShatterRounds.tscn`, `assets/sprites/weapons/sniper_shatter_rounds.png`, `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds_projectile.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 projectile VFX готов к SCRUM-933 |
| `priest_reliquary` | Светлый Реликварий | Священник | Sanctify: отмечает цель священным знаком, затем взрыв по области лечит часть нанесенного урона | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestReliquary.tscn`, `assets/sprites/weapons/priest_reliquary.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_censer` | Кадило Обета | Священник | Ward pulses: несколько защитных волн вокруг героя наносят урон и дают малое лечение | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestCenser.tscn`, `assets/sprites/weapons/priest_censer.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_chime` | Колокол Молитвы | Священник | Prayer chain: молитвенная нить перескакивает между врагами и возвращает sustain | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestChime.tscn`, `assets/sprites/weapons/priest_chime.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_spore_lens` | Споровая Линза | Биолог | Spore bloom: три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSporeLens.tscn`, `assets/sprites/weapons/biologist_spore_lens.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_sample_injector` | Инъектор Образцов | Биолог | Sample dart: берет образец у цели, затем два анализа бьют ее и ближайшие ткани | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSampleInjector.tscn`, `assets/sprites/weapons/biologist_sample_injector.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_symbiote_seed` | Семя Симбионта | Биолог | Symbiote web: первичная цель связывается с соседними врагами и делит биоурон по сети | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSymbioteSeed.tscn`, `assets/sprites/weapons/biologist_symbiote_seed.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_magnetic_anchor` | Магнитный Якорь | Робот | Magnetic anchor: отложенный тяжёлый AoE в точке цели, полный урон с falloff от центра, стягивает рядовых к центру 0.85/каст (импульс cap 1500); элитки/боссы не смещаются, урон полный | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotMagneticAnchor.tscn`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_hydraulic_press` | Гидравлический Пресс | Робот | Compression line: урон по ВСЕЙ ширине коридора suppression_width (300, ×1.30 с «Калибратором»), прижимает рядовых к оси 0.80/каст; элитки/боссы — полный урон, резист смещения ×0.25; SCRUM-917 PixelLab VFX сжимается side-to-centre и синхронизирует active frame с hit delay 0.20с | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotHydraulicPress.tscn`, `scenes/vfx/RobotHydraulicPressCompressionVfx.tscn`, `assets/sprites/weapons/robot_hydraulic_press.png`, `assets/sprites/effects/robot_hydraulic_press_compression/`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_reactor_core` | Реакторное Ядро | Робот | Reactor vent: ровно 4 вентиля 90° от мировой фазы (без самонаведения), паттерн +6°/каст — веер обходит круг за 15 атак; урон вентиля = ролл ×0.42, extra_projectile — dormant/internal injected-only compatibility seam with no live production source; it does not expand the blades | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotReactorCore.tscn`, `assets/sprites/weapons/robot_reactor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_sentry_wrench` | Ключ Часового | Инженер | Sentry turret (SCRUM-888): разворачивает персистентные стационарные турели (жёсткий лимит 2, старейшая заменяется), турели сами обстреливают ближайших врагов залпом снарядов с capped splash | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerSentryWrench.tscn`, `scenes/SentryTurret.tscn`, `scripts/sentry_turret.gd`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_turret/sentry_turret.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_repair_drone` | Орбитальный Дрон | Инженер | SCRUM-906/FAN-1075: 2 увеличенных контактных дрона по умолчанию, строго напротив друг друга на кольце 121 px; visual scale 0.24, спираль с третьего дрона, кап 6 | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerRepairDrone.tscn`, `assets/sprites/weapons/engineer_repair_drone.png`, `scripts/engineer_orbit_drone.gd`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_pressure_mines` | Минная Сетка | Инженер | Pressure mine grid: три мины веером срабатывают отдельно при касании врагом | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerPressureMines.tscn`, `assets/sprites/weapons/engineer_pressure_mines.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `dark_book` | Книга тьмы | Темный маг | Два AoE-снаряда в две ближайшие цели | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `cursed_skull` | Проклятый череп | Темный маг | Самонаводящееся проклятие, DoT и небольшой splash по цели | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `dark_wand` | Темная палочка | Темный маг | Два pierce-луча веером | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `electric_guitar` | Электрогитара | Гитарист | Звуковая волна вперед | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `bass_guitar` | Бас-гитара | Гитарист | Частый слабый контроль-пульс с сильным отталкиванием | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `sound_amp` | Звуковой усилитель | Гитарист | Деплойный усилитель: живет ~7с, лимит 1 + floor(Лидерство/4) | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `chakrams` | Чакрамы | Ассасин | Boomerang-коридор туда и обратно; критовые попадания дают shadow burst у цели без перемещения героя | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `shadow_daggers` | Теневые кинжалы | Ассасин | Быстрые короткие multi-stabs в ближней зоне + crit shadow burst у цели | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `venom_wire` | Ядовитая струна | Ассасин | Тонкая poison-линия с DoT + crit shadow burst у цели | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `moon_crossbow` | Лунный арбалет | Рейнджер | Stance-charged piercing shot | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `storm_longbow` | Грозовой длинный лук | Рейнджер | SCRUM-911/912: stance-charged конус из 5 пробивающих стрел (34°, 980px, pierce 4) с PixelLab bow-release/through-hit VFX | `ProgressionData.RANGER_WEAPONS`, `assets/sprites/effects/vfx_weapon_storm_longbow.png`, `assets/sprites/effects/storm_longbow/storm_longbow_release_spriteframes.tres`, `scenes/vfx/StormLongbowVolleyVfx.tscn` | Реализовано; PixelLab source/evidence в `docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/` |
| `hunter_trap` | Охотничий капкан | Рейнджер | Deploy trap: burst + knockback; stance charge усиливает | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `restore_potion` | Зелье восстановления | Доктор | Drain/lifesteal-связь к цели | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `plague_syringe` | Чумной шприц | Доктор | Drain-связь с poison DoT и sustain | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `bone_saw` | Костяная пила | Доктор | Ближний saw arc/flurry, DoT и lifesteal от урона | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `blast_powder` | Взрывная пыль | Химик | AoE explosion + spark cloud; combo с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `acid_flask` | Кислотная колба | Химик | Большая poison/acid pool; combo explosion с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `homunculus_vial` | Склянка гомункула | Химик | Temporary minion scaling from magic damage | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `long_spear` | Копье | Рыцарь | Длинный точечный strip + block/counter passive | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `tower_shield` | Башенный щит | Рыцарь | Shield bash / frontal control + сильный block/counter | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `holy_flail` | Освященный кистень | Рыцарь | 7-step center-out spiral (`0.085с`, `22%→100%` radius) + broad holy-control counter; SCRUM-924 PixelLab chain/flail VFX follows each live step | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `summon_amulet` | Амулет призыва | Друид | Командуемая beast pack, scaling from Leadership | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `briar_staff` | Посох терний | Друид | Thorn zone, AoE DoT, crowd control | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `raven_totem` | Вороний тотем | Друид | Totem pulses, Leadership-scaled deploy limit | `ProgressionData.DRUID_WEAPONS` | Реализовано |

Weapon art v2 2026-06-12: сцены `WeaponVisual` должны использовать texture path, совпадающий с canonical weapon ID (исключение: Berserk `sword/axe/hammer` используют historical файлы `two_handed_sword/axe/hammer.png`). SCRUM-277 закрыл оставшиеся proxy-ссылки новых классов: Вор, Элементалист, Снайпер, Священник, Биолог и Инженер теперь рендерят свои `assets/sprites/weapons/<weapon_id>.png`, а `PriestChime` больше не показывает `sound_amp.png`. `long_spear`, `tower_shield`, `holy_flail` перерисованы как noble knight equipment. Scene scales уменьшены, чтобы оружие занимало примерно 50-65% высоты персонажа и не перекрывало лицо/корпус. Контрольные листы: `docs/design/previews/weapon_v2_assets_contact.png`, `docs/design/previews/weapon_v2_socket_contact.png`. SCRUM-168 добавил 3 Soldier weapon IDs и подключил canonical textures `soldier_rifle.png`, `soldier_grenade.png`, `soldier_bayonet.png`.

Временные visuals классового оружия регистрируются в runtime-группе `player_weapon_effects` и должны удаляться при смене оружия/персонажа, смерти, завершении забега и очистке world state.

## Призывные Союзники И Deployables

SCRUM-152 Design pass 2026-06-12 добавил канонический raster-набор союзных summon/deployable ассетов в `assets/sprites/allies/`. SCRUM-399 (2026-06-14) заменил четыре мобильных summon visuals на эфирный союзный стиль: голубой/циановый ghost tint, прозрачность, мягкое внутреннее свечение и дымчатые края, чтобы призывы мгновенно отличались от плотных темных монстров. Все PNG RGBA/transparent; runtime IDs, SpriteFrames paths, counts and timings сохранены.

| ID | Игровая роль | Ассет | Runtime status |
| --- | --- | --- | --- |
| `ally_druid_beast` | Базовый питомец Друида / fallback `AllyMinion` | `assets/sprites/allies/ally_druid_beast.png`; `assets/sprites/allies/ally_druid_wolf_spriteframes.tres` + `assets/sprites/allies/druid_wolf/ally_druid_wolf_{move,attack,death}_*.png` | Full-frame SpriteFrames через `FullFrameAnimationRegistry`: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, safe 256x256 wolf canvas, scale `0.37`, position `(0,-37)`, flip вправо по движению/атаке |
| `ally_druid_pack_spirit` | Вариант стаи Друида / ultimate pack visual | `assets/sprites/allies/ally_druid_pack_spirit.png`; `assets/sprites/allies/ally_pack_spirit_spriteframes.tres` + `assets/sprites/allies/pack_spirit/ally_pack_spirit_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `ally_homunculus` | Химикский гомункул от `homunculus_vial` | `assets/sprites/allies/ally_homunculus.png`; `assets/sprites/allies/ally_homunculus_spriteframes.tres` + `assets/sprites/allies/homunculus/ally_homunculus_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `ally_leadership_echo` | Зарезервированный арт эхо-союзника; runtime-потребителя НЕТ (универсальный Leadership-echo удалён FAN-1893, summoner_weapon больше не мапит id) | `assets/sprites/allies/ally_leadership_echo.png`; `assets/sprites/allies/ally_leadership_echo_spriteframes.tres` + `assets/sprites/allies/leadership_echo/ally_leadership_echo_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `druid_ghost_wolf` | Дух-волк Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_wolf/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_wolf_spriteframes.tres`; PixelLab `8d473df8-9bc2-481c-ad58-b69cfecc5d33` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + claw/body-sweep `attack_left/right` 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_bear` | Дух-медведь Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_bear/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_bear_spriteframes.tres`; PixelLab `6805608a-b64a-471c-a1d9-9601a3062e2f` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + ground-slam `attack_left/right` 6f one-shot, transparent 256x256, no flip; SCRUM-1020 replaces `move_right` with coherent same-UUID job `1585ff64-f3e8-4db7-aa8b-fd7631a40bae` pending independent re-QA; roster/gameplay pending SCRUM-902 |
| `druid_ghost_panther` | Дух-пантера Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_panther/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_panther_spriteframes.tres`; PixelLab `b2d06d20-aabb-48e2-9d8a-5053daa03e8e` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + pounce/rake `attack_left/right` 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_stag` | Дух-олень Друида; magical ranged caster animation identity | `assets/sprites/allies/druid_ghost_stag/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_stag_spriteframes.tres`; PixelLab `f17948e2-8e1d-44f2-93f1-8f8593ae01fe` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + spirit-lance `attack_left/right` cast 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_lion` | Дух-лев Друида; magical ranged caster animation identity | `assets/sprites/allies/druid_ghost_lion/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_lion_spriteframes.tres`; PixelLab `48d76788-eeba-4a9f-a36f-bd40a8f42e07` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + spectral-roar `attack_left/right` cast 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `deploy_sound_amp_field` | Полевой объект ампа Гитариста | `assets/sprites/allies/deploy_sound_amp_field.png` | Подключен как `deploy_texture_path` для `sound_amp` |
| `deploy_raven_totem_field` | Полевой объект Вороньего тотема Друида | `assets/sprites/allies/deploy_raven_totem_field.png` | Подключен как `deploy_texture_path` для `raven_totem` |

Preview QA:

- `docs/design/previews/summon_allies_style_references.png` - project style references used for Codex Design generation;
- `docs/design/previews/summon_allies_asset_contact.png` - transparent asset contact sheet;
- `docs/design/previews/summon_allies_scale_meadow_preview.png` - scale/readability check on arena background;
- `docs/design/previews/summons_ethereal_redraw_contact.png` - SCRUM-399 ethereal summon static/frame contact sheet;
- `docs/design/previews/summons_ethereal_readability_meadow.png` - SCRUM-399 meadow readability preview against current arena colors.
- `docs/design/previews/druid_summons_ghost_animation_pack_contact.png` - SCRUM-1016 west/east movement/action contact sheet for all five ghost summons.

Back-end source-specific integration complete in SCRUM-157: runtime selectors preserve cleanup groups and gameplay balance.

## Стандартные Монстры

Эти имена являются каноническими для задач. Если в коде сцена пока называется generic-именем, в задачах все равно нужно ссылаться на игровое имя из таблицы.

| ID | Игровое имя | Текущая сцена | Архетип | Ассет | Поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_cutter` | Рубака Разлома | `scenes/Enemy.tscn` | Ближний бой | `assets/sprites/enemies/enemy_melee.png`; full-frame pilot `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres` from `assets/sprites/enemies/full_frame/rift_cutter_full_frame_sheet.png` | Идет к игроку, бьет с windup; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `ash_marksman` | Пепельный Стрелок | `scenes/EnemyShooter.tscn` | Дальний бой | `assets/sprites/enemies/enemy_ranged.png`; full-frame `assets/sprites/enemies/full_frame/ash_marksman_spriteframes.tres` from `assets/sprites/enemies/full_frame/ash_marksman_full_frame_sheet.png` | Держит дистанцию и стреляет; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `spark_runner` | Искровой Беглец | `scenes/EnemyRunner.tscn` | Быстрый враг | `assets/sprites/enemies/enemy_suicide_runner.png`; full-frame `assets/sprites/enemies/full_frame/spark_runner_spriteframes.tres` from `assets/sprites/enemies/full_frame/spark_runner_full_frame_sheet.png` | Быстро догоняет игрока, может спавниться пачками; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `stone_bruiser` | Каменный Громила | `scenes/EnemyBruiser.tscn` | Жирный медленный | `assets/sprites/enemies/enemy_bruiser_slow.png`; full-frame `assets/sprites/enemies/full_frame/stone_bruiser_spriteframes.tres` from `assets/sprites/enemies/full_frame/stone_bruiser_full_frame_sheet.png` | Высокий HP, низкая скорость; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `bone_caller` | Костяной Зовущий | `scenes/EnemySummoner.tscn` | Суммонер | `assets/sprites/enemies/enemy_summoner.png`; full-frame `assets/sprites/enemies/full_frame/bone_caller_spriteframes.tres` (FAN-2613: explicit 8-направленный PixelLab-пак, `assets/sprites/enemies/pixellab/bone_caller/`) | Призывает маленьких мобов; визуально использует registry explicit-eight-direction `idle_<dir>`/`move_<dir>`/`attack_<dir>`/`hit_<dir>`/`death_<dir>` строки, без flip_h | Реализовано |
| `void_mage` | Маг Пустоты | `scenes/EnemyMage.tscn` | Магический ranged | `assets/sprites/enemies/enemy_void_mage.png`; full-frame `assets/sprites/enemies/full_frame/void_mage_spriteframes.tres` (FAN-2614: explicit 8-направленный PixelLab-пак, `assets/sprites/enemies/pixellab/void_mage/`) | Давление магическими атаками; визуально использует registry explicit-eight-direction `idle_<dir>`/`move_<dir>`/`attack_<dir>`/`hit_<dir>`/`death_<dir>` строки, без flip_h | Реализовано |
| `venom_spitter` | Ядовитый Плеватель | `scenes/EnemySpitter.tscn` | Ranged / hazard | `assets/sprites/enemies/enemy_venom_spitter.png`; full-frame `assets/sprites/enemies/full_frame/venom_spitter_spriteframes.tres` from `assets/sprites/enemies/full_frame/venom_spitter_full_frame_sheet.png` | Дальний плевок, давление зоной; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `rift_shieldbearer` | Щитоносец Разлома | `scenes/EnemyShield.tscn` | Защитный враг | `assets/sprites/enemies/enemy_rift_shieldbearer.png`; full-frame `assets/sprites/enemies/full_frame/rift_shieldbearer_spriteframes.tres` from `assets/sprites/enemies/full_frame/rift_shieldbearer_full_frame_sheet.png` | Более живучий вариант передней линии; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `small_biter` | Малый Кусатель | `scenes/EnemyBiter.tscn` | Маленький быстрый | `assets/sprites/enemies/enemy_small_biter.png`; full-frame `assets/sprites/enemies/full_frame/small_biter_spriteframes.tres` from `assets/sprites/enemies/full_frame/small_biter_full_frame_sheet.png` | Давит числом и скоростью; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `bone_shaman` | Костяной Шаман | `scenes/EnemyBoneShaman.tscn` | Продвинутый суммонер | `assets/sprites/enemies/enemy_bone_shaman.png`; full-frame `assets/sprites/enemies/full_frame/bone_shaman_spriteframes.tres` from `assets/sprites/enemies/full_frame/bone_shaman_full_frame_sheet.png` | Призыв и поддержка толпы; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `winged_spark` | Крылатая Искра | `scenes/EnemyFlyingRunner.tscn` | Летающий враг | `assets/sprites/enemies/enemy_winged_spark.png`; full-frame `assets/sprites/enemies/full_frame/winged_spark_spriteframes.tres` from `assets/sprites/enemies/full_frame/winged_spark_full_frame_sheet.png` | Hover-движение; pit layer отключен вместе с ямами; визуально использует registry `move` 6f loop, `attack_primary`/`attack` 6f one-shot, `hover_flap` 6f loop, `hit` alias и `death` 6f one-shot | Реализовано |

## Элитные Монстры

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Уникальное поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `iron_bastion` | Железный Оплот | `scenes/EliteArmored.tscn` | Танкующая элитка | `assets/sprites/elites/iron_bastion.png`; full-frame `assets/sprites/elites/full_frame/iron_bastion_spriteframes.tres` | Пассив: периодический щит. Уникальная атака `slam_wave`: замах 0.6с с telegraph-кругом, затем кольцевая ударная волна (радиус 260, урон + отбрасывание), кулдаун 6с. Визуально: `move` loop, `attack`/`attack_primary`, `death`, `skill_shield_block`, `skill_slam_wave` + `attack_*` aliases | Реализовано |
| `night_stalker` | Ночной Сталкер | `scenes/EliteStalker.tscn` | Агрессивная элитка | `assets/sprites/elites/night_stalker.png`; full-frame `assets/sprites/elites/full_frame/night_stalker_spriteframes.tres` (FAN-2621: explicit 8-direction PixelLab pack, `explicit_eight_directions: true`, no flip_h) | Пассив: рывки к игроку. Уникальная атака `shadow_strike`: уходит в тень на 0.5с с telegraph-меткой за спиной игрока, телепортируется туда и бьет (радиус 92), кулдаун 7с. Визуально: `idle`/`move`/`hit`/`death` покрыты по всем 8 направлениям; `attack_primary`, `skill_shadow_strike`, `skill_phase_dash` пока не сгенерированы и деградируют на `move` через STATE_ALIASES (FAN-2621 не завершён) | Реализовано (визуал частично) |
| `plague_prophet` | Чумной Пророк | `scenes/ElitePoisoned.tscn` | Зональная элитка | `assets/sprites/elites/plague_prophet.png`; full-frame `assets/sprites/elites/full_frame/plague_prophet_spriteframes.tres` | Пассив: ядовитые зоны. Уникальная атака `poison_volley`: 3 lob-снаряда по дуге в telegraph-метки, в точках падения лужи на 3с (тик 0.6с), кулдаун 8с. Визуально: `move` loop, `attack`/`attack_primary`, `death`, `skill_poison_volley`, `skill_plague_aura` + `attack_*` aliases | Реализовано |
| `shard_marshal` | Маршал Осколков | `scenes/EliteCommander.tscn` | Командир толпы | `assets/sprites/elites/shard_marshal.png`; full-frame `assets/sprites/elites/full_frame/shard_marshal_spriteframes.tres` | Пассив: одноразовая аура усиления ближайших врагов. Уникальная атака `shard_fan`: веер из 5 кристальных снарядов в сторону игрока после замаха 0.5с, кулдаун 6с. Визуально: `move` loop, `attack`/`attack_primary`, `death`, `skill_shard_fan`, `skill_command_pulse` + `attack_*` aliases | Реализовано |

Обновление SCRUM-135 от 2026-06-12: все 4 активные элитки используют native `512x512` source PNG и перенарезанные `assets/sprites/elites/cutout/` части под `scripts/sliced_rig_manifest.gd` `size = Vector2(512, 512)`. Поза/силуэт сохранены 1:1 относительно прежних 256px-спрайтов, чтобы epic scale оставался геометрически тем же, но без билинейного мыла на QHD/Retina.

Все уникальные атаки элиток: параметры лежат в `ProgressionData.ELITE_ATTACK_CONFIGS` (data-driven), reusable mechanics — в `ProgressionData.ENEMY_MECHANIC_CATALOG`, unique signatures — в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`; урон атаки ограничен 25% max HP игрока. VFX: `elite_telegraph_circle.png`, `elite_shockwave_ring.png`, `elite_shadow_trail.png`, `elite_poison_lob.png`, `elite_crystal_shard.png` в `assets/sprites/effects/`.

## Умения Монстров (Канонические Имена Кодекса)

Зарегистрированы задачей «Кодекс» 2026-06-11. Это ссылочные имена: задачи и обсуждения
ссылаются на них. Источник данных кодекса: `scripts/codex_data.gd::MONSTERS`.

SCRUM-621 unlock tracking stores canonical Codex entry IDs, not ability IDs:
standard, elite and mini-elite monsters go to `discovered_monsters`, boss IDs go
to `discovered_bosses`, and artifact IDs from `ProgressionData.ARTIFACTS` go to
`discovered_artifacts` in `MetaProgression`.

| ID умения | Игровое имя | Носитель | Что делает |
| --- | --- | --- | --- |
| `ragged_lunge` | Рваный Выпад | Рубака Разлома | Контактный удар с замахом (windup) |
| `ash_shot` | Пепельный Выстрел | Пепельный Стрелок | Одиночный снаряд по герою |
| `spark_rush` | Искровой Натиск | Искровой Беглец | Быстрое сближение с героем |
| `stone_press` | Каменный Напор | Каменный Громила | Тяжелый контактный удар, высокий HP |
| `bone_call` | Зов Костей | Костяной Зовущий | Призыв малых кусателей |
| `void_bolt` | Сгусток Пустоты | Маг Пустоты | Магический снаряд |
| `venom_spit` | Ядовитый Плевок | Ядовитый Плеватель | Дальнобойный плевок |
| `rift_wall` | Стена Разлома | Щитоносец Разлома | Повышенная живучесть передней линии |
| `swarm_bite` | Укус Стаи | Малый Кусатель | Частые слабые укусы, сила в числе |
| `bone_rite` | Костяной Ритуал | Костяной Шаман | Ритуальный призыв свиты |
| `spark_dive` | Пикирование Искры | Крылатая Искра | Hover-полет и заход поверх толпы |
| `iron_shield` | Железный Щит | Железный Оплот | Пассив: периодический щит (снижение урона) |
| `quaking_slam` | Сотрясающий Удар | Железный Оплот | Slam-волна: замах, кольцо 260, урон + отбрасывание |
| `predator_dash` | Хищный Рывок | Ночной Сталкер | Пассив: рывок к игроку |
| `shadow_strike` | Теневой Удар | Ночной Сталкер | Уход в тень, телепорт за спину, удар |
| `rot_omen` | Гнилое Знамение | Чумной Пророк | Пассив: отложенный ядовитый взрыв зоны |
| `venom_volley` | Ядовитый Залп | Чумной Пророк | 3 lob-снаряда, ядовитые лужи |
| `shard_aura` | Аура Осколков | Маршал Осколков | Пассив: разовое усиление обычных монстров |
| `shard_fan` | Веер Осколков | Маршал Осколков | Веер из 5 кристальных снарядов |
| `rift_volley` | Залп Разлома | Страж Разлома | Веерный залп снарядов |
| `rift_zone` | Зона Разлома | Страж Разлома | Отложенный взрыв размеченной зоны |
| `riftling_call` | Призыв Осколышей | Страж Разлома | Призыв свиты тройками |
| `warden_shield` | Щит Стража | Страж Разлома | Периодический щит |
| `flicker_step` | Мерцающий Уход | Страж Разлома | Шанс полного уворота от удара |
| `devourer_dash` | Рывок Пожирателя | Пожиратель Диска | Бросок через арену |
| `disk_slam` | Удар Диска | Пожиратель Диска | Круговая зона удара |
| `radial_burst` | Радиальный Взрыв | Пожиратель Диска | Кольцо снарядов во все стороны |
| `devourer_frenzy` | Ярость Пожирателя | Пожиратель Диска | Энрейдж на низком HP |

## Мини-Элитки (Свита Возвышения L7, SCRUM-155)

Data-driven ростер `scripts/progression_data_enemies.gd::MINI_ELITE_KINDS` (10 видов): `mini_scavenger_reaper` Жнец-Падальщик, `mini_plague_bellringer` Чумной Звонарь, `mini_bone_warden` Костяной Страж, `mini_spark_wight` Искровик, `mini_rot_hound` Гнилая Гончая, `mini_shadow_devourer` Теневой Пожиратель и (SCRUM-607, «Эхо бездны») `mini_siege_rammer` Осадный Таран, `mini_swarm_sniper` Роевой Снайпер, `mini_plague_berserker` Чумной Берсерк, `mini_void_phantom` Фантом Бездны. Каждый вид: базовая elite-сцена, профиль hp/speed/damage, RGB-тинт различимости, поведение ближайшего elite-паттерна. Свита L7 выбирает вид случайно (`combat_director._maybe_spawn_mini_elite`); kind-мета `mini_elite_kind` на узле. SCRUM-156 подготовил финальные source sprites `assets/sprites/elites/mini_<id>.png` (`512x512`, RGBA, transparent). Runtime использует базовые elite-сцены с mini-elite meta/scale/drop profile, а кодекс имеет отдельный раздел «Мини-элитки». SCRUM-372: full-frame visual lookup теперь предпочитает registered `mini_elite_kind` SpriteFrames entry и fallback'ается на base `elite_behavior`, если mini-specific frames еще не подключены. SCRUM-376 подключил все 6 `assets/sprites/elites/full_frame/mini_*_spriteframes.tres`: у каждого есть `move` loop, `attack`/`attack_primary`, две `skill_*` rows и matching `attack_*` aliases. SCRUM-370 добавил `death` 6f/10fps no-loop rows для всех 6 mini-elite SpriteFrames. SCRUM-607 расширил ростер до 10 видов: четвёрка `mini_siege_rammer`/`mini_swarm_sniper`/`mini_plague_berserker`/`mini_void_phantom` использует базовые elite-сцены (выделенных full-frame SpriteFrames пока нет — registry безопасно fallback'ается на base `elite_behavior`). SCRUM-719 добавил их canonical-записи в кодекс (`codex_data.gd`); ранее эта четвёрка не была зеркалирована и её убийство молча не открывало codex-запись — теперь покрыто контракт-гейтом `tests/codex_discovery_contract_test.gd`.

## Боссы

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Паттерны | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_warden` | Страж Разлома | `scenes/BossWarden.tscn` | Финальный босс контроля | `assets/sprites/bosses/boss_rift_warden.png`; full-frame `assets/sprites/bosses/full_frame/rift_warden_spriteframes.tres`; SCRUM-865 PixelLab object `ab1c7701-3ee7-4c7c-8842-22a7def87f08` | Залпы, зоны разлома, призыв, щит, увороты. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_gravity_well`, `skill_rift_zone` + `attack_*` aliases | Реализовано |
| `disk_devourer` | Пожиратель Диска | `scenes/BossDiskDevourer.tscn` | Финальный босс давления | `assets/sprites/bosses/boss_disk_devourer.png`; full-frame `assets/sprites/bosses/full_frame/disk_devourer_spriteframes.tres`; SCRUM-865 PixelLab object `2df47b9e-a5f8-4f4a-b423-4aca73d8c3b3` | Рывки, disk slam AoE, radial burst, enrage. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_vampiric_bite`, `skill_rift_zone` + `attack_*` aliases | Реализовано |
| `bone_archon` | Костяной Архонт | `scenes/BossBoneArchon.tscn` | Финальный босс-некромант | `assets/sprites/bosses/boss_bone_archon.png`; full-frame `assets/sprites/bosses/full_frame/bone_archon_spriteframes.tres`; SCRUM-865 PixelLab object `0335a72f-9905-4a18-ba1e-e91d2a9de9bc` | Волны скелетов (summon), веер черепов (volley), костяная стена (волна зон с проходом). Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_skull_volley`, `skill_bone_prison` + `attack_*` aliases | Реализовано |
| `brood_mother` | Матерь Роя | `scenes/BossBroodMother.tscn` | Финальный босс-рой | `assets/sprites/bosses/boss_brood_mother.png`; full-frame `assets/sprites/bosses/full_frame/brood_mother_spriteframes.tres`; SCRUM-865 PixelLab object `0f0db439-9b79-4b25-8951-988319c5e821` | Частый выводок мелких, паутинные зоны замедления (apply_web_slow), рывок в фазе 3. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_brood_spawn`, `skill_web_zone` + `attack_*` aliases | Реализовано |
| `ashen_colossus` | Пепельный Колосс | `scenes/BossAshenColossus.tscn` | Финальный босс-гигант | `assets/sprites/bosses/boss_ashen_colossus.png`; full-frame `assets/sprites/bosses/full_frame/ashen_colossus_spriteframes.tres`; SCRUM-865 PixelLab object `eb2bfa56-9406-4855-96e6-dc05c9272494` | Slam-волны + тлеющие зоны после ударов, редкий radial burst, энрейдж <25% HP (быстрее, шире волны). Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_molten_slam`, `skill_armor_pulse` + `attack_*` aliases | Реализовано |
| `bloodthorn_lion` | Кровавый Шипастый Лев | `scenes/BossBloodthornLion.tscn` | Новый боссовый хищник (SCRUM-794, design SCRUM-779) | Live static `assets/sprites/bosses/boss_bloodthorn_lion.png`; full-frame `assets/sprites/bosses/full_frame/bloodthorn_lion_spriteframes.tres`; SCRUM-865 PixelLab object `1b923d8c-e83e-48a1-970e-4681f63ead0a` | Прыжки-рывки (dash-pounce), radial burst шипов, колючие `BossRiftZone` bleed-зоны, уникальная `BloodthornSpikeRing` (кольцо с проходом), enrage <35% HP. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_spike_ring`, `skill_rift_zone` + `attack_*` aliases | Runtime и full-frame реализованы; **вне случайной route-ротации** до QA-gated follow-up |
| `secret_ascension_boss` | Secret Ascension Boss | `scenes/BossSecretAscension.tscn` | Post-final-Act-2 max-Ascension capstone boss | Design source/runtime candidate `assets/sprites/bosses/secret_ascension_boss.png`; source pack `docs/design/references/bosses/secret_ascension_boss/`; telegraphs `assets/sprites/effects/secret_ascension_boss_*_telegraph.png` | `SecretBossSectorRing`, delayed `BossRiftZone` eruptions, phase-2 adds/pressure at 50% HP, phase 3 below 25% HP | SCRUM-539 Design source pack done; animation/runtime integration handoff pending |
| `skeletal_dragon` | Костяной Дракон | TBD | Planned flying skeletal dragon boss | Concept reference `docs/design/references/bosses/pixellab_roster_redraw_2026_06/openai_concepts/skeletal_dragon_concept_openai.png`; PixelLab candidate `assets/sprites/bosses/pixellab_candidates/skeletal_dragon/skeletal_dragon_pixellab_alpha.png` | Planned: flying skeletal pressure, bone/necromancy hazards, wing-safe telegraphs. Mechanics/scene not implemented. | SCRUM-779 Design-source candidate; backend/animation handoff pending |

SCRUM-352/SCRUM-394 Design source для full-frame rows хранится как
`assets/sprites/{enemies,elites,bosses}/full_frame/<entity_id>_full_frame_sheet.png`
(`1704x1144`, RGBA, transparent, 6 columns x 4 rows, `256x256` cells, `24px`
discard-only gutters, `24px` outer padding). Row contract, safe-slicing metadata
and pivot notes are recorded in
`docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`.
SCRUM-378 подключил визуальную маршрутизацию этих boss `skill_*` rows из
`scripts/boss.gd`: callbacks способностей запрашивают соответствующий full-frame
state, но урон, телеграфы, cooldowns, targeting и spawn timing остаются
Back-end mechanics data без изменений.
SCRUM-380/SCRUM-394 Design source для явных full-frame `death` rows хранится в
`assets/sprites/bosses/full_frame/<boss_id>/<boss_id>_death_*.png` и
`<boss_id>_death_row.png`; source references are `1704x304` RGBA with `256x256`
cells, `24px` discard-only gutters and `24px` outer padding; общий манифест:
`docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`.
Для `bone_archon`, `brood_mother` и `ashen_colossus` строки готовы как Design
source pack и подключены Animator-owned SpriteFrames integration SCRUM-370.

Обновление SCRUM-135 от 2026-06-12: оба boss source PNG заменены на native `512x512` и перенарезаны в `assets/sprites/bosses/cutout/`; `rift_warden` сохраняет отдельный `vortex` part, `disk_devourer` остается single-torso rig по текущему CONFIG. Epic boss scale не менялся.

SCRUM-779 (2026-07-01) добавил PixelLab-first Design-source pass для boss
roster refresh и двух новых candidates. OpenAI image generation использовался
только для concept references `skeletal_dragon` и `bloodthorn_lion`; production
sprite candidates созданы через PixelLab MCP и сохранены под
`assets/sprites/bosses/pixellab_candidates/`, с manifest/QA notes в
`docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`.
SCRUM-793 (2026-07-02) promoted only the accepted current-boss candidates
`disk_devourer` and `brood_mother`. SCRUM-865 (2026-07-04) supersedes that
partial runtime state for live bosses: all six live bosses now use PixelLab MCP
8-direction source objects plus imported west-facing runtime full-frame rows in
the existing Godot state contract. `skeletal_dragon` remains source-only/planned,
and `bloodthorn_lion` still stays out of random route rotation until a separate
QA-gated route-pool task. QA evidence:
`build/qa/scrum793_boss_pixellab_promotion/` and
`docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.

## Лор И Летопись (FAN-1080)

Канонический лор мира: `docs/design/lore.md`; единственная рантайм-проекция —
`scripts/lore_data.gd` (интро-слайды, записи «Летописи», BOSS_LORE/ELITE_LORE/
CLASS_ORIGIN, строки исхода забега). Лор объясняет существующие сущности и не
переименовывает их. Канонические лор-имена (надстройка над сущностями):

| Лор-имя | Значение | Где в UI |
| --- | --- | --- |
| Диск | Мир-ковчег из осколков погибших миров | Летопись (Вступление) |
| Око | Центр Диска, будит Хранителей | Летопись (Вступление) |
| Разлом | Трещина Пустоты, источник врагов (эмблема игры) | Летопись (Вступление) |
| Владыки Разлома | Собирательное имя боссов; ротация = «вахта у кромки» | Летопись, досье боссов |
| Прибой / офицеры прибоя | Волны врагов / элитки | Летопись, досье элиток, баннер элитки |
| Хранители | Собирательное имя 17 классов; у каждого «осколок-мир» | Летопись, досье классов («Происхождение») |
| Путь | Забег по маршрутной карте | Летопись (Вступление) |
| Печать | Победа над боссом (закрывает Разлом на время) | Экран победы |
| Возвышение-«витки» | 5 уровней Возвышения = витки Разлома вглубь | Летопись |
| Исток | Лор-имя `secret_ascension_boss`; спойлер-гард до победы | Баннер секретного боя, Летопись (после `secret_boss_defeated`) |

Рантайм-точки: FAN-1099 — интро-экран убран из запуска игры; «Начать новую игру»
и «Новая игра» ведут сразу в выбор героя, рассказ о мире остался только в записи
«Вступление» вкладки Кодекса «Летопись». Экран `LoreIntroScreen`/`_show_lore_intro`
(флаг `settings.cfg: lore_intro_seen`, тест-байпас `main.force_skip_lore_intro`)
сохранён для пересмотра/тестов и возможного возврата, но из потока запуска не
вызывается. Вкладка Кодекса «Летопись» (`_build_codex_chronicle`, 7-я вкладка), лор-строка
под боевым баннером босса/элитки (`_show_combat_title_banner(..., lore_line)`),
лорные строки победы/поражения. Сцены `BossWarden.tscn`/`BossDiskDevourer.tscn`
получили русские `boss_display_name` («Страж Разлома», «Пожиратель Диска»),
`BossSecretAscension.tscn` — «Исток». Тест: `tests/lore_screens_test.gd`.

## Узлы Маршрутной Карты

| ID | Игровое имя | Роль | Иконка | Статус |
| --- | --- | --- | --- | --- |
| `battle` | Обычный бой | Стандартный combat-узел | `assets/sprites/map_icons/map_battle_skull.png` | Реализовано |
| `elite_battle` | Бой с элиткой | Сложный бой с элитным врагом | `assets/sprites/map_icons/map_elite_skull_bones.png` | Реализовано |
| `shop` | Магазин | Покупка нескольких предметов | `assets/sprites/map_icons/map_shop_tent.png` | Реализовано |
| `event` | Событие | Выбор с наградой/риском | `assets/sprites/map_icons/map_event_question.png` | Реализовано |
| `chest` | Сундук | Mid-route special node: выбор 1 из 3 артефактов, затем возврат на карту | `assets/sprites/map_icons/map_chest_artifact.png` | Реализовано (SCRUM-537; icon SCRUM-536) |
| `rest` | Костер | Лечение или защитный бонус | `assets/sprites/map_icons/map_rest_campfire.png` | Реализовано |
| `boss` | Босс | Финальный бой акта | `map_boss_rift_warden.png` / `map_boss_disk_devourer.png` | Реализовано |

## Случайные События

Источник: `scripts/event_data.gd`. Event-node выбирает один сценарий из пула без повторов в рамках акта; после исчерпания пула список использованных событий сбрасывается. Тексты, выборы и последствия лежат в данных, UI только отображает сценарий и применяет outcome.

| ID | Игровое имя | Типы исходов | Ключевая роль | Статус |
| --- | --- | --- | --- | --- |
| `wandering_bard` | Странствующий бард | цена, бафф, check Knowledge | Деньги за темп или рискованный песенный чек | Реализовано |
| `cursed_altar` | Проклятый алтарь | HP-жертва, artifact, elite combat | Риск кровавой сделки или бой с тенью | Реализовано |
| `road_ambush` | Засада! | combat, gold multiplier, check Agility | Внезапный усиленный бой с повышенной наградой | Реализовано |
| `old_well` | Старый колодец | цена, heal/money/combat random, check Perception | Слепой бросок монеты или осторожное исследование | Реализовано |
| `wounded_mercenary` | Раненый наемник | цена, summon/Leadership, money, penalty | Моральный выбор помощи или мародерства | Реализовано |
| `goblin_lottery` | Гоблин-лотерейщик | hidden risk, artifact/junk/combat, check Perception | Мешок вслепую с мимиком как боевым риском | Реализовано |
| `hot_spring` | Горячий источник | rest, Endurance, enemy health modifier | Сильный отдых с будущей боевой ценой | Реализовано |
| `mirror_phantom` | Зеркальный фантом | elite combat, check Intelligence | Дуэль с отражением или изучение класса | Реализовано |
| `stone_guardian` | Каменный страж | check Knowledge, artifact, combat | Загадка или силовой проход | Реализовано |
| `heroes_graveyard` | Кладбище героев | hidden risk, artifact/combat, rest | Грабеж могилы или почтение павшим | Реализовано |
| `fallen_star` | Падшая звезда | Energy, HP cost, check Intelligence | Сильный ресурсный апгрейд с ожогом | Реализовано |
| `training_dummies` | Тренировочные манекены | check Agility/Strength, stat+mods | Испытания скорости и силы | Реализовано |
| `warden_gate_trial` | Врата Хранителя | class-reactive checks Endurance/Intelligence/Leadership | Архетипная развилка: танк/маг/призыватель открывают свою створку | Реализовано |
| `abandoned_forge` | Заброшенная кузница | class-reactive checks Endurance/Intelligence, money | Профильная заготовка под танка/мага или сбор лома | Реализовано |
| `merchant_caravan` | Торговый караван | цена, artifact, rest, check Perception | Лавка артефакта/тоника или торг за сдачу | Реализовано |
| `whispering_grove` | Шепчущая роща | rest, check Knowledge, hidden risk combat | Источник, шёпот-чек или потревоженные стражи | Реализовано |
| `collapsing_mineshaft` | Обвалившаяся шахта | HP cost, artifact/money/combat random, check Endurance | Разбор завала вслепую или укрепление балок | Реализовано |
| `sudden_fork` | Опасная развилка | safe money/heal, risk combat, check Perception | Hazard-узел: безопасный обход или рискованный срез | Реализовано |
| `crystal_geode_vault` | Кристальная жеода | safe money/heal, risk combat+artifact, check Strength | Сбор с краю или прорыв к ядру за артефактом | Реализовано |
| `starlit_observatory` | Звёздная обсерватория | stat/money, check Knowledge+artifact, цена+xp | Запись знаний, чек линзы или настройка зеркал | Реализовано |
| `sunken_caravan` | Затонувший караван | safe money, risk combat+artifact, check Perception | Снять с поверхности или нырнуть за сундуком | Реализовано |
| `war_drums_camp` | Покинутый лагерь воинов | rest/money, risk elite combat, цена attack-баффы | Паёк, призыв элитки барабанами или заточка | Реализовано |
| `twin_offering_shrine` | Святилище двойного подношения | money/xp, цена artifact, HP-жертва random | Монетка, золотое или кровавое подношение | Реализовано |
| `oracle_crossroads` | Перекрёсток оракула | class-reactive checks Endurance/Intelligence/Leadership | Архетипные тропы тела/разума/воли с профильным бонусом | Реализовано |
| `runed_menhir` | Рунный менгир | class-reactive checks Strength/Knowledge, цена heal | Силовой раскол берсерка vs чтение рун учёного | Реализовано |
| `gilded_gambler` | Позолоченный шулер | цена hidden risk artifact/money/combat, check Perception | Ставка вслепую или раскус шулера | Реализовано |
| `tidewater_grotto` | Приливный грот | rest+heal mod, risk combat+artifact, check Agility | Целебная заводь, рейд в грот или ловля отлива | Реализовано |
| `wandering_emberwisp` | Блуждающий огонёк | HP cost money/artifact/combat random, check Intelligence | Погоня за огоньком или приручение искры | Реализовано |

## UI Иконки Характеристик

Все иконки подключаются через `scripts/ui_icon_registry.gd`; это единая backend-точка для Escape stats menu, level-up reward cards, tooltips, shop/reward descriptions и HUD. Иконки должны оставаться polished stylized fantasy cartoon PNG, без emoji/default placeholders.

### Базовые Характеристики

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `strength` | Сила | `assets/sprites/ui/icons/stats/stat_strength.png` |
| `agility` | Ловкость | `assets/sprites/ui/icons/stats/stat_agility.png` |
| `intelligence` | Интеллект | `assets/sprites/ui/icons/stats/stat_intelligence.png` |
| `perception` | Восприятие | `assets/sprites/ui/icons/stats/stat_perception.png` |
| `energy` | Энергия | `assets/sprites/ui/icons/stats/stat_energy.png` |
| `knowledge` | Знание | `assets/sprites/ui/icons/stats/stat_knowledge.png` |
| `endurance` | Выносливость | `assets/sprites/ui/icons/stats/stat_endurance.png` |
| `leadership` | Лидерство | `assets/sprites/ui/icons/stats/stat_leadership.png` |

### Производные Атрибуты

FAN-1887: канонический player-facing реестр прокачки — 16 осей
(`CharacterData.ATTRIBUTE_REGISTRY`); плоская ось «Добавление урона»
(`damage_flat`) использует иконку `attr_damage.png`. Иконки внутренних
параметров (absorb, knockback, attack_range, range_multiplier, dot_speed,
aura_radius, buff_power, projectile_speed, vampiric_chance) сохранены как
ассеты для артефактных превью и legacy-редов, но эти параметры больше не
являются самостоятельными выборами level-up/Shop/Codex/Hero Select. Пять
player-facing defensive choices: max_health, defense, dodge, regeneration и
vampiric. Absorb и vampiric_chance — внутренние параметры: absorb пропускает
≥42% удара, а сила вампиризма масштабируется Knowledge и общим
heal-per-second budget.

Обычный dodge остаётся строго ниже 0.55; smoke bomb Вора — отдельное
достижимое исключение с суммарным пределом 0.90 только внутри живого облака.

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `damage` | Урон | `assets/sprites/ui/icons/derived/attr_damage.png` |
| `magic_damage` | Магический урон | `assets/sprites/ui/icons/derived/attr_magic_damage.png` |
| `attack_speed` | Скорость атаки | `assets/sprites/ui/icons/derived/attr_attack_speed.png` |
| `crit_chance` | Шанс крита | `assets/sprites/ui/icons/derived/attr_crit_chance.png` |
| `crit_damage_multiplier` | Сила крита | `assets/sprites/ui/icons/derived/attr_crit_damage_multiplier.png` |
| `move_speed` | Скорость движения | `assets/sprites/ui/icons/derived/attr_move_speed.png` |
| `dodge` | Уклонение | `assets/sprites/ui/icons/derived/attr_dodge.png` |
| `defense` | Защита | `assets/sprites/ui/icons/derived/attr_defense.png` |
| `absorb` | Поглощение | `assets/sprites/ui/icons/derived/attr_absorb.png` |
| `health_point` | Максимальное здоровье | `assets/sprites/ui/icons/derived/attr_health_point.png` |
| `knockback_distance` | Дистанция отталкивания | `assets/sprites/ui/icons/derived/attr_knockback_distance.png` |
| `summon_amount` | Сила призыва | `assets/sprites/ui/icons/derived/attr_summon_amount.png` |
| `attack_range` | Дальность атаки | `assets/sprites/ui/icons/derived/attr_attack_range.png` |
| `range_multiplier` | Множитель дальности | `assets/sprites/ui/icons/derived/attr_range_multiplier.png` |
| `regeneration` | Регенерация | `assets/sprites/ui/icons/derived/attr_regeneration.png` |
| `vampiric_amount` | Вампиризм | `assets/sprites/ui/icons/derived/attr_vampiric_amount.png` |
| `vampiric_chance` | Шанс вампиризма | `assets/sprites/ui/icons/derived/attr_vampiric_chance.png` |
| `dot_damage` | Периодический урон | `assets/sprites/ui/icons/derived/attr_dot_damage.png` |
| `dot_speed` | Частота периодического урона | `assets/sprites/ui/icons/derived/attr_dot_speed.png` |
| `aoe_radius` | Увеличение области атаки | `assets/sprites/ui/icons/derived/attr_aoe_radius.png` |
| `aura_radius` | Радиус ауры | `assets/sprites/ui/icons/derived/attr_aura_radius.png` |
| `buff_power` | Сила баффов | `assets/sprites/ui/icons/derived/attr_buff_power.png` |
| `knockback_power` | Сила отталкивания | `assets/sprites/ui/icons/derived/attr_knockback_power.png` |
| `projectile_speed` | Скорость снарядов | `assets/sprites/ui/icons/derived/attr_projectile_speed.png` |
| `ultimate_multiplier` | Сила ультимейта | `assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png` |
| `pickup_radius` | Радиус подбора | `assets/sprites/ui/icons/derived/attr_pickup_radius.png` |

### HUD Ресурсы

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `hp` | HP | `assets/sprites/ui/hud/hud_hp.png` |
| `xp` | Опыт | `assets/sprites/ui/hud/hud_xp.png` |
| `money` | Деньги | `assets/sprites/ui/hud/hud_money.png` |
| `ultimate_multiplier` | Сила ультимейта | `assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png` via `UIIconRegistry` |

`scripts/ui_icon_registry.gd` кэширует загруженные Texture2D по пути; новые UI места должны брать иконки через registry, а не делать отдельный `load()`.

## Ультимейты Классов

Источник данных: `scripts/progression_data.gd::ULTIMATE_CONFIGS`. Все ульты активируются через InputMap action `ultimate` и отображаются в HUD как `ULT`.

| Class ID | Ultimate ID/Title | Status |
| --- | --- | --- |
| `berserk` | Неистовство | Реализовано |
| `dark_mage` | Темная буря | Реализовано |
| `guitarist` | Соло | Реализовано |
| `assassin` | Танец клинков | Реализовано |
| `ranger` | Лунный залп | Реализовано |
| `doctor` | Переливание | Реализовано |
| `chemist` | Цепная реакция | Реализовано |
| `knight` | Бастион | Реализовано |
| `druid` | Зов стаи | Реализовано |

## UI Visual Kit 2026-06-14

SCRUM-273 заменяет button-канон SCRUM-147 на Red & Gold Dragon kit из `docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`. Live-кнопки лежат в `assets/sprites/ui/frames/red_gold/`: 15 типов, каждый с idle/base, hover, pressed и disabled. Старый Parchment & Wax Seal button kit скопирован в backup `build/cleanup_backup_red_gold_buttons_2026_06_14/` и больше не является runtime-каноном. SCRUM-274 заменяет non-button panel/frame канон SCRUM-229 на Ornate Dark / Red kit из `docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`. Live-панели/HUD/tooltips/pause frames лежат в `assets/sprites/ui/frames/ornate/`, а прежний leather+gold/dark_fantasy/escape panel kit скопирован в backup `build/cleanup_backup_ornate_frames_2026_06_14/`. No-junk rule: без бессмысленных линий/кружков/квадратиков/дефолтного Godot-декора.

SCRUM-448/SCRUM-449 делают **Minimalist UI restyle** активным non-button frame
направлением: `assets/sprites/ui/frames/minimal/` содержит
`ui_frame_minimal_modal`, `panel`, `card`, `tooltip`, `hud_strip` и `field`.
Spec/metadata: `docs/design/mockups/scrum448_ui_minimalist/spec.md` и
`docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`;
preview: `docs/design/previews/scrum448_minimal_ui_frame_contact.png`.
Все PNG прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Live runtime uses this kit for safe non-button panels/cards/tooltips/HUD wrappers;
SCRUM-273 Red & Gold buttons остаются каноном и не заменяются этим набором.

SCRUM-452 добавляет Design-ready **Minimal Metal UI anchor** для следующего
упрощения интерфейса: `assets/sprites/ui/frames/minimal_metal/` содержит
`ui_frame_minimal_metal_modal`, `panel`, `card`, `tooltip`, `hud_strip` и
`field`. Spec/metadata:
`docs/design/mockups/scrum452_ui_minimal_metal/spec.md` и
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`;
previews: `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`,
`docs/design/previews/scrum452_minimal_metal_safe_zones.png`. Все production PNG
прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Набор не live до Back-end integration handoff; SCRUM-273 buttons остаются
каноном до SCRUM-450.

SCRUM-450 добавляет Design-ready **Minimal Metal button kit**:
`assets/sprites/ui/frames/minimal_metal_buttons/` содержит 15 button types x 5
states (`normal`, `hover`, `pressed`, `focus`, `disabled`). Metadata:
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`;
spec: `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`;
previews: `docs/design/previews/scrum450_minimal_metal_button_contact.png`,
`docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`. Все 75 PNG
прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Набор не live до Back-end integration; SCRUM-273 Red & Gold buttons остаются
активным runtime-каноном.

SCRUM-451 добавляет Design-source **Minimal Metal rollout contract**: все
целевые UI surfaces по экранам сведены к шести frame families SCRUM-452
(`modal`, `panel`, `card`, `tooltip`, `hud_strip`, `field`) с отдельным
подключением SCRUM-450 button kit. Source of truth:
`docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md` и
`docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`;
preview: `docs/design/previews/scrum451_minimal_metal_rollout_contact.png`.
Контракт не live до Back-end integration; старые frame assets удалять/бэкапить
можно только после no-live-ref audit.

| ID | Ассет | Роль |
| --- | --- | --- |
| `ui_panel_frame` | `assets/sprites/ui/frames/global/ui_panel_frame.png` | Базовые большие панели меню/событий/кодекса |
| `ui_button_frame` | `assets/sprites/ui/frames/global/ui_button_frame.png` | Legacy/fallback frame; runtime buttons use SCRUM-273 `ui_btn_red_gold_*` 4-state textures |
| `ui_card_frame` | `assets/sprites/ui/frames/global/ui_card_frame.png` | Карточки персонажей, route node buttons, compact panels |
| `ui_level_panel_frame` | `assets/sprites/ui/frames/global/ui_level_panel_frame.png` | Level-up / reward panel |
| `ui_hud_panel_frame` | `assets/sprites/ui/frames/global/ui_hud_panel_frame.png` | Боевой HUD panel |
| `ui_hud_card_frame` | `assets/sprites/ui/frames/global/ui_hud_card_frame.png` | HP/XP/money HUD cards |
| `ui_tooltip_frame` | `assets/sprites/ui/frames/global/ui_tooltip_frame.png` | Generic tooltip/system panel frame |
| `ui_frame_unified_master` | `assets/sprites/ui/frames/unified/ui_frame_unified_master.png` | SCRUM-384 active thin metallic projectwide master frame border, `1024x1024` RGBA, transparent center; use 9-slice tile margins `72/72/72/72`, content margins `88/88/88/88`, strict safe rect `[88,88,848,848]`; paths preserved from SCRUM-373/SCRUM-382 |
| `ui_gold_menu_shell` | `assets/sprites/ui/meta40/frame_border.png` | SCRUM-981 canonical hollow outer shell for Main Menu, Route Map, Rest, Upgrade, Battle Reward, Victory and Defeat; source `1536x1024`, texture/content rails `160/160/160/160`, `draw_center=false`; safe rects `[133,113,1014,494]` @1280×720, `[200,169,1520,742]` @1920×1080, `[267,225,2026,990]` @2560×1440. Codex/Level Up/Combat and specialist child screens are explicit exceptions. |
| `ui_frame_unified_master_fill` | `assets/sprites/ui/frames/unified/ui_frame_unified_master_fill.png` | SCRUM-384 full panel-fill variant for rectangular surfaces where a quiet dark fill is acceptable |
| `ui_frame_unified_inner_fill` | `assets/sprites/ui/frames/unified/ui_frame_unified_inner_fill.png` | SCRUM-384 `1024x1024` inner fill asset with alpha outside strict content zone |
| `ui_frame_unified_ornament_top_bottom` | `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_top.png`, `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_bottom.png` | SCRUM-384 optional dragon overlays for large-window ornaments only; do not bake into 9-slice stretch zones and do not use on compact HUD, tooltip, chip or button surfaces |
| `ui_frame_unified_hover_overlay` | `assets/sprites/ui/frames/unified/ui_frame_unified_hover_overlay.png` | SCRUM-384 subtle red/gold hover overlay fallback; preferred runtime hover is neutral modulate/contrast, not yellow glow |
| `ui_frame_minimal_modal` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_modal.png` | SCRUM-448/SCRUM-449 live minimalist modal/window frame, `986x900` RGBA, content rect `[74,94,838,720]`; used for Settings/Codex/pause/result shells where safe |
| `ui_frame_minimal_panel` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_panel.png` | SCRUM-448/SCRUM-449 live generic minimal panel, `782x716` RGBA, content rect `[59,75,664,573]`; used for inner panels and large sections where safe |
| `ui_frame_minimal_card` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_card.png` | SCRUM-448/SCRUM-449 live minimal card, `426x486` RGBA, content rect `[45,58,336,372]`; used for reward/economy/Codex cards where safe |
| `ui_frame_minimal_tooltip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_tooltip.png` | SCRUM-448/SCRUM-449 live minimal tooltip, `760x242` RGBA, content rect `[68,46,624,155]`; used for glossary/tooltips where safe |
| `ui_frame_minimal_hud_strip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_hud_strip.png` | SCRUM-448/SCRUM-449 live minimal HUD/resource strip, `1122x288` RGBA, content rect `[107,65,908,164]`; used for compact resource HUD wrapper |
| `ui_frame_minimal_field` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_field.png` | SCRUM-448/SCRUM-449 live minimal input/field/tab frame, `616x286` RGBA, content rect `[59,53,498,183]`; used for Settings switcher, HUD cards and compact price badges |
| `ui_frame_minimal_metal_modal` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png` | SCRUM-452 Design-ready strict minimal-metal modal/window frame, `986x900` RGBA, content rect `[72,92,842,724]`; not live until Back-end integration |
| `ui_frame_minimal_metal_panel` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png` | SCRUM-452 Design-ready strict minimal-metal generic panel, `782x716` RGBA, content rect `[58,72,666,578]`; not live until Back-end integration |
| `ui_frame_minimal_metal_card` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png` | SCRUM-452 Design-ready strict minimal-metal card, `426x486` RGBA, content rect `[46,58,334,374]`; not live until Back-end integration |
| `ui_frame_minimal_metal_tooltip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png` | SCRUM-452 Design-ready strict minimal-metal tooltip, `760x242` RGBA, content rect `[66,44,628,158]`; not live until Back-end integration |
| `ui_frame_minimal_metal_hud_strip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_hud_strip.png` | SCRUM-452 Design-ready strict minimal-metal HUD/status strip, `1122x288` RGBA, content rect `[104,62,914,170]`; not live until Back-end integration |
| `ui_frame_minimal_metal_field` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png` | SCRUM-452 Design-ready strict minimal-metal input/field frame, `616x286` RGBA, content rect `[58,52,500,186]`; not live until Back-end integration |
| `ui_btn_minimal_metal_standard` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_standard*.png` | SCRUM-450 Design-ready standard action button family, `420x104` RGBA, 5 states, content rect `[64,32,292,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_max` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_max*.png` | SCRUM-450 Design-ready maximum action button family, `560x104` RGBA, 5 states, content rect `[72,32,416,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_main_menu` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_main_menu*.png` | SCRUM-450 Design-ready main-menu button family, `380x104` RGBA, 5 states, content rect `[62,32,256,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_back_s_m_l` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_back_*.png` | SCRUM-450 Design-ready back/action variants S/M/L, 5 states each; see metadata for exact content rects; not live until Back-end integration |
| `ui_btn_minimal_metal_compact` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab*.png`, `ui_btn_minimal_metal_utility*.png`, `ui_btn_minimal_metal_pause*.png`, `ui_btn_minimal_metal_rebind*.png` | SCRUM-450 Design-ready compact/slim button families, 5 states each; fixed or 9-slice per metadata; not live until Back-end integration |
| `ui_btn_text_unique_scrum657` | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_<group>_<state>.png` | SCRUM-657 Design-ready text-button audit/redraw package, 15 size groups including 2 expanded long-label variants, 5 states each, transparent PNG, no baked text; source/audit/fit reports live in `docs/design/references/ui_text_buttons_unique_size_redraw/`, with one OpenAI source PNG per size in `per_size_sources/`. Runtime labels must fit inside `content_rect_xywh` between decorative end shutters/caps; increase width when localized text does not fit. Left/right caps are fixed-size ornaments and must not be scaled horizontally; only the center rail may stretch. |
| `ui_frame_settings_tab_switcher_3slot` | `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png` | SCRUM-391 Design-ready Settings tab switcher candidate, `1280x256` RGBA, exactly 3 slots; safe rects `[160,88,270,82]`, `[506,88,270,82]`, `[852,88,270,82]`; runtime activation handed off to `backend_settings_menu_unified_restyle_integration_task.md` |
| `ui_frame_settings_v2_main_modal` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` | SCRUM-439 Design-ready Settings v2 modal candidate, `1536x1024` RGBA; texture margins `96/118/96/96`, content margins `144/192/144/128`; not live until Back-end integration |
| `ui_frame_settings_v2_tab_switcher_3slot` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png` | SCRUM-439 Design-ready Settings v2 switcher candidate, `1280x256` RGBA, exactly 3 slots; safe rects `[150,78,275,92]`, `[502,78,275,92]`, `[854,78,275,92]`; not live until Back-end integration |
| `ui_frame_settings_v2_section_panel` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_section_panel.png` | SCRUM-439 Design-ready nested Settings section panel, `1024x384` RGBA; content margins `104/96/104/92`; optional Back-end use |
| `ui_frame_settings_v2_control_row` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_control_row.png` | SCRUM-439 Design-ready Settings row frame, `1536x192` RGBA; content margins `96/54/96/54`; optional Back-end use for dropdown/rebind/slider rows |
| `ui_frame_combat_hud_resource_panel` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png` | SCRUM-390 Design-ready combat HUD resource strip, `1024x144` RGBA; texture margins `[96,44,96,44]`, content margins `[92,30,92,30]`, safe rect `[92,30,840,84]`; runtime activation handed off to `backend_combat_hud_redraw_integration_task.md` |
| `ui_frame_combat_hud_card_*` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_hp.png`, `_xp.png`, `_gold.png`, `_ult.png` | SCRUM-390 Design-ready resource card frames, `256x144` RGBA; texture margins `[48,42,48,38]`, content margins `[32,24,32,22]`, safe rect `[32,24,192,98]` |
| `ui_frame_combat_hud_timer` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png` | SCRUM-390 Design-ready combat timer frame, `384x128` RGBA; texture margins `[92,42,92,38]`, content margins `[82,32,82,28]`, safe rect `[82,32,220,68]` |
| `ui_frame_combat_hud_ascension_badge` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_ascension_badge.png` | SCRUM-390 Design-ready ascension badge, `128x128` RGBA; content margins `[40,34,40,34]`, safe rect `[40,34,48,60]` |
| `ui_btn_combat_level_up_plus_*` | `assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png` + hover/pressed/disabled | SCRUM-390 opaque bottom-right level-up plus button kit, `128x128` RGBA; safe rect `[36,34,56,58]`; no yellow hover glow |
| `ui_hud_bar_fill_*` | `assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png`, `_xp.png`, `_ult.png`, `_gold.png` | SCRUM-390 painterly resource fill textures, `512x32` RGBA, optional Back-end use for HP/XP/ULT/gold bars |
| `ui_frame_pause_end_modal` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` | SCRUM-330 Design-ready pause/victory/death modal frame, `1280x1024` RGBA transparent. Source safe rect `[170,180,940,670]`, content margins `[170,180,170,174]`; use proportional whole-image frame or verified 9-slice only; runtime content must not overlap dragon heads, side columns, gems, bottom crest or metal border. Metadata: `docs/design/references/ui_overhaul_pause_end/scrum330_pause_end_metadata.json`; Back-end integration handoff: `backend_pause_end_ui_overhaul_integration_task.md` |
| `ui_result_crest_victory_defeat` | `assets/sprites/ui/result_crests/ui_crest_victory.png`, `assets/sprites/ui/result_crests/ui_crest_defeat.png` | SCRUM-330 result-screen decorative crests accepted for victory/death headers; decorative only in this pass, not content containers |
| `ui_frame_codex_*` | `assets/sprites/ui/frames/codex/ui_frame_codex_main_panel.png`, `_section_panel.png`, `_entry_card.png`, `_entry_card_hover.png`, `_portrait_slot.png`, `_tooltip.png`, `_tab.png`, `_tab_hover.png`, `_tab_pressed.png`, `_tab_disabled.png` | SCRUM-345 Design-ready historical Codex texture kit generated through `fantasydisk-asset-generator`; metadata and safe-zones in `docs/design/references/codex/codex_ui_texture_kit_metadata.json`; superseded for live Codex shell/list/detail/cards/tabs by SCRUM-574 2K frames, but still retained as reference/component history |
| `ui_frame_2k_codex_*` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_main.png`, `_nav.png`, `_list.png`, `_detail.png`, `_entry_card.png`, `_tab_btn.png`, `_back_btn.png` | SCRUM-574 live Codex v2 2K frame family generated by `tools/build_ui_2k_frame_kit.py`; source/mockup at `docs/design/references/scrum574_codex_2k/codex_2k_mockup.png`, contract at `docs/design/mockups/scrum574_codex_2k/spec.md`; runtime uses these exact slots for `CodexMainPanel`, `CodexNavPanel`, `CodexContent`, `CodexDetailPanel`, `CodexEntryCard`, `CodexTab_*` and `CodexBackButton` |
| `ui_frame_2k_rc_*` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png`, `ui_frame_2k_rc_btn.png` | SCRUM-584 live rebind-conflict dialog frame pair generated by `tools/build_ui_2k_frame_kit.py`; accepted textless OpenAI mockup at `docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference_v2.png`, safe-zone preview at `docs/design/previews/scrum584_rebind_conflict_2k_safe_zones.png`, contract at `docs/design/mockups/scrum584_rebind_conflict_2k/spec.md`; runtime uses these slots for `RebindConflictPanel`, `RebindConflictRetryButton`, and `RebindConflictBackButton` |
| `ui_codex_v2_mockup_spec` | `docs/design/mockups/scrum438_codex_v2/spec.md`, `codex_v2_mockup_1920x1080.png`, `codex_v2_layout_metadata.json`; SCRUM-574 addendum `docs/design/mockups/scrum574_codex_2k/spec.md` | SCRUM-438 Design/runtime contract for the full Codex window rebuild; SCRUM-574 keeps the Control layout and replaces the live shell/list/detail/cards/tabs/back material with slot-exact 2K frames |
| `ui_frame_ornate_global_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_global_panel.png` | Live global/menu/event/codex panel frame |
| `ui_frame_ornate_level_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_level_panel.png` | Live level-up/reward main panel |
| `ui_frame_ornate_card_frame` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_card_frame.png` | Live list/card frame |
| `ui_frame_ornate_hero_card` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hero_card.png` | Live hero portrait/card frame |
| `ui_frame_ornate_card_hover` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_card_hover.png` | Live hover/selected card frame |
| `ui_frame_ornate_tooltip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_tooltip.png` | Live generic tooltip frame |
| `ui_frame_ornate_hud_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hud_panel.png` | Live combat HUD panel |
| `ui_frame_ornate_hud_card` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hud_card.png` | Live HP/XP/money/ultimate HUD cards |
| `ui_frame_ornate_timer_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_timer_panel.png` | Live combat timer/ascension timer panel |
| `ui_frame_ornate_pause_main` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_main.png` | Live Escape stats main panel |
| `ui_frame_ornate_pause_stat_group` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_group.png` | Live Escape derived stat group |
| `ui_frame_ornate_pause_stat_chip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_chip.png` | Live Escape base row / derived chip |
| `ui_frame_ornate_pause_stat_tooltip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_tooltip.png` | Live Escape stat tooltip |
| `ui_frame_hero_select_portrait` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_portrait.png` | Live Hero Select large portrait frame; SCRUM-321 accepted as production heroframe-style PNG and rendered as whole-image proportional `TextureRect` inside `HeroSelectPortraitFrame` (safe content margins `Vector4(128, 230, 128, 330)`, backup in `build/cleanup_backup_hero_select_portrait_2026_06_14/`) |
| `ui_frame_hero_select_dossier` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png` | Live Hero Select dossier frame; SCRUM-355 thin DescriptionHS recomposition, `1120x1140` RGBA, rendered as whole-image proportional `TextureRect` inside `HeroSelectDossierFrame` (base frame `387x394`; strict Design safe margins `Vector4(126, 160, 126, 172)`; backup in `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`; Back-end SCRUM-354 must integrate the new runtime margins) |
| `ui_frame_hero_select_unified_panel` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_unified_panel.png` | SCRUM-356 Design-ready unified portrait+description frame, `1536x1024` RGBA, generated through OpenAI Images/`fantasydisk-asset-generator` workflow and postprocessed to alpha. Intended to replace separate portrait+dossier runtime frames after Back-end integration; whole-image proportional scaling only. Content zones: portrait `[130,145,420,560]`, description `[610,145,786,500]`, bottom controls `[570,705,660,178]`; metadata in `docs/design/references/hero_select_unified_panel/scrum356_unified_panel_metadata.json` |
| `ui_frame_hero_select_radar` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png` | Live Hero Select floating stat radar frame; SCRUM-322 windrose compass frame, 1024x1024 RGBA, rendered as square whole-image proportional `TextureRect` (safe margins `Vector4(245, 245, 245, 235)`, backup in `build/cleanup_backup_hero_select_windrose_2026_06_14/`) |
| `ui_frame_hero_select_pixellab_parts` | `assets/sprites/ui/frames/hero_select_pixellab/` (`background.png`, `frame_title.png`, `button_back.png`, `frame_portrait.png`, `frame_dossier.png`, `frame_radar.png`, `frame_ascension.png`, `button_asc_minus.png`, `button_asc_plus.png`, `button_choose.png`, `frame_carousel.png`, `button_carousel_left.png`, `button_carousel_right.png`, `frame_hero_slot.png`) | SCRUM-687 live Hero Select PixelLab rebuild kit. Runtime scales the `2560x1440` source-space layout uniformly, keeps all labels/buttons/radar/portraits inside per-part content rects, uses framed carousel slots with child portrait textures, and preserves directional `512x512` PixelLab preview rotation for Berserk, Dark Mage, Guitarist and Doctor. |
| `hero_select_v2_mockup_spec` | `docs/design/mockups/scrum436_hero_select_v2/spec.md` | SCRUM-436 Design-ready Hero Select v2 rebuild package, not a runtime texture. OpenAI mockup, annotated safe-zones and `hero_select_v2_layout_metadata.json` preserve the existing live `HeroSelectRadarPanel` / `HeroStatRadar` while respecing hero preview, dossier/traits/weapons, ascension controls, Select/Back buttons, wide carousel and tooltip zones for 1280x720 / 1920x1080 / 2560x1440. Back-end must rebuild live Controls from this spec rather than displaying the mockup image. |
| `ui_frame_hero_select_thumbnail_strip` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png` | Live Hero Select bottom thumbnail strip frame; SCRUM-355 thin Carusel recomposition, `1536x255` RGBA, rendered as whole-image proportional `TextureRect` (no 9-slice/one-axis stretch; strict Design safe margins `Vector4(132, 62, 132, 62)`; backup in `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`; Back-end SCRUM-354 must integrate the new runtime margins) |
| `ui_frame_hero_select_thumbnail` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail.png` | Live Hero Select adaptive hero thumbnail button frame |
| `ui_frame_hero_select_asc_button` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button.png` | Live Hero Select ascension +/- frame |
| `ui_frame_hero_select_asc_button_small` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button_small.png` | SCRUM-356 Design-ready compact ascension +/- button frame, `256x256` RGBA, generated through OpenAI Images/`fantasydisk-asset-generator` workflow and postprocessed to alpha; use for both minus/plus signs with runtime glyph centered inside content margins `[76,74,76,76]` |
| `ui_frame_hero_select_asc_label` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_label.png` | Live Hero Select ascension level label frame |
| `ui_frame_hero_select_asc_mods` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_mods.png` | Live Hero Select ascension modifier line frame |
| `ui_frame_settings_tab_switcher` | `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` | Design-ready Settings tab switcher frame; SCRUM-325, `1280x256` RGBA, content-zone rects in `docs/tasks/backend_integrate_settings_tab_switcher_frame_task.md`; Back-end runtime integration SCRUM-334 |
| `ui_btn_red_gold_standard_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_standard.png` + hover/pressed/disabled | Standard 420x104 action buttons |
| `ui_btn_red_gold_max_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_max.png` + hover/pressed/disabled | Wide 560x104 action buttons |
| `ui_btn_red_gold_main_menu_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_main_menu.png` + hover/pressed/disabled | Main menu 380x104 buttons |
| `ui_btn_red_gold_hero_confirm_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_hero_confirm.png` + hover/pressed/disabled | Hero confirm 320x104 buttons |
| `ui_btn_red_gold_reset_audio_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_audio.png` + hover/pressed/disabled | Settings reset audio 420x104 buttons |
| `ui_btn_red_gold_reset_bindings_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_bindings.png` + hover/pressed/disabled | Settings reset bindings 440x104 buttons |
| `ui_btn_red_gold_codex_tab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_codex_tab.png` + hover/pressed/disabled | Historical Codex tab family; superseded in live runtime by FAN-1047 `text/main_menu_380x104` |
| `ui_btn_red_gold_back_s/m/l_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_back_s.png` / `back_m.png` / `back_l.png` + states | Navigation/back buttons by width |
| `ui_btn_red_gold_attr_selector_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_attr_selector.png` + hover/pressed/disabled | Attribute selector 560x104 buttons |
| `ui_btn_red_gold_fab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_fab.png` + hover/pressed/disabled | Upgrade FAB 50x50 |
| `ui_btn_red_gold_utility_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility.png` + hover/pressed/disabled | Compact utility 54x42 |
| `ui_btn_red_gold_pause_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause.png` + hover/pressed/disabled | Pause menu 280x60 |
| `ui_btn_red_gold_rebind_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_rebind.png` + hover/pressed/disabled | Keybinding/dropdown-style 420x62 controls |
| `main_menu_title_fantasy_disk` | `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` | SCRUM-680 release refresh main menu logo/title, `960x360` RGBA transparent. PixelLab textless crest source and manifest live in `docs/design/references/main_menu_logo_release_fix/`; generator `tools/build_main_menu_title_logo.py` renders exact `Fantasy Disk` text and runtime displays the asset as `MainMenuTitleLabel` at `Rect2(56,44,720,270)`. |
| `ui_df_button_primary/secondary/danger_*` | `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*` | Superseded SCRUM-147 parchment/wax buttons; retained only as legacy/reference fallback |
| `ui_df_panel_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png` | Superseded SCRUM-229 panel fallback/reference |
| `ui_df_shop_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_shop_frame.png` | Superseded merchant/shop frame fallback/reference |
| `ui_panel_leather_gold_square` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_square.png` | Superseded SCRUM-229 source square/card frame, removed from runtime assets |
| `ui_panel_leather_gold_wide` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_wide.png` | Superseded SCRUM-229 source wide panel/frame, removed from runtime assets |
| `ui_bar_leather_gold_thin` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_bar_leather_gold_thin.png` | Superseded SCRUM-229 source bar/label/divider frame, removed from runtime assets |
| `ui_window_leather_gold_main` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_window_leather_gold_main.png` | Superseded SCRUM-229 source large window panel, removed from runtime assets |
| `ui_check_leather_gold` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_check_leather_gold.png` | Superseded SCRUM-229 source checked state frame, removed from runtime assets |

Pipeline/preview: `tools/build_red_gold_button_kit.py` (SCRUM-273 buttons), `tools/build_ornate_ui_frame_kit.py` (SCRUM-274 panels), `tools/build_hero_select_frame_kit.py` (SCRUM-281 Hero Select frames), `tools/build_hero_select_windrose_frame.py` (SCRUM-322 radar), `tools/build_hero_select_dossier_frame.py` (SCRUM-323 dossier), `tools/build_hero_select_thin_frames.py` (SCRUM-355 dossier/carousel thinning), active previews `docs/design/previews/red_gold_button_kit_contact.png`, `docs/design/previews/ornate_dark_frame_kit_contact.png`, `docs/design/previews/hero_select_frame_kit_contact.png`, `docs/design/previews/hero_select_portrait_frame_content_zone.png`, `docs/design/previews/hero_select_windrose_radar_content_zone.png`, `docs/design/previews/hero_select_dossier_frame_content_zone.png`, `docs/design/previews/hero_select_thin_frames_content_zones.png` and `docs/design/previews/settings_tab_switcher_frame_content_zone.png`. Historical: `tools/apply_button_only_ui_revert.py` (SCRUM-147 buttons/legacy correction), `tools/build_leather_gold_ui_kit.py` (SCRUM-229 panels), `docs/design/previews/interface_leather_gold_panel_kit_contact.png`.

Системные иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_close`, `system_back`, `system_settings`, `system_arrow_left/right/up/down`, `system_checkbox_unchecked`, `system_checkbox_checked`, `system_slider_track`, `system_slider_grabber`. Файлы лежат в `assets/sprites/ui/icons/system/`.

Contextual UI direction 2026-06-12 is superseded by SCRUM-147. SCRUM-418 confirmed no live runtime references and removed the contextual frame PNGs from `assets/sprites/ui/frames/contextual/`; historical backup lives under `build/qa/scrum418/removed_assets_backup/`. New context decisions should use the SCRUM-147 dark fantasy role system instead.

| ID | Ассет | Роль | Статус |
| --- | --- | --- | --- |
| `ui_wild_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_wild_panel_frame.png`, `ui_wild_button_frame.png`, `ui_wild_card_frame.png`, `ui_wild_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_grave_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_grave_panel_frame.png`, `ui_grave_button_frame.png`, `ui_grave_card_frame.png`, `ui_grave_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_laurel_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_laurel_panel_frame.png`, `ui_laurel_button_frame.png`, `ui_laurel_card_frame.png`, `ui_laurel_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_parchment_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_parchment_panel_frame.png`, `ui_parchment_button_frame.png`, `ui_parchment_card_frame.png`, `ui_parchment_tooltip_frame.png`, `ui_parchment_tab_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |

## Фоны И Карты

| ID | Игровое имя | Ассет | Роль |
| --- | --- | --- | --- |
| `arena_2k_combat` | Боевая Арена 2K | Generated by `scripts/main.gd` | Прямоугольная арена 2560x1440 с камерой zoom 1.12 |
| `main_menu_epic_battle` | Эпичный бой стартового экрана | `build/qa/scrum418/removed_assets_backup/assets/backgrounds/main_menu_epic_battle.png` | Legacy фон главного меню, удален из runtime `assets/` SCRUM-418 и сохранен как QA backup вне shipping scope |
| `main_menu_epic_battle_v3` | Последний рубеж у Расколотого Диска | `assets/backgrounds/main_menu_epic_battle_v3.png` | Active FAN-2488 фон главного меню: цельная 2560x1440 mature cinematic dark-fantasy иллюстрация из OpenAI Images API (`gpt-image-2`, `quality=high`, явный выбор пользователя); три взрослых героя на разрушенном бастионе перед колоссальным костяным драконом под расколотым обсидиановым диском с фиолетовым rift, спокойная левая зона под title/6 runtime-кнопок и низкодетальная lower-right utility zone, без baked UI/text/logo/frame/cursor/watermark |
| `ui_backdrop_system_cathedral` | System/Codex/Settings backdrop | `assets/backgrounds/ui/ui_backdrop_system_cathedral.png` | Active for `system`, `settings`, `codex`, `hero_select`, `weapon_select`, `pause_stats`, `meta_tree`, `campfire` |
| `ui_backdrop_merchant_archive` | Shop backdrop | `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` | Active for `shop` |
| `ui_backdrop_arcane_lab` | Level-up/Magic/Meta backdrop | `assets/backgrounds/ui/ui_backdrop_arcane_lab.png` | Active for `event`, `upgrade`, `level_up`, `meta_progression` |
| `ui_backdrop_reward_hall` | Reward/Victory backdrop | `assets/backgrounds/ui/ui_backdrop_reward_hall.png` | Active for `elite_reward`, `victory`, `artifact_reward` |
| `ui_backdrop_defeat_crypt` | Defeat/Danger backdrop | `assets/backgrounds/ui/ui_backdrop_defeat_crypt.png` | Active for `death`, `defeat`, `end_run_confirm` |
| `route_map_backdrop` | Жутковатый фон маршрутной карты | `assets/backgrounds/route_map_backdrop.png` | Низкоконтрастный dark fantasy фон full-screen route map, спокойная центральная зона под узлы и линии |
| `stone_garden` | Каменный Сад | `assets/backgrounds/field_stone_garden.png` | SCRUM-369 realistic D&D/dark fantasy stone-garden arena, 2560x1440 |
| `marsh` | Топь | `assets/backgrounds/field_marsh.png` | SCRUM-369 realistic D&D/dark fantasy marsh arena, 2560x1440 |
| `dry_road` | Сухая Дорога | `assets/backgrounds/field_dry_road.png` | SCRUM-369 realistic D&D/dark fantasy dry-road arena, 2560x1440 |
| `meadow` | Луг | `assets/backgrounds/field_meadow.png` | SCRUM-369 realistic D&D/dark fantasy meadow arena, 2560x1440 |
| `ruined_courtyard` | Руинный Двор | `assets/backgrounds/field_ruined_courtyard.png` | SCRUM-369 realistic D&D/dark fantasy ruined-courtyard arena, 2560x1440 |
| `misty_marsh` | Туманная Топь | `assets/backgrounds/field_misty_marsh.png` | SCRUM-369 realistic D&D/dark fantasy misty-marsh arena, 2560x1440 |
| `dusty_badlands` | Пыльные Пустоши | `assets/backgrounds/field_dusty_badlands.png` | SCRUM-369 realistic D&D/dark fantasy dusty-badlands arena, 2560x1440 |
| `enchanted_meadow` | Зачарованный Луг | `assets/backgrounds/field_enchanted_meadow.png` | SCRUM-369 realistic D&D/dark fantasy enchanted-meadow arena, 2560x1440 |
| `ashen_rift` | Пепельный Разлом | `assets/backgrounds/field_ashen_rift.png` | SCRUM-369 realistic D&D/dark fantasy ashen-rift arena, 2560x1440 |
| `cursed_grove` | Проклятая Роща | `assets/backgrounds/field_cursed_grove.png` | SCRUM-369 realistic D&D/dark fantasy cursed-grove arena, 2560x1440 |

Все активные боевые фоны — нативные 2560x1440. SCRUM-369 (2026-06-14) заменил весь набор из 10 арен через `fantasydisk-asset-generator`: реалистичные top-down D&D/dark fantasy battlefield floors с приглушенной центральной игровой зоной, без tall blockers, UI/text/watermarks и без битых ссылок. Source references: `docs/design/references/backgrounds/`; QA previews: `docs/design/previews/arena_backgrounds_scrum369_contact.png`, `docs/design/previews/arena_backgrounds_scrum369_readability.png`.
`route_map_backdrop` добавлен 2026-06-11 как отдельный 2560x1440 фон для маршрутной карты: мрачная пустошь/туманное предгорье, детали вынесены к краям, центр приглушен для читаемости узлов.

## Препятствия

| ID | Игровое имя | Роль | Правило |
| --- | --- | --- | --- |
| `stone_column` | Каменная Колонна | Непроходимый объект | Отключено в текущей версии; может вернуться после редизайна |
| `pit` | Яма | Непроходимая зона | Отключено в текущей версии; collision layer не используется |
| `arena_wall` | Граница Арены | Ограничение карты | Не дает камере и объектам выходить за пределы 2560x1440 |

## Пикапы И Ресурсы

| ID | Игровое имя | Роль | Статус |
| --- | --- | --- | --- |
| `xp_pickup` | Осколок Опыта | Дает опыт | Реализовано; активный Sprite2D использует `assets/sprites/ui/hud/hud_xp.png` |
| `money_pickup` | Монета | Дает деньги | Реализовано; активный Sprite2D использует `assets/sprites/ui/hud/hud_money.png` |
| `meta_point` | Мета-искра | Награда за босса / метапрогрессия | Реализовано частично |

## Projectiles И VFX Assets

| ID | Игровое имя | Роль | Ассет | Статус |
| --- | --- | --- | --- | --- |
| `enemy_magic_projectile` | Магический снаряд монстра | Маленький заметный снаряд врагов/боссов | `assets/sprites/projectiles/enemy_projectile_magic_64.png` | Реализовано |
| `player_projectile_spark` | Искра игрока | Базовый снаряд игрока вместо Polygon2D placeholder | `assets/sprites/projectiles/player_projectile_spark_64.png` | Реализовано |

SCRUM-335 runtime VFX coverage: `enemy_magic_projectile` дополнительно использует существующие `assets/sprites/effects/beam_strip.png`, `impact_flash.png` и `impact_ring.png` как textured trail/impact feedback в `scripts/enemy_projectile.gd`; gameplay-параметры снаряда не менялись.

SCRUM-337 обновил сами projectile/VFX PNG как часть full attack VFX art pass: `enemy_projectile_magic_64.png` и `player_projectile_spark_64.png` остаются теми же canonical ID/path, но получили новый painterly D&D/dark-fantasy raster treatment с прозрачным фоном.

SCRUM-1066 supersedes the single player-spark runtime contract for canonical
weapons. `scripts/projectile_visual_registry.gd` consumes the accepted
SCRUM-1065 manifest through its export-safe normalized copy
`assets/data/projectile_visual_profiles.json`, keyed by canonical `weapon_id`, and validates all
20 mapped profiles before use. They resolve existing
`res://assets/sprites/projectiles/player/**` textures; the other 31 inventory
rows are intentionally non-projectile. `void_orb.png` and
`player_projectile_spark_64.png` are forbidden fallbacks for registered player
projectile weapons; the old scene remains only as a profile-driven legacy API.

SCRUM-1065 добавляет канонический PixelLab-first player-projectile pack вместо
универсального фиолетового orb. Полный machine-readable inventory находится в
`docs/design/references/SCRUM-1065_player_projectiles/manifest.json`: 17/17
классов, 51/51 selectable weapons, 20 flying/projectile-like visual profiles и
31 механически обоснованный `intentional_non_projectile`. Production PNG лежат
под `assets/sprites/projectiles/player/<character_id>/`; это Design handoff для
SCRUM-1066, поэтому runtime routing в этой задаче не менялся.

| Projectile visual ID | Weapon | Runtime asset |
| --- | --- | --- |
| `soldier_arquebus_round` | `soldier_rifle` | `assets/sprites/projectiles/player/soldier/soldier_arquebus_round.png` |
| `soldier_fuse_grenade` | `soldier_grenade` | `assets/sprites/projectiles/player/soldier/soldier_fuse_grenade.png` |
| `thief_ricochet_coin` | `thief_coin_pouch` | `assets/sprites/projectiles/player/thief/thief_ricochet_coin.png` |
| `thief_smoke_bomb` | `thief_smoke_bomb` | `assets/sprites/projectiles/player/thief/thief_smoke_bomb.png` |
| `elementalist_meteor` | `elementalist_meteor_core` | `assets/sprites/projectiles/player/elementalist/elementalist_meteor.png` |
| `sniper_shatter_round` | `sniper_shatter_rounds` | `assets/sprites/projectiles/player/sniper/sniper_shatter_round.png` |
| `engineer_sentry_round` | `engineer_sentry_wrench` | `assets/sprites/projectiles/player/engineer/engineer_sentry_round.png` |
| `dark_mage_mirror_page` | `dark_book` | `assets/sprites/projectiles/player/dark_mage/dark_mage_mirror_page.png` |
| `dark_mage_cursed_skull` | `cursed_skull` | `assets/sprites/projectiles/player/dark_mage/dark_mage_cursed_skull.png` |
| `dark_mage_chain_bolt` | `dark_wand` | `assets/sprites/projectiles/player/dark_mage/dark_mage_chain_bolt.png` |
| `assassin_void_chakram` | `chakrams` | `assets/sprites/projectiles/player/assassin/assassin_void_chakram.png` |
| `ranger_moon_bolt` | `moon_crossbow` | `assets/sprites/projectiles/player/ranger/ranger_moon_bolt.png` |
| `ranger_storm_arrow` | `storm_longbow` | `assets/sprites/projectiles/player/ranger/ranger_storm_arrow.png` |
| `doctor_restore_potion` | `restore_potion` | `assets/sprites/projectiles/player/doctor/doctor_restore_potion.png` |
| `doctor_plague_syringe` | `plague_syringe` | `assets/sprites/projectiles/player/doctor/doctor_plague_syringe.png` |
| `chemist_blast_powder` | `blast_powder` | `assets/sprites/projectiles/player/chemist/chemist_blast_powder.png` |
| `chemist_acid_flask` | `acid_flask` | `assets/sprites/projectiles/player/chemist/chemist_acid_flask.png` |
| `druid_briar_seed` | `briar_staff` | `assets/sprites/projectiles/player/druid/druid_briar_seed.png` |
| `druid_spectral_raven` | `raven_totem` | `assets/sprites/projectiles/player/druid/druid_spectral_raven.png` |
| `biologist_sample_dart` | `biologist_sample_injector` | `assets/sprites/projectiles/player/biologist/biologist_sample_dart.png` |

## Sprite QA Notes

Активные спрайты персонажей, стандартных монстров, элиток, боссов, оружия, projectiles, pickups, route icons и UI icons проходят quality-audit перед сдачей визуальных задач. После аудита 2026-06-10 у `assets/sprites/enemies/enemy_suicide_runner.png` удален лишний правый фрагмент текстуры; активные pickup/player projectile больше не используют Polygon2D-placeholder как видимый слой.

SCRUM-177 read-only sprite audit 2026-06-13: отчет `docs/design/reviews/sprite_visual_audit_2026_06.md`, contact sheets `docs/design/previews/audit_*.png`, inventory `docs/design/reviews/sprite_visual_audit_inventory_2026_06.*`. Вывод: активные персонажи/оружие/основные враги/артефакты/фоны в целом соответствуют D&D/dark-fantasy канону; отдельные 0.1.4 follow-up задачи заведены для placeholder/tint новых боссов и мини-элиток, polish VFX, унификации derived/shop UI icons и cleanup legacy placeholder sprites.

SCRUM-269 read-only asset/image cleanup audit 2026-06-14: отчет `docs/design/reviews/cleanup_assets_audit_2026_06.md`. Мертвого игрового арта не найдено: 51 `vfx_weapon_<weapon_id>.png`, 18 canonical weapon PNG, новые boss/mini-elite source sprites, marketing collateral и dynamic UI/icon/cutout families защищены от ложных cleanup-срабатываний. Реальный мусор ограничен orphan ` 2.png.import` sidecars после SCRUM-270; cleanup передан и выполнен отдельной Back-end задачей SCRUM-271.

## UI Иконки И HUD

Централизованный mapping: `scripts/ui_icon_registry.gd`.

| Группа | ID | Каноническая папка | Статус |
| --- | --- | --- | --- |
| Базовые характеристики | `strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership` | `assets/sprites/ui/icons/stats/` | Реализовано |
| Производные параметры | `damage`, `magic_damage`, `crit_chance`, `crit_damage_multiplier`, `attack_speed`, `dodge`, `move_speed`, `defense`, `absorb`, `health_point`, `summon_amount`, `regeneration`, `vampiric_amount`, `vampiric_chance`, `dot_damage`, `dot_speed`, `aoe_radius`, `knockback_power`, `ultimate_multiplier`, `pickup_radius` | `assets/sprites/ui/icons/derived/` | Реализовано; retired range/projectile-speed/buff axes остаются только legacy assets |
| HUD ресурсы | `hp`, `xp`, `money` | `assets/sprites/ui/hud/` | Реализовано |
| Кодекс: непрочитанное | `ui_badge_codex_unread` | `assets/sprites/ui/icons/codex/ui_badge_codex_unread.png` | Реализовано (FAN-1077) |

Escape stats menu, level-up reward cards и combat HUD должны брать иконки только через этот registry. Финальный PNG asset pack реализован; code-native fallback не является целевым визуальным состоянием.

## UI Frames / Escape Stats Visual Kit

Каноническая спецификация: `docs/design/escape_stats_visual_kit.md`.

| ID | Игровое имя | Ассет | Роль | Статус |
| --- | --- | --- | --- | --- |
| `ui_escape_panel_frame` | Рамка Escape меню | `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png` | Общий frame для `EscapeStatsPanelFrame` | Реализовано |
| `ui_escape_button_frame` | Рамка кнопки Escape меню | `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` | Кнопки `PauseControlButtons` | Реализовано |
| `ui_stat_basic_row_frame` | Рамка базовой характеристики | `assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png` | `BaseStatRow_<stat_id>` | Реализовано |
| `ui_stat_group_frame` | Рамка группы параметров | `assets/sprites/ui/frames/escape/ui_stat_group_frame.png` | `DerivedStatGroup_<group_id>` | Реализовано |
| `ui_stat_chip_frame` | Рамка stat chip | `assets/sprites/ui/frames/escape/ui_stat_chip_frame.png` | `DerivedStatChip_<stat_id>` | Реализовано |
| `ui_stat_tooltip_frame` | Рамка tooltip характеристик | `assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png` | Tooltip с описанием/формулой/влияниями | Реализовано |
| `ui_stat_section_divider` | Разделитель stat section | `assets/sprites/ui/frames/escape/ui_stat_section_divider.png` | Опциональный разделитель групп/заголовков | Реализовано |
| `ui_stat_value_state_swatches` | Цветовые состояния статов | `assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png` | Design reference для high/low/neutral/effective | Реализовано |
| `escape_stats_visual_kit_preview` | Preview Escape stats visual kit | `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` | Design reference, не runtime UI | Реализовано |

## Награды За Характеристики

| ID | Игровое имя | Эффект |
| --- | --- | --- |
| `strength_training` | Тренировка Силы | Сила +1 |
| `agility_training` | Тренировка Ловкости | Ловкость +1 |
| `intelligence_training` | Тренировка Интеллекта | Интеллект +1 |
| `perception_training` | Тренировка Восприятия | Восприятие +1 |
| `energy_training` | Тренировка Энергии | Энергия +1 |
| `knowledge_training` | Тренировка Знания | Знание +1 |
| `endurance_training` | Тренировка Выносливости | Выносливость +1 |
| `leadership_training` | Тренировка Лидерства | Лидерство +1 |

## Базовые Улучшения За Уровень

| ID | Игровое имя | Эффект |
| --- | --- | --- |
| `damage_up` | Усиление Урона | +15% damage |
| `attack_speed_up` | Ускорение Атак | +12% attack speed |
| `max_hp_up` | Запас Жизни | +18 max HP |
| `move_speed_up` | Легкий Шаг | +10% move speed |
| `aoe_radius_up` | Широкий Размах | +15% AoE и +8% range |
| `pickup_radius_up` | Магнит Добычи | +45 pickup radius |
| `defense_up` | Плотная Стойка | +8% defense |
| `magic_focus_up` | Фокус Силы | +14% magic/sound damage |
| `knockback_up` | Сильный Толчок | +18% knockback |

## Артефакты

SCRUM-960: универсальный пул переехал на **семьи с роллом редкости** (`rarity_scaling: true`;
контракт — `docs/design/systems/artifact_system_matrix.md` §1-2). Тир-канон: **т1 = обычный
(cost 30), т2 = редкий (55), т3 = эпический (95)**. Тир семьи роллится при выдаче
(`ProgressionData.materialize_family_offer`): reward/shop/события — нормализованные
`TIER_WEIGHTS` (≈0.64/0.29/0.08), элитка/сундук — с depth-весом глубины, босс — фиксированно т3.
Корень записи семьи = т1-база для legacy-читателей. Если артефакт переименовывается для UI,
его `id` должен остаться стабильным или миграция должна быть явно описана в задаче.

SCRUM-956 закрепляет player-facing naming без смены id: `red_whetstone` =
«Точильный камень», `field_kit` = «Полевой бинт», `magnetic_buckle` =
«Магнитный талисман», `fast_boots` = «Легкие сапоги», `hawk_lens` = «Линза
охоты». `quickstring` остаётся отдельным артефактом «Быстрая струна»;
«Масло темпа» — магазинный `shop_weapon_cooldown`, «Пыльный артефакт» —
магазинный `shop_artifact`. Отдельного `dusty_artifact` не существует.

### Универсальные семьи (28, rarity_scaling)

8 семей базовых статов (+2/+4/+7):

| ID | Имя | Стат |
| --- | --- | --- |
| `warrior_charm` | Оберег воина | Сила |
| `fox_boots` | Лисьи сапоги | Ловкость |
| `glass_orb` | Стеклянная сфера | Интеллект |
| `hawk_lens` | Линза охоты | Восприятие |
| `ember_core` | Тлеющее ядро | Энергия |
| `old_codex` | Ветхий кодекс | Знание |
| `stone_heart` | Каменное сердце | Выносливость |
| `banner_seed` | Семя знамени | Лидерство |

20 семей производных атрибутов (ключ эффекта = ключ level-up карточки). FAN-1038
убрал семьи мёртвых осей `battle_fan` / `ram_horn` / `falcon_feather`, а общий
cadence-контракт удалил отдельную selectable dot-speed семью `plague_metronome`
(follow-up FAN-1034):

| ID | Имя | Ключ эффекта | т1 / т2 / т3 |
| --- | --- | --- | --- |
| `splinter_gloves` | Перчатки осколков | `damage_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `quickstring` | Быстрая струна | `attack_speed_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `sturdy_amulet` | Крепкий амулет | `max_health_flat` | +15 / +25 / +40 |
| `fast_boots` | Легкие сапоги | `move_speed_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `magnetic_buckle` | Магнитный талисман | `pickup_radius_flat` | +35 / +55 / +90 |
| `iron_scale` | Железная чешуя | `defense_flat` | +0.10 / +0.18 / +0.30 |
| `arcane_prism` | Чародейская призма | `magic_damage_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `sharp_talisman` | Острый талисман | `crit_chance_flat` | +0.10 / +0.18 / +0.30 |
| `executioner_edge` | Грань палача | `crit_damage_flat` | +0.10 / +0.18 / +0.30 |
| `ghost_ribbon` | Лента призрака | `dodge_flat` | +0.10 / +0.18 / +0.30 |
| `wide_sigil` | Дальняя печать | `aoe_radius_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `venom_vial` | Флакон отравы | `dot_damage_flat` | +2 / +4 / +6 |
| `wide_halo` | Широкий нимб | `aoe_radius_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `war_banner` | Боевое знамя | `damage_multiplier` | ×1.10 / ×1.18 / ×1.30 |
| `summoners_bell` | Колокольчик призывателя | `summon_bonus` | +1.5 / +2.5 / +4 |
| `aegis_shard` | Осколок эгиды | `absorb_flat` | +3 / +5 / +8 |
| `troll_blood` | Кровь тролля | `regeneration_flat` | +1.0 / +1.6 / +2.6 |
| `leech_fang` | Клык Пиявки | `vampiric_amount_flat` + `vampiric_heal_per_second_cap` | +0.75 / +1.25 / +2.0 (оба ключа) |
| `thirsty_ruby` | Жаждущий рубин | `vampiric_chance_flat` | +0.10 / +0.18 / +0.30 |
| `overcharge_rune` | Руна перегрузки | `ultimate_flat` | +0.10 / +0.18 / +0.30 |

Иконки 15 новых семей и всех 85 классовых доставлены паком SCRUM-962
(`artifact_<id>.png`, 256×256 RGBA). `swift_ink` удалён (полный дубль семьи
`fast_boots`, поглощён ею — matrix §1.6), его иконка снята в SCRUM-961.

### Сохранённые универсалы (37, без изменений)

| ID | Имя | Роль | Тир |
| --- | --- | --- | --- |
| `red_whetstone` | Точильный камень | +3 Сила, +3 Ловкость | 1 |
| `star_compass` | Звёздный компас | +3 Восприятие, +3 Знание | 1 |
| `living_root` | Живой корень | +3 Выносливость, +3 Энергия | 1 |
| `captains_coin` | Монета капитана | +3 Лидерство, +3 Сила | 1 |
| `silver_coin` | Серебряная монета | +62% золота | 1 |
| `survival_manual` | Учебник выживания | +55% опыта | 1 |
| `heavy_totem` | Тяжёлый тотем | +62% max HP, −5% скорости движения | 2 |
| `cracked_shield` | Треснувший щит | +30% защиты, −6% скорости движения | 2 |
| `cursed_crown` | Проклятая корона | +75% урона, −18% max HP | 2 |
| `fragile_heart` | Хрупкое сердце | +62% скорости атаки, −10% защиты | 2 |
| `greedy_purse` | Жадный кошелек | +112% золота, враги +37% HP | 2 |
| `burning_shard` | Горящий осколок | +50% радиуса атак и зон, −20% лечения | 2 |
| `golden_route_mark` | Золотая метка пути | +37% опыта и +37% золота | 2 |
| `glass_edge` | Стеклянная кромка | +50% урона крита, −8 max HP | 2 |
| `sacrifice_seal` | Печать жертвы | +30% шанса крита, −22% max HP | 2 |
| `hungry_amulet` | Голодный амулет | +85% золота, −35% лечения | 2 |
| `berserk_totem` | Тотем берсерка | +60% урона, −20% скорости движения | 2 |
| `focus_lens` | Линза фокуса | +70% дальности, −25% радиуса атак и зон | 2 |
| `stone_hide` | Каменная шкура | +40% защиты, −25% скорости атаки | 2 |
| `echo_core` | Эхо Разлома | Каждый 5-й удар — эхо-взрыв 80% урона по области | 3 |
| `blood_pact` | Кровавый Рубеж | HP ниже 30% — +50% урона | 3 |
| `leech_heart` | Сердце Пиявки | Убийство возвращает 2% максимального HP | 3 |
| `thorn_pact` | Договор Шипов | Полученный урон отражается ×2 во врагов рядом | 3 |
| `phantom_step` | Призрачный Шаг | Уворот дает +40% скорости движения на 2с | 3 |
| `rift_key` | Ключ Разлома | +4 Восприятие, +4 Знание; реликвия тайной тропы финального разлома | 3 |

Плюс 12 триггерных (`field_kit`, `vital_siphon`, `powder_charge`, `bulwark_echo`, `duelist_spur`,
`guardian_bulwark`, `chain_spark`, `crit_impulse`, `breather_totem`, `counterwave_sigil`,
`soul_harvest` (т3), `second_wind`) — канон в таблице «Триггерные» ниже.

### Классовые артефакты (85 = 17 × 5, SCRUM-961)

Открываются на **Возвышении 5** своего класса (`requires_ascension: 5`, гейт
`is_reward_relevant` §1.4 матрицы — работает во всех сэмплерах: reward/shop/элитка/босс).
Другим классам не выпадают; единственное исключение — `stolen_crest` (§5): на текущий
забег добавляет в пул 2 случайных чужих классовых артефакта. Все — `class_affinity=[класс]`,
cost по тиру (т1 30 / т2 55 / т3 95), без `affinity_mods`. Легаси классовые (16 id:
`blood_sigil, jagged_blade, heavy_grip, war_belt, warriors_rage, void_ink, dark_crystal,
ash_page, skull_resonator, ink_candle, echo_pick, copper_string, broken_pick, loud_amp,
bass_cable, split_core`) удалены вместе с иконками (`swift_ink` поглощён `fast_boots` ещё
в SCRUM-960, его иконка удалена здесь же).

| ID | Имя | Класс | Т | Механика (кратко) |
| --- | --- | --- | --- | --- |
| `perfect_edge` | Идеальная грань | Ассасин | 2 | +15% шанс / +25% урон крита |
| `shadow_twin` | Теневой двойник | Ассасин | 3 | ⚡ крит: теневой росчерк добивает область (45%) |
| `venom_spool` | Ядовитая катушка | Ассасин | 2 | +2 тика яда струны, +5% уклонения |
| `evasion_shroud` | Покров уклонения | Ассасин | 2 | +8% уклонения, спидбуст после уворота |
| `return_arc_rune` | Руна обратной дуги | Ассасин | 3 | возврат чакрамов шире (+35%) и больнее (+30%) |
| `crimson_grip` | Багровая рукоять | Берсерк | 3 | melee-стаки ярости: до 5 × (+2% урона, +1.5% темпа) |
| `spectral_axe` | Призрачный топор | Берсерк | 2 | призрачный повтор взмаха (+25% followup) |
| `hammer_weight` | Вес молота | Берсерк | 2 | слэм шире (+12%), полновесно до 6 целей |
| `blood_roar` | Кровавый рык | Берсерк | 2 | ⚡ удар по себе: 30% шанс волны отталкивания |
| `last_onslaught` | Последний натиск | Берсерк | 3 | ⚡ ниже 30% HP: +35% урона + щит-волна |
| `spore_capacitor` | Споровый конденсатор | Биолог | 2 | кольца линзы замедляют 25%; +10% магии |
| `sample_chain` | Цепь образцов | Биолог | 3 | дротик бьёт весь луч (70%), анализ шире |
| `symbiote_sheath` | Симбиотическая оболочка | Биолог | 2 | хит семени +35%, сеть +2 тика |
| `inhibitor_colony` | Колония торможения | Биолог | 2 | био-хиты: слоу 8%/стак, кап 3 |
| `split_analysis` | Расщепленный анализ | Биолог | 3 | первичная цель сплэшит 40% двум соседям |
| `lucky_coin` | Счастливая монета | Вор | 2 | +2 прыжка монеты, +1 краденое золото |
| `magnetic_purse` | Магнитный кошель | Вор | 2 | +90 радиуса подбора, +10% золота |
| `paralyzing_blade` | Парализующее лезвие | Вор | 3 | паралич-яд Кинжала дольше (+0.7с, кап 1.8с) |
| `smoke_cache` | Дымный тайник | Вор | 2 | завеса +40% дольше, +12% уклонения |
| `stolen_crest` | Украденный герб | Вор | 3 | 2 случайных чужих классовых в пул забега |
| `overdrive_pick` | Медиатор овердрайва | Гитарист | 3 | рифф-серия: +10% урона, +12% темпа |
| `bass_resonator` | Басовый резонатор | Гитарист | 2 | бас-аура +30%, +8% темпа |
| `stage_amplifier` | Сценический усилитель | Гитарист | 2 | ампы +2.5с жизни, кап до 4 |
| `feedback_loop` | Петля фидбэка | Гитарист | 3 | пульсы ампов: уязвимость 5%/стак, кап 3 |
| `rhythm_counter` | Счетчик ритма | Гитарист | 2 | каждый 4-й каст повторяется (55%) |
| `surgical_oath` | Хирургическая клятва | Доктор | 2 | +20% лечения, +2 drain-предела/с |
| `bonesaw_teeth` | Зубья костяной пилы | Доктор | 2 | пила +30% шире, +8% хила с урона |
| `plague_carrier` | Чумной носитель | Доктор | 3 | чума спредится со смертей (2.2с), +тики |
| `restorative_vapor` | Восстановительный пар | Доктор | 3 | паровая зона: жжёт и лечит через drain |
| `triage_protocol` | Протокол триажа | Доктор | 2 | ⚡ ниже 30% HP: следующий хил ×2.5, КД 12с |
| `spirit_pack_banner` | Знамя духовной стаи | Друид | 2 | +20% поддержки, духи +15% урона |
| `wolf_call` | Зов волков | Друид | 3 | +2 призыва; волки, melee-духи +20% |
| `blue_totem` | Голубой тотем | Друид | 2 | тотем +25% урона и чаще; +10% звука |
| `briar_seal` | Печать терновника | Друид | 2 | терновые зоны замедляют 20%; +тики |
| `pack_alpha` | Альфа стаи | Друид | 3 | +40 радиуса аур, +15% поддержки, +1.5 призыва |
| `turret_magazine` | Магазин турели | Инженер | 2 | турели живут по магазину 14+6 выстрелов |
| `drone_gyroscope` | Гироскоп дрона | Инженер | 2 | +1 цель дрона, устройства +12% темпа |
| `mine_satchel` | Минная сумка | Инженер | 3 | мины до срабатывания (кап 5), автоподрыв 6с |
| `field_blueprint` | Полевой чертеж | Инженер | 3 | за 6 LDR: +1 кап устройств, +2 выстрела, +12% жизни мин |
| `salvage_core` | Ядро утилизации | Инженер | 2 | отжившие устройства возвращают 35% КД |
| `impact_string` | Ударная тетива | Рейнджер | 2 | +35% отталкивания лука |
| `moon_splitter` | Лунный расщепитель | Рейнджер | 3 | болт ветвится в 4 цели (45%) |
| `storm_piercer` | Грозовой пробойник | Рейнджер | 2 | +2 пробития заряженным, +15% дальности |
| `root_snare` | Корневой капкан | Рейнджер | 3 | капканы вечны (кап 4): укоренение + кровотечение |
| `hunters_mark` | Метка охотника | Рейнджер | 2 | обездвиженные/отброшенные: +25% урона |
| `armor_protocol` | Бронепротокол | Робот | 2 | +5 поглощения, +8% защиты |
| `anchor_core` | Ядро якоря | Робот | 2 | якорь +25% шире, тяга рядовых +35% |
| `press_calibrator` | Калибратор пресса | Робот | 2 | коридор Пресса +30% шире |
| `reactor_chronometer` | Реакторный хронометр | Робот | 3 | плавная ротация вентов, +10% темпа |
| `repair_subroutine` | Ремонтная подпрограмма | Робот | 3 | ⚡ поглощённое копит заряд: +3 absorb на 5с |
| `rebound_plate` | Отбойная пластина | Рыцарь | 2 | +40% отталкивания |
| `triple_thrust` | Тройной укол | Рыцарь | 3 | копьё колет трижды (боковые 55% ±14°) |
| `tower_slam` | Башенный удар | Рыцарь | 2 | конус щита +20%, +20% отталкивания |
| `holy_chain` | Святая цепь | Рыцарь | 3 | спираль кистеня: +12%/каст, кап +36% |
| `vanguard_oath` | Авангардная клятва | Рыцарь | 2 | +5% защиты; в стойке ещё +10% |
| `prayer_beads` | Четки молитвы | Жрец | 2 | ⚡ старт боя: 6с +30% магии и лечения |
| `reliquary_salvo` | Реликварный залп | Жрец | 3 | без лечения: залпы чаще, взрыв +20% |
| `censer_vow` | Обет кадила | Жрец | 2 | пульс реже, но +45% шире и +35% больнее |
| `twin_bell` | Двойной колокол | Жрец | 3 | взрывы у цели и жреца (55%), дедуп |
| `martyr_shroud` | Покров мученика | Жрец | 2 | ⚡ ниже 30% HP: +12% защиты, +3 регена |
| `longshot_scope` | Дальнобойный прицел | Снайпер | 3 | +3% урона за 100px, кап +30% |
| `deadeye_round` | Патрон мертвого глаза | Снайпер | 3 | дальняя цель + терминальный взрыв 45% |
| `spotter_mark` | Метка наводчика | Снайпер | 2 | зона на 35% быстрее, +1 удар |
| `shatter_drum` | Барабан осколков | Снайпер | 2 | +2 осколка |
| `clean_line` | Чистая линия | Снайпер | 2 | +120 скорости снарядов, +12% дальности |
| `second_volley` | Второй залп | Солдат | 3 | 12% шанс дубля попадания (50%) |
| `arquebus_shrapnel` | Шрапнель аркебузы | Солдат | 2 | коридор +25%, соседям больше |
| `long_fuse` | Длинный фитиль | Солдат | 2 | фитиль +0.35с: взрыв +50%, радиус +10% |
| `bayonet_trigger` | Спуск штыка | Солдат | 2 | 35% шанс пули по линии (420, 70%) |
| `battle_doctrine` | Боевой устав | Солдат | 3 | дубли на пулях/гранатах/штыке, +6% шанс |
| `chain_wand` | Цепная палочка | Тёмный маг | 2 | первые 3 пробития лопаются (35%, r70) |
| `curse_font` | Купель проклятий | Тёмный маг | 2 | +3 DoT за тик, +0.35 тика/с |
| `mirror_page` | Зеркальная страница | Тёмный маг | 3 | взрыв книги зеркалится (55%) через мага |
| `void_hunger` | Голод пустоты | Тёмный маг | 3 | DoT спредится со смертей (2.5с) |
| `black_bargain` | Черная сделка | Тёмный маг | 2 | +4 DoT за тик, +тики; −15% max HP |
| `volatile_dust` | Летучая пыль | Химик | 2 | без облака: касты −22%, взрыв +25% |
| `acid_catalyst` | Кислотный катализатор | Химик | 3 | лужа вешает перманентные DoT-стаки (кап 5) |
| `clear_acid` | Прозрачная кислота | Химик | 1 | лужи прозрачнее с яркой кромкой, +25% жизни |
| `tank_homunculus` | Гомункул-танк | Химик | 3 | +60% HP гомункула + провокация; +25% силы |
| `reactor_homunculus` | Гомункул-реактор | Химик | 3 | неуязвимый реактор: волны DoT-стаков (кап 3) |
| `fourth_ring` | Четвертое кольцо | Элементалист | 3 | 4-я орбита «земля»: физика + DoT + отброс |
| `prismatic_cross` | Призматический крест | Элементалист | 3 | X-линии насквозь (дальняя часть 60%) |
| `meteor_heart` | Сердце метеора | Элементалист | 2 | реже (+45% КД), центр +70%, кратер-DoT |
| `mana_overflow` | Переполнение магии | Элементалист | 2 | +18% магии, +12% заряда ульты |
| `elemental_recoil` | Стихийный отдачник | Элементалист | 2 | области толкают от кастера; +15% отталкивания |

## Тиры Артефактов

Поле `tier` (1-3) есть у всех артефактов в `ProgressionData.ARTIFACTS`; канон имён:
**обычный / редкий / эпический** (UI-лейблы приводит SCRUM-963). У семей корневой
`tier: 1` — фактический тир оффера роллится при выдаче (см. выше). `class_affinity`
задает классовую привязку (пустой список = универсальный).

### Триггерные (активные) артефакты — под-класс `active` (SCRUM-500)

Новый под-класс предметов: запись несёт `active: true` + поле `trigger` (семантика игрового
события) + эффект-флаг в `mods`. Это контент-слой поверх `run_modifiers` — «специи», а не новый
DPS-множитель (survivability/DPS-гейты не сдвигаются). Пометка «⚡ Активный» вшита в `description`
(data-driven, карточка `ui_screens.gd` не правилась). Автоподхват в `reward_pool`/`shop_items`/
`elite_artifact_choices` фактом добавления в `ARTIFACTS`. Иконки — placeholder-копии существующих
(см. follow-up на бэспоук-арт через `fantasydisk-item-icon-generator`).

| ID | Игровое имя | Триггер | Эффект | Тир |
| --- | --- | --- | --- | --- |
| `guardian_bulwark` | Рубеж Стража | `on_low_hp` | Впервые ниже 30% HP: нокбэк-волна + 1.5с неуязвимости (кд 18с) | 2 |
| `chain_spark` | Цепная Искра | `on_kill` | 14% шанс взрыва по области у трупа (70% урона) | 2 |
| `crit_impulse` | Импульс Крита | `on_crit` | Крит → +35% скорости движения на 1.8с | 2 |
| `breather_totem` | Передышка | `on_room_clear` | Победа в бою → лечит 8% max HP | 2 |
| `counterwave_sigil` | Контр-волна | `on_take_hit` | 22% шанс отталкивающей волны (90% полученного урона, кд 3с) | 2 |
| `soul_harvest` | Сбор Душ | `on_kill` | Каждое 6-е убийство лечит 3% max HP (стак сбрасывается между боями) | 3 |
| `second_wind` | Второе Дыхание | `on_low_hp` | Пока HP ниже 30% — +5 к регенерации | 2 |

Runtime-анкеры: `on_take_hit`/`on_low_hp` → `player.take_damage` (+`_trigger_take_hit_pulse`/
`_trigger_lowhp_guard`); `on_crit` → `player.on_weapon_hit(enemy, dmg, was_crit)` →
`_trigger_crit_speed_burst`; `on_kill` → `combat_director._on_enemy_died` → `player.on_enemy_killed`;
`on_room_clear` → `combat_director._end_combat(victory)` ветка победы (до снапшота).

## Возвышения (Усложнения)

Глобальные кумулятивные модификаторы сложности (`ProgressionData.ASCENSION_MODIFIERS`). Уровень N включает 1..N. Уровень 0 = обычная игра. Прогресс/разблокировка — по персонажу (`meta_progression.gd`): победа над финальным боссом на уровне N открывает N+1.

| ID | Уровень | Имя | Эффект |
| --- | --- | --- | --- |
| `asc_hardened_foes` | 1 | Закалённые враги | Монстры +15% HP, +10% урона |
| `asc_greedy_merchants` | 2 | Жадные торговцы | Все цены +25% |
| `asc_swift_horde` | 3 | Быстрая орда | Спавн чаще, плотность +20% |
| `asc_fierce_elites` | 4 | Свирепые элитки | Элитки +20% HP, боевая фаза сразу |
| `asc_scarce_spoils` | 5 | Скудные трофеи | Золото/опыт −20% |
| `asc_thinned_flesh` | 6 | Истончённая плоть | Всё лечение −30% |
| `asc_abyssal_echo` | 7 | Эхо бездны | Шанс мини-элитки в обычной волне |
| `asc_long_watch` | 8 | Длинная вахта | Таймер боя +25% |
| `asc_warden_wrath` | 9 | Гнев стража | Босс +1 фаза, +20% HP, короче телеграфы |
| `asc_edge_of_madness` | 10 | Грань безумия | Игрок −20% макс HP, усиленная стартовая волна |

Наградный трек меты (бывшие `ASCENSION_LEVELS`, теперь per-class баффы за пройденные уровни): применяются на старте забега постоянно; мета-экран после босса — заглушка с рабочим хуком.

## Магазинные Предметы

| ID | Игровое имя | Эффект |
| --- | --- | --- |
| `shop_damage` | Точильный камень | +10% damage |
| `shop_heal` | Полевой бинт | Восстановить 35% max HP |
| `shop_pickup` | Магнитный талисман | +35 pickup radius |
| `shop_speed` | Легкие сапоги | +8% move speed |
| `shop_weapon_cooldown` | Масло темпа | +10% attack speed |
| `shop_range` | Линза охоты | +12% attack range |
| `shop_artifact` | Пыльный артефакт | +1 Восприятие |

## SCRUM-478 Bright Minimalist UI Source Package

This is a Design-source package, not live runtime content yet.

| Группа | ID / naming | Каноническая папка / файл | Статус |
| --- | --- | --- | --- |
| Bright minimalist button anchor | `scrum478_bright_minimal_button_anchor_sheet_transparent` | `docs/design/references/minimalist_full_ui_redesign/scrum478_bright_minimal_button_anchor_sheet_transparent.png` | Design-source review |
| Exact-size frame source | `scrum478_exact_size_frame_source_sheet_transparent` | `docs/design/references/minimalist_full_ui_redesign/scrum478_exact_size_frame_source_sheet_transparent.png` | Design-source review |
| Full-screen mockup board | `scrum478_full_screen_mockup_board` | `docs/design/references/minimalist_full_ui_redesign/scrum478_full_screen_mockup_board.png` | Design-source review |
| Exact-size metadata | `scrum478_minimalist_full_ui_metadata` | `docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json` | Source of truth for 1280/1600/1920 content zones |
| UI-director spec | `scrum478_minimalist_full_ui_spec` | `docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md` | Design-source review |

Runtime asset IDs/paths must be assigned by the Back-end handoff after slicing
or importing final exact-size PNGs. Until then, existing live UI registries stay
authoritative for runtime.

## SCRUM-666 Combat HUD 2K Source Package

This is a Design-source package for a future clean combat HUD integration, not
live runtime content yet.

| Group | ID / naming | Canonical folder / file | Status |
| --- | --- | --- | --- |
| Combat HUD 2K spec | `scrum666_combat_hud_2k_spec` | `docs/design/mockups/scrum666_combat_hud_2k/spec.md` | Design-source review |
| Combat HUD 2K plan | `scrum666_combat_hud_2k_ui_plan` | `docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json` | Authoritative QA-red revised geometry: content zones inside generated dark interiors |
| Combat HUD 2K layout | `scrum666_combat_hud_2k_layout` | `docs/design/mockups/scrum666_combat_hud_2k/layout.json` | Authoritative content zones; level plus/count zones separated |
| Combat HUD 2K visual audit | `scrum666_combat_hud_2k_visual_frame_zone_audit` | `docs/design/mockups/scrum666_combat_hud_2k/visual_frame_zone_audit.md` | Human QA-red note for clean interior placement |
| Combat HUD 2K OpenAI mockup | `scrum666_combat_hud_2k_mockup_base` | `docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png` | Visual source only |
| Combat HUD 2K safe-zone previews | `scrum666_combat_hud_2k_previews` | `docs/design/previews/scrum666_combat_hud_2k_*` | QA evidence; accepted overlay demonstrates zones avoid rails/ornament |

Runtime asset IDs/paths must be assigned by a Back-end integration task after
slot-exact slicing or redraw. Until then, existing live combat HUD registries
remain authoritative.

## Иконки Артефактов, Shop UI И Курсор

Каноническая спецификация и полный mapping `artifact_id -> icon_path`, `shop_item_id -> icon_path`: `docs/design/artifact_shop_cursor_visual_kit.md`.

| Группа | ID / naming | Каноническая папка / файл | Статус |
| --- | --- | --- | --- |
| Artifact icons | `artifact_<artifact_id>.png` для всех `ProgressionData.ARTIFACTS`; 71 шт., 256x256 RGBA, transparent realistic epic D&D/tabletop fantasy raster magic items; QA preview `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`, SCRUM-606/609 contact `docs/design/previews/artifact_icons_606_609_contact.png` | `assets/sprites/ui/icons/artifacts/` | Реализовано (realistic D&D raster redraw 2026-06-12; SCRUM-606/609 icon integration 2026-06-28; `rift_key` documented SCRUM-844) |
| Shop-only item icons | `shop_<shop_item_id>.png` для всех `ProgressionData.SHOP_ITEMS` | `assets/sprites/ui/icons/shop/` | Реализовано |
| Shop slot normal | `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` | Реализовано |
| Shop slot hover | `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` | Реализовано |
| Shop price badge | `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` | Реализовано |
| Shop purchased/unavailable overlay | `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` | Реализовано |
| Shop tooltip frame | `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` | Реализовано |
| Game cursor | `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |
| Game cursor hover | `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |
| Game cursor attack | `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |

Shop-only icons имеют прозрачный фон, размер `128x128`, stylized fantasy cartoon style и не используют текст/emoji/default placeholders. Artifact icons находятся в realistic D&D raster redraw pass 2026-06-12: каждый активный артефакт — отдельная законченная painted magic item-картинка без фона, пьедестала, текста и мусора, с технической проверкой размера, alpha, bbox и 40px-читаемости. Shop item filenames намеренно следуют схеме `shop_<shop_item_id>.png`, поэтому для `shop_damage` путь выглядит как `assets/sprites/ui/icons/shop/shop_shop_damage.png`. Фактические PNG и `.import` файлы готовы в текущем checkout; backend hooks могут подхватывать эти файлы вместо fallback.

## Уровни Возвышения (Метапрогрессия)

Уровень возвышения персонажа растет на 1 за каждую победу над финальным боссом этим персонажем (максимум 10). Бонусы кумулятивны: уровень N включает все бонусы уровней 1..N. Данные: `scripts/progression_data.gd::ASCENSION_LEVELS`, сохранение: `scripts/meta_progression.gd` (`user://fantasydisk_meta.cfg`).

| ID | Персонаж | Уровень | Игровое имя | Бонус уровня |
| --- | --- | --- | --- | --- |
| `berserk_asc_1` | Берсерк | 1 | Кровавая закалка | +5% damage |
| `berserk_asc_2` | Берсерк | 2 | Шкура зверя | +8 max HP |
| `berserk_asc_3` | Берсерк | 3 | Боевой ритм | +4% attack speed |
| `berserk_asc_4` | Берсерк | 4 | Железная воля | +2% defense |
| `berserk_asc_5` | Берсерк | 5 | Ярость предков | +7% damage |
| `berserk_asc_6` | Берсерк | 6 | Несокрушимость | +12 max HP |
| `berserk_asc_7` | Берсерк | 7 | Хищный глаз | +3% crit chance |
| `berserk_asc_8` | Берсерк | 8 | Вихрь стали | +5% attack speed |
| `berserk_asc_9` | Берсерк | 9 | Каменная кожа | +3% defense |
| `berserk_asc_10` | Берсерк | 10 | Аватар войны | +10% damage, +14 max HP |
| `dark_mage_asc_1` | Темный маг | 1 | Темный фокус | +5% damage |
| `dark_mage_asc_2` | Темный маг | 2 | Пелена пустоты | +6 max HP |
| `dark_mage_asc_3` | Темный маг | 3 | Расширение разлома | +5% AoE radius |
| `dark_mage_asc_4` | Темный маг | 4 | Скороговорка заклятий | +4% attack speed |
| `dark_mage_asc_5` | Темный маг | 5 | Глубинная магия | +7% damage |
| `dark_mage_asc_6` | Темный маг | 6 | Щит из тени | +3% defense |
| `dark_mage_asc_7` | Темный маг | 7 | Дальний взор | +6% attack range |
| `dark_mage_asc_8` | Темный маг | 8 | Резонанс проклятий | +6% AoE radius |
| `dark_mage_asc_9` | Темный маг | 9 | Жизнь из праха | +10 max HP |
| `dark_mage_asc_10` | Темный маг | 10 | Владыка разлома | +10% damage, +6% AoE radius |
| `guitarist_asc_1` | Гитарист | 1 | Чистый звук | +5% damage |
| `guitarist_asc_2` | Гитарист | 2 | Сценическая выдержка | +7 max HP |
| `guitarist_asc_3` | Гитарист | 3 | Широкий резонанс | +5% AoE radius |
| `guitarist_asc_4` | Гитарист | 4 | Быстрый перебор | +4% attack speed |
| `guitarist_asc_5` | Гитарист | 5 | Мощный рифф | +7% damage |
| `guitarist_asc_6` | Гитарист | 6 | Ударная волна | +8% knockback |
| `guitarist_asc_7` | Гитарист | 7 | Лёгкая походка | +4% move speed |
| `guitarist_asc_8` | Гитарист | 8 | Глубокий бас | +6% AoE radius |
| `guitarist_asc_9` | Гитарист | 9 | Кураж толпы | +11 max HP |
| `guitarist_asc_10` | Гитарист | 10 | Легенда сцены | +10% damage, +10% knockback |

## Звуковые Ассеты

Бардовский пак SCRUM-966/967, интеграция SCRUM-968 (`scripts/audio_manager.gd`:
`SFX_PATHS`/`MUSIC_META`). Slot-id экранов: `menu`/`route_map`/`shop` — алиасы
на треки ниже; бой — `play_combat_music(kind, duration)`.

| ID | Файл | Использование |
| --- | --- | --- |
| `hit` | `assets/audio/sfx/sfx_hit.ogg` | Попадание по врагу (physical/true) |
| `hit_magic` | `assets/audio/sfx/sfx_hit_magic.ogg` | Попадание магией (`damage_type == "magic"`) |
| `hit_dot` | `assets/audio/sfx/sfx_hit_dot.ogg` | Тик DoT (`damage_type == "dot"`) |
| `player_hit` | `assets/audio/sfx/sfx_player_hit.ogg` | Урон по игроку |
| `dodge` | `assets/audio/sfx/sfx_dodge.ogg` | Уворот игрока |
| `pickup_xp` | `assets/audio/sfx/sfx_pickup_xp.ogg` | Подбор опыта |
| `pickup_money` | `assets/audio/sfx/sfx_pickup_money.ogg` | Подбор денег |
| `level_up` | `assets/audio/sfx/sfx_level_up.ogg` | Получение уровня |
| `purchase` | `assets/audio/sfx/sfx_purchase.ogg` | Успешная покупка (вызовы — ui_screens-хвост SCRUM-968) |
| `ui_click` | `assets/audio/sfx/sfx_ui_click.ogg` | Подтверждение кнопки (ui_screens-хвост) |
| `ui_back` | `assets/audio/sfx/sfx_ui_back.ogg` | Назад/отмена (ui_screens-хвост) |
| `ui_error` | `assets/audio/sfx/sfx_ui_error.ogg` | Отказ действия (ui_screens-хвост) |
| `artifact_reveal` | `assets/audio/sfx/sfx_artifact_reveal.ogg` | Показ артефакт-награды (ui_screens-хвост) |
| `boss_phase` | `assets/audio/sfx/sfx_boss_phase.ogg` | Смена фазы босса (boss.gd) |
| `low_hp_pulse` | `assets/audio/sfx/sfx_low_hp_pulse.ogg` | Луп при HP<30% (`set_sfx_loop`, player.gd) |
| `music_menu_tavern_warm` | `assets/audio/music/music_menu_tavern_warm.ogg` | Меню и мета-экраны (alias `menu`) |
| `music_route_map_bard_journey` | `assets/audio/music/music_route_map_bard_journey.ogg` | Карта маршрута (alias `route_map`) |
| `music_shop_campfire_inn` | `assets/audio/music/music_shop_campfire_inn.ogg` | Safe-узлы: магазин/костёр/событие/сундук (alias `shop`) |
| `music_combat_bardic_skirmish_a` | `assets/audio/music/music_combat_bardic_skirmish_a.ogg` | Обычный бой, ротация №1 |
| `music_combat_bardic_skirmish_b` | `assets/audio/music/music_combat_bardic_skirmish_b.ogg` | Обычный бой, ротация №2 |
| `music_combat_ruined_courtyard` | `assets/audio/music/music_combat_ruined_courtyard.ogg` | Обычный бой, ротация №3 (акт 2 приоритет) |
| `music_combat_fey_marsh` | `assets/audio/music/music_combat_fey_marsh.ogg` | Обычный бой, ротация №4 (без актового приоритета) |
| `music_elite_duel_300` | `assets/audio/music/music_elite_duel_300.ogg` | Элитный бой (300 c) |
| `music_boss_battle_300` | `assets/audio/music/music_boss_battle_300.ogg` | Промежуточный босс акта 1 (300 c) |
| `music_final_boss_crescendo_300` | `assets/audio/music/music_final_boss_crescendo_300.ogg` | Финальный босс акта 2 / секретный босс (300 c) |
| `music_sting_victory` | `assets/audio/music/music_sting_victory.ogg` | Стингер победы обычного боя |
| `music_sting_victory_epic` | `assets/audio/music/music_sting_victory_epic.ogg` | Стингер победы над элиткой/боссом |
| `music_sting_defeat` | `assets/audio/music/music_sting_defeat.ogg` | Стингер поражения |

## Правила Для Новых Сущностей

- Новый монстр получает `id`, игровое имя, архетип, сцену, спрайт, поведение, награды и место в spawn pool.
- Новый босс получает `id`, игровое имя, сцену, иконку карты, минимум 3 уникальных паттерна, награды и правила выбора.
- Новый артефакт получает `id`, игровое имя, описание эффекта, цену/редкость, ограничения по классу и список модификаторов.
- Новый узел карты получает `id`, игровое имя, иконку, tooltip, правила входа/выхода и награды.
- Новый фон получает `id`, игровое имя, ассет, список подходящих типов узлов и fallback.
- Новое оружие получает `id`, игровое имя, класс, форму атаки, параметры урона, сцену, ассет и описание геймплейной роли.

Если новая сущность участвует в случайном выборе, ее нужно добавить в этот реестр в той же задаче.

## SCRUM-541 Secret Boss Registry Addendum

| ID | Game name | Current scene | Role | Asset | Patterns | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `secret_ascension_boss` | Secret Ascension Boss | `scenes/BossSecretAscension.tscn` | Post-final-Act-2 max-Ascension capstone boss | SCRUM-539 Design source pack: `assets/sprites/bosses/secret_ascension_boss.png`, `assets/sprites/effects/secret_ascension_boss_*_telegraph.png` | `SecretBossSectorRing`, delayed `BossRiftZone` eruptions, phase-2 adds/pressure at 50% HP, phase 3 below 25% HP | Backend implemented; final animation/runtime wiring pending |

## SCRUM-723 Scene/Resource Reference Integrity Audit (0.2.0)

Reference-integrity sweep of scenes, `.tres` resources and project config — no asset
deletions, no canonical reference changes. Findings (all CLEAN as of the sweep):

- **0 broken `res://` references** across all tracked `.tscn`/`.tres`/`.godot`/`.cfg`
  (1510 literal refs checked offline; in-engine gate re-checks 1746 unique refs over
  184 files).
- **0 orphan sidecars** — no tracked `.import`/`.uid` whose base file is missing; all
  2561 media files under `assets/` have a tracked `.import`. The 427 images without
  `.import` are all `docs/design/**` backups/references + 2 `build/qa/**` artifacts —
  outside the `res://` import pipeline, correctly un-imported.
- **No duplicate `class_name`** declarations across `scripts/` + `tests/` (guards the
  ` 2`-suffix global-class collision class, SCRUM-440).
- **Version consistent** — `project.godot config/version` and every
  `export_presets.cfg` version field are `0.2.0`; no export-preset drift.
- **Gate strengthened:** `tests/asset_reference_integrity_test.gd` now also scans
  `.tres` under `assets/` (previously scripts/ + scenes/ only), so a broken
  SpriteFrames→texture `ext_resource path` fails the gate instead of rendering blank.

## SCRUM-810 Input Glyphs (Gamepad + Keyboard) — 0.2.0

Пиксель-арт глифы ввода для UI-подсказок пакета полной поддержки геймпада
(подсказки «какая кнопка за что», ребинд в настройках, контекстные хинты).

**Метод генерации:** программная (PIL, `scratchpad/gen_glyphs.py` — не в репо),
НЕ PixelLab MCP. Обоснование: глифы ввода — геометрические UI-примитивы с
точными буквами/стрелками (A/B/X/Y, ESC, WASD, направления), а канон PixelLab —
«no text» (нечитаемый текст на 64px, запекаемый фон — частый QA-FAIL). PIL даёт
гарантированно прозрачный фон (углы alpha=0), читаемые на 32px буквы, единый
стиль и не грузит перегруженный Godot-флот / PixelLab-биллинг. Стиль кита выдержан:
тёмная кожаная основа + светлый латунный контур; лицевые кнопки — узнаваемая
generic Xbox-раскладка (A зелёная / B красная / X синяя / Y жёлтая).

**Размеры:** два нативных — `32×32` и `64×64` (каждый растеризован под свой
масштаб, не даунскейл). `size` в аксессорах реестра выбирает ближайший.

**Пути:** `assets/sprites/ui/input_glyphs/<name>_<32|64>.png` (+ парный `.import`).

**Реестр:** `scripts/ui/input_glyph_registry.gd` — `ALL_GLYPHS`, словари
`JOY_BUTTON_TO_GLYPH` / `JOY_AXIS_TO_GLYPH` / `KEY_TO_GLYPH`; API (все null-safe):
`path_for`, `has_glyph`, `texture_for`, `texture_for_joy_button(idx,size)`,
`texture_for_axis(axis,size)`, `texture_for_key(name,size)`. Экраны НЕ трогает —
интеграцию делают UI-задачи пакета.

**Гейт:** `tests/input_glyph_assets_test.gd` (существование ресурсов, загрузка
текстур, размер PNG, прозрачность углов, покрытие JOY_BUTTON/JOY_AXIS/клавиш,
null-safety). Контакт-лист QA: `build/qa/scrum810/glyphs_contact_sheet.png`.

| Группа | Глифы (name) | Маппинг |
| --- | --- | --- |
| Лицевые | `btn_a` `btn_b` `btn_x` `btn_y` | JOY_BUTTON_A/B/X/Y |
| D-pad | `dpad` `dpad_up` `dpad_down` `dpad_left` `dpad_right` | JOY_BUTTON_DPAD_UP..RIGHT (11-14) |
| Плечи/курки | `lb` `rb` `lt` `rt` | LEFT/RIGHT_SHOULDER; JOY_AXIS_TRIGGER_LEFT/RIGHT |
| Меню | `start` `select` | JOY_BUTTON_START / JOY_BUTTON_BACK |
| Стики | `stick_l` `stick_r` `stick_l_press` `stick_r_press` `stick_move` | LEFT/RIGHT_STICK (нажатие); оси LEFT_*→stick_move, RIGHT_*→stick_r |
| Клавиатура | `key_generic` `key_esc` `key_enter` `key_space` `key_wasd` `key_arrows` | KEY_TO_GLYPH |

`docs/design/systems/input_controls.md` на момент SCRUM-810 не создан (core-задача
пакета); при его появлении сослаться на этот блок и реестр.
