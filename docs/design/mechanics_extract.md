# FantasyDisk Mechanics Spreadsheet Extract

## Актуальный Слой Реализации

Обновлено: 2026-06-14

Ниже сохранена выгрузка исходной таблицы механик. Этот верхний раздел фиксирует, какие механики уже перенесены в игру и как они называются в коде. Для точного текущего состояния также см. `docs/design/current_game_state.md`.

Для актуальной разбивки по системам см. также:
- `docs/design/systems/progression_balance.md` — характеристики, формулы, rewards, artifacts, shop, ascension;
- `docs/design/systems/characters_weapons.md` — текущие роли персонажей и оружия;
- `docs/design/systems/combat.md` — runtime combat rules.

Баланс SCRUM-166: `robot_magnetic_anchor`, `robot_hydraulic_press` и `robot_reactor_core`
прогнаны через `tools/balance_harness.gd`; tuned профиль `balanced/tank` держит
solo DPS ~40.1 и 5-target AoE DPS ~138.6, отклонение от целевого бюджета 0.0%.

### Где Живут Данные В Коде

| Область | Файл |
| --- | --- |
| Compatibility facade для прогрессии/контента | `scripts/progression_data.gd` |
| Конфиги персонажей и классовые интерпретации | `scripts/progression_data_characters.gd` |
| Конфиги оружия | `scripts/progression_data_weapons.gd` |
| Награды, артефакты, level-up pools | `scripts/progression_data_content.gd` |
| Магазинные предметы | `scripts/progression_data_shop.gd` |
| Возвышение | `scripts/progression_data_ascension.gd` |
| Балансовые бюджеты, экономика, XP и drop scaling | `scripts/progression_data_balance.gd` |
| Enemy-side data slices | `scripts/progression_data_enemies.gd` |
| Формулы характеристик и описания для UI | `scripts/stat_formulas.gd` |
| Игрок, движение, урон, уровень, экипировка | `scripts/player.gd` |
| Оружие Берсерка | `scripts/berserk_weapon.gd` |
| Оружие Темного мага и Гитариста | `scripts/class_weapon.gd` |
| Враги, контактный урон, ranged, summoner, elite behavior | `scripts/enemy.gd` |
| Боссы | `scripts/boss.gd` |
| Координатор: state, пауза, основной цикл | `scripts/main.gd` |
| Меню, экраны, HUD, стили | `scripts/ui_screens.gd` |
| Маршрутная карта | `scripts/route_map_screen.gd` |
| Бой, спавн волн, баланс, арена, pickups | `scripts/combat_director.gd` |
| Метапрогрессия и сохранение возвышения | `scripts/meta_progression.gd` |
| Звук (SFX/музыка) | `scripts/audio_manager.gd` (autoload) |

### Базовые Характеристики

| Русское название | ID в коде | Основная роль |
| --- | --- | --- |
| Сила | `strength` | Физический урон и силовые билды |
| Ловкость | `agility` | Скорость атаки, крит, скорость движения, уворот |
| Интеллект | `intelligence` | Магический урон и scaling мага |
| Восприятие | `perception` | Дальность, AoE, снаряды, radius-related параметры |
| Энергия | `energy` | Магический/звуковой потенциал, ресурсная фантазия |
| Знание | `knowledge` | DoT, формулы магии, технические параметры |
| Выносливость | `endurance` | HP, защита, отталкивание |
| Лидерство | `leadership` | Ауры, призывы, поддержка |

### Текущие Статы Персонажей

Источник: `scripts/progression_data_characters.gd::BASE_STATS` / `CHARACTER_CONFIGS`.

| Персонаж | ID | Str | Agi | Int | Per | Energy | Know | End | Lead |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Берсерк | `berserk` | 10 | 5 | 2 | 5 | 4 | 4 | 7 | 3 |
| Солдат | `soldier` | 7 | 6 | 2 | 8 | 4 | 5 | 6 | 5 |
| Вор | `thief` | 5 | 9 | 3 | 8 | 5 | 4 | 4 | 5 |
| Элементалист | `elementalist` | 2 | 4 | 9 | 7 | 8 | 6 | 3 | 5 |
| Снайпер | `sniper` | 6 | 8 | 2 | 10 | 3 | 3 | 7 | 1 |
| Священник | `priest` | 2 | 4 | 8 | 6 | 7 | 9 | 5 | 6 |
| Биолог | `biologist` | 2 | 5 | 8 | 7 | 6 | 10 | 4 | 4 |
| Робот | `robot` | 8 | 3 | 5 | 5 | 7 | 4 | 10 | 4 |
| Инженер | `engineer` | 4 | 5 | 7 | 6 | 6 | 6 | 5 | 10 |
| Темный маг | `dark_mage` | 2 | 3 | 10 | 5 | 7 | 6 | 2 | 5 |
| Гитарист | `guitarist` | 4 | 6 | 4 | 7 | 6 | 5 | 4 | 7 |
| Ассасин | `assassin` | 6 | 10 | 2 | 6 | 3 | 4 | 5 | 4 |
| Рейнджер | `ranger` | 7 | 7 | 2 | 9 | 4 | 4 | 4 | 3 |
| Доктор | `doctor` | 2 | 4 | 8 | 5 | 6 | 8 | 5 | 2 |
| Химик | `chemist` | 2 | 4 | 9 | 6 | 7 | 7 | 3 | 2 |
| Рыцарь | `knight` | 8 | 3 | 2 | 4 | 3 | 4 | 10 | 6 |
| Друид | `druid` | 3 | 4 | 4 | 7 | 6 | 5 | 5 | 9 |

### Основная Характеристика И Уникальная Идентичность Класса

SCRUM-256 закрепил data-driven framework `ProgressionData.CLASS_MECHANIC_IDENTITIES`.
Он хранит главный атрибут, короткую боевую фантазию, mechanic tags и 3 weapon identity
для каждого класса. Таблица служит контрактом для задач 0.1.5 по уникальным атакам,
а не меняет баланс сама по себе.

| Класс | Главный атрибут | Уникальная идентичность | Внутренняя логика оружий |
| --- | --- | --- | --- |
| Берсерк | Сила | Телесный напор: тяжелый melee press, фронтальные зоны и контроль толпы | Меч = длинный frustum, топор = широкая ближняя дуга, молот = центральный AoE slam |
| Солдат | Восприятие | Тактическая линия огня: сектор, дистанция, подавление и удержание позиции | Винтовка = линия подавления, граната = delayed explosive, штык = brace-стойка |
| Вор | Ловкость | Уловка и темп: рикошеты, фантомный backstab, дым и экономические трюки | Монеты = ricochet, плащ = shadow backstab без смещения героя, дым = control/evasion zone |
| Элементалист | Интеллект | Стихийная формула: орбиты, разломы и отложенные стихийные удары | Орбы = orbit ticks, призма = rift control, метеор = delayed shard impacts |
| Снайпер | Восприятие | Точная ликвидация: дальность, метки, kill-zone и пробивающие траектории | Винтовка = lockshot, прицел = kill-zone, патроны = split round |
| Священник | Знание | Священная формула: печати, ward-пульсы, цепи и sustain через урон | Реликварий = sanctify, кадило = wards, колокол = prayer chain |
| Биолог | Знание | Биореакция: споры, анализ образцов и симбиотические сети | Линза = spore bloom, инъектор = sample analysis, семя = symbiote web |
| Робот | Выносливость | Бронеконтур: магнитное удержание, компрессия и реакторное давление | Якорь = magnet pull, пресс = compression line, ядро = reactor vent |
| Инженер | Лидерство | Мастерская приказов: устройства работают как управляемая команда | Ключ = sentry link, дрон = repair support, мины = route control |
| Темный маг | Интеллект | Темная формула: проклятия, лучи, взрывы и распад пространства | Книга = double AoE projectile, череп = homing DoT curse, жезл = pierce beams |
| Гитарист | Лидерство | Сценический контроль: ритм, волны, deploy-усилители и отталкивание | Электро = directed wave, бас = circular pulse, амп = deploy pulses |
| Ассасин | Ловкость | Критический танец: критовые окна, теневые всплески и тонкие poison-линии | Чакрамы = boomerang corridor, кинжалы = stab flurry, струна = poison line |
| Рейнджер | Восприятие | Охотничья стойка: подготовка, траектория и дальний контроль | Арбалет = charged shot, лук = charged fan, капкан = deploy trap |
| Доктор | Знание | Клинический drain: лечение через урон, чума и хирургический риск | Зелье = healing link, шприц = plague DoT link, пила = melee sustain |
| Химик | Интеллект | Алхимическая цепь: реагенты, pools, облака и комбо-взрывы | Пыль = spark cloud, колба = acid pool, гомункул = temporary summon |
| Рыцарь | Выносливость | Щитовая клятва: блок, контратака и удержание линии | Копье = long strip, щит = frontal bash/block, кистень = circular holy control |
| Друид | Лидерство | Командование стаей: питомцы, тернии и тотемы под приказами | Амулет = commanded pets, посох = briar zone, тотем = support pulses |

### Производные Параметры

| Параметр | ID в коде | Что делает |
| --- | --- | --- |
| Урон | `damage` | Основной физический урон |
| Магический урон | `magic_damage` | Урон Темного мага |
| Урон звуковой волны | `sound_wave_damage` | Урон Гитариста |
| Скорость атаки | `attack_speed` | Уменьшает интервалы атак: итоговый интервал = `base_fire_interval / attack_speed`, минимум 0.18с |
| Возвышение | `ascension_level` | Метапрогрессия 1-5 на персонажа; кумулятивные модификаторы из `ASCENSION_LEVELS` применяются при старте забега |
| Шанс крита | `crit_chance` | Вероятность критического удара |
| Множитель крита | `crit_damage_multiplier` | Сила критического удара |
| Скорость движения | `move_speed` | Скорость игрока |
| Уворот | `dodge` | Шанс избежать входящий урон; проверяется в `Player.take_damage`, при успехе урон и invuln-window не применяются, показывается «Промах!». С 0.1.5 использует diminishing returns и cap 55%. |
| Защита | `defense` | Снижает получаемый урон; с 0.1.5 использует diminishing returns и cap 62%. |
| Максимальное здоровье | `health_point` | Max HP игрока |
| Дальность атаки | `attack_range` | Дистанция поиска и поражения целей |
| Радиус AoE | `aoe_radius` | Размер круговых и взрывных зон |
| Радиус подбора | `pickup_radius` | Магнит опыта и денег |
| Урон DoT | `dot_damage` | Урон тиков |
| Скорость DoT | `dot_speed` | Частота / темп тиков |
| Скорость снарядов | `projectile_speed` | Скорость projectile-оружия |
| Радиус ауры | `aura_radius` | Размер аур и зон поддержки |
| Сила баффов | `buff_power` | Мощность эффектов поддержки |
| Сила отталкивания | `knockback_power` | Knockback от звуковых и силовых атак |
| Количество призывов | `summon_amount` | Сила призывов/устройств: количество, урон, живучесть и темп summon-role оружия |

### Оружие

| Класс | Оружие | ID | Тип атаки | Ключевая механика |
| --- | --- | --- | --- | --- |
| Берсерк | Двуручный меч | `sword` | `frustum` | Усеченный замах 90°, радиус 600, base width 150, outer width 1200, interval 0.58, damage x1.15 |
| Берсерк | Двуручный топор | `axe` | `sweep` | Дуга 140 градусов радиуса 320, damage x0.85 |
| Берсерк | Двуручный молот | `hammer` | `circle` | Радиус 100, damage x0.55; экспоненты апгрейдов 1.25 (AoE) / 1.15 (damage), фактическая круговая зона capped at 145 px — сильный ближний AoE без экранного AFK-радиуса |
| Солдат | Аркебуза строя | `soldier_rifle` | `suppression_burst` | 3 быстрых выстрела по линии: первая цель получает полный урон, соседи в коридоре получают reduced suppression damage |
| Солдат | Граната с фитилем | `soldier_grenade` | `grenade_cook` | Телеграф зоны, короткая задержка фитиля, взрыв с falloff урона к краю |
| Солдат | Штык-стойка | `soldier_bayonet` | `bayonet_brace` | Оборонительный forward brace: враг получает один укол за стойку и knockback |
| Вор | Кошель Рикошета | `thief_coin_pouch` | `coin_ricochet` | Монета цепляется по ближайшим целям, урон убывает по цепи, первые попадания крадут немного золота |
| Вор | Плащ Захода | `thief_shadow_cloak` | `shadow_backstab` | Фантомный удар за ближайшей целью наносит усиленный урон и цепляет врагов рядом, не двигая героя |
| Вор | Дымовая Бомба | `thief_smoke_bomb` | `smoke_bomb` | Дымовая зона взрывается после короткой задержки, а Вор получает временный dodge-window |
| Элементалист | Кольцо Трех Стихий | `elementalist_orb_ring` | `elemental_orbit` | Орбитальные стихийные сферы наносят короткие AoE-тики вокруг героя |
| Элементалист | Призматический Фокус | `elementalist_prism_focus` | `prism_rift` | Крестовой разлом из двух лучей по ближайшей цели после короткого телеграфа |
| Элементалист | Ядро Метеора | `elementalist_meteor_core` | `meteor_shards` | Отложенный метеорный удар и вторичные осколочные взрывы вокруг цели |
| Снайпер | Винтовка Мертвого Глаза | `sniper_deadeye_rifle` | `sniper_lockshot` | Короткий прицел/телеграф, затем точный дальний луч по locked target и falloff по линии |
| Снайпер | Прицел Наводчика | `sniper_spotter_scope` | `sniper_kill_zone` | Маркирует kill-zone у ближайшей цели и вызывает несколько точных sky-beam попаданий по врагам внутри |
| Снайпер | Осколочные Патроны | `sniper_shatter_rounds` | `sniper_split_round` | Основной дальний выстрел раскалывается по соседним целям с убывающим уроном |
| Священник | Светлый Реликварий | `priest_reliquary` | `priest_sanctify` | Освящает ближайшую цель, затем знак взрывается по области и лечит часть нанесенного урона |
| Священник | Кадило Обета | `priest_censer` | `priest_ward` | Несколько защитных ward-пульсов вокруг героя наносят урон врагам рядом и дают малое лечение |
| Священник | Колокол Молитвы | `priest_chime` | `priest_prayer_chain` | Молитвенная цепь перескакивает между врагами и возвращает sustain от нанесенного урона |
| Биолог | Споровая Линза | `biologist_spore_lens` | `bio_spore_bloom` | Три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон |
| Биолог | Инъектор Образцов | `biologist_sample_injector` | `bio_sample_dart` | Инъектор берет образец у цели, затем delayed analysis pulses бьют цель и ближайшие ткани |
| Биолог | Семя Симбионта | `biologist_symbiote_seed` | `bio_symbiote_web` | Первичная цель связывается с соседними врагами симбиотической сетью и делит биоурон |
| Робот | Магнитный Якорь | `robot_magnetic_anchor` | `robot_magnetic_anchor` | Ставит якорь на ближайшую цель, затем стягивает врагов к центру и бьет импульсом |
| Робот | Гидравлический Пресс | `robot_hydraulic_press` | `robot_compression_line` | Две силовые губки сходятся по линии атаки, прижимая врагов к оси и нанося урон коридором |
| Робот | Реакторное Ядро | `robot_reactor_core` | `robot_reactor_vent` | Четыре направленных выброса вокруг корпуса чистят ближний круг и отталкивают толпу |
| Инженер | Ключ Часового | `engineer_sentry_wrench` | `engineer_sentry_link` | Временная турель сама выбирает цели и бьет их точечными лучами |
| Инженер | Ремонтный Дрон | `engineer_repair_drone` | `engineer_repair_drone` | Цепная дуга по врагам возвращает часть нанесенного урона в ремонт |
| Инженер | Минная Сетка | `engineer_pressure_mines` | `engineer_pressure_mines` | Три мины веером срабатывают отдельно при касании врагом |
| Темный маг | Темная книга | `dark_book` | `aoe_projectile` | 2 снаряда в две ближайшие цели, взрыв по области |
| Темный маг | Проклятый череп | `cursed_skull` | `homing_curse` | Самонаведение, 5 DoT-тиков и небольшой splash по области цели |
| Темный маг | Темный жезл | `dark_wand` | `beam` | 2 pierce-луча веером (шаг 14 градусов) |
| Гитарист | Электрогитара | `electric_guitar` | `sound_wave` | Широкая волна и knockback; пассив +15% attack speed |
| Гитарист | Бас-гитара | `bass_guitar` | `pulse` | Частый слабый контроль-пульс: x0.30 урона, interval 0.85, сильный knockback |
| Гитарист | Усилитель | `sound_amp` | `amp` | Деплой на ~7с, самостоятельные пульсы каждые 1.1с, лимит 1 + floor(Лидерство/4) |
| Ассасин | Чакрамы | `chakrams` | `boomerang` | Коридор туда/обратно; crit-friendly, критовые попадания запускают неподвижный теневой всплеск у цели |
| Ассасин | Теневые кинжалы | `shadow_daggers` | `stab_flurry` | Быстрые короткие multi-stabs по ближайшим целям, высокий crit + теневой burst у цели |
| Ассасин | Ядовитая струна | `venom_wire` | `dot_beam` | Тонкая poison-линия/гаррота с DoT и теневым всплеском на крите |
| Рейнджер | Лунный арбалет | `moon_crossbow` | `beam` | Заряжаемый piercing shot: неподвижная стойка повышает урон |
| Рейнджер | Грозовой длинный лук | `storm_longbow` | `beam` | Заряжаемый веер дальних лучей, line control |
| Рейнджер | Охотничий капкан | `hunter_trap` | `trap` | Deploy trap: burst + knockback; stance charge усиливает подготовку |
| Доктор | Зелье восстановления | `restore_potion` | `drain_link` | Drain-связь к цели; часть нанесенного урона лечит Доктора |
| Доктор | Чумной шприц | `plague_syringe` | `drain_link` | Тонкая чумная связь, poison DoT + lifesteal |
| Доктор | Костяная пила | `bone_saw` | `stab_flurry` | Ближний saw/flurry, bleed-like DoT, lifesteal от урона |
| Химик | Взрывная пыль | `blast_powder` | `aoe_projectile` | AoE explosion + spark cloud; разные cloud elements дают combo explosion |
| Химик | Кислотная колба | `acid_flask` | `aoe_projectile` | Poison/acid pool, большая DoT-zone, combo с другим элементом |
| Химик | Склянка гомункула | `homunculus_vial` | `summon` | Гомункул `tank_control`: живучий temporary minion от magic damage, отталкивает цель |
| Рыцарь | Копье | `long_spear` | `strip` | Длинный точечный strip, block/counter passive |
| Рыцарь | Башенный щит | `tower_shield` | `sweep` | Shield bash / frontal control, самый сильный block reduction |
| Рыцарь | Освященный кистень | `holy_flail` | `circle` | Medium circular heavy swing, сильнее counter damage |
| Друид | Амулет призыва | `summon_amulet` | `summon` | Beast pack `pack_damage`: быстрые питомцы от Leadership, команды attack_target/guard |
| Друид | Посох терний | `briar_staff` | `aoe_projectile` | Thorn zone, AoE DoT, crowd control |
| Друид | Вороний тотем | `raven_totem` | `amp` | Totem `support_totem`: пульсы контроля/поддержки, Leadership-scaled deploy limit |

### Summon / Deploy Roles

SCRUM-254 усилил призывателей через data-driven поля в weapon config:
`summon_role`, `summon_role_damage_multiplier`, `summon_health_multiplier`,
`summon_attack_interval`, `summon_speed_multiplier`, `summon_lifetime_multiplier`,
`summon_control_knockback` и `summon_support_heal_percent`.

| Role | Где используется | Поведение |
| --- | --- | --- |
| `pack_damage` | `druid/summon_amulet` | Быстрая стая: высокий темп, умеренная живучесть, малый контроль |
| `tank_control` | `chemist/homunculus_vial` | Более плотный одиночный миньон: больше HP, медленнее, отталкивает цель |
| `support_totem` | `druid/raven_totem` | Тотем-поддержка: deploy-пульсы, контроль и малый sustain |
| `engineer_sentry` | `engineer/engineer_sentry_wrench` | Устройство-турель: автономные beam shots, роль считается summon archetype |
| `support_drone` | `engineer/engineer_repair_drone` | Support chain: ремонт от урона + малый дополнительный sustain |

`ProgressionData.weapon_archetype()` считает оружие с `summon_role` как `summon`.
Чистые summon-оружия (`summon_damage_multiplier` без `attack_mode`) в budget harness
не получают невидимый direct hit: их DPS оценивается через миньонов. Итоговый tuned
budget после SCRUM-254: `druid/summon_amulet` solo 47.98 / 5T 149.87,
`chemist/homunculus_vial` solo 38.65 / 5T 224.19, `engineer_sentry_wrench`
solo 41.42 / 5T 161.25.

### Status Effects / Auras

SCRUM-245 добавил `scripts/status_effects.gd` как общий runtime-модуль для аур,
баффов и дебаффов. Статусы хранятся на цели в meta `status_effects` и имеют:
`duration`, `remaining`, `stacks`, `max_stacks`, `stack_mode`, `dot_damage`,
`dot_interval`, `speed_multiplier`, `damage_multiplier`,
`damage_taken_multiplier`, `marker_color`.

| Status | Источник | Эффект |
| --- | --- | --- |
| `arcane_vulnerability` | Темный маг, Элементалист on-hit | Короткая уязвимость к входящему урону, до 2 stacks |
| `toxic_debuff` | Химик, Доктор, Ассасин, Биолог on-hit | Малый DoT, до 2 stacks |
| `staggered` | Солдат, Рыцарь, Робот on-hit | Короткое замедление врага |
| `command_aura` | Гитарист/Друид/Инженер aura на союзниках | Урон и скорость союзников слегка выше |
| `command_pressure` | Гитарист/Друид/Инженер aura на врагах | Замедление и малая уязвимость врагов внутри aura radius |
| `class_aura_focus` | Support/self aura | Малый self speed/focus buff |

Коэффициенты мягкие и не должны ломать global DPS/TTD gates; focused coverage:
`tests/status_effects_aura_test.gd`.

### Runtime-Требования К Оружию

- Временные visuals классового оружия регистрируются в группе `player_weapon_effects`.
- При смене оружия, персонажа, смерти, выходе из забега и world cleanup старые weapon effects должны удаляться.
- `sound_amp` не должен оставлять объект усилителя или pulse-текстуры после перехода на другого персонажа/оружие.
- Deployables новых классов (`hunter_trap`, `raven_totem`) используют тот же cleanup contract через `player_weapon_effects`.
- Новые UI/icon uses должны идти через `scripts/ui_icon_registry.gd`, потому что registry кэширует Texture2D.

### Группы Производных Параметров В Escape Menu

`scripts/pause_stats_menu.gd` показывает производные параметры не общей таблицей, а компактными группами:

| Группа | ID | Параметры |
| --- | --- | --- |
| Физический урон | `physical_damage` | `damage`, `attack_speed`, `crit_chance`, `crit_damage_multiplier`, `knockback_power` |
| Магия | `magic_damage` | `magic_damage`, `aoe_radius`, `projectile_speed`, `attack_range`, `range_multiplier` |
| Звук / Контроль | `sound_control` | `sound_wave_damage`, `aura_radius`, `buff_power`, `knockback_distance` |
| Яд / DoT | `dot_poison` | `dot_damage`, `dot_speed` |
| Выживаемость | `survival` | `health_point`, `defense`, `dodge`, `move_speed`, `absorb`, `regeneration`, `vampiric_amount`, `vampiric_chance` |
| Приспешники / Поддержка | `summons_support` | `summon_amount`, `pickup_radius`, `ultimate_multiplier` |

Базовые характеристики (`strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`) остаются отдельным compact block под кнопками Escape menu. Tooltip каждой строки/плитки берется из `STAT_DEFINITIONS`: описание, формула и `influences`.

### Награды За Уровень

Текущая система выдает 3 варианта награды. Один полученный уровень дает ровно один выбор; при нескольких накопленных уровнях игрок получает несколько последовательных окон. Набор из 3 вариантов фиксируется в `level_up_offer` и не рероллится при закрытии/повторном открытии окна. Окно можно закрыть через «Позже» без потери выбора; нижняя SCRUM-390 plus-кнопка с pending-бейджем возвращает к тому же набору и является единственной level-up точкой входа при `pending_level_ups > 0`. FAB докачки в этом состоянии скрыт и возвращается только для докачки атрибутов за золото при отсутствии pending-уровней. Вес обычных наград считается через `ProgressionData.level_up_reward_weight()`: награда получает зависимый базовый атрибут, затем умножается на значение и позицию этого атрибута в `ATTRIBUTE_PRIORITIES` класса; floor сохраняет шанс любых вариантов.

В пуле есть:
- прямой урон;
- скорость атаки;
- максимальное HP;
- скорость движения;
- радиус AoE;
- дальность атаки;
- радиус подбора;
- защита;
- магический фокус;
- отталкивание;
- редкие основные характеристики (`strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`) с шансом около 5% на слот и визуальной rare-пометкой;
- артефакты.

При открытии level-up окна игра должна полностью ставиться на паузу.

### Артефакты И Магазин

В `ProgressionData` есть расширенный пул артефактов:
- общие offensive/defensive/mobility/pickup предметы;
- предметы под Берсерка;
- предметы под Темного мага;
- предметы под Гитариста;
- риск-награда предметы;
- предметы магазина.

Магазин показывает 4 предложения и поддерживает покупку нескольких предметов за один визит.

### Враги

| Архетип | Поведение | Баланс-роль |
| --- | --- | --- |
| Melee | Идет к игроку и бьет контактной атакой с windup | Базовое давление |
| Shooter | Держит дистанцию и стреляет | Редкая угроза позиционирования |
| Runner / Biter | Быстрый маленький враг | Давление и пачки 3-4 |
| Bruiser / Shield | Медленный жирный враг | HP-стена и контроль маршрута |
| Summoner / Bone Shaman | Призывает маленьких мобов | Эскалация плотности |
| Mage / Spitter | Ranged-варианты | Магическое/снарядное давление |
| Flying Runner | Летающее движение | Быстрый враг с hover-профилем; ямы отключены в текущей версии |

У наземных и летающих монстров collision mask сейчас учитывает только solid-стены арены. Pit layer и ямы отключены вместе с колоннами до будущего редизайна препятствий.

### Элитки

| Элитка | Уникальное поведение |
| --- | --- |
| Armored | Щит, снижение урона, высокая живучесть |
| Stalker | Рывок к игроку |
| Poisoned | Ядовитая зона после предупреждения |
| Commander | Аура усиления ближайших врагов |

Элитные враги должны быть случайными, заметно жирнее и опаснее обычных.

Обновление 2026-06-12: элитки используют общий `ProgressionData.stage_scale(route_stage)`, получают больший HP-бюджет, усиленный урон, более частые уникальные атаки и meta-флаг второй фазы на 50% HP. Победа над элиткой открывает экран выбора 1 из 3 артефактов; шанс tier-2/tier-3 растет с глубиной акта.

Обновление SCRUM-260 (2026-06-13): размеры enemy-rank вынесены в
`ProgressionData.ENEMY_SIZE_PROFILES`. Мини-элитки свиты Возвышения используют
`mini_elite` scale 1.05, карточные элитки узлов маршрута — `elite` scale 1.68,
боссы — `boss` scale 1.90. Профиль записывается в meta `epic_scale_profile`
до `_ready()`, поэтому scale согласованно тянет спрайт/rig, collision shape,
contact_range и HP-bar.

Обновление SCRUM-259 (2026-06-13): каталог mechanics элиток/боссов вынесен в
`ProgressionData.ENEMY_MECHANIC_CATALOG`, а конкретные наборы — в
`ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Каждая из 4 элиток и 5 боссов
получает runtime meta `unique_pattern_id`, `unique_pattern_title` и
`unique_mechanics`. `ELITE_ATTACK_CONFIGS` теперь domain-data, а не локальный
островок в `enemy.gd`. Дополнительные mechanics: `reflect_thorns`,
`mirror_double`, `gravity_pull`, `weakpoint_shell`, `healing_inversion`,
`split_spawn` плюс boss-specific telegraph zones.

### Боссы

| Босс | Паттерны |
| --- | --- |
| Rift Warden | Targeted volley, rift zone, summon riftlings, shield, dodge, gravity well |
| Disk Devourer | Dash, disk slam AoE, radial burst, vampiric bite, enrage |
| Bone Archon | Skeleton summons, skull fan, bone prison/wall with safe gap |
| Brood Mother | Brood summons, web slow zones, extra web pressure, phase-3 lunge |
| Ashen Colossus | Slam waves, ember fields, molten armor pulse, enrage |

Финальный boss-node выбирает одного из пяти боссов. Босс-файт не ограничен обычным combat timer.

Обновление 2026-06-12: боссы имеют 3 фазы по HP (`100-66%`, `66-33%`, `33-0%`), фазовые метки для HP-бара, ускорение паттернов на каждой фазе и danger-zone при переходе фазы. Победа над боссом гарантирует tier-3 артефакт и золото, масштабированное stage scale.

### Спавн И Плотность

Текущая философия спавна:
- меньше хаотичного наплыва со всех сторон;
- больше читаемых волн;
- ограничение active cap;
- снижение раннего окружения;
- рост количества и сложности с волнами;
- дальнобойных врагов меньше;
- маленькие враги иногда появляются пачками.

Текущий слой реализации использует боевую арену 2560x1440 с центром `ARENA_SIZE * 0.5`. Камера боя имеет zoom 1.12 и не показывает всю арену целиком даже при разрешении окна 2560x1440.

Параметры карты и плотности:
- ямы и колонны: отключены, активны только границы арены;
- spawn edge padding: 72 пикселя;
- spawn safe radius around player: 340 пикселей;
- projectile cleanup bounds: 2560x1440 плюс margin 180 пикселей.

### Stage Scale / Difficulty Economy (2026-06-12)

Data source: `ProgressionData.stage_scale(route_stage)`.

Единая кривая сложности и экономики:

`stage_scale = pow(1.18, route_stage) + 0.075 * route_stage`

Этот множитель используется в HP/уроне/скорости/плотности обычных волн, HP/уроне элиток и боссов, стоимости магазина/докачки/reroll, tier-weight выбора артефактов после элитки и золоте за победу над боссом.

SCRUM-260 оставляет глобальную кривую `stage_scale` без изменения, но карточные
элитки получают небольшой runtime buff поверх прежнего бюджета: HP x1.08 и
damage x1.06 в `_scale_elite_enemy`, чтобы новый больший силуэт ощущался
страшнее. Mini-elite HP/скорость/урон продолжают задаваться в
`MINI_ELITE_KINDS`, а их визуальный scale отделен от карточных элиток.

TTK-таблица из `build/balance_report.md` после прогона `tools/balance_harness.gd`:

| Route Stage | Stage Scale | Ordinary Wave TTK | Elite TTK | Boss TTK | Shop Cost x |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1.000 | 6.5s | 51.4s | 74.8s | 1.00x |
| 2 | 1.542 | 10.1s | 55.3s | 83.8s | 1.54x |
| 4 | 2.239 | 14.6s | 60.2s | 95.4s | 2.24x |
| 6 | 3.150 | 20.6s | 66.7s | 110.6s | 3.15x |
| 8 | 4.359 | 28.5s | 75.2s | 130.7s | 4.36x |
| 10 | 5.984 | 39.1s | 86.8s | 157.7s | 5.98x |

Это budget-estimate по выровненным class+weapon профилям. Реальный бой зависит от движения, уворотов, uptime оружия, pickup-паузы, выбранных артефактов и классовой механики.

### Пауза И UI Характеристик

Escape открывает крупное меню характеристик:
- слева кнопки продолжения, настроек и завершения забега;
- справа базовые и производные характеристики;
- каждая строка характеристики имеет иконку из `scripts/ui_icon_registry.gd`;
- при наведении показываются описания, формулы и влияния;
- значения могут подсвечиваться цветом по эффективности.

Та же системная пауза используется при выборе награды за уровень.

Боевой HUD минимальный, но полный для забега: SCRUM-390 resource panel показывает HP, XP, деньги, ULT, таймер/бейдж Возвышения и ряд артефактов; Level-up reward cards показывают иконку главного параметра, который меняет награда.

## Balance Sheet

| Классы |  |  |  |  |  |  |  |  |  |  |  |  |  | Type | value range | Формула | Attribute | Default | Addition | Berserk | Attribute | Default | Addition | Assassin | Attribute | Default | Addition | Темный маг | Attribute | Default | Addition | Рейнджер | Attribute | Default | Addition | Доктор | Attribute | Default | Addition | Химик | Attribute | Default | Addition | Рыцарь | Attribute | Default | Addition | Друид | Attribute | Default | Addition | Монстр Мили | Attribute | Default | Addition | Монстр Рендж | Attribute | Default | Addition | Монстр Чардж | Attribute | Default | Addition | Монстр Лекарь |
|  | Сила | Ловкость | Интеллект | Восприятие | Энергия | Знание | Выносливость | Лидерство |  |  |  |  |  | Plain | 1+ | ( Default + Addition ) * Сила / 10 | Damage | 15.0 | 0.0 | =S$2*(B11/10)+T$2*(B11/10) | Damage | 10.0 | 0.0 | =W$2*C11/10+X$2*C11/10 | Damage | 10.0 | 0.0 | =AA$2*(10*G11/100)+AB$2*(30*G11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*E11/100)+$T$2*(30*E11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*F11/100)+$T$2*(30*F11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*G11/100)+$T$2*(30*G11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*H11/100)+$T$2*(30*H11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*I11/100)+$T$2*(30*I11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*J11/100)+$T$2*(30*J11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*K11/100)+$T$2*(30*K11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*L11/100)+$T$2*(30*L11/100) | Damage | 10.0 | 0.0 | =$S$2*(10*M11/100)+$T$2*(30*M11/100) |
|  | Воин | Вор | Маг | Лучник | Лекарь | Ученый | Танк | Призыватель |  |  |  |  |  | Percent | 0-100% | Default + Addition + Ловкость / 100 | Crit Chance | 0.05 | 0.0 | =B12/100+T3+S3 | Crit Chance | 0.05 | 0.0 | =W3+C12/100+X3 | Crit Chance | 0.0 | 0.0 | =AA3+G12/100+AB$3*(10*G12/100) | Crit Chance | 0.0 | 0.0 | =E12/100+$T$3*(10*E12/100) | Crit Chance | 0.0 | 0.0 | =F12/100+$T$3*(10*F12/100) | Crit Chance | 0.0 | 0.0 | =G12/100+$T$3*(10*G12/100) | Crit Chance | 0.0 | 0.0 | =H12/100+$T$3*(10*H12/100) | Crit Chance | 0.0 | 0.0 | =I12/100+$T$3*(10*I12/100) | Crit Chance | 0.0 | 0.0 | =J12/100+$T$3*(10*J12/100) | Crit Chance | 0.0 | 0.0 | =K12/100+$T$3*(10*K12/100) | Crit Chance | 0.0 | 0.0 | =L12/100+$T$3*(10*L12/100) | Crit Chance | 0.0 | 0.0 | =M12/100+$T$3*(10*M12/100) |
|  | Берсерк | Ассасин | Темный маг | Рейнджер | Доктор | Химик | Рыцарь | Друид |  |  |  |  |  | Percent | 0-300% | 1 + ( Default + Addition ) * Ловкость / 20 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*B12/20+$T$4*B12/20 | Crit Multiplier | 2.0 | 0.0 | =1+W$4*C12/20+X$4*C12/20 | Crit Damage Multiplier | 2.0 | 0.0 | =1+AA$4*G12/20+AB$4*G12/20 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*E12/20+$T$4*E12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*F12/20+$T$4*F12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*G12/20+$T$4*G12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*H12/20+$T$4*H12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*I12/20+$T$4*I12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*J12/20+$T$4*J12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*K12/20+$T$4*K12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*L12/20+$T$4*L12 | Crit Damage Multiplier | 2.0 | 0.0 | =1+$S$4*M12/20+$T$4*M12 |
|  | Солдат | Вор | Элементалист | Снайпер | Священник | Биолог | Робот | Инженер |  |  |  |  |  | Plain | 0.1-10 | ( Default + Addition ) * 3 * Ловкость / 100 | Attack Speed (hits per sec) | 4.0 | 0.0 | =$S$5*(3*B12/100)+$T$5*(3*B12/100) | Attack Speed | 4.0 | 0.0 | =W5*(3*C12/100)+X5*(3*C12/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =AA5*(3*G12/100)+AB5*(3*G12/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*E12/100)+$T$5*(1+E12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*F12/100)+$T$5*(1+F12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*G12/100)+$T$5*(1+G12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*H12/100)+$T$5*(1+H12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*I12/100)+$T$5*(1+I12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*J12/100)+$T$5*(1+J12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*K12/100)+$T$5*(1+K12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*L12/100)+$T$5*(1+L12*3/100) | Attack Speed (hits per sec) | 1.0 | 0.0 | =$S$5*(10*M12/100)+$T$5*(1+M12*3/100) |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  | Percent | 0-80% | ( Default + Addition / 8 ) * Ловкость / 10 | Dodge | 0.1 | 0.0 | =$S$6/10*B12+B12*$T$6/80 | Dodge | 0.1 | 0.0 | =W$6/10*C12+C12*X$6/80 | Dodge | 0.1 | 0.0 | =AA$6/10*G12+G12*AB$6/80 | Dodge | 0.1 | 0.0 | =$S$6*E12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*F12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*G12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*H12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*I12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*J12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*K12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*L12/10+$T$6 | Dodge | 0.1 | 0.0 | =$S$6*M12/10+$T$6 |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  | Percent | 0-100% | Default + Addition + Ловкость | Move Speed | 100.0 | 0.0 | =$S$7+$T$7+B12 | Move Speed | 110.0 | 0.0 | =W$7+X$7+B12 | Move Speed | 100.0 | 0.0 | =AA$7+AB$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 | Move Speed | 100.0 | 0.0 | =$S$7+$T$7 |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  | Percent | 0-80% | ( Default + Addition / 8 ) * Выносливость / 10 | Defense | 0.1 | 0.0 | =$S$6/10*B17+B17*$T$6/80 | Defense | 0.1 | 0.0 | =W$6/10*C17+C17*X$6/80 | Defense | 0.1 | 0.0 | =AA$6/10*G17+G17*AB$6/80 | Defense | 0.1 | 0.0 | =($S$8*E17/20)+($T$8*E17/20)+($S$8*E11/20)+($T$8*E11/20) | Defense | 0.1 | 0.0 | =($S$8*F17/20)+($T$8*F17/20)+($S$8*F11/20)+($T$8*F11/20) | Defense | 0.1 | 0.0 | =($S$8*G17/20)+($T$8*G17/20)+($S$8*G11/20)+($T$8*G11/20) | Defense | 0.1 | 0.0 | =($S$8*H17/20)+($T$8*H17/20)+($S$8*H11/20)+($T$8*H11/20) | Defense | 0.1 | 0.0 | =($S$8*I17/20)+($T$8*I17/20)+($S$8*I11/20)+($T$8*I11/20) | Defense | 0.1 | 0.0 | =($S$8*J17/20)+($T$8*J17/20)+($S$8*J11/20)+($T$8*J11/20) | Defense | 0.1 | 0.0 | =($S$8*K17/20)+($T$8*K17/20)+($S$8*K11/20)+($T$8*K11/20) | Defense | 0.1 | 0.0 | =($S$8*L17/20)+($T$8*L17/20)+($S$8*L11/20)+($T$8*L11/20) | Defense | 0.1 | 0.0 | =($S$8*M17/20)+($T$8*M17/20)+($S$8*M11/20)+($T$8*M11/20) |
| Баланс | Двурук | Клинки | Череп | Луки | мед экип | ЧемГан | Меч | Посох |  |  |  |  |  | Plain | 0+ | Default + Addition | Absorb (Работает ПЕРЕД ВСЕМ) | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =W$9+X$9 | Absorb | 0.0 | 0.0 | =AA$9+AB$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 | Absorb | 0.0 | 0.0 | =$S$9+$T$9 |
|  | Берсерк | Ассасин | Темный маг | Рейнджер | Доктор | Химик | Рыцарь | Друид |  | Монстр Мили | Монстр Маг | Монстр Рендж | Монстр Лекарь | Plain | 1+ | ( Default * Выносливость / 4 ) + Addition | HealthPoint | 50.0 | 0.0 | =($S$10/4*B17)+($T$10) | HealthPoint | 50.0 | 0.0 | =(W$10*C17/4)+(X$10) | HealthPoint | 15.0 | 0.0 | =(AA$10*G17/4)+(AB$10) | HealthPoint | 15.0 | 0.0 | =($S$10*E17)+($T$10*E17) | HealthPoint | 15.0 | 0.0 | =($S$10*F17)+($T$10*F17) | HealthPoint | 15.0 | 0.0 | =($S$10*G17)+($T$10*G17) | HealthPoint | 15.0 | 0.0 | =($S$10*H17)+($T$10*H17) | HealthPoint | 15.0 | 0.0 | =($S$10*I17)+($T$10*I17) | HealthPoint | 15.0 | 0.0 | =($S$10*J17)+($T$10*J17) | HealthPoint | 15.0 | 0.0 | =($S$10*K17)+($T$10*K17) | HealthPoint | 15.0 | 0.0 | =($S$10*L17)+($T$10*L17) | HealthPoint | 15.0 | 0.0 | =($S$10*M17)+($T$10*M17) |
| Сила | 10.0 | 6.0 | 2.0 | 6.0 | 2.0 | 6.0 | 8.0 | 4.0 |  | 5.0 | 2.0 | 3.0 | 3.0 | Plain | 0+ | ( Default + Addition ) * Выносливость / 2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*B17/2 | Knockback Distance | 1.0 | 0.0 | =(W$11+X$11)*C17/2 | Knockback Distance | 1.0 | 0.0 | =(AA$11+AB$11)*G17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*E17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*F17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*G17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*H17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*I17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*J17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*K17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*L17/2 | Knockback Distance | 1.0 | 0.0 | =($S$11+$T$11)*M17/2 |
| Ловкость | 5.0 | 9.0 | 3.0 | 8.0 | 3.0 | 2.0 | 5.0 | 3.0 |  | 5.0 | 4.0 | 8.0 | 8.0 | Plain | 1 - 10 | Default + Addition + Лидерство | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+B18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+C18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+G18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+E18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+F18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+G18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+H18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+I18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+J18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+K18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+L18 | Summon Ammount | 0.0 | 0.0 | =$S$12+$T$12+M18 |
| Интеллект | 2.0 | 4.0 | 10.0 | 4.0 | 7.0 | 7.0 | 4.0 | 5.0 |  | 2.0 | 5.0 | 1.0 | 1.0 | Plain | 0+ | Default + Addition | Attack Range | 200.0 | 0.0 | =S13+T13 | Attack Range | 150.0 | 0.0 | =W13+X13 | Melee Range | 100.0 | 0.0 | =AA13+AB13 | Melee Range | 100.0 | 0.0 | =(AG14*($S$13+$T$13)/2)*E14/8 | Melee Range | 100.0 | 0.0 | =(AK14*($S$13+$T$13)/2)*F14/8 | Melee Range | 100.0 | 0.0 | =(AO14*($S$13+$T$13)/2)*G14/8 | Melee Range | 100.0 | 0.0 | =(AS14*($S$13+$T$13)/2)*H14/8 | Melee Range | 100.0 | 0.0 | =(AW14*($S$13+$T$13)/2)*I14/8 | Melee Range | 100.0 | 0.0 | =(BA14*($S$13+$T$13)/2)*J14/8 | Melee Range | 100.0 | 0.0 | =(BE14*($S$13+$T$13)/2)*K14/8 | Melee Range | 100.0 | 0.0 | =(BI14*($S$13+$T$13)/2)*L14/8 | Melee Range | 100.0 | 0.0 | =(BM14*($S$13+$T$13)/2)*M14/8 |
| Восприятие | 5.0 | 5.0 | 5.0 | 9.0 | 3.0 | 2.0 | 4.0 | 3.0 |  | 2.0 | 3.0 | 2.0 | 2.0 | Percent | 0-200% | 100% + Default + Addition | Range Multiplier | 0.0 | 0.0 | =1+$T$14+S14 | Range Multiplier | 0.0 | 0.0 | =1+W$14+X14 | Range Multiplier | 0.0 | 0.0 | =1+AA$14+AB14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 | Range Multiplier | 0.0 | 0.0 | =1+$T$14 |
| Энергия | 4.0 | 3.0 | 7.0 | 2.0 | 9.0 | 5.0 | 3.0 | 6.0 |  | 2.0 | 2.0 | 2.0 | 2.0 | Plain | 0+ | ( Default + Addition ) * Знание / 5 | Regeneration Tic per sec | 1.0 | 0.0 | =(B16*$S$15)/5 + $T$15*B16/5 | Regeneration Tic per sec | 1.0 | 0.0 | =(C16*W$15)/5 + X$15*C16/5 | Regeneration | 0.0 | 0.0 | =(G16+AA$15)/5 + AB$15*G16/5 | Regeneration | 0.0 | 0.0 | =(E16+$S$15)/5 + $T$15*E16/5 | Regeneration | 0.0 | 0.0 | =(F16+$S$15)/5 + $T$15*F16/5 | Regeneration | 0.0 | 0.0 | =(G16+$S$15)/5 + $T$15*G16/5 | Regeneration | 0.0 | 0.0 | =(H16+$S$15)/5 + $T$15*H16/5 | Regeneration | 0.0 | 0.0 | =(I16+$S$15)/5 + $T$15*I16/5 | Regeneration | 0.0 | 0.0 | =(J16+$S$15)/5 + $T$15*J16/5 | Regeneration | 0.0 | 0.0 | =(K16+$S$15)/5 + $T$15*K16/5 | Regeneration | 0.0 | 0.0 | =(L16+$S$15)/5 + $T$15*L16/5 | Regeneration | 0.0 | 0.0 | =(M16+$S$15)/5 + $T$15*M16/5 |
| Знание | 4.0 | 7.0 | 6.0 | 3.0 | 9.0 | 10.0 | 3.0 | 6.0 |  | 1.0 | 2.0 | 2.0 | 2.0 | Plain | 0+ | Default + Addition + Current Damage / 2 | Vampiric amount | 0.0 | 0.0 | =U2/10+$T$16+S16 | Vampiric amount | 0.0 | 0.0 | =Y2/10+X$16+W16 | Vampiric amount | 0.0 | 0.0 | =AC2/10+AB$16+AA16 | Vampiric amount | 0.0 | 0.0 | =AG2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =AK2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =AO2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =AS2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =AW2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =BA2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =BE2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =BI2/10+$T$16 | Vampiric amount | 0.0 | 0.0 | =BM2/10+$T$16 |
| Выносливость | 7.0 | 3.0 | 2.0 | 3.0 | 5.0 | 6.0 | 10.0 | 4.0 |  | 2.0 | 2.0 | 2.0 | 2.0 | Percent | 0%-50% | Default + Addition | Vampiric chance | 0.0 | 0.0 | =S17+$T$17 | Vampiric chance | 0.0 | 0.0 | =X$17+W17 | Vampiric chance | 0.01 | 0.0 | =AB$17+AA17 | Vampiric chance | 0.01 | 0.0 | =(E15+E16)*$S$17/10+(E15+E16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(F15+F16)*$S$17/10+(F15+F16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(G15+G16)*$S$17/10+(G15+G16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(H15+H16)*$S$17/10+(H15+H16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(I15+I16)*$S$17/10+(I15+I16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(J15+J16)*$S$17/10+(J15+J16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(K15+K16)*$S$17/10+(K15+K16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(L15+L16)*$S$17/10+(L15+L16)*$T$17/10 | Vampiric chance | 0.01 | 0.0 | =(M15+M16)*$S$17/10+(M15+M16)*$T$17/10 |
| Лидерство | 3.0 | 3.0 | 5.0 | 5.0 | 2.0 | 2.0 | 3.0 | 9.0 |  | 2.0 | 1.0 | 1.0 | 1.0 | Percent | 0%+ | ( Default + Addition ) * Знание / 10 | DoT Damage | 0.0 | 0.0 | =S$18*B16/10+T$18*B16/10 | DoT Damage | 0.0 | 0.0 | =W$18*C16/10+X$18*C16/10 |  |  |  | =AA$18*(10*G16/100)+AB$18*(30*G16/100) |
| SUM | =SUM(B11:B18) | =SUM(C11:C18) | =SUM(D11:D18) | =SUM(E11:E18) | =SUM(F11:F18) | =SUM(G11:G18) | =SUM(H11:H18) | =SUM(I11:I18) |  | 0.0 | 0.0 | 0.0 | 0.0 | Plain | 0.1-10 | ( Default + Addition ) * 3 * Знание / 100 | DoT Speed | 4.0 | 0.0 | =S19*(3*B16/100)+T19*(3*B16/100) | DoT Speed | 4.0 | 0.0 | =W19*(3*C16/100)+X19*(3*C16/100) | DoT Speed | 0.1 | 0.0 | =AA19*(3*G16/100)+AB19*(3*G16/100) | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |  | DoT Speed | 0.1 | 0.0 |
|  |  |  |  |  |  |  |  |  |  | =SUM(K11:K19) | =SUM(L11:L19) | =SUM(M11:M19) | =SUM(N11:N19) | Percent | 0%+ | Default + ( 100% + Addition% * Восприятие) * 10 | AoE Radius | 200.0 | 0.0 | =S20+(1+$T$20*B14)*10 | AoE Radius | 150.0 | 0.0 | =W20+(1+X$20*C14)*10 | AoE Radius | 1.0 | 0.0 | =AA20+(1+AB$20*G14)*10 | AoE Radius | 1.0 | 0.0 | =($S$20*E14+$T$20*E14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*F14+$T$20*F14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*G14+$T$20*G14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*H14+$T$20*H14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*I14+$T$20*I14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*K14+$T$20*K14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*L14+$T$20*L14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*M14+$T$20*M14)/2 | AoE Radius | 1.0 | 0.0 | =($S$20*N14+$T$20*N14)/2 |
| Сила | Макс Вес | Мили урон | Радиус Взрывов | Сила крита |  |  |  |  |  |  |  |  |  | Plain | 0+ | ( Default + Addition ) * Восприятие | Projectile speed | 20.0 | 0.0 | =S21*B14+T21*B14 | Projectile speed | 20.0 | 0.0 | =T21*C14+W21*C14 | Projectile speed | 400.0 | 0.0 | =X21*G14+AA21*G14 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 | Projectile speed | 400.0 | 0.0 | =$S$21+$T$21 |
| Ловкость | Скорость Бега | Скорость снарядов | Уворот | Шанс крита |  |  |  |  |  |  |  |  |  | Percent | 0-200% | Default + Addition | Ultimate Multiplier | 1.0 | 0.0 | =$S$22+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =W$22*1+X$22 | Ultimate Multiplier | 1.0 | 0.0 | =AA$22*1+AB$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 | Ultimate Multiplier | 1.0 | 0.0 | =$S$22*1+$T$22 |
| Интеллект | Увеличение Опыта | Сила маг урона | Маг\Хил Криты | Сила маг крита |  |  |  |  |  |  |  |  |  |  |  |  |  |  | DPS | =(U2*(1+U3)*U4)*U5 |  |  | DPS | =(Y2*(1+Y3)*Y4)*Y5 |  |  |  | =(AC2*(1+AC3)*AC4)*AC5 |  |  |  | =(AG2*(1+AG3)*AG4)*AG5 |  |  |  | =(AK2*(1+AK3)*AK4)*AK5 |  |  |  | =(AO2*(1+AO3)*AO4)*AO5 |  |  |  | =(AS2*(1+AS3)*AS4)*AS5 |  |  |  | =(AW2*(1+AW3)*AW4)*AW5 |  |  |  | =(BA2*(1+BA3)*BA4)*BA5 |  |  |  | =(BE2*(1+BE3)*BE4)*BE5 |  |  |  | =(BI2*(1+BI3)*BI4)*BI5 |  |  |  | =(BM2*(1+BM3)*BM4)*BM5 |
| Восприятие | Скорость Стрельбы | АоЕ радиус | Дальний урон | Магнит расходок |
| Энергия | Количество мп | Скорость регена | Вампиризм | Расход маны |
| Знание | Сила хила | Регенерация | Сила ядов/дотов | Скорость Тиков |
| Выносливость | Количество хп | Физ Маг Защита | Вес | Отталкивание |
| Лидерство | Количество самонов | Скорость самонов | Сила самонов | Усиление аур |
| Двурук |
| Клинки |
| Жезл |
| Луки |
| Скальпель |
| Гитара |
| ЧемГан |
| Меч |
| Посох |
| Винтовка |
| Отмычки |
| Сферы |
| Снайперка |  |  |  |  |  |  |  |  |  |  |  |  |  |  | https://github.com/topics/brotato |
| Жезл |
| Книга |
| Кость |
| Руки |
| Отвертка | Турели (дальний урон) | Роботы (мили масс) | Создание Щита (+Защита) | Хил Костюм (ХоТ) | Ловушки |
|  | Винтовка | Отмычки | Сферы | Снайперка | Жезл | Кость | Руки | Отвертка |
|  | Солдат | Вор | Элементаль | Снайпер | Священник | Биолог | Робот | Инженер |
| Сила | 9.0 | 3.0 | 2.0 | 6.0 | 3.0 | 4.0 | 7.0 | 7.0 |
| Ловкость | 7.0 | 10.0 | 3.0 | 8.0 | 1.0 | 3.0 | 7.0 | 2.0 |
| Интеллект | 1.0 | 6.0 | 9.0 | 2.0 | 4.0 | 9.0 | 7.0 | 10.0 |
| Восприятие | 8.0 | 7.0 | 4.0 | 10.0 | 6.0 | 1.0 | 7.0 | 2.0 |
| Энергия | 2.0 | 2.0 | 9.0 | 3.0 | 10.0 | 5.0 | 1.0 | 1.0 |
| Знание | 1.0 | 5.0 | 7.0 | 3.0 | 7.0 | 8.0 | 7.0 | 9.0 |
| Выносливость | 9.0 | 6.0 | 6.0 | 7.0 | 6.0 | 8.0 | 7.0 | 4.0 |
| Лидерство | 4.0 | 2.0 | 2.0 | 1.0 | 4.0 | 3.0 | 1.0 | 8.0 |
| SUM | =SUM(B84:B91) | =SUM(C84:C91) | =SUM(D84:D91) | =SUM(E84:E91) | =SUM(F84:F91) | =SUM(G84:G91) | =SUM(H84:H91) | =SUM(I84:I91) |

## Class Sheet

| Берсерк | Ассасин | Темный маг | Рейнджер | Аптекарь | Алхимик | Рыцарь | Друид |
| Двуручный меч | Теневые клинки | Книга | Лук Ветра | Свиток Лечения | Ядомёт | Меч и Щит | Посох Леса |
| Конусная атака 60 градусов радиус 200 | 2 Конусные атаки 45% вперед и назад от игрока, радиус 150 |
| Пассивка +10% урона | Пассивка +10% скорость атаки |
| Ульта - Крутилка: Меч крутится вокруг игрока со скоростью х2 от скорости атаки вокруг себя и наносит 100% урона, радиус 200 | Ульта - Безумие:  / Увеличение конусов до 70 градусов, увеличение скорости атаки на 30%, увеличение крит шанса на 20% |
| Двуручный топор | Чакрамы | Череп | Лунный арбалет | Зелье восстановления | Взрывная пыль | Копье | Амулет призыва |
| Конусная атака 120 градусов радиус 200 | 2 Вращающихся диска (1 оборот = скорость атаки / 2) радиус 40 вокруг игрока |
| Пассивка -10% урона | Пассивка 10% урона |
| Ульта - Бросок Топора: / Топор летит Вперед и Назад наносит 300% урона дважды (когда летит в 1 сторону и когда возвращается назад), Ширина 200, скорость 500, Дальность 500 | Ульта - Ускорение: / Ускорения вращения х2 от текущего значения. |
| Двуручный молот | Ядовитые кинжалы | Жезл | Огненный Лук | Маска вампиризма | Электрическая трость | Цеп | Семя защиты |
| АоЕ атака в виде круга перед собой радиус АоЕ - 200 | Конусная атака 60 градусов радиус 150, при поподании накладывает стак яда , который дамажит со скоростью ДоТ 30% от атаки, яды не критуют. Макс стаков 10. Каждый эффект яда делает 5 тиков |
| Пассивка +20% радиус АоЕ | Пассивка +10 ДоТ урон - 10 Физ урона |
| Ульта - Удар молота: / 4 Аоешки в 4 стороны, кастуется три раза со скоростью атаки 100% урон, радиус 200 | Ульта - Мастер ядов:  / Все удары накладывают макс количество стаков за удар |
| Пассивки Класса | Пассивки Класса | Пассивки Класса | Пассивки Класса | Пассивки Класса | Пассивки Класса | Пассивки Класса | Пассивки Класса |

## Лист3

| Gigapenis Gaming |  |  | Время |
| Стас С | Персонаж |
| Стас К | Интерфейс + Меню + Экраны + Карта | ГитЛаб + Проект на МИРО |
| Ваня Д | Монстры |
| Леха | Предметы |
| Фома | Модельки + Механики + Предметы |  | 12.0 |
|  |  | Comment |
| Trainings |
|  | создание уровня сцены возможно случайные преграды | случайно генерировать "ямы" и "колоны" | Ваня Демьянов |
|  |  | генерация босс арены (без скроллинга) | Ваня Демьянов |
|  |  | Создание прямоугольной арены | Ваня Демьянов |
|  | генерация случайных монстров в случайных местах | Генерация спавнов монстров | Ваня Демьянов |
|  |  | Милишники которые бегу в игрока | Стас Стреж |
|  |  | Рэндж которые стреляют в игрока и двигаются медленно от игрока до определенной дистанции | Стас Стреж |
|  |  | Чарджеры которые сукоряются на определенном радиусе в игрока | Стас Стреж |
|  |  | Жирные мобы | Стас Стреж |
|  |  | Матрешка Клоны 1-2-4 | Стас Стреж |
|  | движение монстров к игроку или случайно | Мили на игрока | Стас Стреж |
|  |  | Урон у монстров (параметры) | Стас Стреж |
|  |  | Рендж держутся на дистанции 250-300 и стреляют только там | Стас Стреж |
|  |  | чарджеры влетают на дистанции 100-150 | Стас Стреж |
|  | Игрок | Движение игрока по 4 координатам | Стас Стреж |
|  |  | Автоатака в ближайшего монстра или по прицелу (вектор на прицел) | Стас Стреж |
|  |  | Класс Мили | Стас Кирьянов |
|  | Класс Мили | Берсерк согласно механикам на странице 1 | Стас Кирьянов |
|  |  | Урон у игрока (параметры) | Стас Кирьянов |
|  |  | Классовые механики и формулы | Стас Кирьянов |
|  |  | Определение механик и формул | Сергей |
|  | урон по монстрам и игроку | Получение урона (боксы) | Сергей |
|  |  | Нанесение урона (боксы) | Сергей |
|  |  | Проджектайлы (боксы) | Сергей |
|  |  | Взрыва и анимации | Сергей |
|  |  | Звуки | Сергей |
|  | модификаторы для урона и механика защиты и уворотов | Защитные механики |
|  |  | Увороты |
|  |  | Вампирик |
|  |  | Регенирация |
|  |  | Тики ауры |
|  | подбор опыта и расходок, выпадение вещей из монстров | Опыт / Бабки дроп с мобов | Леха |
|  |  | Поднятие опыта на радиусе х (Радиус подбора = радиус ауры) | Леха |
|  | Таймер и завершение раунда | SCRUM-785: обычный бой 60с база +3с/стадию (макс 90, ×Возвышение), выжил = победа; элитка/босс — фикс. 300с «убей или проиграл» (таймаут с живой целью = поражение) | Леха |
|  |  | смерть игрока | Леха |

## Лист2

| MVP |
|  | Берсерк | Темный маг | Гитарист |  | Враг1 | Мили | Бич | Урон в мили |
|  | Оружие | Оружие | Оружие |  | Враг2 | Стрелок | Бич | Стреляет |
|  | Оружие | Оружие | Оружие |  | Враг3 | Самонер | Стреляет | Призывает |
|  | Оружие | Оружие | Оружие |
|  | Сила |  | Физ урон |
|  | Ловкость |  | Физ Крит Шанс |
|  | Интеллект |  | Физ Крит Урон |  | Экран выбора персонажа |
|  | Восприятие |  | Скорость атаки |  | Экран выбора оружия |
|  | Энергия |  | Маг урон |  | Экран игры |
|  | Вдохновение |  | Маг крит шанс |  | Экран ЛвлАп |
|  | Знание |  | Маг крит сила |  | Экран магазина |
|  | Выносливость |  | Вес |  | Экран смерти |
|  | Лидерство |  | Уворот |  | Экран победы |
|  |  |  | Скорость бега |
|  |  |  | Физ Защита |
|  |  |  | Маг Защита |
|  |  |  | Снижение урона |
|  |  |  | Хп |
|  |  |  | Количество самонов |
|  |  |  | Дальность выстрела |
|  |  |  | Реген хп |
|  |  |  | Вампирик |
|  |  |  | Скорость тиков |
|  |  |  | Скорость Ауры |
|  |  |  | Радиус Аур |
|  |  |  | Сила Бафов |
|  |  |  | Скорость снарядов |
|  |  |  | Радиус АоЕ |
|  |  |  | Сила ульты |


### Экономика 0.2: Цены, Тиры Артефактов, Аффинити (2026-06-11)

- **Магазин**: базовые цены уже включают pass x3.5 (пример: `shop_damage` 12 -> 42), а актуальная экономика 0.1.4 дополнительно применяет `ECONOMY_PRICE_MULTIPLIER = 1.10` внутри `stage_scaled_cost()`. Фактическая цена `shop_damage` на stage 0 — 47 золота. Артефакты в магазине стоят по тиру: Tier 1 — 30, Tier 2 — 55, Tier 3 — 95 (`COST_BY_TIER`) до stage/economy scaling.
- **Редкость**: вес появления в наградах/магазине по тиру — 1.0 / 0.45 / 0.12 (`TIER_WEIGHTS`, weighted-выбор без возврата).
- **Окно докачки после боя**: +1 к характеристике за `18 + 6 * route_stage` золота, затем `stage_scaled_cost`; reroll пары предложений за `6 + 2 * route_stage`, затем `stage_scaled_cost`, максимум 2 раза за окно; «Пропустить» — бесплатно.
- **Дроп 0.1.4 (откалибровано SCRUM-507)**: rewards назначаются по `DROP_CLASS_MULTIPLIERS`: ordinary < complex < heavy < mini_elite < elite < boss. Сложные цели дают x1.3 XP / x1.6 золота, жирные (bruiser/shield) около x1.75 XP / x2.2 золота относительно базы; мини-элитки x3.6 / x3.8; элитки x8 / x8.5; босс получает fixed reward `money 43.0`, умноженный на `stage_scale`. SCRUM-507 снизил boss-money 92→43 и поднял complex/heavy золото (1.35→1.6 / 1.85→2.2), чтобы доля boss-дропа в доходе маршрута упала с ~64% до ≤50%, а ранние/средние бои перестали обесцениваться («дожить до босса»). Route-level модель SCRUM-188 (`build/route_economy_xp_model.md`) после калибровки: affordable offers в коридоре ±25% по трём маршрутам (5.7/6.5/6.9), покупательная способность high/high/healthy, доля boss-золота 47/40/49%, XP-темп сохранён (20/25/20 level-up с учётом XP-кривой SCRUM-527).
- **XP-кривая 0.1.4**: следующий уровень считается через `ceil(current_requirement * 1.42 + 3)` вместо прежнего `ceil(req * 1.35 + 2)`, чтобы усиленный дроп сложных целей не разгонял количество level-up сверх цели.
- **Сила артефактов**: tier 1 усилен x2.5 от прежних значений (например +2 к стату -> +5, +20% урона -> +50%); даунсайды НЕ усилены. Tier 2 — двойные эффекты (усилены так же). Tier 3 (6 шт.) — билдообразующие механики: `echo_blast_every`, `extra_projectile`, `low_hp_damage_bonus`, `kill_heal_percent`, `thorn_reflect_multiplier`, `dodge_rush_bonus` (реализованы в player/class_weapon/combat_director/derived_parameters).
- **Триггерные (активные) артефакты (SCRUM-500)**: под-класс предметов с полями `active: true` +
  `trigger` (`on_low_hp`/`on_kill`/`on_crit`/`on_room_clear`/`on_take_hit`) + эффект-флаг в `mods`
  (суммируемый скаляр, НЕ `_multiplier`; раскладывается `_apply_reward_mods` как обычно). Это
  «специи» поверх `run_modifiers` — баланс-нейтральны (лечение/щит/мув-бафф/ситуативный бурст, без
  постоянного +damage), survivability/DPS-гейты не сдвигаются. Шанс/кулдаун обязательны для
  `on_kill`/`on_crit`/`on_take_hit` (анти-runaway). Флаги: `lowhp_guard`, `kill_explosion_chance`,
  `crit_speed_burst`, `room_clear_heal_percent`, `take_hit_pulse_chance`, `kill_streak_heal_every`,
  `lowhp_regen_bonus`. Runtime-анкеры: `player.take_damage` (on_take_hit/on_low_hp),
  `player.on_weapon_hit(enemy,dmg,was_crit)` (on_crit), `combat_director._on_enemy_died` →
  `player.on_enemy_killed` (on_kill), `combat_director._end_combat(victory)` (on_room_clear).
  Временные `*_active`-флаги (`dodge_rush_active`/`low_hp_active`/`crit_speed_burst_active`)
  обнуляются в `_store_player_snapshot`, чтобы бафф не «застывал» между узлами; латчи/кулдауны
  (`_lowhp_guard_used` и т.п.) сбрасываются в `configure_character`. Пометка «⚡ Активный» вшита в
  `description` (карточка не правилась). Покрытие: `tests/runtime_smoke_triggered_artifacts_test.gd`.
- **SCRUM-606 active artifacts**: `field_kit`, `vital_siphon`, `powder_charge`, `bulwark_echo`, `duelist_spur`
  add tier-2/cost55 variants on existing hooks with `room_clear_heal_percent`, `kill_heal_percent`,
  `kill_explosion_chance`, `take_hit_pulse_chance`, and `crit_speed_burst`.
- **SCRUM-609 curse relics**: `sacrifice_seal`, `hungry_amulet`, `berserk_totem`, `focus_lens`, `stone_hide`
  are tier-2/cost55 passive trade-off artifacts using supported mod keys only:
  crit/max HP, money/healing, damage/move speed, range/AoE, and defense/attack speed.
- **class_affinity**: с 2026-06-12 это тематика/исходная фантазия артефакта, а не запрет. `affinity_mods` применяются любому классу через class interpretation text; UI больше не показывает «Не работает»/«Работает вполсилы», а объясняет, как текущий класс использует эффект.


### Универсальная Полезность Атрибутов (2026-06-12)

- Карта «своего» урона класса: `CLASS_DAMAGE_PARAMETER` (berserk -> damage, dark_mage -> magic_damage, guitarist -> sound_wave_damage).
- Старая карта скрытия `STAT_CLASS_RELEVANCE` отключена: `is_stat_relevant()` возвращает `true`, `reward_pool(character_id)` и `level_up_rewards(character_id)` больше не фильтруют «чужие» статы/награды.
- Все базовые и производные параметры могут появляться у любого класса. Если параметр не является «родным» для текущего оружия, он получает runtime-интерпретацию через `ProgressionData.CLASS_INTERPRETATIONS` и hooks в `Player`/`ClassWeapon`.
- Превью изменений урона по-прежнему показывает классовый параметр (Магу — «Маг. урон», Гитаристу — «Звуковой урон»), но tooltip добавляет строку «Интерпретация», чтобы игрок понимал пользу чужого атрибута.
- Фиксация наборов (анти-реролл): набор level-up генерируется один раз на полученный уровень (`level_up_offer`), пара атрибутов и счетчик rerolls — в `attribute_offer`/`attribute_rerolls_left`, сбрасываются только победным флоу нового боя; ассортимент магазина уже фиксировался до ухода с узла.

Матрица runtime-интерпретаций:

| Атрибут / параметр | Универсальная интерпретация |
| --- | --- |
| `intelligence` / `magic_damage` | Физические классы получают зачарование удара: часть магического урона повторяется splash-взрывом вокруг цели. |
| `sound_wave_damage` / `aura_radius` | Не-гитаристы получают боевой клич: периодическая волна отталкивания рядом с героем; радиус и сила берутся из sound/aura параметров. |
| `knowledge` / `dot_damage` / `dot_speed` | Не-DoT классы добавляют малое bleed/burn/poison послевкусие к обычным ударам. |
| `leadership` / `summon_amount` | Не-саммонеры получают эхо-оружие/фантом/сокол/знамя: каждые несколько ударов происходит повторный echo hit. Друид продолжает скейлить питомцев напрямую. |
| `energy` / `ultimate_multiplier` | Ускоряет уникальные class cooldown/циклы: charge рейнджера, crit shadow burst ассасина, block/counter рыцаря, battle shout и будущие ultimates. |
| `strength` / `damage` | Магам/контроллерам дает физическую весомость: прямой урон, knockback и устойчивость снарядов/ударов. |
| `perception` / `attack_range` / `aoe_radius` / `pickup_radius` | Универсально расширяет дистанцию, зоны, magnet и читаемость buildcraft. |
| `endurance` / `defense` / `absorb` / `health_point` | Универсальная выживаемость; блоки и контратаки дополнительно используют эти значения у танковых билдов. |

SCRUM-243 закрепил карту «атрибут × архетип оружия» в
`ProgressionData.ATTRIBUTE_WEAPON_SYNERGY_MAP`. Формулы остаются мягкими:
стартовый DPS компенсируется `budget_damage_multiplier`, но прокачка любого
атрибута теперь меняет хотя бы один фактический параметр для melee/projectile/
beam/aoe/summon/aura оружия.

SCRUM-469 добавил class/stat-specific скалирование роста выше базовых статов:
перед формулами derived-параметров `ProgressionData.derived_parameters()` берёт
только положительный delta от base lvl1 и умножает его на
`CLASS_LEVEL_STAT_GROWTH_SCALARS`. Базовые статы и Base lvl1 остаются прежними;
нормализация касается только lvl20 optimum/random прокачки.

| Атрибут | Melee | Projectile | Beam | AoE | Summon | Aura |
| --- | --- | --- | --- | --- | --- | --- |
| Strength | Вес удара, stagger, knockback | Тяжелый снаряд и отдача | Стабильный канал | Центр взрыва | Сила спутников | Плотность волны |
| Agility | Темп замаха и crit | Перезарядка/скорость | Повтор каналов | Чаще зоны | Быстрее команды | Ритм pulse |
| Intelligence | Зачарование удара | Рунический снаряд | Сила луча | Формула зоны | Качество фамильяра | Магическая гармоника |
| Perception | Длина/ширина зоны | Дальность и цель | Дальность канала | Радиус зоны | Дальность приказа | Радиус сцены |
| Energy | Class tempo/ultimate | Цикл выстрелов | Питание канала | Частота pulse | Питание спутников | Ритм ауры |
| Knowledge | Bleed/burn след | Яд/горение | DoT после канала | Дольше зоны | Поддержка/sustain | Бафф/дебафф |
| Endurance | Стойка и block | Стабилизация отдачи | Удержание канала | Стоять в зоне | Прочные deployables | Центр ауры |
| Leadership | Эхо-оружие | Эхо-залп | Эхо-канал | Командные зоны | Главная сила призыва | Главная сила поддержки |


### Аудит Производных Параметров (полная таблица, 2026-06-11)

Статусы: «работает» — формула в derived_parameters и геймплейная проводка есть.

| Параметр | Формула (актуальная истина) | Реализация | Статус |
| --- | --- | --- | --- |
| damage | `(15*Str/10 + Int*0.18 + Per*0.10 + Energy*0.12 + Know*0.09 + End*0.08 + Lead*0.10) * weapon_mult * damage_mult * archetype_mult + flat` | derived_parameters -> физическое оружие + универсальный impact | работает |
| magic_damage | `(14*Int/10 + Energy*0.65 + Str*0.16 + Agi*0.08 + Per*0.12 + Know*0.14 + End*0.06 + Lead*0.10) * ...` | derived -> магия/зачарование | работает |
| sound_wave_damage | `(12*(Per+Energy)/12 + Lead*0.45 + Str*0.08 + Agi*0.08 + Int*0.09 + Know*0.10 + End*0.05) * ...` | derived -> звук/боевой клич | работает |
| attack_speed | `27*(Agi + Energy*0.18 + Per*0.10 + End*0.04)/100 * mult`; интервал = base_fire_interval / AS | derived -> все оружия | работает |
| crit_chance / crit_damage_multiplier | chance = effective_crit_chance(0.04+Agi*0.0075+flat*0.75), cap 0.55; mult = clamp(1.30+Agi*0.055+flat*0.75, 1.0, 2.75) | derived -> _rolled_damage всех оружий | работает |
| move_speed | (282 + Agi*6.2) * mult (+ dodge_rush) | derived -> player.speed | работает |
| dodge | effective_dodge(0.02 + Agi*0.010 + flat), diminishing returns, cap 0.55 | Player.take_damage | работает |
| defense | effective_defense(0.04 + End*0.018 + flat), diminishing returns, cap 0.62 | Player.take_damage | работает |
| health_point | 50*End/4 + flat) * mult | derived -> max_health | работает |
| attack_range / aoe_radius | `(weapon + Per*2.5/3.5 + малые Int/Know/End/Lead cross-бонусы) * mult` | derived -> оружия | работает |
| pickup_radius | 105 + Per*7 + flat | derived -> магнит pickups | работает |
| dot_damage / dot_speed | `(4+Know*0.65 + Int/Str/Per/Energy/Lead small cross)*mult`; speed = `0.65+Know*0.08+Energy/Agi small` | cursed_skull + universal DoT hook | работает |
| projectile_speed | `weapon + Per*18 + Agi*9 + Energy*4 + Know*2` | derived -> снаряды | работает |
| aura_radius | `(weapon_aoe + Lead*5 + Per/Energy/Know small) * mult` | derived (ампы/зоны/боевой клич) | работает |
| buff_power | `1 + Lead*0.025 + Know*0.006 + Energy*0.004` | derived; потребители — события/бафф-эффекты | работает |
| knockback_power | (weapon + End*4 + Lead*3) * mult | derived -> apply_knockback врагов | работает |
| summon_amount | `Leadership + Know*0.18 + Int*0.12 + Energy*0.10` | max_summons/echo weapons/support | работает |
| **absorb** | End*0.16 + softened flat; срез удара до защиты (мин. 35% проходит) | Player.take_damage | работает |
| **regeneration** | (0.22 + positive_flat*0.45) * (0.45 + Know/12) HP/с | Player._apply_regeneration | работает |
| **vampiric_chance** | награды, cap 0.22; источник — артефакт «Клык Пиявки» (tier 2) | Player.on_weapon_hit | работает |
| **vampiric_amount** | награды*0.55 + 3.5% нанесенного урона при проке, итоговое лечение ограничено `vampiric_heal_per_second_cap` 1.4/с (hard cap 2.6/с) | Player.on_weapon_hit | работает |
| **knockback_distance** | Knockback Power * End / 20 (отображаемая дальность) | НОВОЕ: derived; в бою действует knockback_power (реализованный баланс приоритетнее формулы таблицы) | работает (display) |
| **range_multiplier** | run-множитель дальности | НОВОЕ: выведен в derived для UI | работает |
| **ultimate_multiplier** | `1 + Energy*0.02 + all_other_stats*0.002 + награды` | НОВОЕ: усиливает class ultimate: урон, радиус, длительность или число целей | работает |

SCRUM-255 survivability rebalance: регенерация и вампиризм намеренно ослаблены, а defense/dodge/absorb получили diminishing returns. В синтетическом harness `tank/contact_swarm` упал с 321.0с до 38.5с TTD, regen у tank — с 1.57/с до 0.30/с. Расхождения с балансовой таблицей: knockback_distance в таблице задумывался боевым — оставлен отображаемым (бой использует knockback_power), vampiric_amount «Default + Current Damage / 2» сознательно заменен на малую долю урона с heal-per-second cap, чтобы вампиризм был поддержкой, а не бессмертием.

SCRUM-247 crit rebalance: крит остается значимым burst-слоем, но не заменяет стабильный урон. Flat-награды на шанс крита учитываются с эффективностью 75% и проходят через diminishing returns; шанс крита ограничен 55%, сила крита — 2.75x. Пример: Agility 20 + 50% crit chance + 80% crit damage раньше давал ~3.10x средний crit-factor, теперь ~1.92x. Подробный before/after: `build/crit_rebalance_scrum247_report.md`.

SCRUM-243 universal synergy: все восемь базовых атрибутов больше не имеют
«мертвых» сочетаний с архетипами оружия. `tests/runtime_smoke_test.gd`
проверяет матрицу 8×6: +4 к любому стату меняет хотя бы один effective parameter
для representative melee/projectile/beam/aoe/summon/aura оружия. Подробности:
`build/attribute_weapon_synergy_scrum243_report.md`.

SCRUM-251 melee identities: ближние оружия получили runtime hooks в
`ClassWeapon`/`BerserkWeapon` и budget-модель `_budget_melee_unique_bonus`.
Эффекты data-driven и не перемещают игрока автоматически:

| Hook | Назначение |
| --- | --- |
| `melee_close_bonus_radius` + `melee_close_damage_multiplier` | Компенсация риска вблизи цели. |
| `melee_execute_threshold` + `melee_execute_multiplier` | Добивание раненых целей для точных melee-оружий. |
| `melee_stagger_knockback_multiplier` | Дополнительный stagger/knockback без телепорта игрока. |
| `melee_arc_followup_radius` + `melee_arc_followup_multiplier` | Cleave/splash вокруг пораженной цели. |
| `melee_heal_percent_on_hit` | Малый sustain для явно рискованных sustain-оружий. |

Текущие назначения: меч/копье — execute, топор/кистень — cleave,
молот/щит/штык/робот — stagger, теневые кинжалы — close execute, костяная пила —
close sustain. DoT ticks вызывают `_damage_enemy(..., false)` и не повторяют эти
эффекты, чтобы не создавать каскад. Подробности:
`build/melee_unique_attacks_scrum251_report.md`.

### Ultimate Framework (2026-06-12)

Ульта заряжается от нанесенного урона и полученного урона до шкалы 100. Заряд масштабируется от Energy через `1 + Energy*0.025`. Нажатие InputMap action `ultimate` (default `R`, ребиндится в настройках) при полной шкале активирует классовую ульту и сбрасывает заряд в 0. Во время паузы заряд не копится, потому что gameplay/tweens и игрок находятся в pausable-процессе.

Data source: `ProgressionData.ULTIMATE_CONFIGS`. В каждом конфиге есть `title`, `description`, `duration`, `radius`, `damage`, charge rates и `boss_cap`. Boss cap ограничивает один ultimate-hit процентом `max_health` босса, чтобы ульта решала момент, но не убивала босса одной кнопкой.

| Класс | Ульта | Backend effect |
| --- | --- | --- |
| Берсерк | Неистовство | временный attack/move speed buff; каждый удар запускает эхо-волну |
| Темный маг | Темная буря | большой void burst и магический урон по радиусу |
| Гитарист | Соло | гигантский sound ring, урон и knockback |
| Ассасин | Танец клинков | серия критических slash-hit по ближайшим целям |
| Рейнджер | Лунный залп | залп beam-болтов по ближайшим целям в большой области |
| Доктор | Переливание | массовый drain; overheal переходит в absorb |
| Химик | Цепная реакция | алхимический burst по радиусу |
| Рыцарь | Бастион | короткая неуязвимость + ring counter damage |
| Друид | Зов стаи | временные союзники сверх лимита |

### Class DPS / Survivability Budget Harness (2026-06-12)

Data source: `ProgressionData.CLASS_BUDGET_PROFILES`, `ProgressionData.budget_tuning_for()`, `tools/balance_harness.gd`.

Харнесс запускается одной командой:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
```

Он пишет полный отчет в `build/balance_report.md` и считает 51 комбинацию класс+оружие: solo DPS за 30 секунд, 5-target DPS за 30 секунд, crowd-clear 5/10/20 и EHP. Вклад ульты учитывается как prorated contribution внутри 30-секундного окна.

Формула EHP для бюджетного сравнения: `HP / (1-defense) / (1-dodge) + absorb*6 + regeneration*30 + nerfed lifesteal estimate`; defense/dodge/absorb/regen берутся из SCRUM-255 helper-формул `ProgressionData`.

Runtime применяет один безопасный `budget_damage_multiplier` в `derived_parameters`, чтобы не менять identity-параметры оружия. Для проверки обеих осей harness хранит также `budget_solo_multiplier` и `budget_aoe_multiplier` в возвращаемом weapon config и использует их только в бюджетной модели отчета.

| Класс | Профиль | Survival | Damage budget | Solo target | 5-target target |
| --- | --- | --- | ---: | ---: | ---: |
| Берсерк | balanced | sturdy | 100% | 48.00 | 150.00 |
| Солдат | balanced | steady | 100% | 48.00 | 150.00 |
| Вор | balanced | fragile | 108% | 51.84 | 162.00 |
| Элементалист | aoe | fragile | 108% | 49.25 | 178.20 |
| Снайпер | solo | steady | 100% | 55.20 | 120.00 |
| Священник | balanced | steady | 92% | 41.95 | 144.90 |
| Биолог | aoe | fragile | 108% | 42.51 | 191.16 |
| Инженер | balanced | steady | 96% | 41.47 | 161.28 |
| Темный маг | aoe | fragile | 115% | 38.64 | 224.25 |
| Гитарист | aoe | control | 100% | 33.60 | 195.00 |
| Ассасин | solo | fragile | 115% | 71.76 | 120.75 |
| Рейнджер | solo | fragile | 115% | 71.76 | 120.75 |
| Доктор | balanced | tank | 85% | 40.80 | 127.50 |
| Химик | aoe | fragile | 115% | 38.64 | 224.25 |
| Рыцарь | balanced | tank | 85% | 40.80 | 127.50 |
| Друид | balanced | steady | 100% | 48.00 | 150.00 |

Before/after summary from `build/balance_report.md`:

| State | Covered pairs | Max combined deviation | Notes |
| --- | ---: | ---: | --- |
| Before tuning | 36 | 138.2% | Старые числа сильно выбивали DoT/deploy/summon, тяжелые melee weapons и новые class pipelines. |
| After tuning | 51 | 0.1% | Все пары проходят проверку solo/5-target ≤ ±10% в `runtime_smoke_test.gd`; новые классы Class Sheet держатся в пределах ±20% от Берсерка с мечом. |

Full before/after tables live in `build/balance_report.md` because they are generated artifacts and should be refreshed by the harness when formulas or weapon configs change.

### Final 0.1.5 Crowd-Clear Audit (SCRUM-262, 2026-06-14)

Data source: `ProgressionData.estimate_crowd_clear_budget()` and `tools/balance_harness.gd`.

Final 0.1.5 balance uses crowd-clear as a first-class gate in addition to solo DPS and standard 5-target DPS:

- Solo DPS corridor: every class+weapon pair must stay within +/-20% of its tuned profile target.
- Crowd-clear corridor: 5/10/20 target clear time must stay within +/-30% of the profile AoE target.
- Crowd fixture: 80 HP per target; `CCT = target_count * 80 / modeled_crowd_dps`.
- Every class must have at least one crowd-viable weapon inside the corridor.

Run commands:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/global_damage_balance_smoke_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd
```

Generated reports:
- `build/global_damage_balance_report.md` — focused gate output with solo/combined DPS and 5/10/20 CCT per pair.
- `build/balance_final_audit_0_1_5.md` — final audit summary, class viability table, crowd-clear table and standard budget table.

Current final result: PASS. All 51 class+weapon pairs stay inside solo and crowd-clear corridors. Worst solo deviation: -0.1% (`doctor/plague_syringe`). Worst crowd-clear deviation: +22.0% (`doctor/plague_syringe`, 20 targets), within the +/-30% gate. Every class has at least one viable crowd-clear weapon.

### Survivability Scenario Harness (SCRUM-190, 2026-06-13)

Data sources:
- `tools/survivability_harness.gd` — deterministic fragile/steady/sturdy/tank profile model anchored to `Player.take_damage`.
- `tests/survivability_scenario_test.gd` — verifies TTD monotonicity, mitigation-layer contribution, absorb behavior and one-hit damage parity with real player damage.
- `tools/survivability_scenarios.gd` — class roster projection using current `ProgressionData` character stats and each class' first weapon.

Commands:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/survivability_harness.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/survivability_scenario_test.gd
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/survivability_scenarios.gd
```

Generated reports:
- `build/survivability_report.md` for synthetic stat profiles and mitigation layer math.
- `build/survivability_scenarios_report.md` for real class roster projection.

The class projection is intentionally a measuring harness, not an auto-tuner. Current run result: 6 ok, 62 low, 0 high across contact swarm, shooter crossfire, elite burst and boss phase hazard. This flags current real-class durability against the chosen scenario bands as generally under-budget, especially elite burst and boss hazard cases. SCRUM-190 does not change balance constants; follow-up balance work should decide whether to raise survivability budgets, lower scenario incoming damage bands, or tune class-specific defensive affordances.

### Combat Target Query Cache (SCRUM-197, 2026-06-13)

Runtime target lookups should use `CombatTargetQuery` (`scripts/combat_target_query.gd`) instead of directly repeating `get_tree().get_nodes_in_group("enemies")` inside weapon/player hot paths. The helper keeps `enemies` as the canonical group and caches the valid `Node2D` list for the current process/physics frame.

Available helpers:
- `nearest(source, origin, range_limit, excluded_ids)`.
- `nearest_many(source, origin, range_limit, count, excluded_ids)`.
- `in_radius(source, origin, radius)` and `has_in_radius(...)`.
- `in_corridor(source, origin, direction, width, range_limit, back_allowance)`.
- `in_segment(source, start, finish, width)`.

Integrated systems: `ClassWeapon`, `BerserkWeapon`, player ultimates/secondary effects, `AllyMinion`, `SummonerWeapon`. Focused check: `tests/combat_target_query_cache_test.gd`; broad regressions still run through `tests/melee_weapon_targeting_test.gd` and `tests/runtime_smoke_test.gd`.


### Историческая Выдержка Class Sheet 0.2 — Статы И Баланс (2026-06-11)

Этот блок сохранен как исходная проектная выдержка. Текущие runtime-статы всех 17 классов находятся в таблице «Текущие Статы Персонажей» выше и в `scripts/progression_data_characters.gd`.

| Класс | Str | Agi | Int | Per | Energy | Know | End | Lead | HP | Speed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Элементалист | 2 | 4 | 9 | 7 | 8 | 6 | 3 | 5 | 48 | 258 |
| Снайпер | 6 | 8 | 2 | 10 | 3 | 3 | 7 | 1 | 62 | 252 |
| Священник | 2 | 4 | 8 | 6 | 7 | 9 | 5 | 6 | 66 | 246 |
| Биолог | 2 | 5 | 8 | 7 | 6 | 10 | 4 | 4 | 54 | 254 |
| Инженер | 4 | 5 | 7 | 6 | 6 | 6 | 5 | 10 | 70 | 246 |
| Ассасин | 6 | 10 | 2 | 6 | 3 | 4 | 5 | 4 | 52 | 285 |
| Рейнджер | 7 | 7 | 2 | 9 | 4 | 4 | 4 | 3 | 58 | 262 |
| Доктор | 2 | 4 | 8 | 5 | 6 | 8 | 5 | 2 | 64 | 248 |
| Химик | 2 | 4 | 9 | 6 | 7 | 7 | 3 | 2 | 50 | 252 |
| Рыцарь | 8 | 3 | 2 | 4 | 3 | 4 | 10 | 6 | 95 | 225 |
| Друид | 3 | 4 | 4 | 7 | 6 | 5 | 5 | 9 | 66 | 255 |

Баланс ±20% от Берсерка (расчетные DPS на стартовых статах; референс — меч Берсерка ~36.6 ед/с по линии):
ассасин ~35 (чакрамы x0.45, два прохода, частые криты), рейнджер ~32.5 (одиночная цель, дальность),
рыцарь ~29 (копье x3.0 при медленном темпе + танковость), доктор ~15.6 одиночный / ~45 по волне 3 целей + самолечение,
химик ~12 мгновенно + DoT-облака (волна ~40), друид ~41 (2 зверя по 55% sound_wave). Методика: melee/точные — одиночная цель,
AoE/DoT/саммоны — зачистка волны; точные замеры — плейтест.


### Возвышения 2.1 — Лестница Усложнений (SCRUM-516, 2026-06-28)

5 кумулятивных модификаторов в `ProgressionData.ASCENSION_MODIFIERS`; `ascension_difficulty_mods(level)` сворачивает 1..N в словарь (множители перемножаются, флаги — max). SCRUM-516 сжал прежние 10 тонких шагов в 5 более плотных: кумулятивно L5 даёт `enemy_hp_mult = 1.80` и `enemy_damage_mult = 1.66`. Нейтраль = `ASCENSION_DIFFICULTY_DEFAULTS` (уровень 0). Применение:
- enemy_hp_mult/enemy_damage_mult → `combat_director._scale_enemy_for_current_wave`;
- elite_hp_mult + elite_instant_phase (meta) → `_scale_elite_enemy`; boss_hp_mult/boss_extra_phase/boss_telegraph_mult (meta) → `_scale_boss_for_run`, читаются в `boss.gd` (4-я фаза при extra_phase, `_ascension_telegraph` укорачивает зоны);
- spawn_count_mult/spawn_cooldown_mult + first_wave_boost → `_spawn_enemy_wave`/`_next_spawn_cooldown`;
- round_duration_mult → `_current_round_duration`;
- price_mult → цены магазина (при генерации) и докачки (`_ascension_price`);
- reward_mult/healing_mult/player_max_hp_mult сворачиваются в `run_modifiers` игрока в `main.apply_ascension_bonuses` (на старте забега).

Прогресс: `meta_progression.record_boss_victory(state, char, run_level)` повышает уровень только если `run_level >= completed`; `selectable_max = completed + 1` (cap 5). Наградный трек меты — per-class `ASCENSION_LEVELS` по 5 уровней, применяются за пройденные уровни постоянно. Выбор уровня — селектор в hero select (клампится к `ascension_selectable_max` героя при пике), HUD-индикатор римской цифрой у таймера, кодекс-раздел «Возвышения».

### Мета-древо умений (SCRUM-696)

Общее для всех персонажей древо в `meta_progression.gd` (`SKILL_TREE`, data-driven) теперь является графом в стиле Path of Exile: у каждого узла есть `pos`, `kind`, `cost`, `effects` и неориентированные связи `adj`. Размер v2 — 85 узлов, 5 keystone, суммарный бюджет полной прокачки **100 метаочков** (`META_POINTS_CAP`). У каждого playable class id есть уникальная стартовая точка в `CLASS_ENTRY_NODES`; стартовые class entry nodes можно выделять сразу, остальные узлы открываются только как соседи уже выделенных узлов. «Глобальный уровень» = количество выделенных узлов (`global_level`), а доступный бюджет = `earned_meta_points(state) - allocated_meta_points(state)`.

Экономика метаочков: первый clear уровня возвышения 0..5 каждым классом даёт **1, 1, 2, 3, 4, 5** метаочков соответственно; повторы того же уровня не фармятся, общий cap заработка = 100. `skill_points` оставлен как compatibility facade для текущего UI и возвращает доступные метаочки. Save schema v2 хранит `meta_point_awards` и `skill_nodes`; старые linear-tree saves без schema получают безопасный respec: старые node ids сбрасываются, метаочки пересчитываются из `ascension_levels`.

Ветви и эффекты (`skill_modifiers(state)` — множители суммируются как `1.0+Σ`, флаги — max):
- **Богатство**: `money_gain_mult` (+опыт золота), `shop_price_mult` (скидка магазина), `start_gold_flat`, `attr_cost_mult` (удешевление докачки), capstone `guaranteed_rare_shop`.
- **Знания**: `xp_gain_mult`, `levelup_rerolls`, `attr_extra_options` (+варианты докачки), capstone `first_levelup_rare`.
- **Мощь**: `damage_mult`, `attack_speed_mult`, `ult_charge_mult`, `elite_boss_damage_mult`, capstone `ult_start_charge` (0.5).
- **Стойкость**: `max_health_mult`, `regeneration_flat`, `defense_flat`, `dodge_flat`, capstone `death_save`.

Публичный API для UI/QA: `node_list()`, `entry_map()`, `node_status(state, node_id)`, `allocate_node(state, node_id)` / compatibility `buy_skill_node`, `reset_skill_tree(state)`, `earned_meta_points`, `available_meta_points`, `allocated_meta_points`, `global_level`, `skill_tree_total_cost`.

Применение:
- Боевое подмножество → `player.apply_meta_skill_modifiers(mods)` в `run_modifiers` + предзаряд ульты (ч.2a).
- Эконом-флаги в UI: `shop_price_mult` → `_random_shop_items`, `attr_cost_mult` → `_ascension_price`, `attr_extra_options` → `_random_attribute_pair` (ч.5-7).
- Экран древа — пункт «Древо умений» в главном меню (`_show_skill_tree_screen`, состояния узлов/покупка/счётчик, ч.3); «+очко умений» на экране победы (ч.4).
- Старт забега (`main.apply_ascension_bonuses`): `player.apply_meta_skill_modifiers(skill_modifiers)` + начисление `start_gold_flat` в money (ч.12). SCRUM-150 завершён.

### Экран «Что нового» / патч-ноуты (SCRUM-159)

Data-driven патч-ноуты в `scripts/patch_notes_data.gd` (`PATCH_NOTES`, версии 0.1.0-0.1.4, новейшая первой) — только пользовательские русские формулировки, без внутренних ID/путей. API: `all_entries`, `latest_version`, `entries_since`/`has_new_since` (semver-сравнение). Экран `_show_skill...`→ `_show_patch_notes_screen` из главного меню (пункт «Что нового»): заголовки версий + буллеты, скролл, Назад/Escape. Бейдж «●» на пункте меню при `has_new_since(last_seen_version)`; открытие экрана записывает `last_seen_version = latest` (бейдж гаснет), не модалка. Персистентность `last_seen_version` — в `game_settings` (`user://`).

### Локализация И Глоссарий (SCRUM-210)

Текущий пользовательский язык — русский. Data-driven глоссарий расположен в `scripts/glossary.gd`: `TERMS[term_id] = {name, desc}`, API `term_ids()`, `definition()`, `name()`, `description()`, `is_valid_term()`. Покрыты 8 базовых характеристик, основные производные параметры и ключевые механики: периодический урон, крит, уклонение, защита, радиус подбора, вампиризм, Возвышение, артефакт, тематика класса, телеграф, элитка, мини-элитка, босс, ультимейт, призыв, перезарядка.

UI hook: `ui_screens.gd::_make_glossary_term_button(term_id, popup_context := false)` создает термин с пунктирной underline-меткой. В обычном экране tooltip доступен по hover; в popup-контексте tooltip показывается только при Alt+hover, чтобы не плодить вложенные подсказки. Кодекс получил вкладку «Глоссарий». Runtime smoke проверяет валидность глоссария, underline node и фактический `GlossaryTooltipPanel`.
