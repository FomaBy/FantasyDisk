# Balance Re-Evaluation: Comfort & Pacing Pass

Jira: SCRUM-781
Статус: done
Приоритет: P2
Роль: Back-end / balance
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
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

## QA-Вердикт

Статус: PASSED
Дата: 2026-06-30 | QA: claude-qa | HEAD: origin/dev | Godot 4.7 (godot_gate)

Evidence-driven no-op принят: ось комфорт/pacing здорова в пределах locked paths,
безопасного тюнинг-кандидата нет; форсить правки = риск регрессии соседних гейтов
(прямой AC «не ломать damage/survivability»). Per-weapon crowd-clear-лаггеры (+20–22%)
корректно отложены в damage-пасс SCRUM-782 (вне comfort locked paths).

Гейты (все PASS на HEAD, семафор):
- comfort_band_cross_class_gate: spread 1.13x, 0 нарушений (срезы 1/5/20t).
- ascension_curve_balance_test: монотонна до L5 (hp×1.80), пик L3=0.16→спад L5=0.03 — без стен.
- enemy_damage_spread_gate: TTD-floor 0.48с, fragile ≥1.5× окна реакции (0/4/8/10) — без ваншотов.
- live_balance_simulation_test: 5 архетипов, 0 мягких заметок.

Acceptance:
- Гейты зелёные, разброс комфорта узок (1.13x — сужать нечего). ✓
- Кривая без провалов/стен. ✓ Enemy spread в пределах, без ваншотов. ✓
- Темп наград/прогресса описан/обоснован (progression_balance.md §Comfort/Pacing re-eval). ✓
- Соседние гейты не регрессировали: commits df471125+c11bc81c трогают только docs/ (scripts/tests НЕ изменены). ✓
