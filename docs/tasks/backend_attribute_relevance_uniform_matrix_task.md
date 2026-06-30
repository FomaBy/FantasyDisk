# BALANCE: Единая матрица релевантности атрибутов (attribute_relevance) — 2 основных / 8 второстепенных / 7 необязательных классов на каждый атрибут

Статус: done
Приоритет: high
Роль: Back-end (Balance)
Контур: Claude
Owner: claude-backend
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: User request
Jira: SCRUM-695
Связано: SCRUM-504, SCRUM-524, SCRUM-526
Locked paths: scripts/progression_data_characters.gd; scripts/progression_data.gd; scripts/progression_data_content.gd; scripts/ui_screens.gd; scripts/glossary.gd; scripts/codex_data.gd; docs/design/systems/balance.md; docs/design/current_game_state.md; CHANGELOG.md

## Контекст / Проблема

В игре **17 играбельных классов** и **27 боевых атрибутов** (папки в
`docs/design/references/icons/attributes/`, пул прокачки `LEVEL_UP_REWARDS` в
`scripts/progression_data_content.gd:167-192`):

`absorb, aoe_radius, attack_range, attack_speed, aura_radius, buff_power,
crit_chance, crit_damage_multiplier, damage, defense, dodge, dot_damage,
dot_speed, health_point, knockback_distance, knockback_power, magic_damage,
move_speed, pickup_radius, projectile_speed, range_multiplier, regeneration,
sound_wave_damage, summon_amount, ultimate_multiplier, vampiric_amount,
vampiric_chance`.

Сейчас релевантность атрибута для класса задаётся **косвенно**: 27 боевых
атрибутов схлопываются в 8 базовых характеристик (strength / agility /
intelligence / perception / energy / knowledge / endurance / leadership) через
`reward_attribute_dependency()` (`scripts/progression_data.gd:238-259`), а
приоритет класса задан списками по 5 характеристик в `ATTRIBUTE_PRIORITIES`
(`scripts/progression_data_characters.gd`). Из-за этой косвенности:

1. **Релевантность атрибутов неравномерна.** Атрибуты, висящие на «популярной»
   характеристике (strength → damage/knockback), полезны большинству классов;
   атрибуты на редкой характеристике (energy → ultimate/vampiric, leadership →
   summon/buff) для многих классов фактически мёртвые. Нет гарантии, что у
   каждого атрибута одинаковое число классов, которым он реально нужен.
2. **Непонятно, что атрибут даёт конкретному персонажу в цифрах.** Описания в
   `LEVEL_UP_REWARDS` смешанные: часть конкретна («+15% к урону»), часть
   абстрактна и не переводится в понятный эффект («+0.18 к силе поддержки»,
   «+0.12 ultimate power», «+4 flat damage absorption», «+1.3 regeneration
   base»). Игрок не понимает, что именно изменится у текущего билда.
3. **Награды могут целиком состоять из «ненужного».** `_random_level_up_rewards()`
   (`scripts/ui_screens.gd:6146`) выбирает варианты взвешенно, но нет жёсткой
   гарантии, что в наборе из 3 будет хотя бы один основной/второстепенный для
   класса — теоретически можно получить тройку необязательных атрибутов и
   «пустой» левел-ап.

## Цель

Сделать релевантность **всех** атрибутов одинаково значимой и прозрачной:

1. Каждый атрибут — **основной ровно для 2 классов, второстепенный для 8,
   необязательный для оставшихся 7** (2 + 8 + 7 = 17). Это жёсткое правило по
   каждому атрибуту (по строке матрицы).
2. Эффект **каждого** атрибута объективно и численно понятен: из описания/тултипа
   видно, что он даст **текущему** персонажу в цифрах.
3. В наградах необязательные атрибуты не доминируют: **не более 1 необязательного
   варианта за один показ**, всегда есть хотя бы один основной/второстепенный для
   усиления персонажа.

## Требуемое изменение

### 1. Канонический реестр и матрица релевантности (прямой, не через 8 характеристик)

- Завести **единый канонический список атрибутов** как первоисточник (id, имя,
  иконка, тип значения). Сейчас список фактически дублируется в трёх местах
  (папки иконок, `LEVEL_UP_REWARDS`, маппинг в `reward_attribute_dependency`).
  Свести к одному источнику правды.
- Перед фиксацией матрицы **провести ревизию набора атрибутов** — есть очевидные
  дубли/пересечения, которые надо либо развести по смыслу, либо объединить:
  - `attack_range` vs `range_multiplier` (дальность атаки);
  - `knockback_distance` vs `knockback_power` (отталкивание);
  - `damage` vs `magic_damage` vs `sound_wave_damage` (прямой урон по типам);
  - `aoe_radius` vs `aura_radius` (площадь/радиус).
  Решение (свести / оставить и чётко развести) принимает balance-дизайнер; в этой
  задаче допустимо менять итоговый состав атрибутов (user явно разрешил «возможно
  добавить новые»).
- Построить **матрицу `ATTRIBUTE_RELEVANCE` размера (атрибуты × 17 классов)**, где
  каждая ячейка ∈ {primary, secondary, optional}. **Жёсткий инвариант по каждому
  атрибуту: ровно 2 primary, 8 secondary, 7 optional.** Матрица — первоисточник
  релевантности; старый расчёт через `attribute_priority_weight` по 8
  характеристикам заменить (или сделать производным от матрицы).

  **Математика на проверку дизайнером.** При N атрибутах суммарно по всем
  атрибутам: 2N ячеек primary, 8N secondary, 7N optional. На 17 классов это в
  среднем 2N/17 основных, 8N/17 второстепенных, 7N/17 необязательных **на класс**.
  При N=27 это ≈3 primary / ≈13 secondary / ≈11 optional на класс (с разбросом
  ±1, т.к. 54/17, 216/17, 189/17 не делятся нацело). Идеально ровный (одинаковый
  у всех классов) расклад выходит только при N, кратном 17 — например **ровно 17
  атрибутов даёт строго 2/8/7 на каждый класс**. Это рекомендуемый ориентир, если
  будет решено консолидировать дубли; финальный N — решение дизайнера, но
  **per-attribute правило 2/8/7 обязательно при любом N**.
- Релевантность должна быть осмысленной (основные атрибуты класса = его фактовый
  геймплей: у берсерка — урон/отталкивание, у снайпера — дальность/крит, у
  доктора — поддержка/реген и т.д.), а не случайной раскладкой ради чисел.

### 2. Численно понятный эффект каждого атрибута

- Для каждого атрибута описание/тултип в `LEVEL_UP_REWARDS` и в окне выбора
  награды должны показывать **конкретный численный эффект для текущего
  персонажа**, а не абстрактную внутреннюю величину. Минимум — нормальные
  человекочитаемые единицы во всех описаниях (убрать «+0.18 силы поддержки»,
  «+0.12 ultimate power», «+4 flat absorption» в пользу понятных формулировок).
- Желательно (если позволяет UI-проводка `_level_up_reward_preview` /
  `_format_level_up_reward_text` в `scripts/ui_screens.gd:4749-4920`): показывать
  **before → after** на реальном стате текущего персонажа, например
  «Урон: 120 → 138 (+15%)», «Шанс крита: 12% → 19%». Если полноценный
  before→after слишком дорог, как минимум — корректные итоговые числа/единицы.
- Синхронизировать описания с глоссарием (`scripts/glossary.gd`) и кодексом
  (`scripts/codex_data.gd`).

### 3. Правило наград (не более 1 необязательного за раз)

- В `_random_level_up_rewards(count)` (`scripts/ui_screens.gd:6146`) и связанном
  взвешивании (`_weighted_level_up_index`, `level_up_reward_weight`) ввести
  жёсткое ограничение на итоговый набор:
  - в одном показе **не более одного** атрибута, который для текущего класса
    `optional`;
  - **минимум один** атрибут уровня `primary` или `secondary` присутствует всегда
    (никогда не показывать набор только из необязательных);
  - сохранить уникальность вариантов и существующий «редкий» слот основной
    характеристики (`MAIN_STAT_SLOT_CHANCE`, capstone «Озарение») — он этому
    правилу не противоречит.
- Веса выбора пересчитать от новой матрицы (primary > secondary >> optional),
  старую формулу `1.65 - index*0.12` заменить на расклад от relevance-класса.
- Проверить, что то же правило релевантности консистентно применяется и к
  батл/элитным наградам, где это уместно (`reward_pool`,
  `_weighted_sample`), как минимум — что они не противоречат матрице.

## Implementation Notes

- Это balance/data + UI-проводка тултипов, **без нового арта** (иконки атрибутов
  уже есть в `docs/design/references/icons/attributes/`). Если в ходе ревизии
  меняется состав атрибутов — на недостающие иконки завести отдельный art/UI
  task через `fantasydisk-asset-generator` / `fantasydisk-ui-director`, в этой
  задаче ассеты не генерировать.
- Точки изменения:
  - `scripts/progression_data_characters.gd` — `ATTRIBUTE_PRIORITIES`,
    `ATTRIBUTE_PRIORITY_REASONS` → заменить/дополнить матрицей `ATTRIBUTE_RELEVANCE`.
  - `scripts/progression_data.gd` — `attribute_priority_weight`,
    `reward_attribute_dependency`, `level_up_reward_weight`,
    `attribute_priority_reason` → считать от матрицы напрямую.
  - `scripts/progression_data_content.gd` — `LEVEL_UP_REWARDS` (описания/единицы).
  - `scripts/ui_screens.gd` — `_random_level_up_rewards`,
    `_weighted_level_up_index`, `_format_level_up_reward_text`,
    `_level_up_reward_preview`.
  - `scripts/glossary.gd`, `scripts/codex_data.gd` — тексты атрибутов.
- Глобальное правило фреймов: текст/иконки/числа карточек награды не накладывать
  на орнамент рамок.
- Желательно вынести инвариант 2/8/7 в **тест-валидатор данных** (см. AC), чтобы
  будущие правки матрицы ловились автоматически.
- Объём большой — допустимо разнести реализацию на под-PR (1: матрица+валидатор,
  2: численные описания/тултипы, 3: правило наград), но закрывается задача только
  когда все три части на месте.

## Acceptance Criteria

- [ ] Существует единый канонический реестр атрибутов (один источник правды),
      без дублирующихся независимых списков.
- [ ] Есть матрица `ATTRIBUTE_RELEVANCE` (атрибуты × 17 классов) со значениями
      primary/secondary/optional.
- [ ] **Для каждого атрибута строго: 2 primary, 8 secondary, 7 optional** —
      подтверждено автоматическим тест-валидатором (data-тест падает при любом
      нарушении инварианта).
- [ ] Раскладка осмысленна: основные атрибуты класса совпадают с его реальным
      геймплеем (спот-чек по 4-5 классам в QA-вердикте).
- [ ] Описание/тултип каждого атрибута даёт численно понятный эффект для текущего
      персонажа (нет абстрактных «+0.18 силы поддержки» без понятного перевода);
      по возможности показ before → after на реальном стате.
- [ ] Тексты атрибутов согласованы между `LEVEL_UP_REWARDS`, глоссарием и кодексом.
- [ ] В наборе награды (3 варианта) **не более 1** необязательного для текущего
      класса атрибута и **минимум 1** primary/secondary — подтверждено тестом на
      многих сэмплах по нескольким классам.
- [ ] Веса выбора наград пересчитаны от матрицы (primary чаще secondary, optional
      редко) и не ломают «редкий» слот основной характеристики/capstone.
- [ ] No-overlap / safe-zone: карточки наград не лежат на орнаменте рамок на
      поддерживаемых разрешениях.
- [ ] Зелёные smoke/balance гейты: `runtime_smoke_test.gd`,
      `runtime_smoke_ui_test.gd`, новый data-валидатор матрицы, и релевантные
      balance-гейты прогоняются через `tools/godot_gate.py` (одиночный Godot run
      под нагрузкой; см. memory по single-instance).
- [ ] Обновлены `CHANGELOG.md`, `docs/design/systems/balance.md` и
      `docs/design/current_game_state.md`.

## Files

- scripts/progression_data_characters.gd
- scripts/progression_data.gd
- scripts/progression_data_content.gd
- scripts/ui_screens.gd
- scripts/glossary.gd
- scripts/codex_data.gd
- tests/ (новый data-валидатор матрицы 2/8/7 + правило наград)
- docs/design/systems/balance.md
- docs/design/current_game_state.md
- CHANGELOG.md

## Результат реализации (claude-backend, 2026-06-30, коммит 50680940)

Реализовано прямой матрицей релевантности (без консолидации до 17 — полный набор
из 24 каноничных атрибутов сохранён; per-attribute правило 2/8/7 выполнено при N=24,
per-class выходит ~2-3 primary / 10-12 secondary / 9-12 optional; решение задокументировано
в `progression_balance.md`).

Что сделано по AC:
- **Канон-реестр** `CharacterData.ATTRIBUTE_REGISTRY` (24 атрибута: id/name/icon/value_type) —
  единый источник правды; `LEVEL_UP_REWARDS` ссылается на attr из реестра. Реэкспорт в
  `ProgressionData`.
- **Матрица** `CharacterData.ATTRIBUTE_RELEVANCE` (24×17, primary/secondary/optional). Жёсткий
  инвариант **2 primary / 8 secondary / 7 optional на атрибут** — проверяется
  `tests/attribute_relevance_test.gd` (data-тест валит сборку при любом нарушении: счётчики,
  разбиение всех 17 классов, отсутствие пересечений, реестр↔матрица↔награды).
- **Осмысленность** (спот-чек): берсерк — damage/knockback/vampiric_amount; снайпер —
  crit_chance/crit_damage/range; жрец — defense/aura_radius/buff_power; рыцарь —
  max_health/defense/absorb; друид — aura_radius/summon_amount/regeneration.
- **Численные описания**: убраны «+0.18 силы поддержки» → «+18% к силе аур/кличей»,
  «+4 flat absorption» → «+4 к поглощению (каждый удар слабее на 4)», «+1.3 regeneration base»
  → «+1.3 HP/сек», англо-тайтлы переведены. Карточка по-прежнему рисует before→after через
  `_level_up_reward_preview` (живые числа текущего билда).
- **Тексты согласованы**: glossary дополнен каноничными терминами атрибутов; codex_data.gd
  деривит тексты из progression/stat_formulas (не дублирует строки) — правок не требовал.
- **Правило наград**: `ProgressionData.weighted_level_up_selection` (делегируется из
  `ui_screens._random_level_up_rewards`) — ≤1 optional и ≥1 primary/secondary в наборе из 3;
  rare main-stat слот и capstone «Озарение» не-optional. Подтверждено тестом на 200 сэмплов ×
  17 классов.
- **Веса от матрицы**: `attribute_relevance_weight` primary 1.4 > secondary 0.7 >> optional 0.4
  (optional держится > 0.3). Магнитуды специально занижены относительно первой версии
  (2.4/1.0/0.4), которая раздула «идеальный» билд химика и пробила pool_dot-потолок (72070 >
  70000); на 1.4/0.7/0.4 pool_dot вернулся к 52596/53388 ≤ 70000. `ATTRIBUTE_PRIORITIES`
  (8 базовых) оставлен для редкого main-stat слота и pause-stats tooltips.

Зелёные гейты (через `tools/godot_gate.py`, одиночный Godot):
- `tests/attribute_relevance_test.gd` — PASS (24×17, инвариант 2/8/7 + правило наград).
- `tests/runtime_smoke_test.gd` — PASS (включая level_up_reward_weight assertions).
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/pool_dot_runaway_gate.gd` — PASS (acid 52596, blast 53388 ≤ 70000).
- `tests/berserk_dps_runaway_gate.gd` — PASS (20t=2179 ≤ 3600, 1t=428 ≤ 650).

Примечание: `docs/design/systems/balance.md` из спеки фактически называется
`docs/design/systems/progression_balance.md` — обновлён он.
