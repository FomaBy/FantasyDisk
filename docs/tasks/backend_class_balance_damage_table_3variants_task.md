# BALANCE: Сводная таблица урона классов (1/5/20 целей) × 3 варианта прокачки

Статус: done
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-453
QA: in_progress (2026-06-17)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Анализ баланса классов — сводная таблица урона: по 1 цели, по 5 целям рядом, по 20
целям вокруг персонажа. 3 варианта:
1) без прокачки;
2) 20 уровень с прокачкой МАКСИМАЛЬНО эффективных атрибутов/характеристик;
3) 20 уровень со СЛУЧАЙНОЙ прокачкой атрибутов/характеристик».

## Требования
1. Симуляция/расчёт DPS (или урон/сек) для КАЖДОГО класса (все 16) и его оружий по
   сценариям: **1 цель**, **5 целей рядом** (плотно), **20 целей вокруг** героя.
2. Три варианта билда:
   - **V1 без прокачки** (база, уровень 1, без атрибутов);
   - **V2 lvl20 оптимум** — прокачка максимально эффективных под класс атрибутов/
     характеристик/повышений;
   - **V3 lvl20 случайно** — случайная прокачка (несколько прогонов, усреднить, seed).
3. Использовать существующий sim-движок (backend_test_live_balance_simulation /
   estimate_weapon_budget) и реальные формулы (progression_data*).
4. **Сводная таблица** (markdown + при желании CSV) в docs/design/ или build/qa/:
   строки = классы/оружия, колонки = (1ц/5ц/20ц) × (V1/V2/V3). Выделить явные
   перекосы (слишком сильные/слабые) — короткий вывод для балансировки.
5. Детерминизм (seed) для воспроизводимости; тест/скрипт-генератор таблицы.
6. CHANGELOG; progression_balance; приложить таблицу.

## Files / Assets / IDs
- scripts/progression_data*.gd (формулы/бюджеты), estimate_weapon_budget, CLASS_BALANCE
- tests/live_balance_simulation_test.gd (sim-движок), tools/ (генератор таблицы)
- docs/design/ (итоговая таблица)

## Acceptance Criteria
- [x] Сводная таблица урона: классы × (1ц/5ц/20ц) × (без прокачки / lvl20 оптимум / lvl20 случайно).
- [x] Случайный вариант усреднён по прогонам (seed); детерминизм; выделены перекосы + вывод.
- [x] Скрипт-генератор + таблица в репо; smoke не сломан; CHANGELOG.

## Документация
docs/design/systems/progression_balance.md.

## Результат
- Back-end done 2026-06-17: добавлен детерминированный генератор
  `tools/class_damage_table_3variants.gd` и регрессионный gate
  `tests/class_damage_table_3variants_test.gd`.
- Таблица Markdown: `docs/design/reports/class_damage_table_3variants.md`.
  CSV evidence: `build/qa/scrum453/class_damage_table_3variants.csv`.
- Использована живая ростерная выборка `ProgressionData.character_ids()`:
  сейчас это 17 классов и 51 оружие, хотя исходный текст задачи упоминал 16.
- Методика: V1 base lvl1; V2 lvl20 optimum = greedy allocation of 19 base-stat
  points maximizing class kit score across 1/5/20-target DPS; V3 lvl20 random =
  64 seeded runs averaged (`45320260617`). Живые balance numbers не менялись.
- Выводы отчёта: base lvl1 budget стабилен; относительные выбросы для follow-up
  balance review отмечены в `Outlier Summary` (например high robot/knight/dark_mage
  optimum, low guitarist/assassin/doctor/chemist/druid optimum).
- Проверки PASS: `tests/class_damage_table_3variants_test.gd`,
  `tests/global_damage_balance_smoke_test.gd`, `tools/balance_harness.gd`.

## QA-Вердикт (2026-06-17)
Статус: PASSED — сводная таблица урона (классы × 1/5/20ц × 3 варианта прокачки) детерминирована

Проверено (фактически): `tools/class_damage_table_3variants.gd` генерирует
`docs/design/reports/class_damage_table_3variants.md` + `build/qa/scrum453/...csv`
(17 классов, 153 weapon-build rows); `tests/class_damage_table_3variants_test.gd` PASSED
(детерминизм/seed); живые balance-числа не менялись (методика greedy optimum + 64 seeded
random runs). runtime_smoke зелёный. Acceptance: [x] все пункты. Статус done → Готово.
