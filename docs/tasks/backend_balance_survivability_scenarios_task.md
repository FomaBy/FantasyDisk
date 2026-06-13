# Back-end Task: Survivability Scenario Harness

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-190
QA: in_progress (2026-06-13)
Эпик: epic_full_project_quality_pass

## Scope

Create deterministic survivability scenarios for fragile/steady/sturdy/tank profiles.

## Scenarios

- Contact swarm.
- Shooter crossfire.
- Elite burst.
- Boss phase hazard.

## Requirements

- Measure time-to-death, healing contribution, dodge/defense/absorb contribution.
- Compare against EHP expectations and flag outliers.

## Verification

- New scenario harness runs headless.
- No balance values changed in this task unless follow-up balance tasks are created.

## Done (2026-06-13)
`tools/survivability_harness.gd` — детерминированная модель выживаемости 4 профилей (fragile/steady/sturdy/tank) × 4 сценария (контактный рой/перекрёстный обстрел/бурст элитки/хазард фазы босса) на точной боевой формуле `derived_parameters` + порядок митигейта `take_damage` (absorb→defense→dodge→regen). Считает TTD, EHP, вклад каждого слоя и лечения; отчёт `build/survivability_report.md`. Балансовые значения НЕ менялись.
`tests/survivability_scenario_test.gd` — гейт: монотонность TTD по стойкости в каждом сценарии, положительный вклад слоёв у sturdy/tank, absorb сильнее против роя чем бурста, **якорь к реальному `Player.take_damage`** (неувёрнутый удар == формула, 30.065 на 71 ударе), анти-вакуум 16 строк. Headless зелёный, детерминирован.

## Back-end follow-up (2026-06-13)

Added `tools/survivability_scenarios.gd` as a roster projection layer on top of the formula/parity harness. It measures every current class with its first weapon against contact swarm, shooter crossfire, elite burst and boss phase hazard bands and writes `build/survivability_scenarios_report.md`.

Current projection result: 6 ok, 62 low, 0 high. This is recorded as a measurement finding only; SCRUM-190 still does not change class/enemy/economy constants. Follow-up balance work should decide whether to raise survivability budgets, lower scenario incoming damage assumptions, or add class-specific defensive affordances.

Additional verification:
- `tools/survivability_scenarios.gd` headless: passed, report generated.
- `tests/runtime_smoke_test.gd`: passed.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## QA-Вердикт (2026-06-13)
Статус: PASSED (скоуп «harness/measurement»)
Коммит: 78058d35 (ветка dev)

Проверено (фактически):
- **Тест-гейт не пустышка** (`survivability_scenario_test.gd`, 123 стр.): 5 гейтов
  — монотонность TTD по стойкости (fragile<steady<sturdy<tank), вклад слоёв ≥0 и
  >0 у sturdy/tank, конечный TTD, доля absorb выше в рое чем в бурсте, и
  **ЯКОРЬ к реальному `Player.take_damage`** (неувёрнутый удар снимает ровно
  формульный `expected_hit_damage`). Зелёный, детерминирован.
- **Харнесы**: `tools/survivability_harness.gd` → `build/survivability_report.md`
  (16 строк), `tools/survivability_scenarios.gd` → `build/survivability_scenarios_report.md`
  — оба прогоняются headless, отчёты пишутся.
- **Баланс-константы НЕ менялись**: задача добавила только tools/tests; gameplay
  не тронут.
- **Регрессия (78058d35)**: animation / meta / targeting / progression_economy
  smoke — зелёные.

Acceptance:
- [x] Новый harness прогоняется headless.
- [x] Балансовые значения не менялись.

⚠️ **ФЛАГ ДЛЯ PM/БАЛАНСА (не дефект SCRUM-190 — харнес именно это и должен был
вскрыть):** roster-проекция = **6 ok / 62 low / 0 high**. Подавляющее
большинство классов умирают существенно быстрее ожидаемого EHP-бэнда (напр.
berserk/sturdy Contact Swarm TTD 8.8с против полосы 14-38с; soldier/steady 7.5с
против 11-32с). Это либо реальная нехватка выживаемости, либо слишком жёсткие
incoming-damage/EHP-предположения харнеса. Требуется **отдельная balance-задача**
(решить: поднять бюджеты выживаемости / снизить входящий урон сценариев /
добавить классовые защитные механики). QA не заводит bug (это тюнинг-решение
дизайна, не код-дефект), но рекомендует PM создать balance follow-up.

Баги: нет (в зоне харнеса).
