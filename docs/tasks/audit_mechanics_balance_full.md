# Аудит: все механики и баланс (17 классов x оружие)

Статус: done
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-176
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Back-end (Claude)
## Контекст
17 классов, 51 оружие, артефакты, возвышения, экономика дропа, элитки/боссы.
Есть `tools/balance_harness.gd` и `build/balance_report.md`.

## Что сделать (READ-ONLY анализ + отчёт + дочерние балансфикс-задачи)
1. Прогнать balance harness по ВСЕМ парам класс+оружие; собрать TTK/DPS/
   выживаемость; выделить выбросы за ±20% от эталона (Берсерк меч).
2. Ревью механик каждого класса: уникальность паттернов (нет ли скрытых
   дублей среди 51 оружия после массового add-character), читаемость, баги
   взаимодействий (вампиризм/реген после SCRUM-149, дроп/экономика SCRUM-153).
3. Возвышения (10 ур.), артефакты (аффинити/силы), экономика и XP-кривая —
   проверка на эксплойты и мёртвые опции.
4. **Отчёт** `docs/design/reviews/mechanics_balance_audit_2026_06.md`: таблица
   класс×оружие с метриками, список выбросов и спорных механик по приоритету.
5. **Породить** `backend_balance_<area>_task.md` (0.1.5) на каждую группу правок;
   общие файлы (progression_data/class_weapon) — сериализовать.

## Acceptance Criteria
- [ ] Метрики по всем парам класс+оружие в отчёте; выбросы помечены.
- [ ] Список механик-проблем по приоритету; созданы дочерние балансфикс-задачи.
- [ ] Read-only, 6 smoke зелёные.

## Документация
docs/design/reviews/, mechanics_extract.md (если уточняются формулы — отдельной задачей).

## Результат — 2026-06-13

Read-only аудит завершен. Balance harness запущен:

`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd`

Результат: passed, `build/balance_report.md` обновлен.

Отчет создан:
`docs/design/reviews/mechanics_balance_audit_2026_06.md`.

Ключевые выводы:
- 51/51 class+weapon pairs попадают в model targets после auto tuning.
- Это не является полной live-balance гарантией: `budget_damage_multiplier` нормализует модель, но не проверяет фактический combat uptime/TTK.
- Raw pre-tuning разброс экстремальный у ряда оружий, поэтому нужно проверить, что runtime нигде не обходит `ProgressionData.weapon()`.
- Economy buying power в модели +10.6%, XP tempo +7.1%; XP ниже целевого диапазона +10-15% и требует live route validation.

Созданы child task specs 0.1.5:
- `docs/tasks/backend_balance_live_combat_harness_task.md`
- `docs/tasks/backend_balance_survivability_scenarios_task.md`
- `docs/tasks/backend_balance_economy_xp_live_route_model_task.md`
- `docs/tasks/backend_balance_weapon_tuning_application_regression_task.md`

Jira для child tasks: pending PM sync, потому что текущий Back-end toolset не имеет Jira connector/API.

Verification: balance harness passed; runtime, animation, meta progression, meta skill tree, melee targeting, attack VFX and hazard VFX smoke suites passed on 2026-06-13.
