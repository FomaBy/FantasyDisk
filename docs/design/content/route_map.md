<!-- content-registry-section -->

# FantasyDisk Content Registry — Маршрутная Карта, События И Окружение

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

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
