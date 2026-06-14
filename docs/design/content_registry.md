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
| `berserk` | Берсерк | Ближний бой, физический урон, конусы и AoE | `scripts/progression_data.gd` | `assets/sprites/characters/berserk_unarmed.png`, `assets/sprites/characters/cutout/berserk_*.png` | Реализовано |
| `soldier` | Солдат | Тактический физический класс: залпы, гранаты и удержание линии | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/soldier.png`, `assets/sprites/characters/cutout/soldier_*.png` | Реализовано |
| `thief` | Вор | Уловки, рикошет монет, backstab и дымовое уклонение | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/thief.png`, `assets/sprites/characters/cutout/thief_*.png` | Реализовано |
| `elementalist` | Элементалист | Стихийный AoE-контроль: орбиты, призмы и метеорные осколки | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/elementalist.png`, `assets/sprites/characters/cutout/elementalist_*.png` | Реализовано |
| `sniper` | Снайпер | Дальний точный класс: lockshot, kill-zone и split rounds | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/sniper.png`, `assets/sprites/characters/cutout/sniper_*.png` | Реализовано |
| `priest` | Священник | Священный sustain: sanctify, ward-пульсы и молитвенная цепь | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/priest.png`; `assets/sprites/characters/cutout/priest_*.png` | Реализовано |
| `biologist` | Биолог | Биореакции: spore bloom, sample analysis и symbiote web | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/biologist.png`; `assets/sprites/characters/cutout/biologist_*.png` | Реализовано |
| `robot` | Робот | Тяжелый tank-control: magnetic anchor, compression line и reactor vent | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/robot.png`; `assets/sprites/characters/cutout/robot_*.png` | Реализовано |
| `engineer` | Инженер | Механический summoner/support: sentry link, repair drone и pressure mines | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/engineer.png`; `assets/sprites/characters/cutout/engineer_*.png` | Реализовано |
| `dark_mage` | Темный маг | Магический урон, AoE, DoT, лучи | `scripts/progression_data.gd` | `assets/sprites/characters/dark_mage.png`, `assets/sprites/characters/cutout/dark_mage_*.png` | Реализовано |
| `guitarist` | Гитарист | Звуковые волны, импульсы, ауры, отталкивание | `scripts/progression_data.gd` | `assets/sprites/characters/guitarist.png`, `assets/sprites/characters/cutout/guitarist_*.png` | Реализовано |
| `assassin` | Ассасин | Возвращающиеся чакрамы, крит-мили, яд и рывки к цели на критах | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd` | `assets/sprites/characters/assassin.png`, `assets/sprites/characters/cutout/assassin_*.png` | Реализовано |
| `ranger` | Рейнджер | Дальний контроль через заряжаемые стойкой выстрелы, арбалет, ловушки | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/ranger.png`, `assets/sprites/characters/cutout/ranger_*.png` | Реализовано |
| `doctor` | Доктор | Выживание через drain/lifesteal-связи, чума и ближний sustain | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/doctor.png`, `assets/sprites/characters/cutout/doctor_*.png` | Реализовано |
| `chemist` | Химик | Газовые/кислотные DoT-зоны и combo explosions от разных облаков | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/chemist.png`, `assets/sprites/characters/cutout/chemist_*.png` | Реализовано |
| `knight` | Рыцарь | Танк и тяжелый контроль: копье/щит плюс block/counter | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/knight.png`, `assets/sprites/characters/cutout/knight_*.png` | Реализовано; v2 unarmed base без встроенного копья/щита |
| `druid` | Друид | Командуемые питомцы, природные зоны, тотемы; scaling от Лидерства | `scripts/progression_data.gd`, `scripts/summoner_weapon.gd`, `scripts/ally_minion.gd` | `assets/sprites/characters/druid.png`, `assets/sprites/characters/cutout/druid_*.png` | Реализовано |

## Расширенный Ростер 0.1.4 (Фундамент, 2026-06-11)

Спрайты всех шести прошли Design art-review (2026-06-11) и приняты как polished dark fantasy full-art (512x512, RGBA). Cutout rig-части нарезаны `tools/slice_rig_cutouts.py` и лежат в `assets/sprites/characters/cutout/` (torso, arm_l, arm_r, leg_l, leg_r для каждого). Манифест обновлён в `scripts/sliced_rig_manifest.gd`. Weapon art v2 pass 2026-06-12 устранил fallback-текстуры в сценах оружия, перерисовал три оружия Рыцаря и заменил `knight.png` на unarmed base sprite без встроенного копья/щита, чтобы все три варианта реально крепились через socket.

| ID | Имя | Архетип | 3 стартовых оружия | «Свой» урон |
| --- | --- | --- | --- | --- |
| `assassin` | Ассасин | Быстрый крит-мили | `chakrams`, `shadow_daggers`, `venom_wire` | damage |
| `ranger` | Рейнджер | Дальний точный | `moon_crossbow`, `storm_longbow`, `hunter_trap` | damage |
| `doctor` | Доктор | Выживание через урон | `restore_potion`, `plague_syringe`, `bone_saw` | magic_damage |
| `chemist` | Химик | AoE + DoT зоны | `blast_powder`, `acid_flask`, `homunculus_vial` | magic_damage |
| `knight` | Рыцарь | Танк/копье | `long_spear`, `tower_shield`, `holy_flail` | damage |
| `druid` | Друид | Призыватель | `summon_amulet`, `briar_staff`, `raven_totem` | sound_wave_damage |

Релевантность атрибутов расширена: strength -> berserk/assassin/ranger/knight; intelligence -> dark_mage/doctor/chemist; energy -> dark_mage/guitarist/doctor/chemist/druid. Вознесение: по 10 уровней на каждый новый класс (ID `<класс>_asc_1..10`, тематические имена в ASCENSION_LEVELS).

Канонические character PNG для новых классов: `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). Канонические weapon PNG для новых 18 вариантов: `chakrams.png`, `shadow_daggers.png`, `venom_wire.png`, `moon_crossbow.png`, `storm_longbow.png`, `hunter_trap.png`, `restore_potion.png`, `plague_syringe.png`, `bone_saw.png`, `blast_powder.png`, `acid_flask.png`, `homunculus_vial.png`, `long_spear.png`, `tower_shield.png`, `holy_flail.png`, `summon_amulet.png`, `briar_staff.png`, `raven_totem.png` (`256x256`, transparent). Первые 9 weapon PNG для Berserk/Dark Mage/Guitarist остаются активными по существующим путям.

## Анимации И Rig-Профили

Канонический контроллер cutout-анимации: `scripts/cutout_rig_2d.gd`.

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
| `directional_pose` | Motion layer | Игрок, враги, элитки, боссы | Head/full-art offset для движения вверх, вниз и вбок | Реализовано |
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

Иконки артефактов: `assets/sprites/ui/icons/artifacts/artifact_*.png` (53 шт., 256x256). Финальный Design pass 2026-06-12: все активные артефакты заменены на realistic epic D&D/tabletop fantasy raster magic items с прозрачным фоном. Это не пентаграммы, не плоские UI-symbols и не векторные пиктограммы: каждый файл содержит отдельный нарисованный предмет с объемом, материалами, магическим светом и смысловой привязкой к `ProgressionData.ARTIFACTS`. Пайплайн вырезки из raster source sheets: `tools/extract_realistic_dnd_artifact_icons.py`; QA preview: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`. Предыдущие пассы (flat v1, dark fantasy v2, glossy RPG v3, concept-sheet tile/cut pass, per-item pictogram pass) superseded.

Таймер боя: `assets/sprites/ui/hud/timer_frame.png` и `assets/sprites/ui/hud/timer_frame_alarm.png` (оба 300x90, прозрачный фон) — фэнтези-рамка под цифры (золотая окантовка, темная ниша, самоцветы по бокам, гребень сверху). Для тревоги Back-end просто меняет текстуру на `timer_frame_alarm.png` (красное свечение и красные самоцветы) — программная подсветка не нужна. Генерируются тем же инструментом.

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
| `sword` | Двуручный меч | Берсерк | Усеченный замах 90 градусов, радиус 600, base width 150 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `axe` | Двуручный топор | Берсерк | Широкая дуга 140 градусов радиуса 320 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `hammer` | Двуручный молот | Берсерк | Круговой AoE: слабый старт, усиленный рост от апгрейдов | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `soldier_rifle` | Аркебуза строя | Солдат | Suppression burst: 3 коротких выстрела по линии; основная цель полный урон, соседи reduced damage | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierRifle.tscn` | Реализовано |
| `soldier_grenade` | Граната с фитилем | Солдат | Delayed ground explosion: телеграф, короткий фитиль, falloff урона к краю | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierGrenade.tscn` | Реализовано |
| `soldier_bayonet` | Штык-стойка | Солдат | Defensive brace corridor: каждый враг в стойке получает один укол и knockback | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierBayonet.tscn` | Реализовано |
| `thief_coin_pouch` | Кошель Рикошета | Вор | Coin ricochet: цепь по ближайшим целям с убывающим уроном и малой кражей золота | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefCoinPouch.tscn`, `assets/sprites/weapons/thief_coin_pouch.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_shadow_cloak` | Плащ Захода | Вор | Shadow backstab: мгновенный заход за ближайшую цель, усиленный удар и малый splash рядом | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefShadowCloak.tscn`, `assets/sprites/weapons/thief_shadow_cloak.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_smoke_bomb` | Дымовая Бомба | Вор | Smoke bomb: delayed AoE + временное уклонение Вора | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefSmokeBomb.tscn`, `assets/sprites/weapons/thief_smoke_bomb.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_orb_ring` | Кольцо Трех Стихий | Элементалист | Elemental orbit: короткая орбита стихийных сфер вокруг героя с тиками AoE-урона | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistOrbRing.tscn`, `assets/sprites/weapons/elementalist_orb_ring.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_prism_focus` | Призматический Фокус | Элементалист | Prism rift: два пересекающихся луча-разлома по ближайшей цели после короткого телеграфа | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistPrismFocus.tscn`, `assets/sprites/weapons/elementalist_prism_focus.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_meteor_core` | Ядро Метеора | Элементалист | Meteor shards: delayed impact в цель и вторичные осколочные взрывы рядом | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistMeteorCore.tscn`, `assets/sprites/weapons/elementalist_meteor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `sniper_deadeye_rifle` | Винтовка Мертвого Глаза | Снайпер | Sniper lockshot: короткий прицел/телеграф, затем точный дальний луч по locked target и line falloff | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperDeadeyeRifle.tscn`, `assets/sprites/weapons/sniper_deadeye_rifle.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `sniper_spotter_scope` | Прицел Наводчика | Снайпер | Sniper kill-zone: маркирует область у цели и вызывает несколько точных sky-beam попаданий по врагам внутри | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperSpotterScope.tscn`, `assets/sprites/weapons/sniper_spotter_scope.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `sniper_shatter_rounds` | Осколочные Патроны | Снайпер | Sniper split round: основной дальний выстрел раскалывается по соседним целям или продолжает линию при отсутствии целей | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperShatterRounds.tscn`, `assets/sprites/weapons/sniper_shatter_rounds.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_reliquary` | Светлый Реликварий | Священник | Sanctify: отмечает цель священным знаком, затем взрыв по области лечит часть нанесенного урона | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestReliquary.tscn`, `assets/sprites/weapons/priest_reliquary.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_censer` | Кадило Обета | Священник | Ward pulses: несколько защитных волн вокруг героя наносят урон и дают малое лечение | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestCenser.tscn`, `assets/sprites/weapons/priest_censer.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_chime` | Колокол Молитвы | Священник | Prayer chain: молитвенная нить перескакивает между врагами и возвращает sustain | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestChime.tscn`, `assets/sprites/weapons/priest_chime.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_spore_lens` | Споровая Линза | Биолог | Spore bloom: три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSporeLens.tscn`, `assets/sprites/weapons/biologist_spore_lens.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_sample_injector` | Инъектор Образцов | Биолог | Sample dart: берет образец у цели, затем два анализа бьют ее и ближайшие ткани | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSampleInjector.tscn`, `assets/sprites/weapons/biologist_sample_injector.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_symbiote_seed` | Семя Симбионта | Биолог | Symbiote web: первичная цель связывается с соседними врагами и делит биоурон по сети | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSymbioteSeed.tscn`, `assets/sprites/weapons/biologist_symbiote_seed.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_magnetic_anchor` | Магнитный Якорь | Робот | Magnetic anchor: якорь стягивает врагов к центру и бьет импульсом | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotMagneticAnchor.tscn`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_hydraulic_press` | Гидравлический Пресс | Робот | Compression line: две силовые губки сходятся по линии атаки, прижимают врагов к оси и бьют коридором | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotHydraulicPress.tscn`, `assets/sprites/weapons/robot_hydraulic_press.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_reactor_core` | Реакторное Ядро | Робот | Reactor vent: четыре направленных выброса вокруг корпуса чистят ближний круг и отталкивают толпу | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotReactorCore.tscn`, `assets/sprites/weapons/robot_reactor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_sentry_wrench` | Ключ Часового | Инженер | Sentry link: временная турель сама выбирает цели и бьет их точечными лучами | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerSentryWrench.tscn`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_repair_drone` | Ремонтный Дрон | Инженер | Repair drone: цепная дуга по врагам возвращает часть урона в ремонт героя | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerRepairDrone.tscn`, `assets/sprites/weapons/engineer_repair_drone.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
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
| `storm_longbow` | Грозовой длинный лук | Рейнджер | Stance-charged веер грозовых лучей | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `hunter_trap` | Охотничий капкан | Рейнджер | Deploy trap: burst + knockback; stance charge усиливает | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `restore_potion` | Зелье восстановления | Доктор | Drain/lifesteal-связь к цели | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `plague_syringe` | Чумной шприц | Доктор | Drain-связь с poison DoT и sustain | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `bone_saw` | Костяная пила | Доктор | Ближний saw arc/flurry, DoT и lifesteal от урона | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `blast_powder` | Взрывная пыль | Химик | AoE explosion + spark cloud; combo с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `acid_flask` | Кислотная колба | Химик | Большая poison/acid pool; combo explosion с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `homunculus_vial` | Склянка гомункула | Химик | Temporary minion scaling from magic damage | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `long_spear` | Копье | Рыцарь | Длинный точечный strip + block/counter passive | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `tower_shield` | Башенный щит | Рыцарь | Shield bash / frontal control + сильный block/counter | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `holy_flail` | Освященный кистень | Рыцарь | Medium circular heavy swing + сильнее counter damage | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `summon_amulet` | Амулет призыва | Друид | Командуемая beast pack, scaling from Leadership | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `briar_staff` | Посох терний | Друид | Thorn zone, AoE DoT, crowd control | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `raven_totem` | Вороний тотем | Друид | Totem pulses, Leadership-scaled deploy limit | `ProgressionData.DRUID_WEAPONS` | Реализовано |

Weapon art v2 2026-06-12: сцены `WeaponVisual` должны использовать texture path, совпадающий с canonical weapon ID (исключение: Berserk `sword/axe/hammer` используют historical файлы `two_handed_sword/axe/hammer.png`). SCRUM-277 закрыл оставшиеся proxy-ссылки новых классов: Вор, Элементалист, Снайпер, Священник, Биолог и Инженер теперь рендерят свои `assets/sprites/weapons/<weapon_id>.png`, а `PriestChime` больше не показывает `sound_amp.png`. `long_spear`, `tower_shield`, `holy_flail` перерисованы как noble knight equipment. Scene scales уменьшены, чтобы оружие занимало примерно 50-65% высоты персонажа и не перекрывало лицо/корпус. Контрольные листы: `docs/design/previews/weapon_v2_assets_contact.png`, `docs/design/previews/weapon_v2_socket_contact.png`. SCRUM-168 добавил 3 Soldier weapon IDs и подключил canonical textures `soldier_rifle.png`, `soldier_grenade.png`, `soldier_bayonet.png`.

Временные visuals классового оружия регистрируются в runtime-группе `player_weapon_effects` и должны удаляться при смене оружия/персонажа, смерти, завершении забега и очистке world state.

## Призывные Союзники И Deployables

SCRUM-152 Design pass 2026-06-12 добавил канонический raster-набор союзных summon/deployable ассетов в `assets/sprites/allies/`. Все PNG `256x256`, RGBA, transparent, painterly D&D style, с теплым/зеленым allied accent для отличия от врагов.

| ID | Игровая роль | Ассет | Runtime status |
| --- | --- | --- | --- |
| `ally_druid_beast` | Базовый питомец Друида / fallback `AllyMinion` | `assets/sprites/allies/ally_druid_beast.png` | Подключен как fallback и один из runtime вариантов `summon_amulet` |
| `ally_druid_pack_spirit` | Вариант стаи Друида / ultimate pack visual | `assets/sprites/allies/ally_druid_pack_spirit.png` | Подключен как runtime вариант `summon_amulet` через `ally_visual_ids` |
| `ally_druid_wolf_spriteframes` | Анимированный волк Друида / runtime frames for `druid_beast` | `assets/sprites/allies/ally_druid_wolf_spriteframes.tres` + `assets/sprites/allies/druid_wolf/ally_druid_wolf_{move,attack}_*.png` | Подключен в `AllyMinion`: `move` 8f/12fps loop, `attack` 6f/14fps no-loop, scale `0.34`, flip вправо по движению/атаке |
| `ally_homunculus` | Химикский гомункул от `homunculus_vial` | `assets/sprites/allies/ally_homunculus.png` | Подключен через `ally_visual_id: homunculus` |
| `ally_leadership_echo` | Призрачный союзник/эхо от Leadership | `assets/sprites/allies/ally_leadership_echo.png` | Зарезервирован в `AllyMinion` visual map для future Leadership echo |
| `deploy_sound_amp_field` | Полевой объект ампа Гитариста | `assets/sprites/allies/deploy_sound_amp_field.png` | Подключен как `deploy_texture_path` для `sound_amp` |
| `deploy_raven_totem_field` | Полевой объект Вороньего тотема Друида | `assets/sprites/allies/deploy_raven_totem_field.png` | Подключен как `deploy_texture_path` для `raven_totem` |

Preview QA:

- `docs/design/previews/summon_allies_style_references.png` - project style references used for Codex Design generation;
- `docs/design/previews/summon_allies_asset_contact.png` - transparent asset contact sheet;
- `docs/design/previews/summon_allies_scale_meadow_preview.png` - scale/readability check on arena background.

Back-end source-specific integration complete in SCRUM-157: runtime selectors preserve cleanup groups and gameplay balance.

## Стандартные Монстры

Эти имена являются каноническими для задач. Если в коде сцена пока называется generic-именем, в задачах все равно нужно ссылаться на игровое имя из таблицы.

| ID | Игровое имя | Текущая сцена | Архетип | Ассет | Поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_cutter` | Рубака Разлома | `scenes/Enemy.tscn` | Ближний бой | `assets/sprites/enemies/enemy_melee.png` | Идет к игроку, бьет с windup | Реализовано |
| `ash_marksman` | Пепельный Стрелок | `scenes/EnemyShooter.tscn` | Дальний бой | `assets/sprites/enemies/enemy_ranged.png` | Держит дистанцию и стреляет | Реализовано |
| `spark_runner` | Искровой Беглец | `scenes/EnemyRunner.tscn` | Быстрый враг | `assets/sprites/enemies/enemy_suicide_runner.png` | Быстро догоняет игрока, может спавниться пачками | Реализовано |
| `stone_bruiser` | Каменный Громила | `scenes/EnemyBruiser.tscn` | Жирный медленный | `assets/sprites/enemies/enemy_bruiser_slow.png` | Высокий HP, низкая скорость | Реализовано |
| `bone_caller` | Костяной Зовущий | `scenes/EnemySummoner.tscn` | Суммонер | `assets/sprites/enemies/enemy_summoner.png` | Призывает маленьких мобов | Реализовано |
| `void_mage` | Маг Пустоты | `scenes/EnemyMage.tscn` | Магический ranged | `assets/sprites/enemies/enemy_void_mage.png` | Давление магическими атаками | Реализовано |
| `venom_spitter` | Ядовитый Плеватель | `scenes/EnemySpitter.tscn` | Ranged / hazard | `assets/sprites/enemies/enemy_venom_spitter.png` | Дальний плевок, давление зоной | Реализовано |
| `rift_shieldbearer` | Щитоносец Разлома | `scenes/EnemyShield.tscn` | Защитный враг | `assets/sprites/enemies/enemy_rift_shieldbearer.png` | Более живучий вариант передней линии | Реализовано |
| `small_biter` | Малый Кусатель | `scenes/EnemyBiter.tscn` | Маленький быстрый | `assets/sprites/enemies/enemy_small_biter.png` | Давит числом и скоростью | Реализовано |
| `bone_shaman` | Костяной Шаман | `scenes/EnemyBoneShaman.tscn` | Продвинутый суммонер | `assets/sprites/enemies/enemy_bone_shaman.png` | Призыв и поддержка толпы | Реализовано |
| `winged_spark` | Крылатая Искра | `scenes/EnemyFlyingRunner.tscn` | Летающий враг | `assets/sprites/enemies/enemy_winged_spark.png` | Hover-движение; pit layer отключен вместе с ямами | Реализовано |

## Элитные Монстры

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Уникальное поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `iron_bastion` | Железный Оплот | `scenes/EliteArmored.tscn` | Танкующая элитка | `assets/sprites/elites/iron_bastion.png` | Пассив: периодический щит. Уникальная атака `slam_wave`: замах 0.6с с telegraph-кругом, затем кольцевая ударная волна (радиус 260, урон + отбрасывание), кулдаун 6с | Реализовано |
| `night_stalker` | Ночной Сталкер | `scenes/EliteStalker.tscn` | Агрессивная элитка | `assets/sprites/elites/night_stalker.png` | Пассив: рывки к игроку. Уникальная атака `shadow_strike`: уходит в тень на 0.5с с telegraph-меткой за спиной игрока, телепортируется туда и бьет (радиус 92), кулдаун 7с | Реализовано |
| `plague_prophet` | Чумной Пророк | `scenes/ElitePoisoned.tscn` | Зональная элитка | `assets/sprites/elites/plague_prophet.png` | Пассив: ядовитые зоны. Уникальная атака `poison_volley`: 3 lob-снаряда по дуге в telegraph-метки, в точках падения лужи на 3с (тик 0.6с), кулдаун 8с | Реализовано |
| `shard_marshal` | Маршал Осколков | `scenes/EliteCommander.tscn` | Командир толпы | `assets/sprites/elites/shard_marshal.png` | Пассив: одноразовая аура усиления ближайших врагов. Уникальная атака `shard_fan`: веер из 5 кристальных снарядов в сторону игрока после замаха 0.5с, кулдаун 6с | Реализовано |

Обновление SCRUM-135 от 2026-06-12: все 4 активные элитки используют native `512x512` source PNG и перенарезанные `assets/sprites/elites/cutout/` части под `scripts/sliced_rig_manifest.gd` `size = Vector2(512, 512)`. Поза/силуэт сохранены 1:1 относительно прежних 256px-спрайтов, чтобы epic scale оставался геометрически тем же, но без билинейного мыла на QHD/Retina.

Все уникальные атаки элиток: параметры лежат в `ProgressionData.ELITE_ATTACK_CONFIGS` (data-driven), reusable mechanics — в `ProgressionData.ENEMY_MECHANIC_CATALOG`, unique signatures — в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`; урон атаки ограничен 25% max HP игрока. VFX: `elite_telegraph_circle.png`, `elite_shockwave_ring.png`, `elite_shadow_trail.png`, `elite_poison_lob.png`, `elite_crystal_shard.png` в `assets/sprites/effects/`.

## Умения Монстров (Канонические Имена Кодекса)

Зарегистрированы задачей «Кодекс» 2026-06-11. Это ссылочные имена: задачи и обсуждения
ссылаются на них. Источник данных кодекса: `scripts/codex_data.gd::MONSTERS`.

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

Data-driven ростер `scripts/progression_data.gd::MINI_ELITE_KINDS` (6 видов): `mini_scavenger_reaper` Жнец-Падальщик, `mini_plague_bellringer` Чумной Звонарь, `mini_bone_warden` Костяной Страж, `mini_spark_wight` Искровик, `mini_rot_hound` Гнилая Гончая, `mini_shadow_devourer` Теневой Пожиратель. Каждый вид: базовая elite-сцена, профиль hp/speed/damage, RGB-тинт различимости, поведение ближайшего elite-паттерна. Свита L7 выбирает вид случайно (`combat_director._maybe_spawn_mini_elite`); kind-мета `mini_elite_kind` на узле. SCRUM-156 подготовил финальные source sprites `assets/sprites/elites/mini_<id>.png` (`512x512`, RGBA, transparent). Runtime использует базовые elite-сцены с mini-elite meta/scale/drop profile, а кодекс имеет отдельный раздел «Мини-элитки».

## Боссы

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Паттерны | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_warden` | Страж Разлома | `scenes/BossWarden.tscn` | Финальный босс контроля | `assets/sprites/bosses/boss_rift_warden.png` | Залпы, зоны разлома, призыв, щит, увороты | Реализовано |
| `disk_devourer` | Пожиратель Диска | `scenes/BossDiskDevourer.tscn` | Финальный босс давления | `assets/sprites/bosses/boss_disk_devourer.png` | Рывки, disk slam AoE, radial burst, enrage | Реализовано |
| `bone_archon` | Костяной Архонт | `scenes/BossBoneArchon.tscn` | Финальный босс-некромант | `assets/sprites/bosses/boss_bone_archon.png` (SCRUM-156 source ready; runtime scene wiring Back-end scope) | Волны скелетов (summon), веер черепов (volley), костяная стена (волна зон с проходом) | Реализовано (механики; арт source ready) |
| `brood_mother` | Матерь Роя | `scenes/BossBroodMother.tscn` | Финальный босс-рой | `assets/sprites/bosses/boss_brood_mother.png` (SCRUM-156 source ready; runtime scene wiring Back-end scope) | Частый выводок мелких, паутинные зоны замедления (apply_web_slow), рывок в фазе 3 | Реализовано (механики; арт source ready) |
| `ashen_colossus` | Пепельный Колосс | `scenes/BossAshenColossus.tscn` | Финальный босс-гигант | `assets/sprites/bosses/boss_ashen_colossus.png` (SCRUM-156 source ready; runtime scene wiring Back-end scope) | Slam-волны + тлеющие зоны после ударов, редкий radial burst, энрейдж <25% HP (быстрее, шире волны) | Реализовано (механики; арт source ready) |

Обновление SCRUM-135 от 2026-06-12: оба boss source PNG заменены на native `512x512` и перенарезаны в `assets/sprites/bosses/cutout/`; `rift_warden` сохраняет отдельный `vortex` part, `disk_devourer` остается single-torso rig по текущему CONFIG. Epic boss scale не менялся.

## Узлы Маршрутной Карты

| ID | Игровое имя | Роль | Иконка | Статус |
| --- | --- | --- | --- | --- |
| `battle` | Обычный бой | Стандартный combat-узел | `assets/sprites/map_icons/map_battle_skull.png` | Реализовано |
| `elite_battle` | Бой с элиткой | Сложный бой с элитным врагом | `assets/sprites/map_icons/map_elite_skull_bones.png` | Реализовано |
| `shop` | Магазин | Покупка нескольких предметов | `assets/sprites/map_icons/map_shop_tent.png` | Реализовано |
| `event` | Событие | Выбор с наградой/риском | `assets/sprites/map_icons/map_event_question.png` | Реализовано |
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

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `damage` | Урон | `assets/sprites/ui/icons/derived/attr_damage.png` |
| `magic_damage` | Магический урон | `assets/sprites/ui/icons/derived/attr_magic_damage.png` |
| `sound_wave_damage` | Урон звуковой волны | `assets/sprites/ui/icons/derived/attr_sound_wave_damage.png` |
| `attack_speed` | Скорость атаки | `assets/sprites/ui/icons/derived/attr_attack_speed.png` |
| `crit_chance` | Шанс крита | `assets/sprites/ui/icons/derived/attr_crit_chance.png` |
| `crit_damage_multiplier` | Множитель крита | `assets/sprites/ui/icons/derived/attr_crit_damage_multiplier.png` |
| `move_speed` | Скорость движения | `assets/sprites/ui/icons/derived/attr_move_speed.png` |
| `dodge` | Уворот | `assets/sprites/ui/icons/derived/attr_dodge.png` |
| `defense` | Защита | `assets/sprites/ui/icons/derived/attr_defense.png` |
| `health_point` | Максимальное здоровье | `assets/sprites/ui/icons/derived/attr_health_point.png` |
| `attack_range` | Дальность атаки | `assets/sprites/ui/icons/derived/attr_attack_range.png` |
| `aoe_radius` | Радиус AoE | `assets/sprites/ui/icons/derived/attr_aoe_radius.png` |
| `pickup_radius` | Радиус подбора | `assets/sprites/ui/icons/derived/attr_pickup_radius.png` |
| `dot_damage` | Урон DoT | `assets/sprites/ui/icons/derived/attr_dot_damage.png` |
| `dot_speed` | Скорость тиков DoT | `assets/sprites/ui/icons/derived/attr_dot_speed.png` |
| `projectile_speed` | Скорость снарядов | `assets/sprites/ui/icons/derived/attr_projectile_speed.png` |
| `aura_radius` | Радиус ауры | `assets/sprites/ui/icons/derived/attr_aura_radius.png` |
| `buff_power` | Сила баффов | `assets/sprites/ui/icons/derived/attr_buff_power.png` |
| `knockback_power` | Сила отталкивания | `assets/sprites/ui/icons/derived/attr_knockback_power.png` |
| `summon_amount` | Количество призывов | `assets/sprites/ui/icons/derived/attr_summon_amount.png` |

### HUD Ресурсы

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `hp` | HP | `assets/sprites/ui/hud/hud_hp.png` |
| `xp` | Опыт | `assets/sprites/ui/hud/hud_xp.png` |
| `money` | Деньги | `assets/sprites/ui/hud/hud_money.png` |
| `ultimate_multiplier` | Ультимейт | `assets/sprites/ui/icons/derived/attr_buff_power.png` fallback via `UIIconRegistry` |

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

| ID | Ассет | Роль |
| --- | --- | --- |
| `ui_panel_frame` | `assets/sprites/ui/frames/global/ui_panel_frame.png` | Базовые большие панели меню/событий/кодекса |
| `ui_button_frame` | `assets/sprites/ui/frames/global/ui_button_frame.png` | Legacy/fallback frame; runtime buttons use SCRUM-273 `ui_btn_red_gold_*` 4-state textures |
| `ui_card_frame` | `assets/sprites/ui/frames/global/ui_card_frame.png` | Карточки персонажей, route node buttons, compact panels |
| `ui_level_panel_frame` | `assets/sprites/ui/frames/global/ui_level_panel_frame.png` | Level-up / reward panel |
| `ui_hud_panel_frame` | `assets/sprites/ui/frames/global/ui_hud_panel_frame.png` | Боевой HUD panel |
| `ui_hud_card_frame` | `assets/sprites/ui/frames/global/ui_hud_card_frame.png` | HP/XP/money HUD cards |
| `ui_tooltip_frame` | `assets/sprites/ui/frames/global/ui_tooltip_frame.png` | Generic tooltip/system panel frame |
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
| `ui_frame_hero_select_dossier` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png` | Live Hero Select dossier frame; SCRUM-323 DescriptionHS production PNG, `1120x1140` RGBA, rendered as whole-image proportional `TextureRect` inside `HeroSelectDossierFrame` (base frame `387x394`, safe content margins `Vector4(96, 66, 96, 54)`, backup in `build/cleanup_backup_hero_select_dossier_2026_06_14/`) |
| `ui_frame_hero_select_radar` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png` | Live Hero Select floating stat radar frame; SCRUM-322 windrose compass frame, 1024x1024 RGBA, rendered as square whole-image proportional `TextureRect` (safe margins `Vector4(245, 245, 245, 235)`, backup in `build/cleanup_backup_hero_select_windrose_2026_06_14/`) |
| `ui_frame_hero_select_thumbnail_strip` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png` | Live Hero Select bottom thumbnail strip frame; SCRUM-320 Carusel reference rendered as whole-image proportional `TextureRect` (no 9-slice/one-axis stretch), backup in `build/cleanup_backup_hero_select_carousel_2026_06_14/` |
| `ui_frame_hero_select_thumbnail` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail.png` | Live Hero Select adaptive hero thumbnail button frame |
| `ui_frame_hero_select_asc_button` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button.png` | Live Hero Select ascension +/- frame |
| `ui_frame_hero_select_asc_label` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_label.png` | Live Hero Select ascension level label frame |
| `ui_frame_hero_select_asc_mods` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_mods.png` | Live Hero Select ascension modifier line frame |
| `ui_frame_settings_tab_switcher` | `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` | Design-ready Settings tab switcher frame; SCRUM-325, `1280x256` RGBA, content-zone rects in `docs/tasks/backend_integrate_settings_tab_switcher_frame_task.md`; Back-end runtime integration SCRUM-334 |
| `ui_btn_red_gold_standard_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_standard.png` + hover/pressed/disabled | Standard 420x104 action buttons |
| `ui_btn_red_gold_max_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_max.png` + hover/pressed/disabled | Wide 560x104 action buttons |
| `ui_btn_red_gold_main_menu_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_main_menu.png` + hover/pressed/disabled | Main menu 380x104 buttons |
| `ui_btn_red_gold_hero_confirm_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_hero_confirm.png` + hover/pressed/disabled | Hero confirm 320x104 buttons |
| `ui_btn_red_gold_reset_audio_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_audio.png` + hover/pressed/disabled | Settings reset audio 420x104 buttons |
| `ui_btn_red_gold_reset_bindings_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_bindings.png` + hover/pressed/disabled | Settings reset bindings 440x104 buttons |
| `ui_btn_red_gold_codex_tab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_codex_tab.png` + hover/pressed/disabled | Codex tab buttons |
| `ui_btn_red_gold_back_s/m/l_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_back_s.png` / `back_m.png` / `back_l.png` + states | Navigation/back buttons by width |
| `ui_btn_red_gold_attr_selector_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_attr_selector.png` + hover/pressed/disabled | Attribute selector 560x104 buttons |
| `ui_btn_red_gold_fab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_fab.png` + hover/pressed/disabled | Upgrade FAB 50x50 |
| `ui_btn_red_gold_utility_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility.png` + hover/pressed/disabled | Compact utility 54x42 |
| `ui_btn_red_gold_pause_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause.png` + hover/pressed/disabled | Pause menu 280x60 |
| `ui_btn_red_gold_rebind_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_rebind.png` + hover/pressed/disabled | Keybinding/dropdown-style 420x62 controls |
| `ui_df_button_primary/secondary/danger_*` | `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*` | Superseded SCRUM-147 parchment/wax buttons; retained only as legacy/reference fallback |
| `ui_df_panel_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png` | Superseded SCRUM-229 panel fallback/reference |
| `ui_df_shop_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_shop_frame.png` | Superseded merchant/shop frame fallback/reference |
| `ui_panel_leather_gold_square` | `assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_square.png` | Superseded SCRUM-229 source square/card frame |
| `ui_panel_leather_gold_wide` | `assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_wide.png` | Superseded SCRUM-229 source wide panel/frame |
| `ui_bar_leather_gold_thin` | `assets/sprites/ui/frames/leather_gold/ui_bar_leather_gold_thin.png` | Superseded SCRUM-229 source bar/label/divider frame |
| `ui_window_leather_gold_main` | `assets/sprites/ui/frames/leather_gold/ui_window_leather_gold_main.png` | Superseded SCRUM-229 source large window panel |
| `ui_check_leather_gold` | `assets/sprites/ui/frames/leather_gold/ui_check_leather_gold.png` | Superseded SCRUM-229 source checked state frame |

Pipeline/preview: `tools/build_red_gold_button_kit.py` (SCRUM-273 buttons), `tools/build_ornate_ui_frame_kit.py` (SCRUM-274 panels), `tools/build_hero_select_frame_kit.py` (SCRUM-281 Hero Select frames), `tools/build_hero_select_windrose_frame.py` (SCRUM-322 radar), `tools/build_hero_select_dossier_frame.py` (SCRUM-323 dossier), active previews `docs/design/previews/red_gold_button_kit_contact.png`, `docs/design/previews/ornate_dark_frame_kit_contact.png`, `docs/design/previews/hero_select_frame_kit_contact.png`, `docs/design/previews/hero_select_portrait_frame_content_zone.png`, `docs/design/previews/hero_select_windrose_radar_content_zone.png`, `docs/design/previews/hero_select_dossier_frame_content_zone.png` and `docs/design/previews/settings_tab_switcher_frame_content_zone.png`. Historical: `tools/apply_button_only_ui_revert.py` (SCRUM-147 buttons/legacy correction), `tools/build_leather_gold_ui_kit.py` (SCRUM-229 panels), `docs/design/previews/interface_leather_gold_panel_kit_contact.png`.

Системные иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_close`, `system_back`, `system_settings`, `system_arrow_left/right/up/down`, `system_checkbox_unchecked`, `system_checkbox_checked`, `system_slider_track`, `system_slider_grabber`. Файлы лежат в `assets/sprites/ui/icons/system/`.

Contextual UI direction 2026-06-12 is superseded by SCRUM-147. Contextual assets in `assets/sprites/ui/frames/contextual/` are historical/reference until Back-end cleanup confirms no live references. New context decisions should use the SCRUM-147 dark fantasy role system instead.

| ID | Ассет | Роль | Статус |
| --- | --- | --- | --- |
| `ui_wild_*_frame` | `assets/sprites/ui/frames/contextual/ui_wild_panel_frame.png`, `ui_wild_button_frame.png`, `ui_wild_card_frame.png`, `ui_wild_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147 | Superseded |
| `ui_grave_*_frame` | `assets/sprites/ui/frames/contextual/ui_grave_panel_frame.png`, `ui_grave_button_frame.png`, `ui_grave_card_frame.png`, `ui_grave_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147 | Superseded |
| `ui_laurel_*_frame` | `assets/sprites/ui/frames/contextual/ui_laurel_panel_frame.png`, `ui_laurel_button_frame.png`, `ui_laurel_card_frame.png`, `ui_laurel_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147 | Superseded |
| `ui_parchment_*_frame` | `assets/sprites/ui/frames/contextual/ui_parchment_panel_frame.png`, `ui_parchment_button_frame.png`, `ui_parchment_card_frame.png`, `ui_parchment_tooltip_frame.png`, `ui_parchment_tab_frame.png` | Historical context kit, superseded by SCRUM-147 | Superseded |

## Фоны И Карты

| ID | Игровое имя | Ассет | Роль |
| --- | --- | --- | --- |
| `arena_2k_combat` | Боевая Арена 2K | Generated by `scripts/main.gd` | Прямоугольная арена 2560x1440 с камерой zoom 1.12 |
| `main_menu_epic_battle` | Эпичный бой стартового экрана | `assets/backgrounds/main_menu_epic_battle.png` | Фон главного меню |
| `screen_event_background` | Фон экрана события | `assets/sprites/ui/screens/screen_event_background.png` | Активный фон Event, battle reward, upgrade, victory/death fallback screens |
| `screen_shop_background` | Фон магазина | `assets/sprites/ui/screens/screen_shop_background.png` | Активный фон Shop screen |
| `screen_campfire_background` | Фон костра | `assets/sprites/ui/screens/screen_campfire_background.png` | Активный фон Rest/Campfire screen |
| `ui_backdrop_system_cathedral` | System/Codex/Settings backdrop | `assets/backgrounds/ui/ui_backdrop_system_cathedral.png` | Active for `system`, `settings`, `codex`, `hero_select`, `weapon_select`, `pause_stats`, `meta_tree`, `campfire` |
| `ui_backdrop_merchant_archive` | Shop backdrop | `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` | Active for `shop` |
| `ui_backdrop_arcane_lab` | Level-up/Magic/Meta backdrop | `assets/backgrounds/ui/ui_backdrop_arcane_lab.png` | Active for `event`, `upgrade`, `level_up`, `meta_progression` |
| `ui_backdrop_reward_hall` | Reward/Victory backdrop | `assets/backgrounds/ui/ui_backdrop_reward_hall.png` | Active for `elite_reward`, `victory`, `artifact_reward` |
| `ui_backdrop_defeat_crypt` | Defeat/Danger backdrop | `assets/backgrounds/ui/ui_backdrop_defeat_crypt.png` | Active for `death`, `defeat`, `end_run_confirm` |
| `route_map_backdrop` | Жутковатый фон маршрутной карты | `assets/backgrounds/route_map_backdrop.png` | Низкоконтрастный dark fantasy фон full-screen route map, спокойная центральная зона под узлы и линии |
| `stone_garden` | Каменный Сад | `assets/backgrounds/field_stone_garden.png` | Базовый фон |
| `marsh` | Топь | `assets/backgrounds/field_marsh.png` | Болотный фон |
| `dry_road` | Сухая Дорога | `assets/backgrounds/field_dry_road.png` | Дорожный фон |
| `meadow` | Луг | `assets/backgrounds/field_meadow.png` | Зеленый фон |
| `ruined_courtyard` | Руинный Двор | `assets/backgrounds/field_ruined_courtyard.png` | D&D top-down руинная каменная арена |
| `misty_marsh` | Туманная Топь | `assets/backgrounds/field_misty_marsh.png` | D&D top-down болотный грунт с лужами и мхом |
| `dusty_badlands` | Пыльные Пустоши | `assets/backgrounds/field_dusty_badlands.png` | D&D top-down сухая земля/дорога |
| `enchanted_meadow` | Зачарованный Луг | `assets/backgrounds/field_enchanted_meadow.png` | D&D top-down травяная поляна с мелкими цветами |
| `ashen_rift` | Пепельный Разлом | `assets/backgrounds/field_ashen_rift.png` | D&D top-down вулканический пепел с тонкими трещинами |
| `cursed_grove` | Проклятая Роща | `assets/backgrounds/field_cursed_grove.png` | D&D top-down сине-серый зачарованный лесной грунт |

Все активные боевые фоны — нативные 2560x1440. Pass 2026-06-12 заменил первые 4 на строго плоские top-down ground textures без высоких объектов, ложной перспективы и объемных камней/кустов: только низкоконтрастная почва, мох, трещины, трава, дорожные следы и мелкая наземная фактура. Expansion pass 2026-06-12 добавил еще 6 D&D battlemap-фонов с тем же gameplay-readable правилом: антуражно и красиво, но без крупных камней/кустов и объектов, которые читаются как препятствия. QA preview: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
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

## Sprite QA Notes

Активные спрайты персонажей, стандартных монстров, элиток, боссов, оружия, projectiles, pickups, route icons и UI icons проходят quality-audit перед сдачей визуальных задач. После аудита 2026-06-10 у `assets/sprites/enemies/enemy_suicide_runner.png` удален лишний правый фрагмент текстуры; активные pickup/player projectile больше не используют Polygon2D-placeholder как видимый слой.

SCRUM-177 read-only sprite audit 2026-06-13: отчет `docs/design/reviews/sprite_visual_audit_2026_06.md`, contact sheets `docs/design/previews/audit_*.png`, inventory `docs/design/reviews/sprite_visual_audit_inventory_2026_06.*`. Вывод: активные персонажи/оружие/основные враги/артефакты/фоны в целом соответствуют D&D/dark-fantasy канону; отдельные 0.1.4 follow-up задачи заведены для placeholder/tint новых боссов и мини-элиток, polish VFX, унификации derived/shop UI icons и cleanup legacy placeholder sprites.

SCRUM-269 read-only asset/image cleanup audit 2026-06-14: отчет `docs/design/reviews/cleanup_assets_audit_2026_06.md`. Мертвого игрового арта не найдено: 51 `vfx_weapon_<weapon_id>.png`, 18 canonical weapon PNG, новые boss/mini-elite source sprites, marketing collateral и dynamic UI/icon/cutout families защищены от ложных cleanup-срабатываний. Реальный мусор ограничен orphan ` 2.png.import` sidecars после SCRUM-270; cleanup передан и выполнен отдельной Back-end задачей SCRUM-271.

## UI Иконки И HUD

Централизованный mapping: `scripts/ui_icon_registry.gd`.

| Группа | ID | Каноническая папка | Статус |
| --- | --- | --- | --- |
| Базовые характеристики | `strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership` | `assets/sprites/ui/icons/stats/` | Реализовано |
| Производные параметры | `damage`, `magic_damage`, `sound_wave_damage`, `attack_speed`, `crit_chance`, `crit_damage_multiplier`, `move_speed`, `dodge`, `defense`, `health_point`, `attack_range`, `aoe_radius`, `pickup_radius`, `dot_damage`, `dot_speed`, `projectile_speed`, `aura_radius`, `buff_power`, `knockback_power`, `summon_amount` | `assets/sprites/ui/icons/derived/` | Реализовано |
| HUD ресурсы | `hp`, `xp`, `money` | `assets/sprites/ui/hud/` | Реализовано |

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

Текущие артефакты определены в `ProgressionData.ARTIFACTS`. Если артефакт переименовывается для UI, его `id` должен остаться стабильным или миграция должна быть явно описана в задаче.

| ID | Текущее имя | Роль |
| --- | --- | --- |
| `warrior_charm` | Warrior Charm | +2 Сила |
| `fox_boots` | Fox Boots | +2 Ловкость |
| `glass_orb` | Glass Orb | +2 Интеллект |
| `hawk_lens` | Hawk Lens | +2 Восприятие |
| `ember_core` | Ember Core | +2 Энергия |
| `old_codex` | Old Codex | +2 Знание |
| `stone_heart` | Stone Heart | +2 Выносливость |
| `banner_seed` | Banner Seed | +2 Лидерство |
| `red_whetstone` | Red Whetstone | +1 Сила, +1 Ловкость |
| `star_compass` | Star Compass | +1 Восприятие, +1 Знание |
| `living_root` | Living Root | +1 Выносливость, +1 Энергия |
| `captains_coin` | Captain's Coin | +1 Лидерство, +1 Сила |
| `quickstring` | Quickstring | +15% attack speed |
| `heavy_totem` | Heavy Totem | +25% max HP, -5% move speed |
| `splinter_gloves` | Splinter Gloves | +20% damage |
| `wide_sigil` | Wide Sigil | +20% attack range |
| `swift_ink` | Swift Ink | +12% move speed |
| `summoners_bell` | Summoner's Bell | +1 maximum summon |
| `blood_sigil` | Кровавая печать | Берсерк: damage и max HP |
| `void_ink` | Чернила пустоты | Темный маг: magic damage и AoE |
| `echo_pick` | Медиатор эха | Гитарист: attack speed и knockback |
| `sturdy_amulet` | Крепкий амулет | +24 max HP |
| `fast_boots` | Быстрые сапоги | +10% move speed |
| `magnetic_buckle` | Магнитная пряжка | +55 pickup radius |
| `silver_coin` | Серебряная монета | +25% money gain |
| `survival_manual` | Учебник выживания | +22% XP gain |
| `cracked_shield` | Треснувший щит | +12% defense, -6% move speed |
| `sharp_talisman` | Острый талисман | +8% crit chance |
| `jagged_blade` | Зазубренное лезвие | Берсерк: melee damage |
| `heavy_grip` | Тяжелая рукоять | Берсерк: knockback, меньше attack speed |
| `war_belt` | Боевой ремень | Берсерк: AoE radius |
| `warriors_rage` | Ярость воина | Берсерк: damage, меньше max HP |
| `dark_crystal` | Темный кристалл | Темный маг: magic damage |
| `ash_page` | Пепельная страница | Темный маг: AoE radius и damage |
| `skull_resonator` | Черепной резонатор | Темный маг: attack range |
| `ink_candle` | Чернильная свеча | Темный маг: damage, меньше move speed |
| `copper_string` | Медная струна | Гитарист: sound damage |
| `broken_pick` | Сломанный медиатор | Гитарист: crit chance |
| `loud_amp` | Громкий усилитель | Гитарист: aura/AoE radius |
| `bass_cable` | Басовый кабель | Гитарист: knockback и AoE |
| `cursed_crown` | Проклятая корона | +30% damage, -18% max HP |
| `fragile_heart` | Хрупкое сердце | +25% attack speed, -10% defense |
| `greedy_purse` | Жадный кошелек | +45% money gain, enemies +15% HP |
| `burning_shard` | Горящий осколок | +20% AoE radius, -20% healing |
| `golden_route_mark` | Золотая метка пути | +15% XP gain и money gain |
| `glass_edge` | Стеклянная кромка | +20% crit damage, -8 max HP |

## Тиры Артефактов

Поле `tier` (1-3) есть у всех артефактов в `ProgressionData.ARTIFACTS` — третья арт-итерация рисует иконки «круче = сильнее» по этому полю. Поле `class_affinity` задает классовую привязку (пустой список = универсальный).

- **Tier 2 (редкие, 16 шт.)**: `heavy_totem`, `blood_sigil`, `void_ink`, `echo_pick`, `cracked_shield`, `heavy_grip`, `warriors_rage`, `ash_page`, `ink_candle`, `bass_cable`, `cursed_crown`, `fragile_heart`, `greedy_purse`, `burning_shard`, `golden_route_mark`, `glass_edge`.
- **Tier 3 (легендарные, билдообразующие)**:

| ID | Игровое имя | Механика |
| --- | --- | --- |
| `echo_core` | Эхо Разлома | Каждый 5-й удар — взрыв 80% урона по области вокруг цели |
| `split_core` | Ядро Расщепления | Темный маг/Гитарист: +1 снаряд и луч всем атакам |
| `blood_pact` | Кровавый Рубеж | HP ниже 30% — +50% урона |
| `leech_heart` | Сердце Пиявки | Убийство возвращает 2% максимального HP |
| `thorn_pact` | Договор Шипов | Полученный урон отражается x2 во врагов рядом |
| `phantom_step` | Призрачный Шаг | Уворот дает +40% скорости движения на 2с |

- `leech_fang` (Клык Пиявки) — Tier 2: +25% шанса вампиризма, +2 к силе вампиризма (источник vampiric-атрибутов).
- Остальные артефакты — Tier 1 (эффекты усилены x2.5 от прежних).
- Иконки новых tier-3 — временные копии тематически близких (до арт-итерации Codex по тирам).

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

## Иконки Артефактов, Shop UI И Курсор

Каноническая спецификация и полный mapping `artifact_id -> icon_path`, `shop_item_id -> icon_path`: `docs/design/artifact_shop_cursor_visual_kit.md`.

| Группа | ID / naming | Каноническая папка / файл | Статус |
| --- | --- | --- | --- |
| Artifact icons | `artifact_<artifact_id>.png` для всех `ProgressionData.ARTIFACTS`; 53 шт., 256x256 RGBA, transparent realistic epic D&D/tabletop fantasy raster magic items; QA preview `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` | `assets/sprites/ui/icons/artifacts/` | Реализовано (realistic D&D raster redraw 2026-06-12) |
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

| ID | Файл | Использование |
| --- | --- | --- |
| `sfx_hit` | `assets/audio/sfx_hit.wav` | Попадание по врагу |
| `sfx_player_hit` | `assets/audio/sfx_player_hit.wav` | Урон по игроку |
| `sfx_dodge` | `assets/audio/sfx_dodge.wav` | Уворот игрока |
| `sfx_pickup_xp` | `assets/audio/sfx_pickup_xp.wav` | Подбор опыта |
| `sfx_pickup_money` | `assets/audio/sfx_pickup_money.wav` | Подбор денег |
| `sfx_level_up` | `assets/audio/sfx_level_up.wav` | Получение уровня |
| `music_menu` | `assets/audio/music_menu.wav` | Меню, карта, небоевые экраны |
| `music_combat` | `assets/audio/music_combat.wav` | Бой |

## Правила Для Новых Сущностей

- Новый монстр получает `id`, игровое имя, архетип, сцену, спрайт, поведение, награды и место в spawn pool.
- Новый босс получает `id`, игровое имя, сцену, иконку карты, минимум 3 уникальных паттерна, награды и правила выбора.
- Новый артефакт получает `id`, игровое имя, описание эффекта, цену/редкость, ограничения по классу и список модификаторов.
- Новый узел карты получает `id`, игровое имя, иконку, tooltip, правила входа/выхода и награды.
- Новый фон получает `id`, игровое имя, ассет, список подходящих типов узлов и fallback.
- Новое оружие получает `id`, игровое имя, класс, форму атаки, параметры урона, сцену, ассет и описание геймплейной роли.

Если новая сущность участвует в случайном выборе, ее нужно добавить в этот реестр в той же задаче.
