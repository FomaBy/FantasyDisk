# FantasyDisk Current Game State

Обновлено: 2026-06-12 (dev 0.2)

Этот документ описывает то, что уже есть в текущей версии игры. Он нужен агентам и разработчикам как быстрый фактический снимок проекта перед изменениями в геймплее, балансе, UI, персонажах, врагах, прогрессии и ассетах.

Канонические ID и игровые названия всех сущностей находятся в `docs/design/content_registry.md`. Любая новая сущность должна появляться там в той же задаче, в которой она добавляется в игру.

Domain docs для подробностей по областям:
- `docs/design/systems/combat.md`;
- `docs/design/systems/route_map.md`;
- `docs/design/systems/menus_ui.md`;
- `docs/design/systems/characters_weapons.md`;
- `docs/design/systems/enemies_bosses.md`;
- `docs/design/systems/progression_balance.md`;
- `docs/design/systems/visual_style_assets.md`;
- `docs/design/systems/animation.md`;
- `docs/design/systems/technical_architecture.md`.

## Проект

- Движок: Godot 4.
- Жанр: 2D top-down loot-action survival roguelite с RPG-билдкрафтом.
- Основная рабочая платформа: macOS. Релизные платформы: macOS (dmg) и Windows (x86_64 exe c embed_pck + NSIS-инсталлер).
- Версионирование: SemVer, источник истины `project.godot::config/version`; релизы — теги `vX.Y.Z` на main, разработка в `dev` (см. `docs/process/release_versioning.md`). Сборка: `tools/build_release.sh <версия>`.
- Основная сцена: `scenes/Main.tscn`.
- Основной управляющий скрипт: `scripts/main.gd` — тонкий координатор (state, пауза, основной цикл, делегирующие стабы для тестов). Он владеет модулями-компонентами: `scripts/ui_screens.gd` (меню/экраны/HUD/стили), `scripts/route_map_screen.gd` (генерация маршрута и экран карты), `scripts/combat_director.gd` (бой, спавн, баланс, арена, pickups). Модули — RefCounted с ссылкой `game` на main; общее состояние живет в main.
- Иконка приложения: `icon.svg`, подключена через `project.godot` `application/config/icon` и оформлена как fantasy disk emblem с золотым ободом и фиолетовым разломом.
- Главный игрок: `scenes/Player.tscn`, логика в `scripts/player.gd`.
- Smoke tests: `tests/runtime_smoke_test.gd`, `tests/animation_smoke_test.gd` и `tests/meta_progression_smoke_test.gd`.

## Основной Поток Игры

Текущий забег состоит из следующих этапов:

1. Главное меню.
2. Настройки видео и управления, если игрок их открывает.
3. Выбор персонажа.
4. Выбор оружия выбранного персонажа.
5. Генерация вертикальной маршрутной карты.
6. Выбор узла маршрута.
7. Бой или небоевой экран узла.
8. Получение опыта, денег, наград и артефактов.
9. Возврат на карту.
10. Финальный босс.
11. Победа или смерть.

Бой длится по таймеру `30 + 3 * route_stage` секунд (максимум 60), кроме босс-файтов, где бой идет до победы или смерти.

## Разрешения И Окно

Обновление 2026-06-11 (настройки v2):
- **Мониторы**: при 2+ экранах в настройках появляется дропдаун выбора монитора (номер + разрешение); окно переезжает на выбранный экран во всех режимах. При одном экране опция скрыта.
- **Оконные разрешения** применяются честно: размер клампится по `screen_get_usable_rect` выбранного монитора (учет масштаба ОС/дока/меню-бара), окно центрируется от origin usable rect (раньше центрирование игнорировало origin — на втором мониторе окно уезжало); разрешения больше монитора задизейблены в списке. Borderless занимает usable rect экрана.
- **Звук**: слайдеры Общая/Музыка/Эффекты (0-100%, шаг 5) + чекбоксы вкл/выкл музыки и эффектов; работают мгновенно через громкость шин AudioServer (Master/Music/SFX — шины Music и SFX создаются программно в AudioManager); mute не теряет значение слайдера.
- **Персистенс**: дисплей и звук сохраняются в `user://settings.cfg` (`scripts/game_settings.gd`) и применяются при старте.
- Экран настроек локализован (RU) и разделен на секции «Экран» / «Звук» / «Управление».

В настройках доступны:

| Разрешение | Статус |
| --- | --- |
| 1280x720 | Реализовано |
| 1600x900 | Реализовано |
| 1920x1080 | Реализовано |
| 2560x1440 | Реализовано |

Режимы окна:
- Windowed
- Borderless Window
- Fullscreen

## Игровая Карта И Камера

- Текущий размер боевой арены: 2560x1440.
- Центр арены считается от размера карты: `ARENA_SIZE * 0.5`, сейчас 1280x720.
- Камера использует combat zoom 1.12 и ограничена границами арены.
- На 1600x900 и 2560x1440 камера показывает только часть карты вокруг персонажа, а не всю арену целиком.
- При подходе к краям камера clamp-ится по 0..2560 и 0..1440 и не должна показывать пространство за картой.
- Границы карты рисуются видимой линией.
- Вокруг арены создаются физические стены.
- Зум камеры выбран так, чтобы карта ощущалась крупной, но угрозы вокруг игрока оставались читаемыми.

## Фоны Арены

В проекте есть фоновые изображения:

| Фон | Путь |
| --- | --- |
| Main Menu Epic Battle | `assets/backgrounds/main_menu_epic_battle.png` |
| Event Screen | `assets/sprites/ui/screens/screen_event_background.png` |
| Shop Screen | `assets/sprites/ui/screens/screen_shop_background.png` |
| Campfire Screen | `assets/sprites/ui/screens/screen_campfire_background.png` |
| Route Map Backdrop | `assets/backgrounds/route_map_backdrop.png` |
| Stone Garden | `assets/backgrounds/field_stone_garden.png` |
| Marsh | `assets/backgrounds/field_marsh.png` |
| Dry Road | `assets/backgrounds/field_dry_road.png` |
| Meadow | `assets/backgrounds/field_meadow.png` |

Фон арены выбирается случайно из доступного набора и может зависеть от типа узла карты.

Все 4 боевых фона (`field_stone_garden`, `field_marsh`, `field_dry_road`, `field_meadow`) нарисованы в нативном 2560x1440 — 1:1 к размеру арены, движок их не растягивает и они не мылятся. Pass 2026-06-12 заменил их на плоские top-down ground textures без объемных объектов и ложной перспективы: только низкоконтрастная почва, мох, трещины, трава, сухие дорожные следы и мелкая наземная фактура. Перегенерация: `tools/generate_ui_overhaul_visual_assets.py`.
`main_menu_epic_battle.png` используется стартовым экраном. `screen_event_background.png`, `screen_shop_background.png` и `screen_campfire_background.png` используются небоевыми экранами поверх читаемого затемнения.
`route_map_backdrop.png` используется full-screen route map hook-ом: это темный низкоконтрастный фон пустоши с туманным спокойным центром под узлы и линиями, а детали/силуэты вынесены к краям.

## Брендинг

| Ассет | Путь | Использование |
| --- | --- | --- |
| FantasyDisk App Icon | `icon.svg` | Project/application icon через `project.godot` |

## UI Visual Style

Основной UI pass 2026-06-12 использует reusable fantasy texture frames вместо дефолтных серых Godot/простых плоских панелей. Общие рамки лежат в `assets/sprites/ui/frames/global/` и подключены через helper `_global_texture_style()` в `scripts/ui_screens.gd`: большие панели, кнопки, карточки, HUD, route node buttons, level-up panel и hero/portrait frames используют единый dark wood/metal/bone/gold visual language. Escape stats menu продолжает использовать свой compact frame kit в `assets/sprites/ui/frames/escape/`.

Settings controls получили системные fantasy assets из `assets/sprites/ui/icons/system/`: checkbox checked/unchecked, slider track/grabber, arrows/back/settings/close icons. Иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_*`.

## Препятствия

Ямы и колонны отключены в текущей версии: они не генерируются, не создают collision blockers и не участвуют в pathing. На арене активны только физические границы карты. Препятствия могут вернуться позже после отдельного визуального и gameplay-редизайна.

## Маршрутная Карта

Маршрутная карта вертикальная. Акт состоит из 10 рядов активностей и финального ряда босса (`ROUTE_STEPS_TO_BOSS = 10`). Пулы типов узлов зависят от фазы акта: старт — почти только бои, ранние ряды — бои с редкими событиями/магазином, середина — смешанный пул, последние ряды перед боссом — больше элиток, а предпоследний ряд дает подготовку (костер/магазин).

Карта открывается отдельным full-screen экраном, а не маленьким виджетом внутри menu panel. Основной canvas `VerticalRouteMap` находится в большом `ScrollContainer`, который занимает почти весь экран под верхней статусной полосой. Горизонтальный скролл отключен: ширина канвы подгоняется под экран (`_route_map_canvas_size`), скролл и pan работают только по вертикали. Высота канвы растет с количеством рядов (~165px на ряд). Карта доступна целиком на 1600x900 и 2560x1440.

При открытии карты UI автоматически прокручивается к текущему доступному ряду: на старте забега нижний стартовый ряд виден сразу, а выше видно следующие развилки для планирования маршрута. Пустую область карты и сами узлы можно перетаскивать зажатой левой кнопкой мыши для панорамирования. Если движение мыши превышает drag threshold, клик по узлу подавляется и encounter не стартует случайно.

Линии маршрута тонкие и декоративные. Они игнорируют мышь, как и иконки внутри узлов, поэтому hover tooltip и клики по узлам работают после скролла/pan. На route screen компактный HP/XP/money HUD находится в том же UI-слое, чтобы отдельный fullscreen HUD CanvasLayer не перекрывал карту и не перехватывал клики.

Debug-режим карты: клавиша `F12` переключает `route_debug_free_pick`. При включении любой узел любого ряда становится доступным для клика в любой момент; выбор узла из другого ряда перематывает `route_stage` к этому ряду. В шапке карты показывается красный индикатор «DEBUG: свободный выбор». Режим выключен по умолчанию и не сохраняется между запусками.

Типы узлов:

| Тип | Назначение |
| --- | --- |
| `battle` | Обычный бой |
| `elite_battle` | Бой с элитным врагом |
| `shop` | Магазин |
| `event` | Случайное событие |
| `rest` | Костер / отдых |
| `boss` | Финальный босс |

Узлы имеют:
- название;
- цвет;
- рамку;
- PNG-иконку;
- tooltip при наведении;
- связи с узлами следующего ряда.

Иконки карты:

| Узел | Ассет |
| --- | --- |
| Обычный бой | `assets/sprites/map_icons/map_battle_skull.png` |
| Элитный бой | `assets/sprites/map_icons/map_elite_skull_bones.png` |
| Магазин | `assets/sprites/map_icons/map_shop_tent.png` |
| Событие | `assets/sprites/map_icons/map_event_question.png` |
| Костер | `assets/sprites/map_icons/map_rest_campfire.png` |
| Rift Warden | `assets/sprites/map_icons/map_boss_rift_warden.png` |
| Disk Devourer | `assets/sprites/map_icons/map_boss_disk_devourer.png` |

## Игрок

Игрок реализован как `CharacterBody2D`.

Ключевые свойства:
- движение по WASD / стрелкам;
- ручное управление перемещением;
- автоматические атаки оружия;
- сбор опыта и денег;
- уровень и награды;
- урон, уворот, защита, invulnerability window;
- визуальная анимация движения;
- socket для оружия;
- возможность проходить сквозь монстров.

Коллизия игрока не должна физически цепляться за enemy layers. Монстры наносят контактный урон отдельной атакой с задержкой.

## Персонажи

Первые три игровых персонажа используют polished stylized cartoon fantasy full hero sprites без квадратных placeholder-форм и без вида минимальных технических болванок. Новые шесть классов доступны в 0.2 foundation и прошли Design art-review как polished cartoon dark fantasy full-art. В бою `scripts/cutout_rig_2d.gd` собирает видимую фигуру из нарезанных кусков того же polished-арта (torso, arm_l/arm_r, leg_l/leg_r): в покое сборка пиксельно совпадает с исходным PNG, в движении конечности реально двигаются. Нарезка генерируется инструментом `tools/slice_rig_cutouts.py` в `assets/sprites/characters/cutout/`, метаданные частей — в сгенерированном `scripts/sliced_rig_manifest.gd`. Source PNG в `assets/sprites/characters/` используются меню и выбором персонажа и являются исходником нарезки. Берсерк остается без оружия в базовом спрайте, а оружие крепится отдельно через `WeaponSocket`.

Текущие character sprites сделаны в стиле референса пользователя: Берсерк имеет бороду, плетеные волосы, массивное тело, мех, ремни, металлические браслеты, плечо со шипами, красную боевую разметку и skull-belt без встроенного оружия; Темный маг имеет капюшон, маску, мантию, черепа, кристаллы и фиолетовые spell-orbs; Гитарист имеет сине-золотой сценический костюм, музыкальные значки, ремни, перчатки и медиаторный амулет без встроенной гитары.

Стандартные монстры, элитки и боссы также используют polished cartoon fantasy full-art sprites в стиле последнего референса пользователя: темное фэнтези, выразительные силуэты, сильные черные контуры, объемная покраска и читаемые archetype-shapes. В бою их видимая фигура тоже собирается `scripts/cutout_rig_2d.gd` из нарезанных кусков того же арта (`assets/sprites/enemies|elites|bosses/cutout/`): конечности, оружие (арбалет), щиты, крылья, хвост и вихрь босса — отдельные анимируемые части. Старые placeholder rig-parts удалены. Нельзя возвращать монстров к generic placeholder-спрайтам или видимым квадратным заглушкам частей тела.

### Берсерк

- ID: `berserk`
- Роль: ближний бой, физический урон, выживаемость.
- Базовое здоровье: 88.
- Базовая скорость: 235.
- Спрайты: `assets/sprites/characters/berserk_unarmed.png`, `assets/sprites/characters/berserk_walk_sheet_v2.png`, cutout-части `assets/sprites/characters/cutout/berserk_*.png`.
- Особенность: оружие отделено от персонажа и крепится к `WeaponSocket`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 10 |
| Ловкость | 5 |
| Интеллект | 2 |
| Восприятие | 5 |
| Энергия | 4 |
| Знание | 4 |
| Выносливость | 7 |
| Лидерство | 3 |

### Темный Маг

- ID: `dark_mage`
- Роль: магический урон, AoE, лучи, DoT.
- Базовое здоровье: 42.
- Базовая скорость: 250.
- Спрайт: `assets/sprites/characters/dark_mage.png`, cutout-части `assets/sprites/characters/cutout/dark_mage_*.png`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 2 |
| Ловкость | 3 |
| Интеллект | 10 |
| Восприятие | 5 |
| Энергия | 7 |
| Знание | 6 |
| Выносливость | 2 |
| Лидерство | 5 |

### Гитарист

- ID: `guitarist`
- Роль: звуковые волны, импульсы, ауры, отталкивание.
- Базовое здоровье: 60.
- Базовая скорость: 268.
- Спрайт: `assets/sprites/characters/guitarist.png`, cutout-части `assets/sprites/characters/cutout/guitarist_*.png`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 4 |
| Ловкость | 6 |
| Интеллект | 4 |
| Восприятие | 7 |
| Энергия | 6 |
| Знание | 5 |
| Выносливость | 4 |
| Лидерство | 7 |

### Новые Классы 0.2

Foundation новых классов уже включен в выбор персонажа, выбор оружия, кодекс, формулы характеристик, ascension и smoke tests. Design visual set для новых персонажей и полного набора оружия 9 классов готов: новые герои art-approved, все 27 weapon PNG существуют по каноническим путям; gameplay/backend-сцены могут подключать их без documented visual fallback.

| ID | Имя | Роль | Базовые характеристики |
| --- | --- | --- | --- |
| `assassin` | Ассасин | Быстрый крит-мили/линии | Str 6, Agi 10, Int 2, Per 6, Energy 3, Know 4, End 5, Lead 4 |
| `ranger` | Рейнджер | Дальний точный контроль | Str 7, Agi 7, Int 2, Per 9, Energy 4, Know 4, End 4, Lead 3 |
| `doctor` | Доктор | Sustain через урон и яд | Str 2, Agi 4, Int 8, Per 5, Energy 6, Know 8, End 5, Lead 2 |
| `chemist` | Химик | AoE/DoT зоны и алхимический summon | Str 2, Agi 4, Int 9, Per 6, Energy 7, Know 7, End 3, Lead 2 |
| `knight` | Рыцарь | Танк и тяжелый melee-control | Str 8, Agi 3, Int 2, Per 4, Energy 3, Know 4, End 10, Lead 6 |
| `druid` | Друид | Призыв, тернии, тотемы | Str 3, Agi 4, Int 4, Per 7, Energy 6, Know 5, End 5, Lead 9 |

## Оружие Берсерка

Берсерк использует отдельный скрипт `scripts/berserk_weapon.gd`. Урон наносится только в активное окно удара, синхронизированное с анимацией. Оружие показывает область поражения и не бьет одну цель несколько раз за один swing.

| Оружие | ID | Форма | Основной стиль | Сцена |
| --- | --- | --- | --- | --- |
| Двуручный меч | `berserk_sword` | Усеченный конус (`frustum`) | Широкий замах 90 градусов, радиус 600, высокий урон и надежное попадание по врагам рядом | `scenes/TwoHandedSword.tscn` |
| Двуручный топор | `berserk_axe` | Дуга (`sweep`) | Широкий контроль окружения вблизи, урон ниже меча | `scenes/TwoHandedAxe.tscn` |
| Двуручный молот | `berserk_hammer` | Круг | Слабый старт, усиленный рост от апгрейдов | `scenes/TwoHandedHammer.tscn` |

Параметры (идентичность оружия, 2026-06-11):

| Оружие | Зона | Темп / Урон | Модификаторы |
| --- | --- | --- | --- |
| Меч | Полоса 120 x 500 | interval 0.70, damage x1.15 | +10% урон (пассив) |
| Топор | Дуга 140 градусов, радиус 320 | interval 1.06, damage x0.85 | -10% урон (пассив) |
| Молот | Круг радиуса 100 | interval 1.25, damage x0.55 | +20% AoE (пассив); `upgrade_aoe_exponent` 1.8 и `upgrade_damage_exponent` 1.45 усиливают рост именно от апгрейдов забега до большого круга и высокого урона к концу акта |

Видимая VFX-зона каждой атаки совпадает с фактической зоной урона: художественный VFX (AttackVfx) дополняется полупрозрачным оверлеем точной геометрии зоны (`_show_exact_zone_overlay`).

## Оружие Темного Мага

Темный маг использует универсальный скрипт `scripts/class_weapon.gd`.

| Оружие | ID | Режим | Механика |
| --- | --- | --- | --- |
| Темная книга | `dark_book` | `aoe_projectile` | Два снаряда летят в две ближайшие цели и взрываются по области (`projectile_count: 2`) |
| Проклятый череп | `cursed_skull` | `homing_curse` | Самонаводящееся проклятие, прямой урон, 5 DoT-тиков и небольшой splash по области цели |
| Темный жезл | `dark_wand` | `beam` | Два pierce-луча веером (`beam_count: 2`, шаг 14 градусов), каждый пробивает несколько целей |

## Оружие Гитариста

Гитарист также использует `scripts/class_weapon.gd`.

| Оружие | ID | Режим | Механика |
| --- | --- | --- | --- |
| Электрогитара | `electric_guitar` | `sound_wave` | Широкая звуковая волна с отталкиванием; пассив +15% attack speed |
| Бас-гитара | `bass_guitar` | `pulse` | Частый слабый контроль-пульс: damage x0.30, interval 0.85, сильный knockback, пассив +10% attack speed |
| Усилитель | `sound_amp` | `amp` | Деплой: усилитель стоит на земле ~7с и пульсирует сам (тик 1.1с); одновременно 1 + floor(Лидерство/4) ампов, старший исчезает при превышении; группа `deployed_sound_amps`, чистится со сменой оружия/персонажа/забега |

## Оружие Новых Классов 0.2

Все 9 классов теперь имеют ровно 3 selectable weapon variants в `ProgressionData.WEAPONS_BY_CLASS`; smoke test проверяет загрузку и экипировку всех 27 вариантов.

| Класс | Оружие | ID | Режим | Механика |
| --- | --- | --- | --- | --- |
| Ассасин | Чакрамы | `chakrams` | `boomerang` | Коридор до цели и обратно; критовые попадания запускают короткий рывок к цели |
| Ассасин | Теневые кинжалы | `shadow_daggers` | `stab_flurry` | Быстрые short-range multi-stabs с критовыми рывками |
| Ассасин | Ядовитая струна | `venom_wire` | `dot_beam` | Тонкая poison-линия с DoT и mobility hook на крите |
| Рейнджер | Лунный арбалет | `moon_crossbow` | `beam` | Заряжаемый piercing shot: неподвижная стойка повышает урон |
| Рейнджер | Грозовой длинный лук | `storm_longbow` | `beam` | Заряжаемый веер дальних лучей |
| Рейнджер | Охотничий капкан | `hunter_trap` | `trap` | Deploy trap: burst + knockback; стойка усиливает подготовку |
| Доктор | Зелье восстановления | `restore_potion` | `drain_link` | Drain-связь к ближайшей цели, часть нанесенного урона лечит Доктора |
| Доктор | Чумной шприц | `plague_syringe` | `drain_link` | Тонкая чумная связь с DoT и lifesteal |
| Доктор | Костяная пила | `bone_saw` | `stab_flurry` | Ближний saw/flurry, DoT и lifesteal от нанесенного урона |
| Химик | Взрывная пыль | `blast_powder` | `aoe_projectile` | Spark cloud + взрыв; облака разных элементов дают combo explosion |
| Химик | Кислотная колба | `acid_flask` | `aoe_projectile` | Poison/acid pool; пересечение с другим элементом взрывает комбо |
| Химик | Склянка гомункула | `homunculus_vial` | `summon` | Temporary minion от magic damage |
| Рыцарь | Копье | `long_spear` | `strip` | Длинный точечный strip; блок раз в cooldown снижает удар и контратакует рядом |
| Рыцарь | Башенный щит | `tower_shield` | `sweep` | Frontal bash/control; самый надежный block/counter вариант |
| Рыцарь | Освященный кистень | `holy_flail` | `circle` | Medium circular heavy swing; более сильная контратака, но длиннее cooldown |
| Друид | Амулет призыва | `summon_amulet` | `summon` | Beast pack scaling from Leadership; питомцы получают команду attack_target |
| Друид | Посох терний | `briar_staff` | `aoe_projectile` | Thorn zone, AoE DoT |
| Друид | Вороний тотем | `raven_totem` | `amp` | Totem pulses, Leadership-scaled deploy limit |

Новые backend modes/hooks: `stab_flurry`, `dot_beam`, `trap`, `drain_link`, ranger stance charge (`charge_seconds`/`charge_max_multiplier`), assassin crit dash (`dash_on_crit_distance`), chemist cloud combos (`pool_element`/`combo_clouds`), knight block/counter (`block_reduction`/`counter_damage_multiplier`) и druid pet commands (`command_mode`, `command_target`). Deploy/trap/totem/cloud visuals используют `WeaponVisual` или `AttackVfx`, регистрируются в `player_weapon_effects` для cleanup; химические облака дополнительно временно входят в `chemist_clouds`.

## Боевые Эффекты (Attack VFX)

Все зоны атак и снаряды игрока рисуются текстурными спрайтами через общий модуль `scripts/attack_vfx.gd` (класс `AttackVfx`); плоские полупрозрачные Polygon2D-зоны убраны из активного боевого визуала. Текстуры эффектов лежат в `assets/sprites/effects/` и генерируются `tools/generate_attack_vfx.py` (тонируемые white-спрайты + прецветные элементы в стиле основного арта: темный контур, объемная заливка).

| Эффект | Текстуры | Где используется |
| --- | --- | --- |
| Дуга-слэш | `slash_arc.png` (+ непрозрачный подслой для контраста) | Меч/топор берсерка (frustum/sweep); дуга вылетает из героя вдоль направления удара и заполняет зону поражения за ~0.18с |
| Удар молота | `impact_flash.png`, `impact_ring.png`, `dust_puff_0..2.png` | Молот: оружие замахивается вверх и с ускорением падает в землю (`_animate_hammer_slam`), затем вспышка, расходящееся кольцо и 8 клубов пыли разлетаются по радиусу AoE |
| Вой-орб | `void_orb.png` + трейл из затухающих копий | `dark_book` (aoe_projectile): пульсирующий снаряд, на взрыве — `orb_burst` (кольцо+вспышка+вой-дымки) |
| Проклятый череп | `weapons/cursed_skull.png` + glow и трейл | `cursed_skull`: череп летит к цели ~0.2с, урон и splash наносятся в момент попадания |
| Луч | `beam_strip.png` + вспышки на концах | `dark_wand` (beam) |
| Звуковая волна | `sound_wave.png` + `music_note.png` | `electric_guitar` (sound_wave): волна `)))` расширяется по направлению, вылетают ноты |
| Кольцевой импульс | `impact_ring.png` + ноты (для гитариста) | `bass_guitar` (pulse), `sound_amp` (amp) |

Правила: эффекты самоочищаются tween-ами, классовое оружие дополнительно регистрирует их в `player_weapon_effects` (мертвые ссылки фильтруются в `_register_effect`/`cleanup_effects`). Runtime smoke проверяет экипировку всех 27 weapon variants; VFX smoke остается профильным тестом основных хелперов. Скриншоты для ручной проверки: `tools/capture_vfx_preview.gd` (windowed) -> `build/vfx_preview/`.

## Характеристики

Базовые характеристики:
- `strength` / Сила
- `agility` / Ловкость
- `intelligence` / Интеллект
- `perception` / Восприятие
- `energy` / Энергия
- `knowledge` / Знание
- `endurance` / Выносливость
- `leadership` / Лидерство

Производные параметры:
- `damage`
- `magic_damage`
- `sound_wave_damage`
- `attack_speed`
- `crit_chance`
- `crit_damage_multiplier`
- `move_speed`
- `dodge`
- `defense`
- `absorb`
- `health_point`
- `knockback_distance`
- `summon_amount`
- `attack_range`
- `range_multiplier`
- `regeneration`
- `vampiric_amount`
- `vampiric_chance`
- `aoe_radius`
- `pickup_radius`
- `dot_damage`
- `dot_speed`
- `projectile_speed`
- `aura_radius`
- `buff_power`
- `knockback_power`
- `ultimate_multiplier`

Формулы и описания для UI характеристик находятся в `scripts/stat_formulas.gd`. Конфиги классов, оружия, наград, артефактов и магазина находятся в `scripts/progression_data.gd`.

Актуальная философия прокачки: все базовые и производные атрибуты полезны каждому классу. Старая фильтрация «нерелевантных» статов отключена; `STAT_CLASS_RELEVANCE` оставлен пустым для совместимости, а reward pools не скрывают чужие параметры. Для тематически чужих эффектов UI показывает классовую интерпретацию: магический урон становится зачарованием оружия, Лидерство — эхо-оружием/фантомом/соколом/фамильяром, звуковой урон — боевым кличем, DoT — малым bleed/burn/poison, Energy — ускорением уникальной механики.

Runtime hooks уже подключены в `scripts/player.gd` и `scripts/class_weapon.gd`: оружейные попадания могут запускать magic enchant splash, малый DoT, leadership echo-hit и battle shout; Energy ускоряет dash Ассасина, counter Рыцаря и charge Рейнджера.

## Награды И Артефакты

В игре есть:
- награды за уровень;
- награды базовых характеристик;
- артефакты;
- магазинные предметы;
- классовые артефакты;
- риск-награда артефакты.

Магазин показывает четыре случайных предложения inline поверх `screen_shop_background.png` в центральной свободной области фона и позволяет купить несколько предметов за один визит, если хватает денег. Предметы показывают иконку и цену; название, описание, цену, class restriction и причину недоступности игрок видит только в hover tooltip. Купленные предметы получают overlay-состояние и становятся недоступными.

Design visual kit/spec для всех артефактов, shop-only предметов и курсора описан в `docs/design/artifact_shop_cursor_visual_kit.md`:
- 53 unique artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png` (`256x256`, transparent realistic epic D&D/tabletop fantasy raster magic items);
- 7 shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`;
- полный mapping: `docs/design/artifact_shop_cursor_visual_kit.md`;
- artifact icon raster extraction pipeline: `tools/extract_realistic_dnd_artifact_icons.py`;
- shop/cursor generator: `tools/generate_artifact_shop_cursor_assets.py`;
- active QA preview: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` (large and 40px checks for every active artifact).

После пользовательского фидбэка 2026-06-12 artifact icons заменены как красивые растровые предметы, а не пентаграммы/плоские символы: один законченный D&D-style magic item на файл, bbox с запасом от краев, без пьедесталов, фоновых тайлов, осколков, частиц и текста. Образ каждого предмета привязан к названию и эффекту из `ProgressionData.ARTIFACTS`; предыдущие generated/vector-like, glossy, concept-sheet tile и per-item pictogram направления заменены. Shop/cursor assets остаются в FantasyDisk fantasy-medallion / dagger-quill style.

Back-end integration complete: `scripts/ui_screens.gd` сначала ищет финальные PNG по mapping из visual kit, а если их нет, временно использует осмысленный fallback через `scripts/ui_icon_registry.gd` по эффекту предмета. На 2026-06-11 фактические artifact/shop/cursor PNG готовы и импортированы, поэтому fallback остается только fail-safe.

Level-up и докачка атрибутов показывают иконки через `UIIconRegistry` и добавляют текст «Интерпретация» для выбранного героя. Артефакты с `class_affinity` больше не считаются нерабочими для чужого класса: affinity теперь описывает тематику, а `affinity_mods` применяются через интерпретацию текущего героя.

## Звук

Звуковая система реализована через autoload `AudioManager` (`scripts/audio_manager.gd`, регистрация в `project.godot`):

- SFX: `sfx_hit` (попадание по врагу), `sfx_player_hit` (урон по игроку), `sfx_dodge` (уворот), `sfx_pickup_xp`, `sfx_pickup_money`, `sfx_level_up`.
- Музыка: `music_menu` (меню, карта, небоевые экраны), `music_combat` (бой). Лупы включаются через `AudioStreamWAV.LOOP_FORWARD`.
- Ассеты лежат в `assets/audio/` и генерируются воспроизводимо скриптом `tools/generate_audio_assets.py` (production helper, не runtime).
- Пул из 8 SFX-плееров и троттлинг 0.05с на звук защищают от спама при уроне по толпе.
- В headless-режиме (smoke tests) аудио полностью отключено, чтобы не оставлять висячие AudioStreamPlayback при выходе.
- Громкость: музыка -8 dB, SFX -4 dB, шина Master.

## Флоу Победы И Докачка (2026-06-11)

- После победного боя (обычного/элитного): затемнение + крупная золотая надпись «ПОБЕДА» (клик или 1.3с) -> окно докачки атрибутов -> карта. Босс ведет на отдельный экран победы, как раньше.
- Окно докачки: выбор 1 из 2 случайных характеристик (+1) за `18 + 6 * route_stage` золота; «Обновить» пары за `6 + 2 * route_stage` (2 раза за окно); «Пропустить»; Escape = пропуск.
- Желтая кнопка-стрелка прокачки (FAB, низ-право) на карте, в магазине, на костре и событии: при непотраченных level-up выборах открывает их (пульсирующий бейдж с числом), иначе — окно докачки за золото. На событии докачка отключена (повторный вход перегенерировал бы выборы события), доступен только level-up. В бою FAB не показывается — там остается своя кнопка level-up.

## Навигация И UX

- Escape = назад на всех небоевых экранах через единый стек: каждый экран регистрирует действие возврата в `main.ui_escape_action` (сбрасывается в `_clear_ui`). Цепочки: настройки/кодекс/выбор персонажа -> меню; выбор оружия -> выбор персонажа; магазин/костер -> уйти с узла (как кнопка); победа/смерть -> меню. Событие — выбор обязателен, Escape отключен. В бою Escape — пауза (как раньше).
- Экран выбора героя — fullscreen `HeroSelectScreen`: 9 классов видны одновременно сеткой 3x3 без ScrollContainer. Карточки выбора персонажа — целиком кликабельные Button с hover-подсветкой рамки и pointer-курсором; портрет занимает основную часть карточки, на карточке только имя/короткий стиль/сильные/слабые, полные базовые характеристики доступны в tooltip и нижней `HeroSelectInfoPanel`. Отдельной кнопки «Выбрать» нет. Все кнопки игры используют pointer-курсор.
- Размеры изображений: кодекс — персонажи 176px, монстры 150px, артефакты 96px; HUD-артефакты 48px; пауза-артефакты 56px; иконки магазина 100px (слот 164x186).
- Фон маршрутной карты: если существует `assets/backgrounds/route_map_backdrop.png`, он подключается с cover-растяжением и затемнением 0.62 для читаемости узлов; иначе — прежний однотонный фон (graceful fallback до выхода арта).

## Кодекс (Энциклопедия)

Кнопка «Кодекс» в главном меню открывает внутриигровую энциклопедию (`_show_codex_screen` в `scripts/ui_screens.gd`). Данные — data-driven из `scripts/codex_data.gd`: персонажи/оружие/артефакты/характеристики собираются из `progression_data.gd` и `stat_formulas.gd`, описания монстров и канонические имена умений живут в `CODEX_DATA.MONSTERS` и зарегистрированы в `docs/design/content_registry.md` (раздел «Умения Монстров»).

Разделы: Персонажи (3 класса, стиль игры, сильные/слабые стороны, оружие), Монстры (11 обычных + 4 элитки + 2 босса, поведение и названные умения), Артефакты (все из ARTIFACTS + SHOP_ITEMS с иконками), Характеристики (8 базовых + производные из STAT_DEFINITIONS с влияниями). Разделы строятся лениво при первом открытии вкладки и кэшируются — меню не фризит.

## Пауза

Система паузы реализована через причины паузы. Основные причины:
- `escape_menu`;
- `level_up`.

При активной паузе:
- `get_tree().paused = true`;
- UI продолжает работать;
- состояние gameplay объектов замораживается;
- скорость игрока, врагов, боссов, снарядов и pickups обнуляется;
- таймер не идет;
- камера не двигается.

Пауза используется при:
- Escape menu;
- выборе награды за уровень.

## UI

Реализованные UI-состояния:

| Экран | Описание |
| --- | --- |
| Главное меню | Эпичный battle-art фон и левая колонка из трех кнопок: начать новую игру, настройки, выйти из игры |
| Настройки | Разрешение, режим окна, клавиши движения |
| Выбор персонажа | Карточки с портретами, описанием и статами |
| Выбор оружия | Три оружия выбранного класса |
| Карта маршрута | Вертикальная карта с иконками и tooltip |
| Боевой HUD | Минимальные HP, XP, деньги с иконками |
| Level-up | Геройский экран выбора одной из трех наград с портретом персонажа, частицами и стилизованными карточками |
| Магазин | Inline-предметы поверх `screen_shop_background.png`: иконка + цена, описание только hover tooltip, purchased/unavailable state |
| Событие | Выбор одного из вариантов события поверх `screen_event_background.png` |
| Отдых | Лечение или защитный бонус поверх `screen_campfire_background.png` |
| Pause stats | Compact Escape menu: кнопки слева, базовые характеристики слева под кнопками, производные параметры справа в логических группах с tooltip |
| Смерть | Завершение забега |
| Победа | Награда и возврат в меню |

HP, XP и деньги должны оставаться видимыми на карте, в событиях и в магазине.

Обновление 2026-06-11 (артефакты и таймер):
- Игрок хранит артефакты как `{id, title}` (`scripts/player.gd`); id используется для иконок, формат совместим со старыми title-записями.
- Боевой HUD показывает ряд иконок подобранных артефактов 40px в правом верхнем углу (`ArtifactHudRow`, HFlowContainer с переносом) с tooltip «название + эффект»; ряд перестраивается только при изменении количества артефактов.
- Меню паузы содержит блок «Артефакты» под базовыми характеристиками (`ArtifactsList` в `scripts/pause_stats_menu.gd`): иконки с tooltip, либо подпись «Пока не найдено».
- Таймер боя — стилизованная панель по центру сверху (`CombatTimerPanel`, формат M:SS); при остатке <=5 секунд цифры и рамка краснеют с легкой пульсацией; на босс-файтах панель не создается. Рамка пока кодовая — будет заменена на `timer_frame.png` от Design.
- Магазин: сетка товаров 2x2 лежит на «пустой стене» фона — светлом пергаменте правее торговца (`ShopParchmentWall`, анкеры ~50-82% ширины и 10-72% высоты экрана). Боевой экран не показывает полный список характеристик, оружие, артефакты, stage/debug text или derived-stat dump; подробности живут в Escape stats menu и reward UI.

Shop visual kit asset-ready:
- `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png`;
- `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png`;
- `assets/sprites/ui/shop/ui_shop_price_badge.png`;
- `assets/sprites/ui/shop/ui_shop_purchased_overlay.png`;
- `assets/sprites/ui/shop/ui_shop_tooltip_frame.png`.

Game cursor asset-ready:
- default: `assets/sprites/ui/cursor/game_cursor.png`;
- hover: `assets/sprites/ui/cursor/game_cursor_hover.png`;
- attack: `assets/sprites/ui/cursor/game_cursor_attack.png`;
- hotspot: `(5, 4)`.
- style: fantasy dagger/quill pointer with gem detail and gold/cyan/red state accents.

Централизованный mapping UI-иконок находится в `scripts/ui_icon_registry.gd`. Он покрывает 8 базовых характеристик, все активные производные параметры из Escape stats menu и HUD-ресурсы `hp`, `xp`, `money`. Финальные polished stylized fantasy cartoon PNG лежат в `assets/sprites/ui/icons/stats/`, `assets/sprites/ui/icons/derived/` и `assets/sprites/ui/hud/`; registry автоматически подхватывает реальные текстуры для боевого HUD, level-up reward cards, Escape stats menu, Кодекса и stat/reward/tooltips. Для производных параметров, у которых пока нет отдельного Design PNG (`absorb`, `regeneration`, `vampiric_*`, `range_multiplier`, `knockback_distance`, `ultimate_multiplier`), registry использует ближайшую существующую derived-иконку как backend fallback, без emoji/default placeholders. Shop item icons дополнительно разрешаются через реальные `artifact_<artifact_id>.png` / `shop_<shop_item_id>.png`; fallback в этот registry остается только fail-safe, если asset временно отсутствует.

Escape stats menu layout:
- `RunControls` слева содержит кнопки управления (`Продолжить`, `Настройки`, `Завершить забег`, `Выйти в главное меню`).
- `BaseStatsList` находится под кнопками и показывает базовые характеристики компактными строками: иконка, русское имя, значение.
- `DerivedStatsGroups` справа группирует производные параметры в `physical_damage`, `magic_damage`, `sound_control`, `dot_poison`, `survival`, `summons_support`.
- Каждый `BaseStatRow_<stat_id>` и `DerivedStatChip_<stat_id>` имеет hover tooltip с описанием, формулой и влияниями из `scripts/stat_formulas.gd`.
- Fantasy visual kit для `EscapeStatsPanelFrame`, кнопок, stat rows, groups, chips, divider и tooltip подключен через `StyleBoxTexture` / `TextureRect` из `assets/sprites/ui/frames/escape/`; точные paths, colors, margins и spacing описаны в `docs/design/escape_stats_visual_kit.md`.
- Custom tooltip создается в `scripts/pause_stats_menu.gd::_make_custom_tooltip()` и ограничен целевой шириной 430px, чтобы Godot мог удерживать его внутри viewport.

Все стандартные UI-кнопки используют единый FantasyDisk style: темный fantasy-metal фон, золотая bevel-рамка, readable hover/pressed/disabled/focus состояния и тень. Level-up reward cards используют отдельный магический вариант этого стиля с фиолетово-золотой рамкой, портретом выбранного героя в header и частицами поверх затемненного боя.

Escape stats visual kit assets:
- `ui_escape_panel_frame.png` - outer menu frame;
- `ui_escape_button_frame.png` - run control buttons;
- `ui_stat_basic_row_frame.png` - compact base stat rows;
- `ui_stat_group_frame.png` - grouped derived stat sections;
- `ui_stat_chip_frame.png` - derived stat chips;
- `ui_stat_tooltip_frame.png` - custom tooltip frame;
- `ui_stat_section_divider.png` - optional group divider;
- `ui_stat_value_state_swatches.png` and `escape_stats_visual_kit_preview.png` - design references.

Sprite quality audit 2026-06-11: повторный полный аудит (`tools/sprite_quality_audit.py` — отчет/фикс грязных пикселей, островков, halo) + автопостобработка нарезки `fix_detached_fragments` в `tools/slice_rig_cutouts.py`, которая убирает обрезки соседних частей тела из подвижных конечностей (главная причина «лишних кусочков» на краях спрайтов в движении). UI-иконки с легитимными отдельными искрами island-фиксом не трогаются.

Sprite quality audit 2026-06-10: активные UI/gameplay элементы не должны использовать видимый Polygon2D-placeholder. Pickups отображаются Sprite2D через HUD PNG (`hud_xp.png` / `hud_money.png`), player projectile использует `assets/sprites/projectiles/player_projectile_spark_64.png`, а у `enemy_suicide_runner.png` удален лишний правый фрагмент текстуры.

## Враги

Базовый скрипт врагов: `scripts/enemy.gd`.

Общие возможности:
- полоса HP над каждым врагом (моб/элитка/босс/призванный полноценный враг): дешевый `_draw`-нод `scripts/enemy_health_bar.gd`, ширина пропорциональна видимому размеру спрайта, значение всегда синхронизируется как `health / max_health` через `refresh_health_bar()` после runtime-скейлинга и после получения урона;
- contact_range автоматически подгоняется под фактический видимый размер спрайта (`_fit_contact_range_to_sprite`): радиус врага + радиус игрока, экспортное значение сцены остается минимумом;
- движение к игроку;
- ranged behavior с удержанием дистанции;
- contact damage через windup и cooldown;
- снаряды;
- призыв маленьких врагов;
- ground/flying collision profile;
- выпадение опыта и денег.

Стандартные враги:

| Архетип | Сцена | Спрайт | Роль |
| --- | --- | --- | --- |
| Ближний бой | `scenes/Enemy.tscn` | `enemy_melee.png` | Базовое давление толпой |
| Дальний бой | `scenes/EnemyShooter.tscn` | `enemy_ranged.png` | Редкие читаемые снаряды |
| Быстрый | `scenes/EnemyRunner.tscn` | `enemy_suicide_runner.png` | Быстро догоняет игрока |
| Жирный | `scenes/EnemyBruiser.tscn` | `enemy_bruiser_slow.png` | Медленный, высокий HP |
| Суммонер | `scenes/EnemySummoner.tscn` | `enemy_summoner.png` | Призывает мелких мобов |
| Маг | `scenes/EnemyMage.tscn` | `enemy_void_mage.png` | Магический ranged-вариант |
| Плевательщик | `scenes/EnemySpitter.tscn` | `enemy_venom_spitter.png` | Ranged pressure |
| Щитовик | `scenes/EnemyShield.tscn` | `enemy_rift_shieldbearer.png` | Защитный вариант |
| Кусачий | `scenes/EnemyBiter.tscn` | `enemy_small_biter.png` | Маленький быстрый враг |
| Костяной шаман | `scenes/EnemyBoneShaman.tscn` | `enemy_bone_shaman.png` | Вариант призывателя |
| Летающий | `scenes/EnemyFlyingRunner.tscn` | `enemy_winged_spark.png` | Летающее движение; pit layer отключен вместе с ямами |

## Снаряды Врагов

Сцена: `scenes/EnemyProjectile.tscn`.

Скрипт: `scripts/enemy_projectile.gd`.

Спрайт: `assets/sprites/projectiles/enemy_projectile_magic_64.png`.

Снаряд:
- летит по направлению к цели;
- наносит урон игроку;
- исчезает после попадания;
- удаляется по lifetime;
- удаляется за пределами арены.

## Снаряды Игрока И Pickups

Базовый снаряд игрока: `scenes/Projectile.tscn`, `scripts/projectile.gd`.

Активный спрайт: `assets/sprites/projectiles/player_projectile_spark_64.png`.

Pickups: `scenes/Pickup.tscn`, `scripts/pickup.gd`.

Активные visual textures:
- XP pickup: `assets/sprites/ui/hud/hud_xp.png`;
- money pickup: `assets/sprites/ui/hud/hud_money.png`.

Старые Polygon2D diamond/triangle visuals больше не являются активным визуальным состоянием.

## Элитные Враги

Элитки выбираются случайно. Они должны быть примерно на порядок опаснее обычных врагов за счет HP, урона и паттернов.

Обновление 2026-06-11: элитки крупнее обычных мобов в ~1.35 раза — спрайты 256x256 при прежнем scale сцен дают видимый апсайз, collision shape увеличены в 1.35x, contact_range подгоняется автоматически под видимый размер. У каждой элитки есть уникальная телеграфированная активная атака со state machine `windup -> strike -> recover -> idle` (конфиг `scripts/enemy.gd::ELITE_ATTACK_CONFIG`, сигнал `elite_attack_phase_changed` для Animator). Во время атаки элитка стоит на месте; урон атаки ограничен 25% максимального HP игрока; от всех атак можно увернуться движением.

| Элитка | Сцена | Спрайт | Уникальное поведение |
| --- | --- | --- | --- |
| Железный Оплот | `scenes/EliteArmored.tscn` | `assets/sprites/elites/iron_bastion.png` | Щит; Slam-волна: замах 0.6с, кольцо 260 с уроном и отбрасыванием (кулдаун 6с) |
| Ночной Сталкер | `scenes/EliteStalker.tscn` | `assets/sprites/elites/night_stalker.png` | Рывки; Теневой удар: уход в тень 0.5с, телепорт за спину игрока, быстрый удар (кулдаун 7с) |
| Чумной Пророк | `scenes/ElitePoisoned.tscn` | `assets/sprites/elites/plague_prophet.png` | Ядовитые зоны; Ядовитый залп: 3 lob-снаряда, лужи на 3с с тиками (кулдаун 8с) |
| Маршал Осколков | `scenes/EliteCommander.tscn` | `assets/sprites/elites/shard_marshal.png` | Аура усиления; Залп осколков: веер из 5 кристальных снарядов (кулдаун 6с) |

## Боссы

Босс выбирается случайно на финальном узле маршрута.

| Босс | ID | Сцена | Спрайт | Паттерны |
| --- | --- | --- | --- | --- |
| Rift Warden | `rift_warden` | `scenes/BossWarden.tscn` | `boss_rift_warden.png` | Залпы, зоны разлома, призыв, щит, увороты |
| Disk Devourer | `disk_devourer` | `scenes/BossDiskDevourer.tscn` | `boss_disk_devourer.png` | Рывок, slam AoE, radial burst, enrage |

Боссы используют `scripts/boss.gd`, который расширяет логику обычного врага.

## Спавн И Волны

Ключевые правила:
- монстры появляются волнами;
- активное количество врагов ограничено;
- враги могут появляться с одной или двух сторон волны;
- ранние волны избегают ситуации, где враги сразу давят со всех противоположных сторон;
- маленькие враги могут появляться пачками по 3-4;
- дальнобойные враги появляются реже обычных;
- с каждым этапом и волной растут HP, урон и количество врагов.

Текущая базовая настройка:
- base spawn count: 2;
- normal active cap: 14;
- elite active cap: 12;
- boss active cap: 12;
- spawn edge padding: 72 пикселя от физической границы арены;
- spawn safe radius around player/start: 340 пикселей;
- глобальный потолок активных врагов: 30 (`max_active_cap`), включая поэтапный рост обычных и элитных боев;
- normal spawn pause: 1.35-2.15 секунды;
- boss spawn pause: 2.0-3.2 секунды.

Спавн использует реальные границы 2560x1440: правый и нижний edge-spawn больше не ограничены старой областью 1600x900. Снаряды игрока и врагов удаляются только за пределами новой арены с cleanup margin 180 пикселей.

## Баланс Врагов

Обновление 2026-06-11 (10-этапный акт): базовые множители `ENEMY_BALANCE` подняты примерно на +10% HP и +8% урона у всех архетипов (например, default 3.1 HP / 1.25 damage, elite 4.6 HP / 2.10 damage, boss 1.9 HP / 1.46 damage). Поэтапный рост остался линейным, но акт теперь длиннее, поэтому добавлен жесткий потолок активных врагов 30.

Текущие модификаторы направлены на то, чтобы враги были жирнее, немного медленнее и появлялись меньшей плотностью, чем ранний прототип.

Основная идея:
- обычные враги имеют повышенный HP;
- элитки имеют сильно повышенный HP, урон и устойчивость;
- боссы сложнее за счет паттернов, HP, щитов, уворотов и ярости;
- скорость врагов снижена, чтобы игрок мог водить их и собирать группы.

## Анимации

Каноническая архитектура анимации движения находится в `scripts/cutout_rig_2d.gd`.

Архитектура нарезанного cutout-рига (2026-06-10):
- Источник данных — сгенерированный `scripts/sliced_rig_manifest.gd` (создается `tools/slice_rig_cutouts.py` вместе с PNG-частями в `assets/sprites/<group>/cutout/`).
- Иерархия: `RigRoot/Pelvis/Figure/Torso` + части `ArmL`, `ArmR`, `Weapon`, `Shield`, `WingL/R`, `Tail`, `Vortex` (дети `Torso`) и `LegL`, `LegR` (дети `Figure`). У каждой части пивот в суставе и спрайт-кусок исходного арта.
- В покое сборка пиксельно идентична исходному full-art PNG; зоны конечностей стерты из торса только за пределами силуэта тела (внутренние дырки заполнены инпейнтом), поэтому при взмахах нет дыр.
- Разворот в сторону движения — зеркалирование `Pelvis.scale.x`; вертикальное движение сохраняет горизонтальный facing. Манифест хранит `base_facing` (куда смотрит исходный арт): герои нарисованы вправо (+1), все мобы/элитки/боссы — влево (-1), поэтому моб, идущий вправо, зеркалится и не двигается спиной вперед. Итоговый знак: `facing_sign * base_facing`.
- Per-style профили движения: humanoid, heavy/guard, beast/stalker, robed, robed_walker, floating_robed, flyer, blob, colossus.
- Player polish 2026-06-11/12: `walk_blend_rate` и `direction_blend_rate` задаются профилем движения. `berserk`, `dark_mage`, `guitarist`, `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` имеют отдельные motion profiles, чтобы старт/остановка, разворот, weight shift и шаг не выглядели одинаково. Новые 6 профилей 2026-06-12: assassin быстрый/резкий, ranger собранный, doctor тяжелее и спокойнее, chemist чуть нервнее, knight тяжелый инертный, druid мягкий ритуальный.

Игрок:
- `scenes/Player.tscn` сохраняет `VisualRoot/Body` как скрытый `AnimatedSprite2D` fallback и источник кадров.
- Видимое движение строится через `VisualRoot/RigRoot` (нарезанный риг из манифеста).
- `WeaponSocket` остается в `VisualRoot` для совместимости с оружием, но его позиция и вращение следуют за `WeaponSocketMount` (закреплен на руке атаки в `Torso`).
- Берсерк, Темный маг и Гитарист переведены на общий нарезанный rig.
- Берсерк по-прежнему имеет `berserk_walk_sheet_v2.png` как fallback/resource animation sheet.
- Движение: сглаженный `walk_blend`, противофазные ноги с подъемом стопы, маховые руки, body bob, наклон в сторону движения, idle breathing. У Темного мага отдельный более спокойный walk profile с меньшим bob/lean и читаемым переносом веса после rework ног.

Канонические состояния игрока:
- `idle`
- `walk`
- `attack`
- `shoot`
- `cast`
- `hit`
- `death`

Враги:
- все стандартные враги, элитки и боссы используют общий `RigRoot` поверх существующего `Body` / `Sprite2D`;
- исходный спрайт врага скрыт и остается источником текстуры и масштаба; видимая фигура собирается из cutout-частей того же арта;
- части тела берутся из `assets/sprites/enemies/cutout`, `assets/sprites/elites/cutout`, `assets/sprites/bosses/cutout`;
- `winged_spark` машет отдельными `wing_l`/`wing_r` (нарезанные крылья) и болтает лапами в полете;
- `ash_marksman` несет арбалет отдельной частью `weapon` (отдача при выстреле), `rift_shieldbearer` и `iron_bastion` — щит частью `shield`, `spark_runner` — хвост `tail`, `rift_warden` — вихрь `vortex` с постоянным покачиванием и пульсом;
- наземные враги шагают противофазными ногами с подъемом стопы и weight shift;
- shooter/mage/spitter имеют малую амплитуду, runner/biter/stalker — частую низкую походку, bruiser/shield/armored — тяжелый медленный sway, robed-касты — ritual sway без ног;
- элитки усиливают амплитуду rig-профиля;
- боссы используют colossus/blob профили с медленной heavy-анимацией.

Специальные движения атак (видимые жесты конечностей):
- `attack`: замах руки атаки назад (anticipation) и широкий удар вперед с выпадом корпуса и squash; у существ без конечностей (Disk Devourer, Venom Spitter) — лансж со squash-snap;
- `attack` Берсерка получает animation variant из текущего `weapon_id`: `sword` читается как короткий линейный thrust вперед, `axe` как широкая горизонтальная arc-поза, `hammer` как overhead lift + downward slam. Это визуальный слой rig-а; damage shapes, fire interval и active windows остаются в weapon/backend конфигурации.
- `shoot`: отдача корпуса и оружия/руки назад-вверх;
- `cast`: подъем обеих рук/посоха/черепа с подъемом корпуса и удержанием позы;
- Уникальные атаки элиток получают animation variant из backend-фазы `<elite_behavior>:<elite_attack_id>:<phase>` и используют длительность `windup/strike/recover` из `ELITE_ATTACK_CONFIG`: Iron Bastion поднимается в slam windup и резко проседает на strike; Night Stalker сжимается в crouch и делает forward lunge; Plague Prophet делает ritual arm raise/throw; Shard Marshal разводит руки и затем жестом выбрасывает shard fan.
- `hit`: красная вспышка и короткая тряска;
- `death`: при гибели враг оставляет `DeathGhostRig` (копию рига), которая падает, сминается и растворяется (`spawn_death_ghost` в `scripts/cutout_rig_2d.gd`).

Канонические файлы:
- rig controller: `scripts/cutout_rig_2d.gd`;
- player integration: `scripts/player.gd`;
- enemy integration: `scripts/enemy.gd`;
- boss action triggers: `scripts/boss.gd`;
- regression test: `tests/animation_smoke_test.gd`.

Тайминги атак, windup/recovery и damage windows не менялись; изменен только визуальный слой.

## Ассеты

Ключевые папки:
- `assets/sprites/characters`
- `assets/sprites/characters/cutout`
- `assets/sprites/weapons`
- `assets/sprites/enemies`
- `assets/sprites/enemies/cutout`
- `assets/sprites/elites`
- `assets/sprites/elites/cutout`
- `assets/sprites/bosses`
- `assets/sprites/bosses/cutout`
- `assets/sprites/projectiles`
- `assets/sprites/effects`
- `assets/sprites/backgrounds`
- `assets/sprites/map_icons`
- `assets/sprites/ui/icons/stats`
- `assets/sprites/ui/icons/derived`
- `assets/sprites/ui/hud`

При добавлении или замене ассетов нужно обновлять соответствующие `.tscn`, тесты и документацию.

Новый визуальный набор после movement overhaul сгенерирован через `tools/generate_visual_redesign_assets.py` (исторический helper). Актуальная нарезка cutout-частей из polished full-art выполняется `tools/slice_rig_cutouts.py`: он генерирует PNG в `assets/sprites/*/cutout/`, манифест `scripts/sliced_rig_manifest.gd` и debug-листы в `build/rig_debug/`. Скрипты не используются в runtime.

## Метапрогрессия

Метапрогрессия персистентна между сессиями:

- За каждую победу над финальным боссом игрок получает 1 meta point, а выбранный персонаж — +1 уровень возвышения (максимум 10).
- Бонусы уровней кумулятивны: уровень N включает все бонусы уровней 1..N. Таблицы уровней: `scripts/progression_data.gd::ASCENSION_LEVELS`, канонические ID в `docs/design/content_registry.md`.
- Сохранение через `scripts/meta_progression.gd` в `user://fantasydisk_meta.cfg` (ConfigFile).
- Бонусы применяются к игроку при старте первого боя забега (`apply_ascension_bonuses` в `scripts/main.gd`).
- Карточка выбора персонажа показывает «Возвышение: N/10», экран победы показывает прогресс возвышения выбранного героя.
- Smoke test: `tests/meta_progression_smoke_test.gd`.

## Боевые Правила После Bugfix-Пакета 2026-06-10

- Уворот игрока работает: `dodge` из `derived_parameters` проверяется в `Player.take_damage`, при успехе показывается всплывающий текст «Промах!» и звук уворота; урон и invulnerability window не применяются. Защита дополнительно ограничена 95%.
- Скорость атаки оружия считается как `base_fire_interval / attack_speed` (минимум 0.18с): базовый `fire_interval` каждого оружия из `progression_data.gd` снова значим, оружия одного класса различаются темпом.
- Ребаланс 2026-06-10: базовые `fire_interval` первых 9 оружий увеличены в 1.6 раза, чтобы итоговый темп после фикса формулы остался близким к прежнему ощущению, но с различиями между оружиями; 18 новых оружий 0.2 балансируются в своих конфигах.
- Pulse-режим бас-гитары и усилителя использует `_rolled_damage` (учитывает `damage_parameter` и криты), как остальные режимы классового оружия.
- Все отложенные боевые эффекты (ядовитые зоны элиток, rift zone, disk slam, DoT-тики, окна урона свинга берсерка, очистка визуалов) используют tween-таймлайны, привязанные к нодам, а не `SceneTreeTimer`. Они замораживаются вместе с паузой и не наносят урон в level-up/Escape паузе.
- Аура Маршала Осколков усиливает каждого обычного врага не более одного раза (meta `commander_aura_buffed`), без бесконечного мультипликативного стака.
- Статусные перекраски врагов/боссов (щит, windup, аура, ярость, dodge-flash) применяются к видимым cutout-частям через `CutoutRig2D.set_status_tint`, а не только на скрытый source-спрайт.
- Отталкивание классового оружия идет через `Enemy.apply_knockback` (импульс в velocity с затуханием), а не телепорт `global_position`; враги без метода сохраняют старый fallback.
- Враги кэшируют ссылку на игрока (`_player()`), а не ищут группу каждый физический кадр.
- Прицеливание оружия игрока (фикс 2026-06-11): все оружия целятся в ближайшего живого врага. Приоритет: ближайший в attack_range -> ближайший на арене -> последнее направление атаки. Направление движения персонажа влияет только на walk-анимацию; анимация атаки и VFX используют то же направление, что и расчет урона.
- При любом уроне по игроку боевой HUD показывает легкое покраснение экрана (`DamageFlashOverlay`): фиксированный пик alpha 0.20 без стакания, затухание ~0.32с, эффект замирает на паузе (PROCESS_MODE_PAUSABLE). Сигнал: `Player.damaged`.
- Нерф 2026-06-11: стартовый радиус молота Берсерка уменьшен вдвое — `aoe_radius` и `attack_range` 200 -> 100, пассив +20% AoE сохранен.

## Runtime И Performance Hygiene

Дополнение после полного code review 2026-06-11:

- Враги кэшируют ссылки на свой Body-спрайт, RigRoot и AudioManager (`_body_sprite()`, `_cutout_rig()`, `_cached_audio`) — без `get_node_or_null` в каждом физическом кадре/попадании; игрок кэширует AudioManager аналогично.
- Ежекадровый HUD-снапшот использует дешевый `_player_artifact_count()`; нормализация списка артефактов выполняется только при фактической перестройке ряда иконок.
- Удален мертвый код: `scenes/MeleeWeapon.tscn` + `scripts/melee_weapon.gd` и `scenes/Weapon.tscn` + `scripts/weapon.gd` (нигде не инстанцировались; перенесены в `build/unused_assets_backup/`), неиспользуемые константы `ROUTE_MAP_CANVAS_SIZE`, `ACTIVE_ENEMY_CAP_*`, `SHOP_INLINE_AREA_SIZE`.
- `scenes/SummonerWeapon.tscn` / `AllyMinion.tscn` и их скрипты сохранены как заготовка summon-механики (`summon_amount`), хотя сейчас не инстанцируются из конфигов.
- Консоль чистая: headless-запуск игры и все три smoke-теста проходят без ошибок, warnings и debug-print.

Основные runtime-правила после performance/code quality review:

- `scripts/main.gd` кэширует Texture2D для меню, портретов, route map и фоновых экранов через локальный texture cache, чтобы не дергать `load()` повторно при перестроении UI.
- `scripts/ui_icon_registry.gd` кэширует иконки характеристик/HUD, поэтому level-up, stats menu и HUD могут безопасно переиспользовать registry без повторной загрузки PNG.
- Inline shop item icons, shop slot frames and cursor variants используют тот же texture cache; отсутствующие Design PNG кэшируются как `null` и не вызывают повторный `load()` при перестроении магазина.
- Компактный HUD обновляет HP/XP/деньги только когда значения реально изменились; при создании нового HUD snapshot сбрасывается.
- Временные визуальные эффекты классового оружия должны регистрироваться в группе `player_weapon_effects`. `ClassWeapon.cleanup_effects()`, `Player._clear_equipped_weapon()`, `_freeze_gameplay_state()` и `_clear_world()` учитывают эту группу.
- Event/shop/campfire экраны поддерживают screen background hook-и: если PNG в `assets/sprites/ui/screens/` еще нет, используется цветной fallback-слой, который не блокирует клики.
- World cleanup чистит врагов, боссов, projectiles, enemy hazards, pickups, player weapons, weapon effects, level-up effects, arena boundaries/backgrounds.

## Известные Ограничения

- Исходный GDD упоминает автоскролл уровня вниз, но текущая реализация использует статичную арену с маршрутной картой.
- Баланс чисел является рабочим и должен дальше уточняться через playtest.
- Таблица механик остается долгосрочным источником формул, но код сейчас использует адаптированный слой формул.
- Data-driven scene loading оружия в `scripts/player.gd` пока остается через `load()` на момент экипировки; это не hot path, но при большом расширении оружия можно вынести в общий PackedScene cache.
- DOCX-документ может отставать от Markdown-документации, если его специально не регенерировали.

## Документация Будущих Изменений

Начиная с 2026-06-10, все будущие задачи должны обновлять документацию вместе с изменениями:

- новая механика, экран, маршрут, пауза или UX: обновить этот файл и `docs/design/fantasydisk_design_brief.md`;
- новый персонаж, враг, элитка, босс, артефакт, событие, оружие, фон или узел карты: обновить `docs/design/content_registry.md`;
- новые формулы, параметры, награды, экономика или баланс: обновить `docs/design/mechanics_extract.md`;
- изменение исходного дизайн-направления: добавить актуальное дополнение в `docs/design/gdd_source.md`.

Случайный выбор в игре должен работать только по определенным сущностям из реестра. Например, "случайный босс" означает случайный выбор из `Страж Разлома` и `Пожиратель Диска`, а не создание безымянного босса.

После завершения крупных пачек изменений нужно выполнить `docs/tasks/documentation_post_changes_domain_split_task.md`: обновить текущие документы и разнести подробности по доменным файлам в `docs/design/systems/`, минимум отдельно для боя, карты и меню/UI.

## Автономность Агентов

Пользователь заранее одобряет изменения в рамках задач. Будущие агенты должны:

- не спрашивать подтверждение на очевидные in-scope изменения;
- самостоятельно принимать разумные технические и продуктовые решения;
- доводить задачу до реализации, проверки и документации;
- описывать допущения в финальном ответе или документации.

Спрашивать нужно только при реальном блокере, обязательной эскалации среды, потенциально разрушительном действии или решении, которое выходит за scope задачи.

## Проверка Перед Сдачей Геймплейных Изменений

Runtime smoke test:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Animation smoke test:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Документационные правки не требуют запуска тестов, если не меняют код, сцены или ассеты.
