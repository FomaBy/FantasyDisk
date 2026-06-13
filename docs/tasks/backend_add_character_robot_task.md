# Задача Для Back-end-Агента: Новый персонаж «Робот» (robot) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-166
Разблокировано: класс «Биолог» закрыт в `backend_add_character_biologist_task.md`; можно брать следующей задачей цепочки.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Робот», архетип Танк (пара Рыцаря). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Робот» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_engineer_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Инженер».

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

## Dispatch

- 2026-06-13: dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after `backend_add_character_biologist_task.md` reached done. Scope: gameplay/data/UI integration/tests/docs only; art and animation stay in Design/Animator handoffs.

## Result

2026-06-13: Back-end scope завершен.

- Добавлен класс `robot` / «Робот» с tank-control профилем, базовыми статами, приоритетами атрибутов, class interpretations, ultimate `Аварийная Перегрузка` и 10 уровнями Возвышения.
- Добавлены ровно 3 weapon variants:
  - `robot_magnetic_anchor` / `robot_magnetic_anchor`: target-centered magnetic pull + impulse damage.
  - `robot_hydraulic_press` / `robot_compression_line`: line corridor compression с прижатием врагов к оси.
  - `robot_reactor_core` / `robot_reactor_vent`: 4 directional reactor vents вокруг корпуса.
- Созданы сцены `RobotMagneticAnchor.tscn`, `RobotHydraulicPress.tscn`, `RobotReactorCore.tscn`; после Design handoff подключены canonical Robot character/weapon PNG.
- Созданы и переданы handoff-задачи `codex_design_robot_art_task.md` и `animation_robot_rig_motion_task.md`.
- `runtime_smoke_test.gd` расширен проверками класса/оружий Robot и отдельным `_test_robot_weapon_mechanics`; parse blocker `backend_runtime_smoke_weapon_mechanics_indent_parse_task.md` закрыт.
- Исправлен доступ `CutoutRig2D` к sliced rig manifest через runtime script constants, чтобы animation smoke оставался чистым после импорта Robot cutout assets.
- Balance harness: `robot_magnetic_anchor`, `robot_hydraulic_press`, `robot_reactor_core` tuned profile `balanced/tank`, solo DPS ~40.1, 5-target AoE DPS ~138.6, deviation 0.0%.
- Документация обновлена: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `docs/design/mechanics_extract.md`, `docs/design/systems/characters_weapons.md`, `docs/design/systems/visual_style_assets.md`.
- Verification passed: runtime smoke, balance harness, animation smoke, attack VFX smoke, hazard VFX smoke, melee targeting, meta progression smoke.
- Следующая задача цепочки `backend_add_character_engineer_task.md` разблокирована.
