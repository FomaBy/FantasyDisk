# Skill Tree FINAL — древо умений в стиле PoE с РАЗНЫМИ усилениями для разных героев

> Историческая справка: упоминания `sound_wave_damage` в этом документе описывают состояние ДО SCRUM-898 (2026-07-10). Звуковая ось урона удалена; оружия Гитариста/Друида бьют магией (`magic_damage`).

Статус: done
Приоритет: high
Роль: Design main + Back-end (Codex)
Контур: Codex
Lane: codex
Версия: 0.2.0
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-726
Owner: codex-backend-scrum726-skill-tree-final
Thread/Worker: codex-backend-scrum726-skill-tree-final
Labels: foma, p1, codex, backend, design-main, skill-tree, meta-progression, redesign
Locked paths: `scripts/meta_progression.gd`, `scripts/skill_tree_data.gd` (новый, если выносить дерево),
`scripts/player.gd` (только секция применения run/attr-модификаторов), `scripts/main.gd`
(только точка применения skill-модов в `start_run`), `tests/meta_skill_tree_smoke_test.gd`,
`tests/skill_tree_per_hero_test.gd` (новый), `docs/design/systems/skill_tree.md` (новый),
`docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`, `CHANGELOG.md`,
`docs/tasks/codex_skill_tree_final_per_hero_enhancements_task.md`
Связано: SCRUM-696 (v2 backend data model), SCRUM-697 (v2 art), SCRUM-698 (v2 UI), SCRUM-699 (v2 QA),
SCRUM-675 (redesign design pack), SCRUM-676 (relayout backend)

---

## 0. TL;DR для исполнителя

Уже есть рабочее PoE-древо v2 (единый граф 82–85 узлов, точки входа классов, метаочки cap 100,
pan/zoom UI, миграция сейва — всё PASSED в SCRUM-696/698/699). **Эта задача — НЕ переписывание с нуля.**
Это **финализация контента и структуры дерева так, чтобы РАЗНЫЕ герои получали РАЗНЫЕ усиления.**

Сейчас дерево даёт всем героям одинаковые аккаунтные бонусы (узел «+урон» одинаково полезен всем).
Пользователь хочет, чтобы дерево было как в Path of Exile в полном смысле: **общий граф, но с
атрибутными «лепестками» и классовыми сигнатурными узлами, из-за которых один и тот же путь по дереву
даёт разным героям разный профиль силы, а у каждого героя есть свой уникальный keystone-узел.**

Делается это БЕЗ слома существующего save/UI/API: добавляются (а) атрибутные узлы (дают +атрибут, а
движок уже конвертирует атрибуты в бой по-разному для каждого класса) и (б) классовые сигнатурные узлы
(`class_affinity`), эффект которых применяется только активному герою.

---

## 1. Контекст и что уже есть (НЕ ломать)

### 1.1 Текущая модель данных (канон: `scripts/meta_progression.gd`)
Узел дерева:
```gdscript
{
  "id": String,         # уникальный id ("core_origin", "might_dmg_1", "entry_berserk", ...)
  "branch": String,     # "core" | "might" | "wealth" | "lore" | "endure"
  "tier": int,          # порядковый тир внутри ветки
  "cost": int,          # метаочков за выделение (1..5)
  "kind": String,       # "minor" | "notable" | "keystone" | "entry"
  "title": String,      # рус. название
  "desc": String,       # рус. описание
  "effects": Dictionary,# боевые модификаторы
  "pos": Vector2,       # координаты на холсте
  "adj": Array[String], # рёбра (неориентированный граф)
}
```
- `_build_skill_tree() -> Array` — строит граф (сейчас 82–85 узлов, 5 keystone).
- `CLASS_ENTRY_NODES := { "<character_id>": "<node_id>", ... }` — точка входа КАЖДОГО класса
  (все классы из `ProgressionDataCharacters` — 17 шт; разные места дерева).
- Экономика: `const META_POINTS_CAP := 100`, `META_POINT_REWARDS_BY_ASCENSION := [1,1,2,3,4,5]`
  (за первое закрытие возвышения 0..5 по каждому герою; максимум 16/герой; суммарный потолок 100).
- Публичный API (стабилен, используется UI SCRUM-698 — НЕ ломать сигнатуры):
  `node_list()`, `node_by_id(id)`, `entry_map()`, `node_status(state, id)` → `locked|available|purchased`,
  `allocate_node(state, id)` / `buy_skill_node(state, id)`, `reset_skill_tree(state)`,
  `earned_meta_points(state)`, `available_meta_points(state)`, `allocated_meta_points(state)`,
  `global_level(state)`, `skill_tree_total_cost()`, `skill_modifiers(state)`.
- Правила выделения (PoE-связность): узел выделяем, если это точка входа ОТКРЫТОГО класса (корень)
  ИЛИ сосед уже выделенного узла; хватает метаочков; не превышен cap.
- Сейв `user://fantasydisk_meta.cfg`, поле `skill_tree_schema` (сейчас = 2), миграция реализована.

### 1.2 Как эффекты дерева попадают в бой
- `skill_modifiers(state) -> Dictionary` суммирует `effects` всех купленных узлов
  (множители складываются как `1.0 + sum`, флаги — как max).
- Применяется в `scripts/main.gd:985` → `player.apply_meta_skill_modifiers(skill_mods)`
  (`scripts/player.gd:860`) на старте забега, складывается в `player.run_modifiers`.
- Параллельно есть `class_modifiers(state, character_id)` — бонусы ТОЛЬКО выбранному классу
  (ключи `class_damage_mult`, `class_max_health_mult`, `class_attack_speed_mult`). Это уже доказывает,
  что движок умеет применять «классово-обусловленные» бонусы — мы расширяем этот паттерн на дерево.

### 1.3 Атрибуты и боевой движок (`scripts/stat_formulas.gd`)
8 базовых атрибутов и их вклад в бой (ключевой факт для дизайна!):
| Атрибут | Что качает в бою |
|---|---|
| `strength` | физ. урон, откидывание |
| `agility` | скорость атаки, уклонение, крит |
| `intelligence` | магический урон, чары |
| `perception` | дальность атаки, радиус AoE, скорость снарядов, радиус подбора |
| `energy` | скорость заряда ульты, классовые механики |
| `knowledge` | масштабирование/опыт/кодекс |
| `endurance` | максимум HP, защита |
| `leadership` | масштаб призывов и аур |

Профили атрибутов классов заданы в `scripts/progression_data_characters.gd` (`BASE_STATS`), они РАЗНЫЕ.
**Именно поэтому атрибутный узел естественно усиливает разных героев по-разному** — это и есть PoE-модель
str/dex/int-«колёс», только на 8 атрибутов.

### 1.4 Производные статы движка (доступные ключи для сигнатур, из `stat_formulas.gd`)
`damage, magic_damage, sound_wave_damage, crit_chance, crit_damage_multiplier, attack_speed, dodge,
move_speed, defense, absorb, health_point, knockback_distance, summon_amount, attack_range,
range_multiplier, regeneration, vampiric_amount, vampiric_chance, dot_damage, dot_speed, aoe_radius,
aura_radius, buff_power, projectile_speed, ultimate_multiplier, pickup_radius.`

### 1.5 Список классов (17) и их боевые архетипы (по `BASE_STATS`)
| Класс (id) | Доминантные атрибуты | Архетип | Лепесток-сектор |
|---|---|---|---|
| `berserk` | STR 10, END 7 | бруизер-берсерк, ближний напор | **СИЛА** |
| `knight` | END 10, STR 8, LEAD 6 | танк/защита | **СТОЙКОСТЬ** |
| `robot` | END 10, STR 8, ENERGY 7 | танк + ульта | **СТОЙКОСТЬ** |
| `soldier` | PER 8, STR 7, END 6 | живучий стрелок | **ВОСПРИЯТИЕ** |
| `sniper` | PER 10, AGI 8 | дальний крит-стрелок | **ВОСПРИЯТИЕ** |
| `ranger` | PER 9, STR 7, AGI 7 | стрелок-следопыт | **ВОСПРИЯТИЕ** |
| `thief` | AGI 9, PER 8 | быстрый крит + лут | **ЛОВКОСТЬ** |
| `assassin` | AGI 10 | бурст-крит ближний | **ЛОВКОСТЬ** |
| `elementalist` | INT 9, ENERGY 8 | каст AoE-стихий | **ИНТЕЛЛЕКТ** |
| `dark_mage` | INT 10, ENERGY 7 | стекло-пушка маг | **ИНТЕЛЛЕКТ** |
| `chemist` | INT 9, ENERGY 7, KNOW 7 | яды/DoT | **ЗНАНИЕ (DoT)** |
| `biologist` | KNOW 10, INT 8 | DoT/заражение/призыв | **ЗНАНИЕ (DoT)** |
| `doctor` | INT 8, KNOW 8 | лекарь/саппорт | **ЗНАНИЕ (саппорт)** |
| `priest` | KNOW 9, INT 8, ENERGY 7 | хил/священная волна | **ЗНАНИЕ (саппорт)** |
| `engineer` | LEAD 10, INT 7 | миньоны/турели | **ЛИДЕРСТВО** |
| `druid` | LEAD 9, PER 7 | призывы/природа | **ЛИДЕРСТВО** |
| `guitarist` | LEAD 7, PER 7 | ауры/баффы | **ЛИДЕРСТВО** |

---

## 2. Цель задачи (что должно получиться)

**Финальная версия древа умений в стиле PoE, где:**
1. Сохраняется единый общий граф и вся текущая механика (метаочки, связность, миграция, UI/API).
2. Добавляется **8 атрибутных лепестков** (по числу атрибутов) — узлы, дающие `+атрибут`. Поскольку
   движок конвертирует атрибуты в бой по-разному для каждого героя, один и тот же лепесток усиливает
   разных героев по-разному. Точки входа классов сидят в «своём» лепестке (см. таблицу 1.5).
3. Добавляются **классовые сигнатурные узлы** (`class_affinity`): рядом с точкой входа каждого героя —
   маленький «под» из 1–2 сигнатурных notable + **1 уникального keystone на героя**, эффект которых
   применяется ТОЛЬКО этому герою (как `class_modifiers`). Это и есть «разные усиления для разных героев»
   в буквальном смысле: 17 уникальных keystone-узлов, каждый меняет правила игры под своего героя.
4. **Build-выбор становится осмысленным**: суммарная стоимость полного дерева делается заведомо БОЛЬШЕ
   потолка метаочков (cap 100 неизменен), поэтому игрок не может выкупить всё и выбирает путь под своего
   основного героя; кнопка полного сброса (`reset_skill_tree`) позволяет перенастроить дерево под другого.

Итог: **то же дерево даёт каждому из 17 героев ощутимо разный профиль силы**, и у каждого есть свой
сигнатурный keystone.

---

## 3. Структура дерева (детальный дизайн)

### 3.1 Топология: ядро + 8 атрибутных лепестков + классовые поды
```
                          [ЯДРО / core]  (3–5 универсальных узлов, общий старт-хаб)
        ┌────────────┬────────────┬───────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
   СИЛА(STR)   ЛОВКОСТЬ(AGI)  ИНТЕЛЛ(INT)  ВОСПР(PER)  ЭНЕРГ(ENE)  ЗНАНИЕ(KNO)  СТОЙК(END)  ЛИДЕР(LEA)
   berserk      thief          elementalist  sniper      (мост)      chemist      knight       engineer
   (+ STR-под)  assassin       dark_mage     ranger                  biologist    robot        druid
                                             soldier                 doctor                    guitarist
                                                                     priest
```
- **Ядро (core)**: 3–5 универсальных `minor` (мелкий общий урон/HP), плюс «спицы» к каждому лепестку.
  Через ядро лепестки связаны между собой (можно дойти куда угодно — PoE-связность сохраняется).
- **Атрибутный лепесток** (по одному на каждый из 8 атрибутов): «колесо» из `minor` атрибутных узлов
  (`+1..+2` к атрибуту), 1–2 `notable` (`+атрибут` крупнее + небольшой профильный боевой бонус) и
  ОПЦИОНАЛЬНО 1 атрибутный `keystone` (см. 3.4). Точка входа класса (`entry`) садится в лепесток своего
  доминантного атрибута (таблица 1.5).
- **Классовый сигнатурный под**: вплотную к каждой `entry_<class>` — 1–2 сигнатурных `notable` +
  1 сигнатурный `keystone`, помеченные `class_affinity: "<class_id>"`.
- Энергия (`energy`) — лепесток-мост между Интеллектом и Знанием (мало классов имеют её доминантной,
  но она усиливает ульту/механики у elementalist/robot/chemist/priest).

### 3.2 Бюджет узлов и осмысленный выбор
- Ориентир по размеру: **~95–120 узлов** (немного больше текущих 85: добавляем атрибутные колёса и
  17 классовых подов). «Чуть поменьше, чем в ПоЕ» — соблюдаем, это не тысяча узлов.
- Состав по типам: преимущественно `minor` (cost 1), ~18–26 `notable` (cost 2–3),
  **ровно 17 классовых `keystone`** (по одному на героя, cost 4–5) + 3–6 универсальных/атрибутных
  `keystone` (cost 4–5).
- **Суммарная стоимость полного дерева ≈ 150–180 метаочков** (заведомо > cap 100). Это сознательная
  эволюция относительно v2 (там full-cost ≈ cap): теперь 100 метаочков НЕ хватает на всё дерево →
  игрок строит реальный build под героя. `META_POINTS_CAP` остаётся **100** (жёсткое требование).
- `skill_tree_total_cost()` должен честно вернуть новую суммарную стоимость (> 100); добавить
  `skill_tree_total_cost_capped()` если UI нужен «сколько максимум можно потратить» (= 100).

### 3.3 Атрибутные узлы (новые)
- `kind`: `minor` (колесо) / `notable` (крупный + профильный бонус).
- `effects` используют **новые атрибутные ключи** (по 8 атрибутам):
  `strength_flat`, `agility_flat`, `intelligence_flat`, `perception_flat`, `energy_flat`,
  `knowledge_flat`, `endurance_flat`, `leadership_flat`.
- Эти ключи применяются как **прибавка к базовым атрибутам персонажа на старте забега** (account-wide),
  ДО конвертации в боевые статы в `stat_formulas`. Так один узел `+intelligence_flat: 3` даст
  dark_mage огромный магический урон, а berserk — почти ничего (его INT мал и плохо конвертится) —
  это и есть требуемая дифференциация.
- Размер прибавок калибровать так, чтобы прокачка одного лепестка под своего героя давала заметный, но
  не ломающий буст (ориентир: полный профильный лепесток ≈ +25..40% эффективной силы по профильному
  стату; сверять с `estimated_power_multiplier`). Точные числа подобрать и обосновать в спеке-результате.

### 3.4 Классовые сигнатурные узлы (ядро фичи «разные усиления разных героев»)
- Новое поле узла: `"class_affinity": "<character_id>"` (есть только у сигнатурных узлов).
- **Правило применения**: эффекты узла с `class_affinity` применяются к забегу ТОЛЬКО если активный
  герой == `class_affinity`. Иначе узел можно выделить (он часть графа, тратит метаочки и даёт связность),
  но его боевой эффект «спит» — как в PoE, где чужой класс-под бесполезен, но проходим.
- `effects` сигнатурных узлов **переиспользуют существующие run-ключи** движка (НЕ плодим `class_*` под
  каждый стат): `damage_mult`, `attack_speed_mult`, `max_health_mult`, `crit_chance_flat`,
  `crit_damage_flat`, `dodge_flat`, `defense_flat`, `regeneration_flat`, плюс при необходимости новые
  run-ключи под производные статы: `dot_damage_mult`, `summon_amount_flat`, `aura_radius_mult`,
  `vampiric_chance_flat`, `ult_charge_mult`, `projectile_count_flat` и т.п. — добавлять в
  `player.apply_meta_skill_modifiers` ТОЛЬКО те, что реально нужны сигнатурам ниже.
- **17 уникальных keystone (по одному на героя)** — таблица обязательного контента (числа — стартовый
  ориентир, финал подобрать и обосновать; эффекты должны быть «правило-меняющими», не просто «+5%»):

| Герой | Keystone (рус. название) | Эффект (ориентир, через run-ключи) |
|---|---|---|
| berserk | «Кровавая жатва» | при низком HP резко растёт урон: `damage_mult +0.25`, `regeneration_flat +X`, риск выше |
| knight | «Несокрушимый» | `defense_flat +X`, `max_health_mult +0.20`, но `attack_speed_mult -0.10` (танк-стиль) |
| robot | «Овердрайв» | `ult_charge_mult +0.40`, ульта длится дольше / заряжается быстрее |
| soldier | «Подавляющий огонь» | `projectile_count_flat +1` или `attack_speed_mult +0.15` по плотной толпе |
| sniper | «Идеальный выстрел» | `crit_chance_flat +0.15`, `crit_damage_flat +0.50`, `range_multiplier +0.20` |
| ranger | «Град стрел» | `projectile_count_flat +1`, `attack_speed_mult +0.10` |
| thief | «Большой куш» | `money_gain_mult +0.30` + `crit_chance_flat +0.10` (лут-крит-стиль) |
| assassin | «Из тени» | первый удар по цели крит / `crit_damage_flat +0.60`, `move_speed +X` |
| elementalist | «Сверхновая» | `aoe_radius_mult +0.30`, `damage_mult +0.15` по площади |
| dark_mage | «Запретное знание» | `damage_mult +0.35`, но `max_health_mult -0.15` (стекло-пушка) |
| chemist | «Каталитический распад» | `dot_damage_mult +0.40`, `dot_speed +X` |
| biologist | «Эпидемия» | DoT распространяется на соседей / `dot_damage_mult +0.30`, `summon_amount_flat +1` |
| doctor | «Триаж» | `regeneration_flat +X`, лечение бьёт по врагам, `max_health_mult +0.10` |
| priest | «Хор искупления» | `vampiric_chance_flat +0.20` / доля урона → хил, `aura_radius_mult +0.20` |
| engineer | «Армия машин» | `summon_amount_flat +2`, миньоны крепче |
| druid | «Зов стаи» | `summon_amount_flat +1`, `aura_radius_mult +0.25` |
| guitarist | «Крещендо» | `buff_power +X`, `aura_radius_mult +0.30`, баффы сильнее со временем |

  (Сигнатурные `notable` рядом с keystone — 1–2 на героя, более слабые версии той же темы.)

### 3.5 Универсальные/атрибутные keystone (3–6 шт, account-wide, как сейчас)
Сохранить/обновить существующие сильные узлы (death_save, ult_start_charge, guaranteed_rare_shop и т.п.)
как нейтральные «правило-меняющие» keystone, доступные всем. Не плодить — 3–6 максимум.

---

## 4. Изменения в бэкенде (точный объём работ)

### 4.1 Данные дерева (`meta_progression.gd` или новый `scripts/skill_tree_data.gd`)
- Перестроить `_build_skill_tree()` под топологию ядро + 8 лепестков + 17 классовых подов (~95–120 узлов).
- Расставить `pos` так, чтобы лепестки читались как «колёса» вокруг ядра (для текущего pan/zoom UI),
  без перекрытий узлов; `adj` симметричны (неориентированный граф), без «висящих» id.
- Обновить `CLASS_ENTRY_NODES`: каждая `entry_<class>` сидит в лепестке доминантного атрибута героя
  (таблица 1.5) и соединена с его классовым подом.
- Добавить поле `class_affinity` на сигнатурных узлах.

### 4.2 Применение эффектов
- **Атрибутные ключи**: в `player.apply_meta_skill_modifiers` (или в точке сборки статов) прибавлять
  `*_flat` атрибуты к базовым атрибутам героя ДО конвертации в `stat_formulas`. Покрыть тестом, что
  один и тот же набор атрибутных узлов даёт разным героям разный итоговый боевой профиль.
- **Классово-обусловленные узлы**: ввести `skill_modifiers_for_class(state, character_id) -> Dictionary` —
  возвращает аккаунтные эффекты + эффекты узлов, у которых `class_affinity == character_id`.
  В `scripts/main.gd:985` заменить вызов `skill_modifiers(state)` на `skill_modifiers_for_class(state,
  selected_character_id)`. Старый `skill_modifiers(state)` оставить (UI-превью/обратная совместимость):
  он возвращает только аккаунтные эффекты (без `class_affinity`), чтобы не врать в общем превью.
- Новые run-ключи (`dot_damage_mult`, `summon_amount_flat`, `aura_radius_mult`, `vampiric_chance_flat`,
  `ult_charge_mult`, `projectile_count_flat`, `buff_power` и т.д. — только реально используемые в 3.4)
  замапить в `player.run_modifiers`/применение статов. Множители — `1.0 + sum`, плоские — суммой,
  флаги — max (как сейчас).

### 4.3 Экономика и правила (минимально менять)
- `META_POINTS_CAP = 100` — без изменений. Формула начисления `[1,1,2,3,4,5]` — без изменений.
- Правила связности (`node_status`, `allocate_node`) — без изменений по сути; убедиться, что классовые
  поды доступны через связность (корень = entry своего класса, рост по `adj`).
- `skill_tree_total_cost()` вернёт новую сумму (> 100). UI должен показывать «потрачено / 100», а не
  «/ total» — согласовать строкой в спеке-результате (UI-таск, если потребуется, отдельно).

### 4.4 Миграция сейва (НЕ ронять старые сейвы)
- Поднять `skill_tree_schema` 2 → 3. При загрузке сейва со схемой < 3:
  - старые `skill_nodes` (id из v2-дерева) могут отсутствовать в новом графе → безопасный полный респек:
    `skill_nodes = []`, метаочки пересчитать детерминированно из `ascension_levels` (как уже делает
    миграция v2). Не падать, не оставлять «висящих» id.
  - сохранить все прочие поля стейта (class_boss_wins, achievements, discovered_*, challenges и т.д.).
- Миграция идемпотентна, покрыта тестом (старый cfg → корректный новый стейт без краша).

---

## 5. Acceptance Criteria

- [ ] Новый граф дерева: ядро + 8 атрибутных лепестков + 17 классовых подов, ~95–120 узлов, корректные
      `pos`/`adj` (симметрия, без висящих id, без накладок узлов).
- [ ] Атрибутные узлы с ключами `*_flat` по всем 8 атрибутам; прибавки применяются к базовым атрибутам
      героя ДО `stat_formulas`; тест доказывает РАЗНЫЙ итоговый боевой профиль у разных героев от
      одного и того же набора атрибутных узлов.
- [ ] Ровно 17 классовых keystone (по одному на каждого героя из `CHARACTER_CONFIGS`), помеченных
      `class_affinity`; их эффект применяется ТОЛЬКО активному герою. Плюс 1–2 сигнатурных `notable` на
      героя. Плюс 3–6 нейтральных keystone.
- [ ] `skill_modifiers_for_class(state, character_id)` реализован и используется в `main.gd` для забега;
      `skill_modifiers(state)` оставлен для аккаунтного превью (без `class_affinity`-узлов).
- [ ] `CLASS_ENTRY_NODES` покрывает все 17 классов; каждая точка входа в лепестке доминантного атрибута
      и связана со своим классовым подом; все id валидны.
- [ ] Суммарная стоимость полного дерева > 100 (осмысленный build-выбор); `META_POINTS_CAP = 100`
      сохранён; `skill_tree_total_cost()` отражает новую сумму.
- [ ] Экономика метаочков (формула `[1,1,2,3,4,5]`, cap 100, начисление за первое закрытие возвышения)
      без регрессий; `reset_skill_tree` (полный рефанд) работает.
- [ ] Миграция схема 2→3: старые сейвы не падают, метаочки пересчитаны, старые узлы безопасно
      сброшены, прочие поля сохранены; идемпотентна.
- [ ] Публичный API (`node_list/node_by_id/entry_map/node_status/allocate_node/buy_skill_node/
      reset_skill_tree/earned_/available_/allocated_meta_points/global_level/skill_tree_total_cost`)
      стабилен — UI SCRUM-698 продолжает работать без правок сигнатур.
- [ ] Тесты ЗЕЛЁНЫЕ через `tools/godot_gate.py`:
      - обновлённый `tests/meta_skill_tree_smoke_test.gd` (граф/adj/входы/статусы/экономика/миграция);
      - новый `tests/skill_tree_per_hero_test.gd`: (а) атрибутный узел даёт разным героям разный профиль;
        (б) `class_affinity`-keystone действует только на своего героя и «спит» у чужих; (в) 17 уникальных
        keystone присутствуют и валидны; (г) full-tree-cost > 100, cap = 100;
      - `tests/runtime_smoke_test.gd` без регрессий.
- [ ] Документация: новый `docs/design/systems/skill_tree.md` (каноничное описание финальной модели:
      топология, атрибутные лепестки, таблица 17 keystone с финальными числами, правила применения,
      API, экономика, миграция); обновлены `mechanics_extract.md`, `current_game_state.md`, `CHANGELOG.md`.
- [ ] Балансовая заметка: для каждого героя указать, какой лепесток+keystone — его «домашний» путь, и
      грубую оценку прироста (через `estimated_power_multiplier`/ручной расчёт), чтобы числа не ломали игру.

## 6. Files
- `scripts/meta_progression.gd` — данные дерева, `class_affinity`, `skill_modifiers_for_class`,
  атрибутные ключи, миграция схемы 3, обновление total_cost. (или вынести граф в новый
  `scripts/skill_tree_data.gd` и подключить — на усмотрение исполнителя).
- `scripts/player.gd` — применение атрибутных `*_flat` к базовым атрибутам + новые run-ключи (только
  секция `apply_meta_skill_modifiers`; не трогать остальной player).
- `scripts/main.gd` — переключить старт-забег на `skill_modifiers_for_class(state, selected_character_id)`.
- `scripts/progression_data_characters.gd` — только чтение (id классов, профили атрибутов).
- `tests/meta_skill_tree_smoke_test.gd` — обновить; `tests/skill_tree_per_hero_test.gd` — создать.
- `docs/design/systems/skill_tree.md` — создать; `docs/design/mechanics_extract.md`,
  `docs/design/current_game_state.md`, `CHANGELOG.md` — обновить.

## 7. Заметки по lane/изоляции и сдаче
- Lane=codex. Единоличный владелец `meta_progression.gd`/`skill_tree_data.gd` в этой волне.
- **UI/Art НЕ трогать в этой задаче**: текущий UI рендерит `node_list()` (pos/adj/kind/status) и
  потребляет API — он продолжит работать. Если для отображения `class_affinity`/атрибутов/«потрачено из
  100» захочется UI-доработка — это ОТДЕЛЬНЫЙ follow-up таск (lane=claude, `ui_screens.gd`), здесь только
  зафиксировать предложение в спеке-результате.
- Перед сдачей в QA: green-gate ДО коммита; влить в `origin/dev` (НЕ оставлять на `codex/*`-ветке — см.
  правило codex-strand); закоммитить с сайдкарами (`.uid`/`.import`); `git merge-base --is-ancestor
  <commit> origin/dev` должен проходить.
- Финальный отчёт исполнителя обязан содержать раздел `Disk cleanup:` по политике репо.

## 8. Result / Отчёт исполнителя

Статус: реализовано, готово к QA после commit/push.

Owner/worker: `codex-backend-scrum726-skill-tree-final`.
Branch: `codex/scrum-726-skill-tree-final` from `origin/dev`.
Commit: будет указан в финальном Jira-комментарии после green-gate, commit и push.

Результат:
- Древо умений поднято до schema 3: общий PoE-like граф на 107 узлов с ядром, 8 атрибутными лепестками и 17 class pods.
- Добавлены account-wide атрибутные `*_flat` узлы; `Player.apply_meta_skill_modifiers()` применяет их к базовым stats до derived formulas.
- Добавлены `class_affinity`-сигнатуры и `skill_modifiers_for_class(state, character_id)`; старт забега в `main.gd` теперь применяет class-aware skill modifiers.
- У каждого из 17 героев есть уникальный `sig_<class>_keystone`; чужие class pod эффекты не применяются к активному герою.
- Экономика сохранена: `META_POINTS_CAP = 100`, награды `[1, 1, 2, 3, 4, 5]`, полный бюджет дерева 183 метаочка, `skill_tree_total_cost_capped()` возвращает cap-aware 100.
- Миграция schema 2 -> 3 делает безопасный full respec старых skill node ids и сохраняет прочую meta-state структуру.

Changed files:
- `scripts/meta_progression.gd`
- `scripts/player.gd`
- `scripts/main.gd`
- `tests/meta_skill_tree_smoke_test.gd`
- `tests/skill_tree_per_hero_test.gd`
- `tests/skill_tree_per_hero_test.gd.uid`
- `docs/design/systems/skill_tree.md`
- `docs/design/mechanics_extract.md`
- `docs/design/current_game_state.md`
- `docs/design/systems/progression_balance.md`
- `CHANGELOG.md`
- `docs/tasks/codex_skill_tree_final_per_hero_enhancements_task.md`

Tests:
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_skill_tree_smoke_test.gd`
  (`Meta skill tree smoke test passed.`)
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/skill_tree_per_hero_test.gd`
  (`Skill tree per-hero test passed.`)
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  (`Runtime smoke test passed.`)

Balance note:
- SCRUM-726 changes meta-progression structure and class-specific run modifier plumbing, not weapon trio configs. Class balance harnesses were not broadened in this task; focused tests prove graph/economy/class-affinity behavior, and follow-up balance playtests should inspect high-investment class pods near the 100-point cap.

Disk cleanup:
- Removed task-created `.godot/` import cache (~1.2 GB after test imports). No `.import` churn left in git status. Dedicated worktree kept as pushed QA handoff path: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-726-skill-tree-final`.

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-01 (claude-qa)
Проверено на origin/dev HEAD 0c4dc75e (8e34be4e интегрирован, не strand). Три gate-теста зелёные: meta_skill_tree_smoke_test, skill_tree_per_hero_test (17 уник. class_affinity keystone, per-hero профиль, cap=100), runtime_smoke_test. Переведено в «Готово».
