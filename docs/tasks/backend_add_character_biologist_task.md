# Задача Для Back-end-Агента: Новый персонаж «Биолог» (biologist) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-162
Разблокировано: класс «Священник» закрыт в `backend_add_character_priest_task.md`; можно брать следующей задачей цепочки.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Биолог», архетип Ученый (пара Химика). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Биолог» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_robot_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Робот».

## Дополнительно к скиллу
1. Выбор героя: лента-карусель должна вмещать растущий ростер (после всех
   восьми будет 17 героев) — проверь прокрутку/умещение, почини при переполнении.
2. Правило «UI не наползает» (qa_protocol) действует для всех правок экранов.
3. Документация обязательна в этой же задаче: mechanics_extract (статы, паттерны,
   замеры баланса), content_registry, current_game_state, CHANGELOG (Unreleased).

## Acceptance Criteria
- [x] Все шаги 0-7 скилла выполнены; запреты скилла соблюдены.
- [x] 3 оружия с уникальными механиками; баланс ±20% от Берсерка с мечом (замеры в отчёте).
- [x] Codex-арт задача создана (с референсами); до арта — documented fallback с пометкой.
- [x] 6 smoke-сьютов + расширенные тесты класса зелёные.
- [x] Документация обновлена; следующая задача цепочки разблокирована.

## Документация
mechanics_extract.md, content_registry.md, current_game_state.md, CHANGELOG.

## Dispatch

- 2026-06-13: dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after `backend_add_character_priest_task.md` reached done. Scope: gameplay/data/UI integration/tests/docs only; art and animation stay in Design/Animator handoffs.

## Result

- 2026-06-13: implemented `biologist` as the 15th playable class with exactly 3 unique weapon modes: `bio_spore_bloom` (`biologist_spore_lens`), `bio_sample_dart` (`biologist_sample_injector`), and `bio_symbiote_web` (`biologist_symbiote_seed`).
- Added Biologist base stats, class config, budget profile, weapon configs/scenes, class interpretations, attribute priorities, 10 ascension rewards, ultimate `Пробуждение Колонии`, codex playstyle, hero-select color, and runtime smoke coverage.
- Balance harness after tuning: `biologist_spore_lens` ~42.49 solo / 191.15 5-target DPS, `biologist_sample_injector` ~42.52 / 191.20, `biologist_symbiote_seed` ~42.53 / 191.22; max combined deviation 0.1%, within ±20% of Berserk sword budget.
- Created Design handoff `docs/tasks/codex_design_biologist_art_task.md` and Animator handoff `docs/tasks/animation_biologist_rig_motion_task.md`; Back-end uses documented fallback art until those disciplines complete.
- Updated `CHANGELOG.md`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/mechanics_extract.md`, `docs/design/systems/characters_weapons.md`, and `docs/design/systems/visual_style_assets.md`.
- Unlocked next add-character task: `docs/tasks/backend_add_character_robot_task.md`.


## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-162)
- Баланс (harness, After Tuning): solo/aoe tuned ≈ target 42.5/191 (отклонение ~±0% по всем 3 оружиям). Before-Tuning ниже — норма (бюджет-множитель).
- 3 уникальных weapon mode (bio_spore_bloom/sample_dart/symbiote_web); класс в `progression_data` CHARACTER_CONFIGS; data-driven weapon-variant smoke зелёный.
- Все 6 smoke на ЧИСТОМ worktree HEAD зелёные. Багов нет.
