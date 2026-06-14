# FantasyDisk Current Game State

Обновлено: 2026-06-13 (0.1.5 dev snapshot)

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
- Текущий sprint target: `0.1.5` на ветке `dev`; release `v0.1.4` уже выпущен, feature freeze снят.
- Основная рабочая платформа: macOS. Релизные платформы: macOS (dmg) и Windows (x86_64 exe c embed_pck + NSIS-инсталлер).
- Версионирование: SemVer, источник истины `project.godot::config/version`; релизы — теги `vX.Y.Z` на main, разработка в `dev` (см. `docs/process/release_versioning.md`). Сборка: `tools/build_release.sh <версия>`.
- Основная сцена: `scenes/Main.tscn`.
- Основной управляющий скрипт: `scripts/main.gd` — тонкий координатор (state, пауза, основной цикл, делегирующие стабы для тестов). Он владеет модулями-компонентами: `scripts/ui_screens.gd` (меню/экраны/HUD/стили), `scripts/route_map_screen.gd` (генерация маршрута и экран карты), `scripts/combat_director.gd` (бой, спавн, баланс, арена, pickups). Модули — RefCounted с ссылкой `game` на main; общее состояние живет в main.
- Иконка приложения: `icon.svg`, подключена через `project.godot` `application/config/icon` и оформлена как fantasy disk emblem с золотым ободом и фиолетовым разломом.
- Главный игрок: `scenes/Player.tscn`, логика в `scripts/player.gd`.
- Smoke tests: `tests/runtime_smoke_test.gd` остается umbrella-проверкой полного core loop. Для быстрых регрессий SCRUM-202 добавил focused suites: `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_combat_test.gd`, `tests/runtime_smoke_progression_economy_test.gd`, `tests/runtime_smoke_weapon_mechanics_test.gd`, `tests/runtime_smoke_boss_elite_test.gd`. Дополнительно используются `tests/animation_smoke_test.gd` и `tests/meta_progression_smoke_test.gd`.

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

Обновление 2026-06-12 (настройки v3):
- **Мониторы**: при 2+ экранах в настройках появляется дропдаун выбора монитора (номер + разрешение); окно переезжает на выбранный экран во всех режимах. При одном экране опция скрыта.
- **Оконные разрешения** применяются честно: размер клампится по `screen_get_usable_rect` выбранного монитора (учет масштаба ОС/дока/меню-бара), окно центрируется от origin usable rect (раньше центрирование игнорировало origin — на втором мониторе окно уезжало); разрешения больше монитора задизейблены в списке. Borderless занимает usable rect экрана.
- **Вкладки**: экран настроек разделен на `TabContainer`-вкладки «Экран», «Звук», «Управление», чтобы каждая вкладка помещалась в окно 1280x720 без вертикального скролла.
- **Звук**: слайдеры Общая/Музыка/Эффекты (0-100%, шаг 2) вынесены во вкладку «Звук», занимают всю ширину контентной зоны, имеют видимый темный трек, золотую заполненную часть, числовое значение справа и keyboard focus для стрелок. Переключатели музыки/эффектов подписаны «Вкл.»/«Выкл.»; mute не сбрасывает значение слайдера. Кнопка «Сбросить звук по умолчанию» возвращает master/music/sfx к 100% и включает music/SFX. Изменения применяются мгновенно через AudioServer (Master/Music/SFX — шины Music и SFX создаются программно в AudioManager).
- **Управление**: вкладка «Управление» показывает режим прицеливания (`Автонаводка на ближайшего` / `По курсору`) и биндинги движения, паузы и `ultimate`. Дефолты: aim mode `nearest`, WASD + стрелки для движения, Escape для паузы, R для ультимейта. Ребинд проверяет конфликт с другими действиями и не перезаписывает чужую клавишу молча; есть reset defaults.
- **Персистенс**: дисплей, звук, `aim_mode` и `input_bindings` сохраняются в `user://settings.cfg` (`scripts/game_settings.gd`) и применяются при старте.

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
| Ruined Courtyard | `assets/backgrounds/field_ruined_courtyard.png` |
| Misty Marsh | `assets/backgrounds/field_misty_marsh.png` |
| Dusty Badlands | `assets/backgrounds/field_dusty_badlands.png` |
| Enchanted Meadow | `assets/backgrounds/field_enchanted_meadow.png` |
| Ashen Rift | `assets/backgrounds/field_ashen_rift.png` |
| Cursed Grove | `assets/backgrounds/field_cursed_grove.png` |

Фон арены выбирается случайно из доступного набора и может зависеть от типа узла карты.

Все 10 боевых фонов нарисованы в нативном 2560x1440 — 1:1 к размеру арены, движок их не растягивает и они не мылятся. Pass 2026-06-12 заменил первые 4 на плоские top-down ground textures без объемных объектов и ложной перспективы: только низкоконтрастная почва, мох, трещины, трава, сухие дорожные следы и мелкая наземная фактура. Expansion pass 2026-06-12 добавил 6 новых D&D-style арен (`ruined_courtyard`, `misty_marsh`, `dusty_badlands`, `enchanted_meadow`, `ashen_rift`, `cursed_grove`) с мелким антуражем и без крупных камней/кустов; они подключены в `ARENA_BACKGROUND_OPTIONS` для обычных боев, а более драматичные варианты — для boss pool. QA preview: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
`main_menu_epic_battle.png` используется стартовым экраном и обновлен SCRUM-158 как dark fantasy battle art с героями/боссами FantasyDisk и спокойной левой зоной под 3 кнопки. `screen_event_background.png`, `screen_shop_background.png` и `screen_campfire_background.png` используются небоевыми экранами поверх читаемого затемнения; SCRUM-158 заменил их на dark fantasy подложки из нового набора, сохранив существующие пути для совместимости.

SCRUM-158/170 добавили и подключили canonical UI backdrop set `assets/backgrounds/ui/`: `ui_backdrop_system_cathedral.png`, `ui_backdrop_merchant_archive.png`, `ui_backdrop_arcane_lab.png`, `ui_backdrop_reward_hall.png`, `ui_backdrop_defeat_crypt.png`. Все `2560x1440`, с низкоконтрастным спокойным центром под центральные окна и более богатым dark fantasy материалом по краям. Runtime mapping идет через `SCREEN_BACKGROUND_PATHS`: `system/settings/codex/hero_select/weapon_select/pause_stats/meta_tree/campfire` -> cathedral, `shop` -> merchant archive, `event/upgrade/level_up/meta_progression` -> arcane lab, `elite_reward/victory/artifact_reward` -> reward hall, `death/defeat/end_run_confirm` -> defeat crypt. Фоны ставятся `TextureRect` cover-scaling под читаемое затемнение, без замены route map/combat backgrounds.
`route_map_backdrop.png` используется full-screen route map hook-ом: это темный низкоконтрастный фон пустоши с туманным спокойным центром под узлы и линиями, а детали/силуэты вынесены к краям.

## Брендинг

| Ассет | Путь | Использование |
| --- | --- | --- |
| FantasyDisk App Icon | `icon.svg` | Project/application icon через `project.godot` |
| FantasyDisk Steam Library Logo | `assets/marketing/steam/fantasydisk_steam_library_logo.png` | 1280x720 transparent PNG для Steam library/logo placement; preview на темном фоне: `assets/marketing/steam/fantasydisk_steam_library_logo_preview.png` |

## UI Visual Style

Hero select v3 keeps the hero portrait on the left, dossier/details in the main
right-side information area, and `HeroSelectRadarPanel` as a separate floating
top-right widget. The radar is intentionally offset below the header/wax-seal
buttons to keep the 1280x720, 1600x900 and 2560x1440 no-overlap smoke stable.
The radar drawing control now lives in `scripts/ui/hero_stat_radar.gd`, while
hero-select constants, shop UI constants and dark-fantasy theme paths live in
focused `scripts/ui/*` modules and are exposed through the existing
`scripts/ui_screens.gd` facade.

Основной UI pass SCRUM-147 после пользовательской правки 2026-06-13 использует Parchment & Wax Seal только для кнопок. Общие fallback-рамки лежат в `assets/sprites/ui/frames/global/`, Escape stats kit — в `assets/sprites/ui/frames/escape/`, canonical 4-state kit — в `assets/sprites/ui/frames/dark_fantasy/`. Кнопки вырезаны из `button_parchment_wax_seal.png` и сделаны выше, чтобы сургучная печать помещалась. Full parchment panels были отклонены как странно разрезанные; SCRUM-229 заменил non-button panels/windows/bars/checks на leather+gold kit из `docs/design/references/interface/`. Source kit: `assets/sprites/ui/frames/leather_gold/`; active preview: `docs/design/previews/interface_leather_gold_panel_kit_contact.png`; QA copy: `build/qa/interface_leather_gold_panel_kit_contact.png`; pipeline: `tools/build_leather_gold_ui_kit.py`.

SCRUM-222 подключил stateful Back-end style layer к SCRUM-147 kit: кнопки используют реальные 4-state textures для ролей `primary`, `secondary` и `danger` (`idle/hover/pressed/disabled`), а общие панели, карточки, level-up panel, HUD panel/card и tooltip берутся из canonical `assets/sprites/ui/frames/dark_fantasy/` paths. После SCRUM-229 эти non-button canonical paths визуально являются leather+gold frames. Runtime smoke проверяет точные texture paths главных primary/secondary/danger кнопок, а `tests/dark_fantasy_ui_theme_test.gd` проверяет набор стилей отдельно.

SCRUM-227 закрепил правило для Parchment & Wax Seal кнопок: если control использует `ui_df_button_*` texture state, его фактическая высота должна быть не ниже ~64px. SCRUM-263/264 подняли стандарт action-кнопок до 104px: `_make_button()` и `_set_action_button_size()` задают единый размер, главное меню использует тот же стандарт, а широкие action-кнопки capped по визуальной ширине, чтобы не растягивать торцы/печать. Text-heavy choices используют паттерн «инфо-рамка над + короткая стандартная кнопка под». Маленькие utility controls (`+/-`, dropdown/keybind-style controls, shop/item hit areas, hero thumbnails, route nodes, reward/weapon cards) остаются компактными или карточными без сжатой печати. Runtime smoke пишет фактический dump размеров в `build/qa/parchment_button_seal_sizes.md`.

Contextual UI frame kits в `assets/sprites/ui/frames/contextual/` остаются historical/reference only и не являются активным runtime theme direction.

Settings controls получили системные fantasy assets из `assets/sprites/ui/icons/system/`: checkbox checked/unchecked, slider track/grabber, arrows/back/settings/close icons. Иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_*`.

## Combat VFX

Активные атаки оружия используют raster/fantasy VFX из `assets/sprites/effects/` через `scripts/attack_vfx.gd` и `scripts/class_weapon.gd`. Persistent pools больше не выглядят как программные круги: `poison_pool.png`, `spark_pool.png` и `briar_pool.png` подключены к Химику/Друиду как Sprite2D с мягкой пульсацией и fade-out, при этом урон, радиус и интервалы тиков остаются в data-driven weapon config.

SCRUM-261 обновил enemy/boss skill VFX под runtime mechanics SCRUM-259. `HazardVfx` теперь выбирает отдельные D&D/painterly PNG по node name (`BossGravityWell`, `BossVampiricBite`, `BossRiftZone`, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`) и даёт отдельные helpers для shield block, summon portal, reflect-thorns aura и command aura. Это визуальная маршрутизация: gameplay timing, damage, node names и balance не менялись. Preview-лист: `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.

SCRUM-258 добавил per-weapon visual signature layer для всех 51 оружий ростера 0.1.5: `assets/sprites/effects/vfx_weapon_<weapon_id>.png`. `ClassWeapon` перед исполнением текущего attack mode вызывает `AttackVfx.weapon_signature()` и размещает короткую полупрозрачную D&D/painterly пластину по `weapon_id` в зоне атаки/цели/ауры. Это только визуальный слой: урон, радиусы, формулы, targeting, cooldowns, delay и status mechanics остаются из Back-end SCRUM-256/251/254/245. Preview-листы: `docs/design/previews/scrum258_unique_weapon_vfx_contact.png`, `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`.

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
| `elite_battle` | Бой с элитным врагом (победа открывает окно награды: выбор 1 из 3 артефактов крупными карточками по центру экрана, иконка 112px + тир цветом + эффект + классовая интерпретация, выбор обязателен, навигация мышью/клавиатурой/геймпадом; панель центрируется через full-rect `CenterContainer` и проверяется фактическим `global_rect` на 1280x720/1469x908/2560x1440; показывается до экрана докачки) |
| `shop` | Магазин |
| `event` | Случайное событие |
| `rest` | Костер / отдых |
| `boss` | Финальный босс |

### Случайные События

Event-node открывает один data-driven сценарий из `scripts/event_data.gd`. В пуле 12 сценариев: `wandering_bard`, `cursed_altar`, `road_ambush`, `old_well`, `wounded_mercenary`, `goblin_lottery`, `hot_spring`, `mirror_phantom`, `stone_guardian`, `heroes_graveyard`, `fallen_star`, `training_dummies`.

Правила:
- один и тот же event ID не повторяется в рамках акта, пока пул не исчерпан;
- каждый сценарий имеет историю и 2-3 выбора;
- честные сделки заранее показывают цену HP/золота/стата;
- hidden-risk варианты помечены как риск и могут дать артефакт, хлам или бой;
- attribute checks используют текущие базовые характеристики игрока (`strength`, `agility`, `intelligence`, `perception`, `knowledge`, `endurance`);
- боевые исходы стартуют обычный или элитный бой с временным `pending_event_combat` payload: enemy health multiplier, reward multiplier и optional post-combat reward очищаются после боя;
- небоевые исходы применяются к run snapshot через `stats`, `mods`, `money`, `heal_percent`, `health_percent_cost`, `random_artifact`.

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

### Выживаемость и сценарные проверки

Текущая выживаемость проверяется двумя headless harness-слоями:
- `tools/survivability_harness.gd` + `tests/survivability_scenario_test.gd` моделируют синтетические fragile/steady/sturdy/tank профили, проверяют рост TTD по стойкости, вклад absorb/defense/dodge/regen и якорят формулу к реальному `Player.take_damage`.
- `tools/survivability_scenarios.gd` строит roster projection по текущим классам и first-weapon конфигам, пишет `build/survivability_scenarios_report.md`.

Последний замер SCRUM-190: 6 ok, 62 low, 0 high по contact swarm, shooter crossfire, elite burst и boss phase hazard. Это измерительный флаг, а не изменение баланса: константы классов/врагов не менялись, follow-up balance pass должен отдельно решить, усиливать ли survivability, снижать входящий DPS сценариев или добавлять классовые защитные инструменты.

### Target queries

Горячие weapon/player target scans используют `scripts/combat_target_query.gd`. Helper кеширует список `enemies` на один frame и дает единые методы `nearest`, `nearest_many`, `in_radius`, `has_in_radius`, `in_corridor` и `in_segment`. Group membership `enemies` сохранен как compatibility contract для спавна, cleanup и старых систем. Текущая интеграция покрывает `ClassWeapon`, `BerserkWeapon`, player ultimates/secondary effects, `AllyMinion` и `SummonerWeapon`; тест `tests/combat_target_query_cache_test.gd` проверяет геометрию helper-ов и отсутствие rebuild в том же frame.

## Персонажи

Первые три игровых персонажа используют polished stylized cartoon fantasy full hero sprites без квадратных placeholder-форм и без вида минимальных технических болванок. Расширенный ростер 0.1.4 доведен до 17 классов; новые классы прошли Design art-review как polished cartoon dark fantasy full-art. SCRUM-168 добавил Back-end-класс `soldier`; Design pass 2026-06-13 подготовил финальные `soldier.png`, `soldier_rifle.png`, `soldier_grenade.png` и `soldier_bayonet.png`, а Animator pass 2026-06-13 добавил Soldier cutout rig, manifest/profile и weapon pose hooks. В бою `scripts/cutout_rig_2d.gd` собирает видимую фигуру из нарезанных кусков того же polished-арта (torso, arm_l/arm_r, leg_l/leg_r): в покое сборка пиксельно совпадает с исходным PNG, в движении конечности реально двигаются. Нарезка генерируется инструментом `tools/slice_rig_cutouts.py` в `assets/sprites/characters/cutout/`, метаданные частей — в сгенерированном `scripts/sliced_rig_manifest.gd`. Source PNG в `assets/sprites/characters/` используются меню и выбором персонажа и являются исходником нарезки. Берсерк остается без оружия в базовом спрайте, а оружие крепится отдельно через `WeaponSocket`.

SCRUM-193 cleanup 2026-06-13: старые `*_placeholder.png` для Assassin/Chemist/Doctor/Druid/Knight/Ranger отсутствуют в активной папке персонажей; backup сохранен в `build/cleanup_backup_2026_06_13/`. Канонические source sprites персонажей — только `assets/sprites/characters/<class_id>.png`, а runtime cutout-части — `assets/sprites/characters/cutout/`.

Текущие character sprites сделаны в стиле референса пользователя: Берсерк имеет бороду, плетеные волосы, массивное тело, мех, ремни, металлические браслеты, плечо со шипами, красную боевую разметку и skull-belt без встроенного оружия; Темный маг имеет капюшон, маску, мантию, черепа, кристаллы и фиолетовые spell-orbs; Гитарист имеет сине-золотой сценический костюм, музыкальные значки, ремни, перчатки и медиаторный амулет без встроенной гитары.

Стандартные монстры, элитки и боссы также используют polished cartoon fantasy full-art sprites в стиле последнего референса пользователя: темное фэнтези, выразительные силуэты, сильные черные контуры, объемная покраска и читаемые archetype-shapes. В бою их видимая фигура тоже собирается `scripts/cutout_rig_2d.gd` из нарезанных кусков того же арта (`assets/sprites/enemies|elites|bosses/cutout/`): конечности, оружие (арбалет), щиты, крылья, хвост и вихрь босса — отдельные анимируемые части. Старые placeholder rig-parts удалены. Нельзя возвращать монстров к generic placeholder-спрайтам или видимым квадратным заглушкам частей тела.

SCRUM-156 Design pass 2026-06-13 подготовил финальные painterly D&D source sprites для новых сущностей SCRUM-155:
`assets/sprites/bosses/boss_bone_archon.png`,
`assets/sprites/bosses/boss_brood_mother.png`,
`assets/sprites/bosses/boss_ashen_colossus.png`,
`assets/sprites/elites/mini_scavenger_reaper.png`,
`assets/sprites/elites/mini_plague_bellringer.png`,
`assets/sprites/elites/mini_bone_warden.png`,
`assets/sprites/elites/mini_spark_wight.png`,
`assets/sprites/elites/mini_rot_hound.png`,
`assets/sprites/elites/mini_shadow_devourer.png`.
Все 9 PNG — `512x512`, RGBA, transparent, с preview-листами
`docs/design/previews/new_bosses_mini_elites_contact.png` и
`docs/design/previews/new_bosses_mini_elites_scale_preview.png`. Runtime scene/codex wiring и cutout rig slicing остаются Back-end/Animator scope; Design handoff записан в соответствующие task-файлы.

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

### Солдат

- ID: `soldier`
- Роль: тактический физический класс, удерживает линию огня через залпы, гранаты и штык.
- Базовое здоровье: около 78 от `Endurance=6`.
- Базовая скорость: средняя.
- Спрайты: `assets/sprites/characters/soldier.png`, cutout-части `assets/sprites/characters/cutout/soldier_*.png`.
- Особенность: оружие отделено от персонажа и крепится через `WeaponSocket`; все 3 оружия используют новые режимы `ClassWeapon`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 7 |
| Ловкость | 6 |
| Интеллект | 2 |
| Восприятие | 8 |
| Энергия | 4 |
| Знание | 5 |
| Выносливость | 6 |
| Лидерство | 5 |

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

### Расширенный Ростер 0.1.4

Foundation новых классов уже включен в выбор персонажа, выбор оружия, кодекс, формулы характеристик, ascension и smoke tests. Design visual set для первых 9 персонажей и полного набора оружия 9 классов готов: новые герои art-approved, все 27 weapon PNG существуют по каноническим путям; gameplay/backend-сцены подключают matching weapon PNG без documented visual fallback. SCRUM-168 добавил 10-й Back-end-класс `soldier` и довел набор до 30 weapon variants; canonical Soldier character/weapon PNG и cutout rig/motion подключены. SCRUM-169 добавил 11-й Back-end-класс `thief` и довел набор до 33 weapon variants; canonical Thief character/weapon PNG и cutout rig/motion подключены. SCRUM-163 добавил 12-й Back-end-класс `elementalist` и довел набор до 36 weapon variants; canonical Elementalist character/weapon PNG и cutout rig/motion подключены. SCRUM-167 добавил 13-й Back-end-класс `sniper` и довел набор до 39 weapon variants; canonical Sniper character/weapon PNG и cutout rig/motion подключены. SCRUM-165 добавил 14-й Back-end-класс `priest` и довел набор до 42 weapon variants; canonical Priest character/weapon PNG и cutout rig/motion подключены. SCRUM-162 добавил 15-й Back-end-класс `biologist` и довел набор до 45 weapon variants; canonical Biologist character/weapon PNG и cutout rig/motion подключены. SCRUM-166 добавил 16-й Back-end-класс `robot` и довел набор до 48 weapon variants; canonical Robot character/weapon PNG и cutout rig/motion подключены. SCRUM-164 добавил финальный 17-й Back-end-класс `engineer` и довел набор до 51 weapon variant; canonical Engineer character/weapon PNG и cutout rig/motion подключены. Weapon art v2 pass 2026-06-12 дополнительно перерисовал оружие Рыцаря, заменил базовый `knight.png` на unarmed sprite без встроенного копья/щита, пересобрал `knight_*` cutouts и уменьшил `WeaponVisual.scale` у крупных оружий.

SCRUM-192 выровнял runtime `sprite_path` всех новых классов с `docs/design/content_registry.md`: `thief`, `elementalist`, `sniper`, `priest`, `biologist`, `robot` и `engineer` используют собственные canonical PNG из `assets/sprites/characters/`. Регрессия закрыта focused-тестом `tests/character_sprite_registry_alignment_test.gd`, который проверяет все 17 character IDs и существование их canonical sprite resources.

SCRUM-256 добавил framework уникальных классовых идентичностей: `ProgressionData.CLASS_MECHANIC_IDENTITIES` и фасадные API `class_mechanic_identity`, `class_main_attribute`, `weapon_mechanic_identity`. Для всех 17 классов зафиксированы главный атрибут, identity title, mechanic tags и 3 weapon identity. Это data contract для патча 0.1.5: последующие задачи melee/summoner/aura/VFX используют таблицу как источник направления, а сам framework не меняет текущий баланс.

SCRUM-243 добавил универсальную матрицу синергий `ProgressionData.ATTRIBUTE_WEAPON_SYNERGY_MAP`: каждый базовый атрибут имеет понятный эффект для melee, projectile, beam, AoE, summon и aura архетипов. `derived_parameters` получил мягкий cross-scaling для damage/magic/sound, attack speed, range/AoE, projectile speed, DoT, aura, summon и ultimate, поэтому прокачка любого атрибута меняет фактический параметр у representative оружия каждого архетипа. Стартовый DPS удерживается budget tuning; global damage/survivability smoke остаются зелеными.

SCRUM-254 усилил summon/support персонажей через data-driven `summon_role` поля. `SummonerWeapon` передает `AllyMinion` профиль урона, HP, скорости, интервала атаки, lifetime, control knockback и support heal, которые масштабируются от Leadership/`summon_amount`. Друидский `summon_amulet` теперь роль `pack_damage`, Химик `homunculus_vial` — `tank_control`, Друид `raven_totem` — `support_totem`, Инженер `engineer_sentry_wrench` — `engineer_sentry`, `engineer_repair_drone` — `support_drone`. `ProgressionData.weapon_archetype()` считает `summon_role` как summon archetype, а balance harness больше не добавляет чистым summon-оружиям невидимый direct hit.

SCRUM-245 добавил reusable status layer `scripts/status_effects.gd`. Статусы живут в meta цели (`status_effects`), поддерживают duration, refresh/add/extend stack policy, DoT ticks, speed multiplier, damage multiplier, damage-taken multiplier и marker metadata. `Enemy` учитывает status slow и vulnerability в движении/получении урона; `AllyMinion` учитывает command-aura damage/speed buff; `Player` тикает собственные статусы, раздает on-hit debuffs и классовые ауры. Тематические назначения: Dark Mage/Elementalist — `arcane_vulnerability`, Chemist/Doctor/Assassin/Biologist — `toxic_debuff`, Soldier/Knight/Robot — `staggered`, Guitarist/Druid/Engineer — `command_pressure` вокруг героя, Priest — мягкая self-support aura.

SCRUM-251 усилил ближние классы через data-driven melee identity hooks в `ClassWeapon` и `BerserkWeapon`: close-hit bonus, wounded execute, stagger knockback, cleave follow-up и small sustain. Эффекты назначены не одинаково, а по роли оружия: меч/копье добивают раненых, топор/кистень дают cleave, молот/щит/штык/робот дают stagger, кинжалы получают close execute, костяная пила — sustain. Эти эффекты не двигают тело игрока автоматически и учитываются в `ProgressionData._budget_melee_unique_bonus()` при DPS tuning.

| ID | Имя | Роль | Базовые характеристики |
| --- | --- | --- | --- |
| `soldier` | Солдат | Тактический физический контроль | Str 7, Agi 5, Int 3, Per 8, Energy 4, Know 3, End 7, Lead 5 |
| `thief` | Вор | Уловки, рикошеты, backstab и дымовое уклонение | Str 5, Agi 9, Int 3, Per 8, Energy 5, Know 4, End 4, Lead 5 |
| `elementalist` | Элементалист | Стихийные орбиты, призматические разломы и метеорные осколки | Str 2, Agi 4, Int 9, Per 7, Energy 8, Know 6, End 3, Lead 5 |
| `sniper` | Снайпер | Дальний lockshot, kill-zone и осколочные выстрелы | Str 6, Agi 8, Int 2, Per 10, Energy 3, Know 3, End 7, Lead 1 |
| `priest` | Священник | Священный sustain через освящение, ward-пульсы и молитвенную цепь | Str 2, Agi 4, Int 8, Per 6, Energy 7, Know 9, End 5, Lead 6 |
| `biologist` | Биолог | Биореакции: споровые зоны, анализ образцов и симбиотическая сеть | Str 2, Agi 5, Int 8, Per 7, Energy 6, Know 10, End 4, Lead 4 |
| `robot` | Робот | Тяжелый контроль: магнитный якорь, гидравлический пресс и реакторные выбросы | Str 8, Agi 3, Int 5, Per 5, Energy 7, Know 4, End 10, Lead 4 |
| `engineer` | Инженер | Мастерская устройств: sentry link, repair drone и pressure mines | Str 4, Agi 5, Int 7, Per 6, Energy 6, Know 6, End 5, Lead 10 |
| `assassin` | Ассасин | Быстрый крит-мили/линии | Str 6, Agi 10, Int 2, Per 6, Energy 3, Know 4, End 5, Lead 4 |
| `ranger` | Рейнджер | Дальний точный контроль | Str 7, Agi 7, Int 2, Per 9, Energy 4, Know 4, End 4, Lead 3 |
| `doctor` | Доктор | Sustain через урон и яд | Str 2, Agi 4, Int 8, Per 5, Energy 6, Know 8, End 5, Lead 2 |
| `chemist` | Химик | AoE/DoT зоны и алхимический summon | Str 2, Agi 4, Int 9, Per 6, Energy 7, Know 7, End 3, Lead 2 |
| `knight` | Рыцарь | Танк и тяжелый melee-control | Str 8, Agi 3, Int 2, Per 4, Energy 3, Know 4, End 10, Lead 6 |
| `druid` | Друид | Призыв, тернии, тотемы | Str 3, Agi 4, Int 4, Per 7, Energy 6, Know 5, End 5, Lead 9 |

## Оружие Берсерка

Берсерк использует отдельный скрипт `scripts/berserk_weapon.gd`. Урон наносится только в активное окно удара, синхронизированное с анимацией. Оружие показывает область поражения и не бьет одну цель несколько раз за один swing.

SCRUM-241 добавил переключатель прицеливания: `nearest` сохраняет автонаводку на ближайшего врага, `cursor` заставляет melee-дуги, лучи, снаряды и зоны использовать `Player.attack_aim_direction()` / `Player.attack_aim_position()` от курсора. Значение хранится в `user://settings.cfg` как `aim_mode` и применяется живьем через root meta.

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

## Оружие Расширенного Ростера 0.1.4

Все 17 игровых классов теперь имеют ровно 3 selectable weapon variants в `ProgressionData.WEAPONS_BY_CLASS`; smoke test проверяет загрузку и экипировку всех 51 вариантов.

ClassWeapon-режимы с полем `attack_mode` диспетчеризуются через
`ClassWeapon.ATTACK_MODE_EXECUTORS`, а не через длинный inline `match`.
Focused weapon smoke и umbrella runtime smoke проверяют, что каждый
data-driven `attack_mode` из `ProgressionData.WEAPONS_BY_CLASS` имеет
зарегистрированный executor. Legacy/Berserk-геометрия (`attack_shape`,
`summon`, `strip`, `sweep`, `circle`) остается в собственных runtime-скриптах и
не входит в этот ClassWeapon registry contract.

| Класс | Оружие | ID | Режим | Механика |
| --- | --- | --- | --- | --- |
| Солдат | Аркебуза строя | `soldier_rifle` | `suppression_burst` | 3 коротких выстрела по линии; основная цель полный урон, соседние цели reduced suppression damage |
| Солдат | Граната с фитилем | `soldier_grenade` | `grenade_cook` | Телеграф ground-zone, короткая задержка и взрыв с falloff урона |
| Солдат | Штык-стойка | `soldier_bayonet` | `bayonet_brace` | Короткая defensive corridor-стойка: один укол на врага за brace window + knockback |
| Вор | Кошель Рикошета | `thief_coin_pouch` | `coin_ricochet` | Монета цепляется по ближайшим врагам, урон убывает по цепи, первые попадания крадут золото |
| Вор | Плащ Захода | `thief_shadow_cloak` | `shadow_backstab` | Фантомный удар за ближайшей целью наносит усиленный урон и малый splash рядом, не двигая героя |
| Вор | Дымовая Бомба | `thief_smoke_bomb` | `smoke_bomb` | Delayed AoE дыма плюс временный dodge-window |
| Элементалист | Кольцо Трех Стихий | `elementalist_orb_ring` | `elemental_orbit` | Орбита стихийных сфер вокруг героя с несколькими AoE-тиками |
| Элементалист | Призматический Фокус | `elementalist_prism_focus` | `prism_rift` | Крестовой разлом из двух лучей по ближайшей цели после короткого телеграфа |
| Элементалист | Ядро Метеора | `elementalist_meteor_core` | `meteor_shards` | Отложенный удар метеора и вторичные осколочные взрывы рядом |
| Снайпер | Винтовка Мертвого Глаза | `sniper_deadeye_rifle` | `sniper_lockshot` | Короткий прицел/телеграф, затем точный дальний beam по locked target и falloff по линии |
| Снайпер | Прицел Наводчика | `sniper_spotter_scope` | `sniper_kill_zone` | Маркированная kill-zone у ближайшей цели вызывает несколько точных sky-beam попаданий |
| Снайпер | Осколочные Патроны | `sniper_shatter_rounds` | `sniper_split_round` | Основной дальний выстрел раскалывается по соседним врагам с убывающим уроном |
| Священник | Светлый Реликварий | `priest_reliquary` | `priest_sanctify` | Освящает ближайшую цель, затем знак взрывается по области и лечит часть нанесенного урона |
| Священник | Кадило Обета | `priest_censer` | `priest_ward` | Несколько ward-пульсов вокруг героя наносят урон врагам рядом и дают малое лечение |
| Священник | Колокол Молитвы | `priest_chime` | `priest_prayer_chain` | Молитвенная цепь перескакивает между врагами и возвращает sustain |
| Биолог | Споровая Линза | `biologist_spore_lens` | `bio_spore_bloom` | Три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон |
| Биолог | Инъектор Образцов | `biologist_sample_injector` | `bio_sample_dart` | Инъектор берет образец у цели, затем delayed analysis pulses бьют цель и ближайшие ткани |
| Биолог | Семя Симбионта | `biologist_symbiote_seed` | `bio_symbiote_web` | Первичная цель связывается с соседними врагами симбиотической сетью и делит биоурон |
| Робот | Магнитный Якорь | `robot_magnetic_anchor` | `robot_magnetic_anchor` | Якорь на ближайшей цели стягивает врагов к центру и бьет импульсом |
| Робот | Гидравлический Пресс | `robot_hydraulic_press` | `robot_compression_line` | Две силовые губки сходятся по линии атаки и сжимают врагов к оси |
| Робот | Реакторное Ядро | `robot_reactor_core` | `robot_reactor_vent` | Четыре направленных выброса вокруг корпуса чистят ближний круг |
| Инженер | Ключ Часового | `engineer_sentry_wrench` | `engineer_sentry_link` | Временная турель сама выбирает цели и бьет их точечными лучами |
| Инженер | Ремонтный Дрон | `engineer_repair_drone` | `engineer_repair_drone` | Цепная дуга по врагам возвращает часть нанесенного урона в ремонт |
| Инженер | Минная Сетка | `engineer_pressure_mines` | `engineer_pressure_mines` | Три мины веером срабатывают отдельно при касании врагом |
| Ассасин | Чакрамы | `chakrams` | `boomerang` | Коридор до цели и обратно; критовые попадания запускают теневой всплеск у цели без смещения героя |
| Ассасин | Теневые кинжалы | `shadow_daggers` | `stab_flurry` | Быстрые short-range multi-stabs с критовым теневым burst у цели |
| Ассасин | Ядовитая струна | `venom_wire` | `dot_beam` | Тонкая poison-линия с DoT и теневым всплеском на крите |
| Рейнджер | Лунный арбалет | `moon_crossbow` | `beam` | Заряжаемый piercing shot: неподвижная стойка повышает урон |
| Рейнджер | Грозовой длинный лук | `storm_longbow` | `beam` | Заряжаемый веер дальних лучей |
| Рейнджер | Охотничий капкан | `hunter_trap` | `trap` | Deploy trap: burst + knockback; стойка усиливает подготовку |
| Доктор | Зелье восстановления | `restore_potion` | `drain_link` | Drain-связь к ближайшей цели, часть нанесенного урона лечит Доктора |
| Доктор | Чумной шприц | `plague_syringe` | `drain_link` | Тонкая чумная связь с DoT и lifesteal |
| Доктор | Костяная пила | `bone_saw` | `stab_flurry` | Ближний saw/flurry, DoT и lifesteal от нанесенного урона |
| Химик | Взрывная пыль | `blast_powder` | `aoe_projectile` | Spark cloud + взрыв; облака разных элементов дают combo explosion |
| Химик | Кислотная колба | `acid_flask` | `aoe_projectile` | Poison/acid pool; пересечение с другим элементом взрывает комбо |
| Химик | Склянка гомункула | `homunculus_vial` | `summon` | Гомункул `tank_control`: temporary minion от magic damage, больше HP и control knockback |
| Рыцарь | Копье | `long_spear` | `strip` | Длинный точечный strip; блок раз в cooldown снижает удар и контратакует рядом |
| Рыцарь | Башенный щит | `tower_shield` | `sweep` | Frontal bash/control; самый надежный block/counter вариант |
| Рыцарь | Освященный кистень | `holy_flail` | `circle` | Medium circular heavy swing; более сильная контратака, но длиннее cooldown |
| Друид | Амулет призыва | `summon_amulet` | `summon` | Beast pack `pack_damage`: Leadership scaling, быстрые питомцы получают команду attack_target |
| Друид | Посох терний | `briar_staff` | `aoe_projectile` | Thorn zone, AoE DoT |
| Друид | Вороний тотем | `raven_totem` | `amp` | `support_totem` pulses, Leadership-scaled deploy limit, малый support sustain |

Новые backend modes/hooks: Soldier `suppression_burst`/`grenade_cook`/`bayonet_brace`, Thief `coin_ricochet`/`shadow_backstab`/`smoke_bomb`, Elementalist `elemental_orbit`/`prism_rift`/`meteor_shards`, Sniper `sniper_lockshot`/`sniper_kill_zone`/`sniper_split_round`, Priest `priest_sanctify`/`priest_ward`/`priest_prayer_chain`, Biologist `bio_spore_bloom`/`bio_sample_dart`/`bio_symbiote_web`, `stab_flurry`, `dot_beam`, `trap`, `drain_link`, ranger stance charge (`charge_seconds`/`charge_max_multiplier`), assassin crit shadow burst (`crit_shadow_burst_radius`), chemist cloud combos (`pool_element`/`combo_clouds`), knight block/counter (`block_reduction`/`counter_damage_multiplier`) и druid pet commands (`command_mode`, `command_target`). Deploy/trap/totem/cloud visuals используют `WeaponVisual` или `AttackVfx`, регистрируются в `player_weapon_effects` для cleanup; химические облака дополнительно временно входят в `chemist_clouds`.

SCRUM-152/157/254: `AllyMinion.tscn` больше не использует Polygon2D-placeholder, а показывает `assets/sprites/allies/ally_druid_beast.png` как безопасный fallback. Source-specific runtime mapping подключен: `summon_amulet` выбирает `ally_druid_beast.png` или `ally_druid_pack_spirit.png`, `homunculus_vial` использует `ally_homunculus.png`, будущий `leadership_echo` зарезервирован под `ally_leadership_echo.png`. Deployable mapping вынесен в weapon config: `sound_amp` ставит `deploy_sound_amp_field.png`, `raven_totem` ставит `deploy_raven_totem_field.png`. С SCRUM-254 `AllyMinion` имеет runtime `max_health/health`, `take_damage()` и `set_combat_profile()`, чтобы призывы могли получать роль, выживаемость и темп от владельца. Cleanup groups (`allies`, `player_weapon_effects`, `deployed_sound_amps`) не менялись.

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

Правила: эффекты самоочищаются tween-ами, классовое оружие дополнительно регистрирует их в `player_weapon_effects` (мертвые ссылки фильтруются в `_register_effect`/`cleanup_effects`). Runtime smoke проверяет экипировку всех 51 weapon variants; VFX smoke остается профильным тестом основных хелперов. Скриншоты для ручной проверки: `tools/capture_vfx_preview.gd` (windowed) -> `build/vfx_preview/`.

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

Формулы и описания для UI характеристик находятся в `scripts/stat_formulas.gd`.
`scripts/progression_data.gd` остается compatibility facade для старых runtime
ссылок, а данные разделены по domain owners: `progression_data_characters.gd`,
`progression_data_weapons.gd`, `progression_data_content.gd`,
`progression_data_shop.gd`, `progression_data_ascension.gd`,
`progression_data_balance.gd` и `progression_data_enemies.gd`.

Актуальная философия прокачки: все базовые и производные атрибуты полезны каждому классу. Старая фильтрация «нерелевантных» статов отключена; `STAT_CLASS_RELEVANCE` оставлен пустым для совместимости, а reward pools не скрывают чужие параметры. Для тематически чужих эффектов UI показывает классовую интерпретацию: магический урон становится зачарованием оружия, Лидерство — эхо-оружием/фантомом/соколом/фамильяром, звуковой урон — боевым кличем, DoT — малым bleed/burn/poison, Energy — ускорением уникальной механики.

Runtime hooks уже подключены в `scripts/player.gd` и `scripts/class_weapon.gd`: оружейные попадания могут запускать magic enchant splash, малый DoT, leadership echo-hit и battle shout; Energy ускоряет теневой burst Ассасина, counter Рыцаря и charge Рейнджера. Крит/уворот игрока не двигают тело персонажа автоматически: позиция героя остается под контролем ввода, а критовые классовые эффекты Ассасина происходят как вспышка/удар у цели.

Status hooks SCRUM-245: weapon hit дополнительно может наложить `arcane_vulnerability`, `toxic_debuff` или `staggered` по классу. Leadership/support классы обновляют ауру примерно раз в 0.55с: союзники внутри радиуса получают `command_aura`, враги — `command_pressure`. Визуально используется существующий мягкий `AttackVfx.ring_pulse` плюс marker metadata; новый Design asset не требуется.

Криты после SCRUM-247 используют сглаженные формулы: `crit_chance = effective_crit_chance(0.04 + Agility*0.0075 + flat*0.75)`, cap 55%; `crit_damage_multiplier = clamp(1.30 + Agility*0.055 + flat*0.75, 1.0, 2.75)`. Это сохраняет crit-builds полезными, но не дает flat-стаку шанса/силы крита доминировать над стабильным уроном; средний DPS удерживается через `ProgressionData.weapon()` budget tuning.

## Награды И Артефакты

В игре есть:
- награды за уровень;
- награды базовых характеристик;
- артефакты;
- магазинные предметы;
- классовые артефакты;
- риск-награда артефакты.

Магазин показывает четыре случайных предложения inline поверх `screen_shop_background.png` / shop backdrop в центральной свободной области экрана и позволяет купить несколько предметов за один визит, если хватает денег. Сток генерируется один раз на конкретный `shop`-узел маршрута и сохраняет purchased-состояние при повторном открытии того же экрана через меню/досье/FAB; новый `shop`-узел получает свежий набор. Предметы висят без карточных рамок: прозрачная clickable area, предметная иконка, контактная тень и компактный ценник с иконкой монеты. Название, описание, цену, class restriction и причину недоступности игрок видит только в hover tooltip. Недоступные товары затемняются и получают красноватый ценник; купленные товары снимаются со стены и заменяются маленьким empty-hook состоянием «снято». Runtime smoke проверяет фактический центр группы товаров и no-overlap на 1280x720/2560x1440; dump пишется в `build/qa/shop_wall_frameless_rects.md`.

Экономика 0.1.4: магазин, докачка атрибутов, reroll и платные event-исходы проходят через `ProgressionData.stage_scaled_cost()`, где поверх stage scale применяется глобальный `ECONOMY_PRICE_MULTIPLIER = 1.10`. Дроп назначается по классам целей (`DROP_CLASS_MULTIPLIERS`): обычные враги остаются базой, сложные ranged/summoner получают умеренный бонус, bruiser/shield дают около x1.75 XP и x1.85 золота, мини-элитки x3.6/x3.8, элитки x8/x8.5, босс получает fixed reward, умноженный на `stage_scale`. XP-кривая усилена до `ceil(req * 1.42 + 3)`, чтобы общий темп level-up оставался близким к прежнему. Проверка SCRUM-188 (`build/route_economy_xp_model.md`) моделирует balanced/combat-heavy/shop-heavy маршруты: 8-9 level-up до/включая босса, healthy/high покупательная способность; текущий +7.1% XP fixture оставлен без дополнительного повышения.

Design visual kit/spec для всех артефактов, shop-only предметов и курсора описан в `docs/design/artifact_shop_cursor_visual_kit.md`:
- 53 unique artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png` (`256x256`, transparent realistic epic D&D/tabletop fantasy raster magic items);
- 7 shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`;
- полный mapping: `docs/design/artifact_shop_cursor_visual_kit.md`;
- artifact icon raster extraction pipeline: `tools/extract_realistic_dnd_artifact_icons.py`;
- shop/cursor generator: `tools/generate_artifact_shop_cursor_assets.py`;
- active QA preview: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` (large and 40px checks for every active artifact).

После пользовательского фидбэка 2026-06-12 artifact icons заменены как красивые растровые предметы, а не пентаграммы/плоские символы: один законченный D&D-style magic item на файл, bbox с запасом от краев, без пьедесталов, фоновых тайлов, осколков, частиц и текста. Образ каждого предмета привязан к названию и эффекту из `ProgressionData.ARTIFACTS`; предыдущие generated/vector-like, glossy, concept-sheet tile и per-item pictogram направления заменены. Shop assets остаются в FantasyDisk fantasy-medallion style; cursor assets заменены в SCRUM-223 на dragon/claw/fire pointer.

Back-end integration complete: `scripts/ui_screens.gd` сначала ищет финальные PNG по mapping из visual kit, а если их нет, временно использует осмысленный fallback через `scripts/ui_icon_registry.gd` по эффекту предмета. На 2026-06-11 фактические artifact/shop/cursor PNG готовы и импортированы, поэтому fallback остается только fail-safe.

Level-up показывает 3 фиксированных варианта на каждый полученный уровень: обычные улучшения оружия/параметров и очень редкие основные характеристики (`strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`) с визуальной rare-пометкой. Вес обычных наград считается от единого источника `ProgressionData.ATTRIBUTE_PRIORITIES` и зависимости награды от базовой характеристики: профильные параметры класса выпадают чаще, но у каждого варианта есть floor. Один уровень дает ровно один выбор; если накопилось несколько уровней, окна открываются последовательно. Окно можно закрыть через «Позже» без потери выбора: тот же набор остается в `level_up_offer`, а нижняя кнопка «Повышение уровня (N)» возвращает игрока к сохраненному пику. Level-up и докачка атрибутов показывают иконки через `UIIconRegistry` и добавляют текст «Интерпретация» для выбранного героя. Артефакты с `class_affinity` больше не считаются нерабочими для чужого класса: affinity теперь описывает тематику, а `affinity_mods` применяются через интерпретацию текущего героя.

## Ультимейты

У каждого из 17 игровых классов есть ultimate ability, описанная в `ProgressionData.ULTIMATE_CONFIGS` и показанная в Кодексе. Заряд копится от нанесенного и полученного урона до 100, масштабируется от Energy и активируется InputMap action `ultimate` (default R, ребиндится в настройках). После активации заряд сбрасывается.

Боевой HUD содержит компактную карточку `ULT` рядом с HP/XP/money; tooltip показывает текущую клавишу и состояние готовности. `ultimate_multiplier` больше не зарезервирован: он усиливает урон, радиус, длительность или число целей ульты. По боссам действует per-hit cap от max HP босса. Верхний HUD обязан проходить no-overlap проверку фактических `global_rect`: ресурсная панель, таймер/бейдж Возвышения и ряд артефактов адаптивно размещаются без пересечений на 1152x648, 1280x720 и 2560x1440.

UI no-overlap coverage 0.1.4: `tests/ui_no_overlap_matrix_test.gd` проверяет peer-controls main menu, settings, Codex, patch notes, hero select, victory и death на 1152x648, 1280x720, 1600x900 и 2560x1440, а `runtime_smoke_test.gd` дополнительно держит специализированные проверки HUD, shop wall, hero radar, route/level-up/elite reward flows. Matrix dump пишется в `build/qa/ui_no_overlap_matrix.md`.

Runtime smoke split 0.1.4: focused suites наследуют helper/assertion слой umbrella smoke и запускают тематические подмножества без изменения gameplay behavior. Это дает быстрые проверки для UI/menu, combat, progression/economy, weapon mechanics и boss/elite перед крупными refactor-задачами, но обязательная полная команда `runtime_smoke_test.gd` остается доступной и должна проходить.

Реализованные ульты: Берсерк — Неистовство; Солдат — Огневой приказ; Вор — Черная метка; Элементалист — Стихийная Сверхнова; Снайпер — Последний Выстрел; Священник — Хор Искупления; Биолог — Пробуждение Колонии; Темный маг — Темная буря; Гитарист — Соло; Ассасин — Танец клинков; Рейнджер — Лунный залп; Доктор — Переливание; Химик — Цепная реакция; Рыцарь — Бастион; Друид — Зов стаи.

## Звук

Звуковая система реализована через autoload `AudioManager` (`scripts/audio_manager.gd`, регистрация в `project.godot`):

- SFX: `sfx_hit` (попадание по врагу), `sfx_player_hit` (урон по игроку), `sfx_dodge` (уворот), `sfx_pickup_xp`, `sfx_pickup_money`, `sfx_level_up`.
- Музыка: `music_menu` (меню, карта, небоевые экраны), `music_combat` (бой). Лупы включаются через `AudioStreamWAV.LOOP_FORWARD`.
- Ассеты лежат в `assets/audio/` и генерируются воспроизводимо скриптом `tools/generate_audio_assets.py` (production helper, не runtime).
- Пул из 8 SFX-плееров и троттлинг 0.05с на звук защищают от спама при уроне по толпе.
- В headless-режиме (smoke tests) аудио полностью отключено, чтобы не оставлять висячие AudioStreamPlayback при выходе.
- Громкость: музыка -8 dB, SFX -4 dB, шина Master. Нулевой `master_volume` задает очень тихую громкость, но не hard-mute'ит Master bus; mute применяется только явными флагами `music_enabled=false` / `sfx_enabled=false`. Старые `user://settings.cfg` с `master_volume <= 0` и без `master_zero_intent` мигрируют к дефолтным 100%, чтобы случайно «залипшая» тишина не переживала перезапуск. Кроссфейд музыки при прерывании твина сбрасывает fade-player и восстанавливает целевую громкость текущего трека.

## Флоу Победы И Докачка (обновлено 2026-06-12)

- После обычного победного боя: затемнение + крупная золотая надпись «ПОБЕДА» (клик или 1.3с) -> окно докачки атрибутов -> карта.
- После элитного победного боя: «ПОБЕДА» -> экран выбора 1 из 3 артефактов -> окно докачки атрибутов -> карта.
- Босс ведет на отдельный экран победы, как раньше; дополнительно игрок получает гарантированный tier-3 артефакт и крупное золото.
- Окно докачки: выбор 1 из 2 случайных характеристик (+1) за `ProgressionData.stage_scaled_cost(18 + 6 * route_stage, route_stage)` золота; «Обновить» пары за `stage_scaled_cost(6 + 2 * route_stage, route_stage)` (2 раза за окно); «Пропустить»; Escape = пропуск.
- Нижняя кнопка «Повышение уровня (N)» появляется при непотраченных level-up выборах в бою и на небоевых экранах; она открывает тот же зафиксированный набор из 3 карт и показывает pending-бейдж. При `pending_level_ups > 0` это единственная точка входа в level-up: `UpgradeFabButton` скрывается, чтобы не дублировать действие. Когда pending-уровней нет, FAB остается доступен для докачки характеристик за золото. На событии докачка отключена (повторный вход перегенерировал бы выборы события).

## Навигация И UX

- Escape = назад на меню/предзабеговых экранах через единый стек: настройки/кодекс/выбор персонажа -> меню; выбор оружия -> выбор персонажа. В активном забеге Escape открывает единое меню паузы поверх текущего состояния: бой, route map, магазин, level-up, докачка атрибутов, событие, награда элитки. Повторный Escape закрывает меню и оставляет подлежащий экран без reroll/сброса; досье персонажа открывается отдельной кнопкой «Досье персонажа» внутри pause menu. Событие по-прежнему требует выбора действия; если skip не разрешен, кнопка «Назад» на событии видна, но disabled и объясняет это в tooltip.
- Экран выбора героя — fullscreen `HeroSelectScreen` v3: слева крупный full-art портрет выбранного героя без отдельной подписи под портретом, в центре-справа отдельная рамка досье (единственное имя героя, описание, сильные/слабые стороны, список 3 оружий, селектор Возвышения, кнопка «Выбрать»), а программная радар-диаграмма по 8 базовым характеристикам вынесена из рамки в плавающий `HeroSelectRadarPanel` в правом верхнем углу. Layout резервирует место под радар, поэтому досье остается слева от него и не наползает на виджет. Селектор Возвышения возле кнопки старта показывает только дельту выбранного уровня (`Уровень N: ...`), чтобы игрок видел новое усложнение без повторения предыдущих уровней. Радар нормируется по общему максимуму каждой характеристики среди всех игровых героев, поэтому силуэты классов сравнимы между собой. Runtime smoke проверяет, что правый край описания/досье остается левее радара с зазором, что радар parented to `HeroSelectScreen`/anchored top-right и что нет overlap на 1280x720, 1600x900 и 2560x1440; dump: `build/qa/hero_select_radar_rects.md`. Внизу находится адаптивная лента кликабельных миниатюр-картинок без видимых подписей; выбор миниатюры мгновенно обновляет портрет, досье и радар, а переход к оружию происходит только через кнопку «Выбрать». Все кнопки игры используют pointer-курсор.
- Размеры изображений: кодекс — персонажи 176px, монстры 150px, артефакты 96px; HUD-артефакты 48px; пауза-артефакты 56px; иконки магазина 112px внутри frameless hit area 164x186.
- Фон маршрутной карты: если существует `assets/backgrounds/route_map_backdrop.png`, он подключается с cover-растяжением и затемнением 0.62 для читаемости узлов; иначе — прежний однотонный фон (graceful fallback до выхода арта).

## Кодекс (Энциклопедия)

Кнопка «Кодекс» в главном меню открывает внутриигровую энциклопедию (`_show_codex_screen` в `scripts/ui_screens.gd`). Данные — data-driven из `scripts/codex_data.gd`: персонажи/оружие/артефакты/характеристики собираются из `progression_data.gd` и `stat_formulas.gd`, описания монстров и канонические имена умений живут в `CODEX_DATA.MONSTERS` и зарегистрированы в `docs/design/content_registry.md` (раздел «Умения Монстров»).

Разделы: Персонажи (17 игровых классов, стиль игры, сильные/слабые стороны, оружие), Монстры (11 обычных + 4 элитки + 2 босса, поведение и названные умения), Артефакты (все из ARTIFACTS + SHOP_ITEMS с иконками), Характеристики (8 базовых + производные из STAT_DEFINITIONS с влияниями). Разделы строятся лениво при первом открытии вкладки и кэшируются — меню не фризит.

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
| Главное меню | Эпичный battle-art фон и левая колонка из шести стандартных action-кнопок: начать новую игру, настройки, древо умений, что нового, кодекс, выйти из игры |
| Настройки | Вкладки «Экран» / «Звук» / «Управление»: монитор, режим окна, разрешение, full-width audio sliders, mute, rebinding движения/паузы/ultimate |
| Выбор персонажа | Fullscreen v3: большой портрет слева без дубля имени, справа единая информ-панель с досье слева от радара характеристик, адаптивная лента героев снизу только картинками |
| Выбор оружия | Три оружия выбранного класса как легкие кликабельные карточки: спрайт оружия слева, название/описание, русские статы «Дальность/Радиус/Перезарядка»; тяжелая button texture frame не используется |
| Карта маршрута | Вертикальная карта с иконками и tooltip |
| Боевой HUD | Минимальные HP, XP, деньги, ULT, таймер/бейдж Возвышения и ряд артефактов с no-overlap layout |
| Level-up | Геройский экран выбора 1 из 3 наград с портретом персонажа, частицами, редким main-stat акцентом и отложенным выбором через нижнюю кнопку; reward варианты выглядят как text-field/panel карточки, оставаясь кликабельными |
| Магазин | Frameless wall-предметы поверх `screen_shop_background.png`: иконка, тень, компактная цена, описание только hover tooltip, unavailable dim/price и empty-hook после покупки |
| Событие | Выбор одного из вариантов события поверх `screen_event_background.png`; длинный текст исхода находится в рамке над короткой кнопкой выбора |
| Отдых | Лечение или защитный бонус поверх `screen_campfire_background.png`; описание бонуса находится в рамке над стандартной action-кнопкой |
| Pause menu / stats | Escape открывает компактное run menu с Continue/Досье/Settings/End Run/Main Menu; досье персонажа открывается из него и показывает кнопки слева, приоритетные базовые характеристики сверху с бейджем/tooltip, производные параметры справа в логических группах |
| Смерть | Завершение забега |
| Победа | Русский пользовательский итог без внутренних ID: победа над боссом, очки наследия, прогресс Возвышения и смысл новой награды |

HP, XP и деньги должны оставаться видимыми на карте, в событиях и в магазине.

Обновление 2026-06-12 (артефакты, таймер и no-overlap HUD):
- Игрок хранит артефакты как `{id, title}` (`scripts/player.gd`); id используется для иконок, формат совместим со старыми title-записями.
- Боевой HUD показывает ряд иконок подобранных артефактов 40px в правом верхнем углу (`ArtifactHudRow`, HFlowContainer с переносом) с tooltip «название + эффект»; ряд перестраивается только при изменении количества артефактов. Если на узком окне верхняя полоса занята ресурсами/таймером/бейджем, ряд артефактов переносится ниже, чтобы HUD-плашки не пересекались.
- Меню паузы содержит блок «Артефакты» под базовыми характеристиками (`ArtifactsList` в `scripts/pause_stats_menu.gd`): иконки с tooltip, либо подпись «Пока не найдено».
- Таймер боя — стилизованная верхняя панель (`CombatTimerPanel`, формат M:SS); при остатке <=5 секунд цифры и рамка краснеют с легкой пульсацией. На широких окнах таймер остается по центру; на узких он смещается вправо от ресурсной панели. Таймер создается только в обычных/элитных боях; на босс-файтах `CombatTimerPanel` и `timer_label` не создаются вообще, вместо него может показываться `AscensionHudBadge`.
- Магазин: товары больше не лежат в карточной 2x2 сетке. `ShopParchmentWall` держит свободно расставленные wall hit areas на «пустой стене» фона правее торговца (анкеры ~50-82% ширины и 10-72% высоты экрана), чтобы предметы выглядели подвешенными на стене лавки. Runtime smoke пишет `build/qa/shop_wall_frameless_rects.md` и проверяет, что hit areas/иконки/ценники не пересекаются между собой и верхним HUD на 1280x720 и 2560x1440. Боевой экран не показывает полный список характеристик, оружие, артефакты, stage/debug text или derived-stat dump; подробности живут в Escape stats menu и reward UI.

Shop visual kit asset-ready (слот/hover frame больше не используется активным wall layout, но оставлен как совместимый asset):
- `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png`;
- `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png`;
- `assets/sprites/ui/shop/ui_shop_price_badge.png`;
- `assets/sprites/ui/shop/ui_shop_purchased_overlay.png`;
- `assets/sprites/ui/shop/ui_shop_tooltip_frame.png`.

Game cursor asset-ready:
- default: `assets/sprites/ui/cursor/game_cursor.png`;
- hover: `assets/sprites/ui/cursor/game_cursor_hover.png`;
- attack: `assets/sprites/ui/cursor/game_cursor_attack.png`;
- hotspot: `(2, 2)`.
- style: dark steel dragon/clawed pointer with a sharp upper-left tip, orange fire glow and red gem/eye; hover/attack reuse the same silhouette with stronger warm glow.

Централизованный mapping UI-иконок находится в `scripts/ui_icon_registry.gd`. Он покрывает 8 базовых характеристик, все активные производные параметры из Escape stats menu и HUD-ресурсы `hp`, `xp`, `money`, `ultimate_multiplier`. Финальные polished stylized fantasy cartoon PNG лежат в `assets/sprites/ui/icons/stats/`, `assets/sprites/ui/icons/derived/` и `assets/sprites/ui/hud/`; registry автоматически подхватывает реальные текстуры для боевого HUD, level-up reward cards, Escape stats menu, Кодекса и stat/reward/tooltips. Для производных параметров, у которых пока нет отдельного Design PNG (`absorb`, `regeneration`, `vampiric_*`, `range_multiplier`, `knockback_distance`, `ultimate_multiplier`), registry использует ближайшую существующую derived-иконку как backend fallback, без emoji/default placeholders. Shop item icons дополнительно разрешаются через реальные `artifact_<artifact_id>.png` / `shop_<shop_item_id>.png`; fallback в этот registry остается только fail-safe, если asset временно отсутствует.

Локализация и глоссарий (SCRUM-210): пользовательские строки ключевых экранов ведутся на русском; магазин, level-up rewards, HUD-ресурсы, кодексные описания и артефактные тиры больше не используют видимые `damage/HP/Tier/DoT/AoE` формулировки. Data-driven глоссарий живет в `scripts/glossary.gd` и покрывает базовые характеристики, производные параметры и основные механики (`Возвышение`, `Артефакт`, `Телеграф`, `Периодический урон`, `Ультимейт`, `Призыв` и т.д.). В кодексе есть вкладка «Глоссарий». Термины создаются через `_make_glossary_term_button()`: пунктирная underline-метка, tooltip по hover на обычных экранах и Alt+hover в popup-контексте.

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

Элитки выбираются случайно. Они должны быть примерно на порядок опаснее обычных врагов за счет HP, урона и паттернов. Обновление 2026-06-12: элитки используют `ProgressionData.stage_scale(route_stage)`, получают большой HP-бюджет под ~45-90с активного боя в budget estimate, имеют meta-флаг второй фазы на 50% HP и после победы открывают выбор 1 из 3 артефактов.

Обновление SCRUM-260 от 2026-06-13: размеры enemy-rank data-driven через `ProgressionData.ENEMY_SIZE_PROFILES`: ordinary 1.00, mini_elite 1.05, route elite 1.68, boss 1.90. Mini-элитки свиты Возвышения получают meta `epic_scale_profile=mini_elite` до `_ready()` и визуально читаются как усиленные мобы, карточные элитки стали крупнее и немного опаснее (HP x1.08, damage x1.06 в `_scale_elite_enemy`), боссы остаются крупнейшими. Один node scale тянет rig/body, `CollisionShape2D`, auto-fit contact_range и HP-bar.

Обновление SCRUM-259 от 2026-06-13: у элиток и боссов есть общий data-driven каталог `ProgressionData.ENEMY_MECHANIC_CATALOG`, боевые конфиги элиток `ELITE_ATTACK_CONFIGS` и unique-pattern registry `UNIQUE_ENCOUNTER_PATTERNS`. При `_ready()` сущность получает meta `unique_pattern_id`, `unique_pattern_title`, `unique_mechanics`; smoke проверяет каталог, неповторяемые signatures, telegraph/state phases и фактический spawn boss-specific mechanics. У каждой элитки есть уникальная телеграфированная активная атака со state machine `windup -> strike -> recover -> idle` (сигнал `elite_attack_phase_changed` для Animator). Во время атаки элитка стоит на месте; урон атаки ограничен 25% максимального HP игрока; от всех атак можно увернуться движением.

Обновление SCRUM-135 от 2026-06-12: активные source sprites всех 4 элиток заменены на native `512x512` и перенарезаны в `assets/sprites/elites/cutout/` с manifest `size = Vector2(512, 512)`. Поза/силуэт сохранены 1:1, поэтому хитбоксы, contact_range и epic scale остались прежними, а QHD/Retina-рендер больше не тянет 256px-арт выше native.

| Элитка | Сцена | Спрайт | Уникальное поведение |
| --- | --- | --- | --- |
| Железный Оплот | `scenes/EliteArmored.tscn` | `assets/sprites/elites/iron_bastion.png` | Щит; шипованный панцирь во время щита; Slam-волна: замах 0.6с, кольцо 260 с уроном и отбрасыванием |
| Ночной Сталкер | `scenes/EliteStalker.tscn` | `assets/sprites/elites/night_stalker.png` | Рывки; Теневой удар: уход в тень 0.5с, телепорт за спину игрока; во второй фазе зеркальный второй заход |
| Чумной Пророк | `scenes/ElitePoisoned.tscn` | `assets/sprites/elites/plague_prophet.png` | Ядовитые зоны; Ядовитый залп: lob-снаряды, лужи на 3с с тиками, чумная тематика healing inversion hook |
| Маршал Осколков | `scenes/EliteCommander.tscn` | `assets/sprites/elites/shard_marshal.png` | Аура усиления; Залп осколков: веер из 5 кристальных снарядов; фаза 2 добавляет кольцо осколков |

## Боссы

Босс выбирается случайно на финальном узле маршрута.

| Босс | ID | Сцена | Спрайт | Паттерны |
| --- | --- | --- | --- | --- |
| Rift Warden | `rift_warden` | `scenes/BossWarden.tscn` | `boss_rift_warden.png` | Залпы, зоны разлома, призыв, щит, увороты, gravity well |
| Disk Devourer | `disk_devourer` | `scenes/BossDiskDevourer.tscn` | `boss_disk_devourer.png` | Рывок, slam AoE, radial burst, vampiric bite, enrage |
| Bone Archon | `bone_archon` | `scenes/BossBoneArchon.tscn` | placeholder `boss_rift_warden.png` | Скелеты, веер черепов, bone prison/wall с проходом |
| Brood Mother | `brood_mother` | `scenes/BossBroodMother.tscn` | placeholder `boss_disk_devourer.png` | Выводок, web slow zones, дополнительный web pressure, phase-3 lunge |
| Ashen Colossus | `ashen_colossus` | `scenes/BossAshenColossus.tscn` | placeholder `boss_disk_devourer.png` | Slam-волны, ember fields, molten armor pulse, enrage |

Боссы используют `scripts/boss.gd`, который расширяет логику обычного врага. Обновление 2026-06-12: каждый босс имеет 3 HP-фазы (`100-66%`, `66-33%`, `33-0%`), фазовые метки в meta/HP-bar, ускорение атак на фазах и danger-zone при переходе. Обновление SCRUM-259: boss-specific mechanics создают telegraph nodes (`BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `BossMoltenArmorPulse`) и закреплены в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. HP/урон боссов масштабируются через ту же `stage_scale`, что и экономика.

Обновление SCRUM-135 от 2026-06-12: `boss_rift_warden.png` и `boss_disk_devourer.png` теперь native `512x512`, их boss cutout parts и `scripts/sliced_rig_manifest.gd` обновлены под 512px. `rift_warden` сохраняет отдельный `vortex` part; `disk_devourer` остается single-torso rig по текущему cutout CONFIG.

## Спавн И Волны

Ключевые правила:
- монстры появляются волнами;
- активное количество врагов ограничено;
- враги могут появляться с одной или двух сторон волны;
- ранние волны избегают ситуации, где враги сразу давят со всех противоположных сторон;
- HP/урон/скорость/active cap и темп спавна растут плавно от `ProgressionData.stage_scale(route_stage) = pow(1.18, route_stage) + 0.075 * route_stage`;
- магазин, докачка атрибутов и reroll используют тот же множитель через `stage_scaled_cost`, чтобы сложность и экономика дорожали синхронно;
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
- Player polish 2026-06-11/13: `walk_blend_rate` и `direction_blend_rate` задаются профилем движения. `berserk`, `soldier`, `dark_mage`, `guitarist`, `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` имеют отдельные motion profiles, чтобы старт/остановка, разворот, weight shift и шаг не выглядели одинаково. Soldier profile — дисциплинированный средневесовый строевой шаг с умеренным bob и сдержанным arm swing.

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
- `shoot` Солдата получает animation variant из текущего `weapon_id`: `soldier_rifle` — короткая отдача строевого залпа, `soldier_grenade` — cook/overhand throw, `soldier_bayonet` — forward defensive brace. Это только motion layer; `suppression_burst`, `grenade_cook`, `bayonet_brace` damage/timing остаются в `ClassWeapon`.
- `cast`: подъем обеих рук/посоха/черепа с подъемом корпуса и удержанием позы;
- Уникальные атаки элиток получают animation variant из backend-фазы `<elite_behavior>:<elite_attack_id>:<phase>` и используют длительность `windup/strike/recover` из `ProgressionData.ELITE_ATTACK_CONFIGS`: Iron Bastion поднимается в slam windup и резко проседает на strike; Night Stalker сжимается в crouch и делает forward lunge; Plague Prophet делает ritual arm raise/throw; Shard Marshal разводит руки и затем жестом выбрасывает shard fan.
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

## Возвышения И Мета-Цикл

Возвышение — режим усложнения (10 кумулятивных уровней, как heat в Hades). Уровень выбирается на старте забега в hero select (0..открытый максимум персонажа), показан римской цифрой в боевом HUD и отдельным разделом в кодексе. Усложнения данными в `ProgressionData.ASCENSION_MODIFIERS`, применяются через `game.ascension_difficulty()` в combat_director/boss и `run_modifiers` игрока. У кнопки старта hero select показывает только изменение выбранного уровня через `ascension_level_change_line(level)`, а кумулятивный список `ascension_modifier_lines(level)` остается для tooltip/кодекса. Победа над финальным боссом на уровне N открывает N+1 для этого персонажа (`meta_progression.gd`). Старые per-class asc-баффы стали наградным треком меты (применяются на старте за пройденные уровни); полноценный мета-экран — заглушка с рабочим хуком.

## Метапрогрессия

Метапрогрессия персистентна между сессиями:

- За каждую победу над финальным боссом игрок получает 1 meta point, а выбранный персонаж — +1 уровень возвышения (максимум 10).
- Бонусы уровней кумулятивны: уровень N включает все бонусы уровней 1..N. Таблицы уровней доступны через `ProgressionData.ASCENSION_LEVELS` и хранятся в `scripts/progression_data_ascension.gd`; канонические ID в `docs/design/content_registry.md`.
- Сохранение через `scripts/meta_progression.gd` в `user://fantasydisk_meta.cfg` (ConfigFile).
- Бонусы применяются к игроку при старте первого боя забега (`apply_ascension_bonuses` в `scripts/main.gd`).
- Карточка выбора персонажа показывает «Возвышение: N/10», экран победы показывает прогресс возвышения выбранного героя.
- Smoke test: `tests/meta_progression_smoke_test.gd`.

## Боевые Правила После Bugfix-Пакета 2026-06-10

- Уворот игрока работает: `dodge` из `derived_parameters` проверяется в `Player.take_damage`, при успехе показывается всплывающий текст «Промах!» и звук уворота; урон и invulnerability window не применяются. С 0.1.5 defense/dodge/absorb используют SCRUM-255 diminishing returns: defense cap 62%, dodge cap 55%, absorb пропускает минимум 35% каждого удара.
- Регенерация и вампиризм после SCRUM-255 стали поддержкой, а не основным sustain: `regeneration = (0.22 + flat*0.45) * (0.45 + Knowledge/12)`, vampiric chance cap 22%, vampiric heal = `vampiric_amount*0.55 + 3.5% dealt damage`, cap 1.4/с с hard cap 2.6/с. Synthetic tank contact swarm в `tools/survivability_harness.gd` теперь 38.5с TTD вместо 321.0с.
- Формулы атрибутов после SCRUM-243 используют универсальный cross-scaling: Strength/Intelligence/Knowledge/Leadership больше не являются «мертвыми» на чужих archetype-оружиях, а Perception/Energy/Endurance дают не только профильные, но и малые темп/стабилизационные эффекты. Тест `runtime_smoke_test.gd::_test_attribute_weapon_synergy_matrix` проверяет все 8 атрибутов против 6 weapon archetypes.
- Скорость атаки оружия считается как `base_fire_interval / attack_speed` (минимум 0.18с): базовый `fire_interval` каждого оружия из `progression_data.gd` снова значим, оружия одного класса различаются темпом.
- Ребаланс 2026-06-10: базовые `fire_interval` первых 9 оружий увеличены в 1.6 раза, чтобы итоговый темп после фикса формулы остался близким к прежнему ощущению, но с различиями между оружиями; оружие расширенного ростера 0.1.4 балансируется в своих конфигах.
- Pulse-режим бас-гитары и усилителя использует `_rolled_damage` (учитывает `damage_parameter` и криты), как остальные режимы классового оружия.
- Все отложенные боевые эффекты (ядовитые зоны элиток, rift zone, disk slam, DoT-тики, окна урона свинга берсерка, очистка визуалов) используют tween-таймлайны, привязанные к нодам, а не `SceneTreeTimer`. Они замораживаются вместе с паузой и не наносят урон в level-up/Escape паузе.
- Status effects (`scripts/status_effects.gd`) тикают из `_physics_process()` владельца, а не через отдельные таймеры, поэтому пауза замораживает duration/DoT вместе с gameplay.
- Аура Маршала Осколков усиливает каждого обычного врага не более одного раза (meta `commander_aura_buffed`), без бесконечного мультипликативного стака.
- Статусные перекраски врагов/боссов (щит, windup, аура, ярость, dodge-flash) применяются к видимым cutout-частям через `CutoutRig2D.set_status_tint`, а не только на скрытый source-спрайт.
- Отталкивание классового оружия идет через `Enemy.apply_knockback` (импульс в velocity с затуханием), а не телепорт `global_position`; враги без метода сохраняют старый fallback.
- Враги кэшируют ссылку на игрока (`_player()`), а не ищут группу каждый физический кадр.
- Прицеливание оружия игрока (фикс 2026-06-11): все оружия целятся в ближайшего живого врага. Приоритет: ближайший в attack_range -> ближайший на арене -> последнее направление атаки. Направление движения персонажа влияет только на walk-анимацию; анимация атаки и VFX используют то же направление, что и расчет урона.
- Ближние identity-эффекты SCRUM-251 работают только на прямых weapon hits: DoT-тики не повторяют close/execute/stagger/cleave, поэтому эффекты не каскадят через яды и кровотечение. Focused coverage: `tests/melee_unique_mechanics_test.gd`.
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
- Баланс классов и оружия теперь имеет измерительный слой: `tools/balance_harness.gd` генерирует `build/balance_report.md` для 51 пары класс+оружие (solo DPS, 5-target DPS, crowd-clear 5/10/20, EHP) и финальный отчет `build/balance_final_audit_0_1_5.md`. `tests/global_damage_balance_smoke_test.gd` проверяет combined DPS ±25%, solo DPS ±20% и 5/10/20 crowd-clear time ±30%; текущий SCRUM-262 результат PASS, худшее CCT +22.0% у `doctor/plague_syringe` на 20 целях. Playtest все еще нужен для ощущения темпа, но базовая численная сетка больше не держится только на ручной оценке.
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
