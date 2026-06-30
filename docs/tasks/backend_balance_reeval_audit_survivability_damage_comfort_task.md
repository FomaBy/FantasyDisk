# Balance Re-Evaluation: Measurement & Findings (Survivability / Damage / Comfort)

Jira: SCRUM-780
Статус: done
Приоритет: P1
Роль: Back-end / balance
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM по запросу пользователя «пересмотреть баланс персонажей: выживаемость, урон, комфорт игры»
Labels: backend, claude, foma, balance, p1, area-balance, reeval-wave
Epic: SCRUM-214 - Баланс

## Context

Пользователь просит полный пересмотр баланса персонажей по трём осям:
**выживаемость**, **урон** и **комфорт игры**. Предыдущая балансовая волна
(SCRUM-504/505/506/544) частично заблокирована из-за устаревших AC и
нестабильного CSV-арбитра (`character_balance_csv.gd` интермиттентно падает
SIGABRT под нагрузкой). Поэтому эта волна делается **evidence-first**: сначала
замер и выводы (эта задача), затем три тюнинг-пасса по результатам.

Эта задача — **read-only замер и анализ**. Никаких изменений баланса в коде:
только данные, выводы и предложения по тюнингу для дочерних задач.

## Scope / Locked Paths (read-only)

- Чтение: `scripts/progression_data*.gd`, `scripts/stat_formulas.gd`,
  `scripts/class_weapon.gd`, `docs/design/systems/progression_balance.md`,
  `docs/design/mechanics_extract.md`, `docs/design/reviews/`.
- Запись только в новый отчёт: `docs/design/reviews/balance_reeval_2026_06.md`.
- Не трогать тюнинг-значения и тесты.

## Required Change

Собрать актуальную картину баланса всех 51 пары класс/оружие по трём осям и
зафиксировать выводы + конкретные предложения по тюнингу:

1. **Урон (damage):** lvl1/lvl20 ideal и random билды, spread между классами
   (best-weapon и random), выбросы сверху/снизу, berserk-ось отдельно.
2. **Выживаемость (survivability):** effective HP (HP + defense + dodge),
   vampirism/sustain, время до смерти в death-сценариях, разброс между классами,
   классы-«стекляшки» и классы-«танки».
3. **Комфорт игры (comfort/pacing):** time-to-kill по волнам, AoE/clear-комфорт,
   контроль/таргетинг summon-классов, читаемость прогрессии, ощущение наград,
   простои и пики сложности. Опереться на `comfort_band_cross_class_gate.gd`.

Для каждой оси: что в норме, что выбивается, гипотеза причины, предложение.

## Acceptance Criteria

- Создан отчёт `docs/design/reviews/balance_reeval_2026_06.md` с тремя секциями
  (выживаемость / урон / комфорт) и таблицей выбросов по классам.
- Для каждой оси перечислены конкретные кандидаты на тюнинг с числами
  before и целевым диапазоном (band), а не абсолютом.
- Явно отмечены классы вне comfort-band и вне 0.75x–2.0x spread-гейтов.
- Сформирован приоритизированный backlog правок для трёх дочерних задач
  (survivability / damage / comfort).
- Никаких изменений баланс-значений или тестов в этом тикете.
- Финальный Jira-коммент: branch/commit, прогнанные гейты, путь к отчёту,
  `Disk cleanup: ...`.

## Suggested Verification

Замерять детерминированными гейтами; **не** гонять тяжёлый
`character_balance_csv.gd` под нагрузкой (SIGABRT-флейк) — для berserk-оси юзать
`berserk_dps_runaway_gate.gd`, при необходимости считать ре-нормировку в Python.

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/survivability_scenario_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/comfort_band_cross_class_gate.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/class_damage_table_3variants_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd
```

## Process Notes

Перед стартом: sync `dev`, проверить dirty tree и отсутствие активных владельцев
на locked paths. Запускать Godot-гейты по одному (pkill чужих параллельных
процессов опасен при живом флоте — сперва ps-проверить чужой worktree). После:
Jira -> local mirror -> intentional commit -> push. Эта задача — гейт для
дочерних: survivability / damage / comfort пассов.

## QA-Вердикт

Статус: PASSED
Дата: 2026-06-30 | QA: claude-qa | HEAD: origin/dev | Godot 4.7 (godot_gate)

Read-only замер/отчёт — приёмка структуры и точности, без правок баланса/тестов.
- Отчёт docs/design/reviews/balance_reeval_2026_06.md: 3 секции (выживаемость/урон/
  комфорт) + сводная таблица выбросов (before-числа + целевые band'ы) + приоритизированный
  backlog для 3 дочерних пассов. Все acceptance-пункты покрыты. ✓
- Классы вне band явно отмечены: dark_mage (EHP 34.6, 0.39x), knight/robot (2.0–2.3x),
  cap-pinned damage-пары (mult 2.800), summon/DoT over-hitters (mult 0.28–0.62),
  comfort-лаггеры crowd-clear +20–22%. ✓
- Acceptance #5 (никаких правок баланс-значений/тестов): commits 63e004bd+947834c5 трогают
  только docs/ (180 строк отчёта + 3 строки mirror в task md); scripts/ и tests/ НЕ изменены. ✓
- Дочерние таски существуют: backend_balance_reeval_{survivability,damage,comfort_pacing}_*_task.md. ✓

Гейты (sanity на HEAD, семафор): comfort_band_cross_class_gate (spread 1.13x, 0 нарушений
на срезах 1/5/20 — совпадает с отчётом), global_survivability_balance_smoke (16 строк,
TTD≤600с) — оба PASS. Измерительный инструмент зелёный, выводы отчёта обоснованы.
