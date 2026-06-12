# QA Review: Mini Elite Spawn Behavioral Test Coverage

Статус: done
Создано: 2026-06-12
Автор: Codex Dispatcher
Jira: SCRUM-113

## Source Task
- `docs/tasks/test_mini_elite_spawn_behavioral_coverage_task.md`

## Ready For QA
Исходная Back-end test-hardening задача получила `done` 2026-06-12.

## QA Scope
Проверить, что добавлен именно поведенческий тест спавна мини-элитки, а не только data-check.

## Acceptance Criteria
- [ ] Тест форсирует `mini_elite_chance = 1.0` или эквивалентный детерминированный сценарий.
- [ ] Проверяется фактическое создание узла в `elite_enemies`.
- [ ] Проверяется HP mini-elite около elite HP x0.55.
- [ ] Проверяется расход слотов и ограничение свиты.
- [ ] Тест действительно покрывает потребление `mini_elite_chance`.
- [ ] runtime smoke/regression зеленые или заведены bug tasks.

## QA-Вердикт (2026-06-12)
Статус: PASSED

Независимая верификация (отдельная QA-сессия; тест читал adversarial + прогон):
- Тест в `runtime_smoke_test.gd:2936-2996` — реально поведенческий, не data-only.
- (A) Путь потребления (2953-2962): forced `mini_elite_chance=1.0`, вызов
  `_spawn_enemy_wave`, ассерт `elites_after > elites_before`. Падает на «мёртвой»
  версии (где потребление отсутствует) — закрывает исходный слепой пятно.
- (B) Прямой вызов (2964-2996): ровно 1 мини-элитка в `elite_enemies`; `used` в
  2..5; учёт слотов `enemies==used`; HP = свежескейленный эталон той же сцены ×0.55
  (допуск ±3%) — убиваемая, не танк.
- Детерминированный rng (seed 24607), чистая арена. runtime_smoke + все 6 smoke
  зелёные.

Все 6 acceptance-пунктов выполнены фактически. Багов нет.
