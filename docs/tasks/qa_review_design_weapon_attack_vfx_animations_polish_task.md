# Задача Для QA-Агента: Review Анимаций Атак Оружия И VFX-Полировки

Статус: done
Создано: 2026-06-12
Автор: Codex dispatcher
Jira: SCRUM-126
Роль: QA (Claude)
Источник: `docs/tasks/design_weapon_attack_vfx_animations_polish_task.md`
Готово к QA: исходная Design задача получила `done` 2026-06-12.

## Autonomy / Approval
Пользователь заранее одобрил QA-проверку всех in-scope изменений. QA не чинит
баги сам: найденные дефекты оформлять отдельными `bug_*.md` задачами на доске.

## Что Проверить
- Аудит всех combat/VFX эффектов из исходного task-файла: голых видимых
  `Polygon2D`/программных кругов в бою не осталось, если они не помечены как OK.
- Лужи/облака/зоны/ауры/ульты читаются на боевых фонах и не перекрывают бой.
- Все 27 оружий имеют заметный, аккуратный attack/shoot/cast motion без рассинхрона
  с таймингами урона.
- Пауза замораживает новые VFX/анимации.
- Массовые эффекты не дают заметной просадки на 100+ врагах.
- Документация, registry и CHANGELOG обновлены.

## Ожидаемые Проверки
- Прочитать исходный task-файл, progress log, скриншоты/preview.
- Прогнать `attack_vfx_smoke_test`, `hazard_vfx_smoke_test`,
  `animation_smoke_test`, `runtime_smoke_test` и обязательные QA regression tests.
- Сделать визуальную проверку в окне игры; сохранить артефакты в
  `build/qa/design_weapon_attack_vfx_animations_polish/`.
- Проверить edge cases: пауза во время VFX, 1280x720, бой с большим числом врагов.

## Acceptance Criteria
- [ ] Все пункты исходной задачи проверены фактически.
- [ ] Visual QA не нашел голых/сломанных/перекрывающих эффектов.
- [ ] Smoke/regression проверки зеленые или оформлены bug tasks.
- [ ] В исходный task-файл добавлен `## QA-Вердикт` по протоколу.
- [ ] Board обновлена пометкой `QA: passed` или `QA: failed`.

## Result Summary — 2026-06-12

QA выполнена, вердикт `FAILED` зафиксирован в исходном файле
`docs/tasks/design_weapon_attack_vfx_animations_polish_task.md`. По результату
заведен bug-таск `bug_boss_phase_hazard_naked_circle_task.md`.
