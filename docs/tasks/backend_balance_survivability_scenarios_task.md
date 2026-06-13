# Back-end Task: Survivability Scenario Harness

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-190
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
