# BALANCE: Общий ребаланс + увеличить урон соло-скилов (single-target)

Статус: new
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-359

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
