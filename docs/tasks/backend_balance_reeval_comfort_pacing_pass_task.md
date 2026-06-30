# Balance Re-Evaluation: Comfort & Pacing Pass

Jira: SCRUM-781
Статус: new
Приоритет: P2
Роль: Back-end / balance
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM по запросу пользователя на пересмотр баланса (ось «комфорт игры»)
Labels: backend, claude, foma, balance, p2, area-balance, area-comfort, reeval-wave
Epic: SCRUM-214 - Баланс

## Context

Дочерняя задача волны пересмотра баланса. Опирается на отчёт
`docs/design/reviews/balance_reeval_2026_06.md`. Цель — ощущение игры: ровный
time-to-kill, отсутствие провисаний и резких пиков сложности, читаемый
прогресс, удовлетворяющие награды, удобный контроль/таргетинг — без поломки
урон/выживаемость пассов.

Не стартовать, пока аудит не зафиксировал findings по комфорту; идти после/в
изоляции от damage и survivability пассов (разные locked paths).

## Scope / Locked Paths

- `scripts/progression_data_content.gd` (волны/спавн/темп),
  `scripts/progression_data_ascension.gd` (кривая сложности),
  `scripts/progression_data_shop.gd` / drop-экономика (ощущение наград) —
  только pacing/comfort-параметры, без пересечения с damage/survivability числами.
- Тесты: `tests/comfort_band_cross_class_gate.gd`,
  `tests/live_balance_simulation_test.gd`, `tests/ascension_curve_balance_test.gd`,
  `tests/enemy_damage_spread_gate.gd`.
- `docs/design/systems/progression_balance.md` (секция комфорта/pacing).

## Required Change

По выводам аудита:

- Выровнять time-to-kill по волнам: убрать провисания (слишком долгие пустые
  волны) и резкие пики (внезапные стены сложности) в кривой ascension.
- Сгладить enemy damage spread, чтобы не было ваншотов вне дизайна
  (`enemy_damage_spread_gate.gd`, `contact_damage_softcap_test.gd`).
- Улучшить ощущение наград/прогресса: темп level-up и drop-экономики так, чтобы
  выборы ощущались значимо и регулярно (без инфляции силы).
- Комфорт summon/AoE-классов: контроль/таргетинг и читаемость на экране при
  толпе (на уровне баланс-параметров, не VFX).
- Каждое число — before/after + обоснование; не ломать damage/survivability
  гейты из соседних пассов.

## Acceptance Criteria

- `comfort_band_cross_class_gate.gd` зелёный, разброс комфорта сужен.
- Кривая сложности без провалов/стен: `ascension_curve_balance_test.gd` и
  `live_balance_simulation_test.gd` зелёные.
- Enemy damage spread в пределах гейта; нет недизайненных ваншотов.
- Темп наград/прогресса описан и обоснован; нет инфляции силы, ломающей spread.
- Damage/survivability гейты соседних пассов не регрессировали.
- Финальный Jira-коммент: branch/commit, тесты, before/after, `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/comfort_band_cross_class_gate.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/live_balance_simulation_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ascension_curve_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_damage_spread_gate.gd
```

## Process Notes

Sync `dev`, проверить отсутствие активных владельцев на locked paths (изоляция
от damage/survivability пассов). Гейты по одному. После: Jira -> mirror ->
intentional commit (явный git add своих файлов) -> push.
