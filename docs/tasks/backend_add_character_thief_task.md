# Задача Для Back-end-Агента: Новый персонаж «Вор» (thief) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-169
Разблокировано: класс «Солдат» закрыт в `backend_add_character_soldier_task.md`; можно брать следующей задачей цепочки.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Вор», архетип Вор (пара Ассасина). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Вор» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_elementalist_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Элементалист».

## Дополнительно к скиллу
1. Выбор героя: лента-карусель должна вмещать растущий ростер (после всех
   восьми будет 17 героев) — проверь прокрутку/умещение, почини при переполнении.
2. Правило «UI не наползает» (qa_protocol) действует для всех правок экранов.
3. Документация обязательна в этой же задаче: mechanics_extract (статы, паттерны,
   замеры баланса), content_registry, current_game_state, CHANGELOG (Unreleased).

## Acceptance Criteria
- [x] Все Back-end шаги 0-7 скилла выполнены; запреты скилла соблюдены. Art/rig/motion оформлены отдельными handoff-задачами по role boundary.
- [x] 3 оружия с уникальными механиками; balance harness: `thief_coin_pouch` 51.87/162.08 DPS, `thief_shadow_cloak` 51.81/161.99 DPS, `thief_smoke_bomb` 51.84/162.00 DPS против Берсерка с мечом 47.96/149.84 DPS.
- [x] Codex-арт задача создана: `docs/tasks/codex_design_thief_art_task.md`; до арта используются documented fallback textures.
- [x] Runtime smoke и balance harness зелёные; расширенные тесты класса добавлены в `tests/runtime_smoke_test.gd`.
- [x] Документация обновлена; следующая задача цепочки `backend_add_character_elementalist_task.md` разблокирована.

## Документация
mechanics_extract.md, content_registry.md, current_game_state.md, CHANGELOG.

## Dispatch

- 2026-06-12: Codex Documentation dispatcher отправил задачу в Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`; Jira `SCRUM-169` переведена в работу. Напоминание: art -> Design handoff, rig/motion/attack poses -> Animator handoff.

## Result

2026-06-12 — Back-end scope done.

- Добавлен playable class `thief` в `ProgressionData`, `Player`, hero select, Codex и class priorities/interpreations/ascension.
- Добавлены 3 weapon variants: `thief_coin_pouch` (`coin_ricochet` + steal money), `thief_shadow_cloak` (`shadow_backstab`) и `thief_smoke_bomb` (`smoke_bomb` + temporary dodge).
- Добавлены сцены `ThiefCoinPouch.tscn`, `ThiefShadowCloak.tscn`, `ThiefSmokeBomb.tscn` на fallback textures до Design pass.
- Созданы handoff-задачи `docs/tasks/codex_design_thief_art_task.md` и `docs/tasks/animation_thief_rig_motion_task.md`.
- Проверки: runtime smoke passed; balance harness passed and wrote `build/balance_report.md`.
