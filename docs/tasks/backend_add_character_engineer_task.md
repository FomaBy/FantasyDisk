# Задача Для Back-end-Агента: Новый персонаж «Инженер» (engineer) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-164
Разблокировано: класс «Робот» закрыт в `backend_add_character_robot_task.md`; можно брать финальную задачу цепочки.
Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Инженер», архетип Призыватель (пара Друида). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Инженер» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Это последний класс цепочки. После done — отметь в отчёте, что ростер Class Sheet реализован полностью (17 героев).

## Дополнительно к скиллу
1. Выбор героя: лента-карусель должна вмещать растущий ростер (после всех
   восьми будет 17 героев) — проверь прокрутку/умещение, почини при переполнении.
2. Правило «UI не наползает» (qa_protocol) действует для всех правок экранов.
3. Документация обязательна в этой же задаче: mechanics_extract (статы, паттерны,
   замеры баланса), content_registry, current_game_state, CHANGELOG (Unreleased).

## Acceptance Criteria
- [ ] Все шаги 0-7 скилла выполнены; запреты скилла соблюдены.
- [ ] 3 оружия с уникальными механиками; баланс ±20% от Берсерка с мечом (замеры в отчёте).
- [ ] Codex-арт задача создана (с референсами); до арта — hue-shift placeholder с пометкой.
- [ ] 6 smoke-сьютов + расширенные тесты класса зелёные.
- [ ] Документация обновлена; следующая задача цепочки разблокирована.

## Документация
mechanics_extract.md, content_registry.md, current_game_state.md, CHANGELOG.

## Result

2026-06-13: Back-end scope завершен.

- Добавлен финальный Class Sheet класс `engineer` / «Инженер»: базовые статы, class config, class interpretation, priorities, 10 ascension levels, ultimate config и codex playstyle.
- Добавлены ровно 3 уникальных weapon modes: `engineer_sentry_link` / Ключ Часового, `engineer_repair_drone` / Ремонтный Дрон, `engineer_pressure_mines` / Минная Сетка.
- Добавлены сцены оружия `EngineerSentryWrench.tscn`, `EngineerRepairDrone.tscn`, `EngineerPressureMines.tscn` с documented placeholder textures до Design art.
- Codex обновлен через `scripts/codex_data.gd` и data-driven `ProgressionData`: герой, оружие, стили игры и 51 weapon variant доступны системам.
- Runtime smoke расширен проверкой Engineer weapon mechanics, all playable classes, all weapon variants и unique class identity patterns.
- Balance harness обновлен для 51 пары class+weapon; Engineer tuned в пределах бюджета: solo/5-target deviation около 0.1%.
- Handoff-задачи созданы/синхронизированы: `codex_design_engineer_art_task.md` для Design и `animation_engineer_rig_motion_task.md` для Animator.
- Class Sheet roster полностью реализован в Back-end: 17 героев / 51 стартовое оружие.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/balance_harness.gd` — passed, `build/balance_report.md` regenerated.
