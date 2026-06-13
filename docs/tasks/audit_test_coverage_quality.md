# Аудит: покрытие и качество тестов

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-178
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Back-end (Claude)
## Контекст
7 smoke-сьютов (runtime, animation, meta_progression, melee_targeting, attack_vfx,
hazard_vfx). После роста контента (17 классов, новые боссы/мини-элитки, мета-древо,
экономика) покрытие надо пересмотреть. Был урок: тесты иногда проверяли намерение,
а не фактический рендер/дерево (SCRUM-144).

## Что сделать (READ-ONLY + отчёт + дочерние тест-задачи)
1. Карта «система → есть ли тест, что именно проверяет, фактический ли ассерт».
2. Найти непокрытые механики (новые классы/оружие, мета-древо, дроп-экономика,
   призывы, no-overlap UI на всех экранах) и тесты-пустышки.
3. **Отчёт** `docs/design/reviews/test_coverage_audit_2026_06.md` с пробелами
   по приоритету.
4. **Породить** `backend_test_<area>_task.md` (0.1.4) на добор покрытия;
   акцент на фактические ассерты (дерево узлов/значения, не флаги).

## Acceptance Criteria
- [ ] Карта покрытия систем; список пробелов и пустышек по приоритету.
- [ ] Созданы дочерние тест-задачи; существующие 6 smoke зелёные.

## Документация
docs/design/reviews/.

## Результат — 2026-06-13

Read-only аудит завершен. Отчет создан:
`docs/design/reviews/test_coverage_audit_2026_06.md`.

Ключевые выводы:
- `tests/runtime_smoke_test.gd` стал mega-suite на 4824 строки; нужен split на focused suites с umbrella command.
- UI тесты стали фактическими по node tree/global rect для части экранов, но no-overlap matrix не покрывает все экраны.
- Balance coverage остается model-first; нужны live DPS/TTK/survivability simulations.
- Нет автоматического registry-vs-code-vs-assets gate.

Созданы child task specs 0.1.4:
- `docs/tasks/backend_test_runtime_smoke_suite_split_task.md`
- `docs/tasks/backend_test_live_balance_simulation_task.md`
- `docs/tasks/backend_test_content_registry_consistency_task.md`
- `docs/tasks/backend_test_ui_no_overlap_matrix_task.md`

Jira для child tasks: pending PM sync, потому что текущий Back-end toolset не имеет Jira connector/API.

Verification: runtime, animation, meta progression, meta skill tree, melee targeting, attack VFX and hazard VFX smoke suites passed on 2026-06-13.
