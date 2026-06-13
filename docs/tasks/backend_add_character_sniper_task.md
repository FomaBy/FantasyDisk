# Задача Для Back-end-Агента: Новый персонаж «Снайпер» (sniper) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-167
Разблокировано: класс «Элементалист» закрыт в `backend_add_character_elementalist_task.md`; можно брать следующей задачей цепочки.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Снайпер», архетип Лучник (пара Рейнджера). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Снайпер» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_priest_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Священник».

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

- 2026-06-13: dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after `backend_add_character_elementalist_task.md` reached done. Back-end owns Sniper logic/balance/tests/docs only; art and animation must be handed off to Design/Animator.

## Result

- 2026-06-13: done. Добавлен playable class `sniper` с 3 unique weapon modes: `sniper_lockshot`, `sniper_kill_zone`, `sniper_split_round`.
- Balance harness: 39 class+weapon pairs green; Sniper tuned around solo 55.2 / AoE 120.0, within ±20% of Berserk sword role budget.
- Runtime smoke blocker `backend_runtime_smoke_class_weapon_type_inference_task.md` fixed by explicit GDScript types/casts in sniper weapon methods.
- Design handoff: `docs/tasks/codex_design_sniper_art_task.md`; Animator handoff: `docs/tasks/animation_sniper_rig_motion_task.md`.
- Docs updated: `CHANGELOG.md`, `docs/design/content_registry.md`, `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`, `docs/design/systems/characters_weapons.md`, `docs/design/systems/visual_style_assets.md`.
- Next class unlocked: `docs/tasks/backend_add_character_priest_task.md`.
