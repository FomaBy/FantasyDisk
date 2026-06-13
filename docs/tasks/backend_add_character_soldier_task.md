# Задача Для Back-end-Агента: Новый персонаж «Солдат» (soldier) — конвейер add-character

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя: 8 классов Class Sheet)
Jira: SCRUM-168

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-12. Back-end owns gameplay/balance/integration; art must go through Design handoff, and rig/motion/attack poses must go through Animator handoff.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Ты — Back-end-агент (владелец конвейера класса). Арт — строго через Codex Design
задачу (шаг 3 конвейера), анимация — шаг 4 (handoff Animator при необходимости).

## Контекст
Пользователь добавляет все 8 оставшихся классов Class Sheet. Этот класс —
«Солдат», архетип Воин (пара Берсерка). ПОЛНЫЙ регламент выполнения — скилл-файл
`.claude/skills/add-character/SKILL.md`: выполни его шаги 0-7 буквально для
класса «Солдат» (валидация по Class Sheet, статы/конфиги/интерпретации, РОВНО
3 оружия с механиками, не повторяющими НИ ОДНО существующее оружие любого
класса, codex-арт задача с референсами, cutout-риг с персональным
motion-профилем, интеграция, тесты, документация).

## ВАЖНО: последовательная цепочка (общие файлы)
Все 8 классовых задач правят progression_data.gd/ui_screens.gd — параллельное
выполнение ЗАПРЕЩЕНО. Порядок: Солдат → Вор → Элементалист → Снайпер →
Священник → Биолог → Робот → Инженер.
Завершив этот класс (done), РАЗБЛОКИРУЙ следующий: в docs/tasks/backend_add_character_thief_task.md замени Статус: blocked на Статус: new (и строку на доске), чтобы воркер взял «Вор».

## Дополнительно к скиллу
1. Выбор героя: лента-карусель должна вмещать растущий ростер (после всех
   восьми будет 17 героев) — проверь прокрутку/умещение, почини при переполнении.
2. Правило «UI не наползает» (qa_protocol) действует для всех правок экранов.
3. Документация обязательна в этой же задаче: mechanics_extract (статы, паттерны,
   замеры баланса), content_registry, current_game_state, CHANGELOG (Unreleased).

## Acceptance Criteria
- [x] Все шаги 0-7 скилла выполнены в Back-end scope; Design/Animator scope передан handoff-задачами.
- [x] 3 оружия с уникальными механиками; баланс ±20% от Берсерка с мечом подтвержден `build/balance_report.md` (после tuning: `soldier_rifle` 47.99/150.03 DPS, `soldier_grenade` 48.02/149.94 DPS, `soldier_bayonet` 48.01/149.92 DPS).
- [x] Codex-арт задача создана: `docs/tasks/codex_design_soldier_art_task.md`; canonical Soldier PNG подключены, rig/motion остается Animator handoff.
- [x] 6 smoke-сьютов + расширенные тесты класса зелёные.
- [x] Документация обновлена; следующая задача цепочки `backend_add_character_thief_task.md` разблокирована.

## Документация
mechanics_extract.md, content_registry.md, current_game_state.md, CHANGELOG.

## Result Summary — 2026-06-12

- Добавлен playable class `soldier` с конфигами `BASE_STATS`, `CHARACTER_CONFIGS`, `CLASS_DAMAGE_PARAMETER`, `CLASS_INTERPRETATIONS`, `ATTRIBUTE_PRIORITIES`, `ULTIMATE_CONFIGS`, `ASCENSION_LEVELS`.
- Добавлены 3 weapon configs/scenes: `soldier_rifle` (`suppression_burst`), `soldier_grenade` (`grenade_cook`), `soldier_bayonet` (`bayonet_brace`).
- `scripts/class_weapon.gd` получил 3 новых data-driven backend modes с cleanup-safe tween callbacks; `scripts/player.gd` масштабирует `suppression_width` через AoE scaling.
- Hero select thumbnail strip стал адаптивным под растущий roster без возврата к старому scroll UI.
- Подключены canonical Soldier PNG: `assets/sprites/characters/soldier.png`, `assets/sprites/weapons/soldier_rifle.png`, `assets/sprites/weapons/soldier_grenade.png`, `assets/sprites/weapons/soldier_bayonet.png`.
- Кодекс, runtime smoke, balance harness и docs обновлены под 10 классов / 30 weapon variants.
- Handoff отправлен в Design thread для финальных Soldier PNG и в Animator thread для rig/motion после готовности арта.
- Проверки passed: runtime, animation, meta_progression, melee_targeting, attack_vfx, hazard_vfx, balance_harness.


## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-168)
- Баланс (harness, After Tuning): solo/aoe tuned ≈ target 48.0/150 (отклонение ~±0% по всем 3 оружиям). Before-Tuning ниже — норма (бюджет-множитель).
- 3 уникальных weapon mode (suppression_burst/grenade_cook/bayonet_brace); класс в `progression_data` CHARACTER_CONFIGS; data-driven weapon-variant smoke зелёный.
- Все 6 smoke на ЧИСТОМ worktree HEAD зелёные. Багов нет.
