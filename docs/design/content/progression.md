<!-- content-registry-section -->

# FantasyDisk Content Registry — Прогрессия, Награды И Экономика

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

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
