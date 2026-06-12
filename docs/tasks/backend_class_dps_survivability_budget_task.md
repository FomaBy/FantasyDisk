# Задача Для Back-end-Агента: Бюджет Силы Классов — Урон Соло/АоЕ И Выживаемость

Статус: done
Создано: 2026-06-12
Автор: PM
Dispatch: отправлено в существующий Back-end чат `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-12.
Масштаб: крупная. Выполнять ПЕРВОЙ из балансового пакета — задача
`backend_enemy_scaling_elite_boss_difficulty_task.md` опирается на её замеры.

## Autonomy / Approval
Пользователь заранее одобрил. Конкретные числа — твои, рамки — ниже.

## Контекст (решение пользователя)
Пересмотреть ВСЕ абилки персонажей. Целевая модель:
- примерно одинаковый бюджет урона **по 1 цели** и **по 5 целям** у всех классов;
- у кого-то соло-урон выше, а АоЕ ниже; у кого-то наоборот; у кого-то золотая
  середина — но СУММАРНЫЙ бюджет в балансе;
- выживаемость — отдельная ось: мало выживаемости → компенсируется уроном.

## Требования
1. **Измерительный харнесс** (главный инструмент): автоматический тест/скрипт,
   замеряющий для каждой пары класс+оружие (27 комбинаций):
   - DPS по 1 жирной цели за 30с;
   - DPS по группе из 5 целей за 30с;
   - индекс выживаемости (EHP: HP * (1+защита) * (1+уворот) + лечение/щиты в сек).
   Вывод — таблица в `build/balance_report.md`, обновляемая одной командой
   (`tools/balance_harness.gd` или тест). Без харнесса баланс не принимается.
2. **Профили архетипов** (зафиксировать в данных, каждому классу — профиль):
   - `solo` (например assassin, ranger): соло-DPS ~130% базы, АоЕ ~70%;
   - `aoe` (chemist, dark_mage, guitarist): соло ~70%, АоЕ ~130%;
   - `balanced` (berserk, druid): ~100/100;
   - база — средний бюджет по всем классам.
3. **Ось выживаемости**: суммарный индекс силы = урон-бюджет * коэффициент
   выживаемости. Танковые (knight, doctor) — выживаемость высокая, урон-бюджет
   ~85%; хрупкие (assassin, dark_mage) — выживаемость низкая, урон-бюджет ~115%.
   Формализуй кривую компенсации и задокументируй.
4. **Перебалансировать все 27 оружий** под профили: множители, интервалы,
   радиусы. Идентичность механик НЕ менять (паттерны остаются уникальными),
   крутим только числа.
5. Ульты — в том же бюджете: вклад ульты в DPS окна учесть в замерах.
6. Допуск: внутри профиля отклонение пар класс+оружие от целевых значений ≤ ±10%.
7. Харнесс-замеры ДО и ПОСЛЕ — в отчет и mechanics_extract (таблица бюджетов).

## Files / Assets / IDs
- `scripts/progression_data.gd` (числа оружий, профили), `scripts/stat_formulas.gd`,
  новый `tools/balance_harness.gd` (или тест), `docs/design/mechanics_extract.md`.

## Acceptance Criteria
- [x] Харнесс генерирует таблицу 27 комбинаций одной командой.
- [x] Профили solo/aoe/balanced заданы в данных; отклонения ≤ ±10%.
- [x] Кривая «урон компенсирует выживаемость» формализована и применена.
- [x] Таблицы до/после в mechanics_extract; все smoke зеленые.

## Документация
- mechanics_extract (бюджеты, профили, формула компенсации), CHANGELOG.

## Результат 2026-06-12

Back-end implementation complete:
- Добавлен `tools/balance_harness.gd`, который одной Godot-командой пишет `build/balance_report.md`.
- В `ProgressionData` добавлены `CLASS_BUDGET_PROFILES`, base solo/5-target targets, auto `budget_tuning_for()` и `estimate_weapon_budget()`.
- `derived_parameters()` применяет runtime `budget_damage_multiplier`, а harness дополнительно проверяет solo/5-target residual multipliers без изменения attack identity.
- Покрытие: 27/27 class+weapon pairs; max combined deviation after tuning: 0.1%; smoke проверяет отклонения ≤ ±10%.

Checks:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd` — passed, report generated.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed (Godot warning about freed lambda capture printed, test result green).
