# Задача Для Back-end-Агента: Новый персонаж «Элементалист» (elementalist) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-163
Разблокировано: класс «Вор» закрыт в `backend_add_character_thief_task.md`; можно брать следующей задачей цепочки.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Элементалист», архетип Маг (пара Тёмного мага). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Элементалист» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_sniper_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Снайпер».

## Дополнительно к скиллу
1. Выбор героя: лента-карусель должна вмещать растущий ростер (после всех
   восьми будет 17 героев) — проверь прокрутку/умещение, почини при переполнении.
2. Правило «UI не наползает» (qa_protocol) действует для всех правок экранов.
3. Документация обязательна в этой же задаче: mechanics_extract (статы, паттерны,
   замеры баланса), content_registry, current_game_state, CHANGELOG (Unreleased).

## Acceptance Criteria
- [x] Все шаги 0-7 скилла выполнены; запреты скилла соблюдены.
- [x] 3 оружия с уникальными механиками; баланс ±20% от Берсерка с мечом (замеры в отчёте).
- [x] Codex-арт задача создана (с референсами); до арта — documented fallback placeholder с пометкой.
- [x] 6 smoke-сьютов + расширенные тесты класса зелёные.
- [x] Документация обновлена; следующая задача цепочки разблокирована.

## Документация
mechanics_extract.md, content_registry.md, current_game_state.md, CHANGELOG.

## Dispatch

- 2026-06-12: Codex Documentation dispatcher отправил задачу в Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`; Jira `SCRUM-163` переведена в работу. Art -> Design handoff, rig/motion/attack poses -> Animator handoff.

## Result

- 2026-06-13: Back-end завершил `elementalist`: добавлен персонаж, 3 уникальных weapon modes (`elemental_orbit`, `prism_rift`, `meteor_shards`), выбор героя/оружия, кодекс, ultimate, ascension, attribute priorities и class interpretations.
- Баланс: `tools/balance_harness.gd` green; Elementalist weapons дают примерно 49.2 solo DPS и 178.2 5-target DPS против Berserk sword 48.0/149.8, то есть в пределах ±20% acceptance.
- Тесты: `runtime_smoke_test.gd` green, Elementalist coverage добавлен в class/weapon/equip/mechanics проверки; дополнительные smoke-сценарии прогнаны перед закрытием задачи.
- Handoff: создано `docs/tasks/codex_design_elementalist_art_task.md` для Design и `docs/tasks/animation_elementalist_rig_motion_task.md` для Animator.
