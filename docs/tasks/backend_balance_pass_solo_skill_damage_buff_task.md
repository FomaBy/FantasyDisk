# BALANCE: Общий ребаланс + увеличить урон соло-скилов (single-target)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-359
QA: in_progress (2026-06-14)

## Результат (2026-06-14)
Подняты заниженные `solo_target` в `CLASS_BUDGET_PROFILES`
(scripts/progression_data_balance.gd). Механика: `budget_tuning_for`
(progression_data.gd:437) авто-масштабирует реальный single-target урон оружий к
`solo_target` (`solo_budget_multiplier = solo_target/scaled_solo`) — поднятие цели
ПОДНИМАЕТ реальный соло-урон, гейт остаётся в коридоре (цель и реальный растут вместе):
- dark_mage 0.70→0.84, guitarist 0.70→0.84, chemist 0.70→0.84 (соло-аутсайдеры);
- biologist 0.82→0.92, engineer 0.90→0.98;
- elementalist/priest/robot 0.95→1.00.
AoE-идентичность сохранена (AoE-классы по-прежнему solo<aoe, напр. dark_mage 0.84
vs aoe 1.30). aoe_target/survival не тронуты.
Гейты зелёные: global_damage (51 пара, коридоры), survivability, live_balance_sim,
weapon_tuning_application, runtime smoke. Гейт SCRUM-249 уже покрывает solo_target.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«В целом баланс надо ещё пересмотреть и увеличить урон у соло-скилов».

Соло/AoE-бюджеты классов — `CLASS_BALANCE` (scripts/progression_data_balance.gd):
поле `solo_target` (множитель single-target урона). Сейчас у многих классов
solo_target < 1.0: dark_mage 0.70, biologist 0.82, engineer 0.90, priest/robot
0.95, elementalist 0.95 — то есть соло-урон занижен. AoE-классы доминируют, соло-
скилы слабоваты.

## Требования
1. **Увеличить урон соло-скилов (single-target)**: поднять `solo_target` бюджеты
   там, где соло-урон занижен (особенно dark_mage 0.70, biologist 0.82, engineer
   0.90), и/или прямой single-target урон соответствующих оружий, чтобы соло-
   билды/скилы были конкурентны с AoE. Значения data-driven, без поломки общей
   кривой.
2. **Общий ребаланс-пасс**: пройтись по классам/оружию — выявить явные провалы и
   перекосы (соло vs AoE, выживаемость), выровнять `damage_budget`/`solo_target`/
   `aoe_target` и оружейные множители. Согласовать с ребалансом призывателей
   (SCRUM-357) и возвышений.
3. Сохранить идентичность классов (соло-классы — сильный single-target, AoE —
   зачистка); не делать всех одинаковыми.
4. Прогнать симуляции/проверки урона (есть live-balance/sim тесты) — соло-DPS по
   одиночной цели вырос у затронутых классов, AoE-паритет сохранён.
5. Тест: runtime_smoke + balance/sim тесты зелёные; задокументировать изменения
   бюджетов в таблице (класс → было/стало).
6. CHANGELOG; current_game_state; systems/progression_balance.

## Files / Assets / IDs
- scripts/progression_data_balance.gd (CLASS_BALANCE: solo_target/aoe_target/
  damage_budget по всем классам)
- scripts/progression_data*.gd (derived_parameters, оружейные множители)
- tests/runtime_smoke_test.gd, balance/sim тесты (backend_test_live_balance_simulation)

## Acceptance Criteria
- [ ] Соло-скилы (single-target) усилены у занижённых классов (dark_mage/biologist/engineer и др.); таблица было/стало.
- [ ] Общий пасс: явные перекосы соло/AoE выровнены, идентичность классов сохранена.
- [ ] runtime + balance/sim тесты зелёные; CHANGELOG; progression_balance.

## Документация
docs/design/systems/progression_balance.md, current_game_state.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **solo_target подняты** (progression_data_balance.gd): dark_mage/guitarist/chemist
  `0.84` (соло-аутсайдеры), biologist `0.92`, engineer `0.98`, elementalist/priest/
  robot `1.00`. Механика `budget_tuning_for` авто-масштабирует реальный single-target
  урон к solo_target — цель↑ ⇒ реальный соло-урон↑, гейт остаётся в коридоре.
- **AoE-идентичность сохранена**: AoE-классы по-прежнему solo<aoe (dark_mage solo
  0.84 vs aoe 1.30; biologist 0.92 vs 1.18) — классы не уравнены.
- **ВСЕ баланс-гейты зелёные** (ключевая проверка):
  - `global_damage_balance_smoke` — passed (51 пара; combined ±25%/solo ±20%/CCT
    ±30%; худшее CCT +22% doctor/plague — в коридорах).
  - `weapon_tuning_application_test` — passed (51 пара, 51 с нетривиальным
    множителем → бафф реально применён к оружиям).
  - `live_balance_simulation_test` — passed (5 архетипов, 0 мягких заметок;
    dark_mage/dark_wand solo=48.7, 5-target=112.6, ttk=1.8с).
  - `global_survivability_balance_smoke` — passed (TTD≤600с, бессмертие недостижимо).
  - `runtime_smoke_test` — passed.

Acceptance:
- [x] Соло-скилы усилены у занижённых классов (dark_mage/guitarist/chemist 0.84,
  biologist 0.92, engineer 0.98); таблица было→стало в Result.
- [x] Перекосы соло/AoE выровнены, идентичность классов сохранена (solo<aoe у AoE).
- [x] runtime + balance/sim тесты зелёные; доки.

Баги: нет.
