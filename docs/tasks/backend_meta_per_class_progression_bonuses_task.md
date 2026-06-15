# FEATURE: Прогрессия по классам в дереве меты (бонусы за класс, реиграбельность)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high

## Завершено (2026-06-14) — фича полная
- **Ядро** (meta_progression.gd, в HEAD): CLASS_PROGRESSION (накопит. пороги),
  class_boss_wins per character (record_boss_victory), class_modifiers (бонусы
  только своему классу), save/load; гейт tests/class_progression_test.gd.
- **Применение** (main.gd + player.gd, коммит a69ddcc0): main мерджит
  class_modifiers(meta_state, selected_character_id) в skill_mods; player.gd
  META_SKILL_MULT_MAP += class_* → множатся с аккаунтными бонусами.
- **UI** (ui_screens.gd `_show_skill_tree_screen`): компактный раздел «Классы» —
  выбранный класс, побед над боссами, открытые бонусы, следующий порог
  (`class_next_threshold`) и список активных бонусов (`class_unlocked_tiers`).
- Зелёные: runtime smoke, UI smoke, class_progression, meta skill tree smoke.
Роль: Back-end (прогрессия)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-360
QA: ready (2026-06-14)

## Прогресс (2026-06-14, Claude Fable 5)
**Сделано — ядро (изолированно, scripts/meta_progression.gd, не трогая занятые):**
- `CLASS_PROGRESSION` — накопительные пороги по классам (общие, data-driven; бонусы
  class_damage_mult/class_max_health_mult/class_attack_speed_mult — ключи `class_*`
  отдельны от аккаунтных skill_modifiers).
- `class_boss_wins` в state (default/load/save, версия-совместимо через ConfigFile).
- `record_boss_victory` копит победы класса (per character) — увязано с уже
  существующим per-character трекингом.
- API: `class_boss_wins`/`class_level`/`class_unlocked_tiers`/`class_modifiers`
  (бонусы ТОЛЬКО своему классу)/`class_next_threshold` (для UI).
- Гейт `tests/class_progression_test.gd`: накопление, изоляция бонусов по классу,
  частичные пороги, save/load — PASS. meta + runtime smoke зелёные.

**Финальная интеграция (2026-06-14, Codex Back-end):**
- Проверено, что main.gd передает `class_modifiers(meta_state, selected_character_id)`
  игроку рядом со `skill_modifiers`.
- Проверено, что player.gd обрабатывает `class_*` в `apply_meta_skill_modifiers`
  и сворачивает их в run_modifiers как `1.0 + sum`.
- UI раздел «Классы» усилен до отдельной compact panel с русским именем героя,
  прогрессом, списком открытых бонусов и следующим порогом.
- `tests/meta_skill_tree_smoke_test.gd` расширен проверкой run-start применения
  и отсутствия протекания бонусов Берсерка на Солдата.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Хочу улучшить реиграбельность за классы — добавить в дерево мета-прогрессии
прогрессию ПО КЛАССАМ, дающую какие-то бонусы для класса».

Сейчас мета-дерево `META_NODES` (scripts/meta_progression.gd) — аккаунтное
(ветви wealth/lore/...), бонусы общие, не зависят от класса. Возвышение
трекается per-character. Экран дерева: ui_screens.gd `_show_skill_tree_screen`.

## Требования
1. Добавить **прогрессию по классам**: per-class узлы/ветка, дающие бонусы
   КОНКРЕТНОМУ классу (стимул отыгрывать каждый класс). Варианты бонусов
   (data-driven, на усмотрение, согласовать с балансом): +урон/+HP/+скорость
   конкретного класса, усиление его уникальной механики/оружия, мелкий уникальный
   перк класса. Прогресс копится за игру этим классом (напр. за победы/боссов на
   классе — увязать с record_boss_victory/ascension per character).
2. Data-driven: классовые узлы и эффекты в данных (META_NODES или новый
   CLASS_PROGRESSION), применяются в run-модификаторах только для выбранного
   класса (selected_character_id). Не ломать аккаунтные ветви.
3. UI в дереве меты (_show_skill_tree_screen): раздел/вкладка «Классы» или
   per-class под-дерево; показывает прогресс/разблокировки выбранного класса;
   соблюдать глобальное правило фреймов и no-overlap.
4. Сохранение в user:// (как meta_progression ConfigFile), версионирование.
5. Тест: классовые бонусы применяются только своему классу; прогресс копится и
   сохраняется; runtime_smoke + meta_progression smoke зелёные.
6. CHANGELOG; current_game_state; systems/progression_balance.

## Files / Assets / IDs
- scripts/meta_progression.gd (META_NODES, load/save, record_boss_victory,
  per-character levels)
- scripts/progression_data*.gd (применение run-модификаторов по классу)
- scripts/ui_screens.gd (_show_skill_tree_screen)
- tests/meta_progression_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] В дереве меты есть прогрессия по классам с бонусами для конкретного класса; копится за игру классом, сохраняется.
- [x] Бонусы применяются только выбранному классу; аккаунтные ветви целы.
- [x] UI классовой прогрессии без overlap; meta + runtime smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/progression_balance.md, current_game_state.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Ядро** (meta_progression.gd): `CLASS_PROGRESSION` (накопит. пороги, стр.73),
  `class_boss_wins` в state (default/load/save 88/112/127, ConfigFile версия-совмест.),
  `record_boss_victory` (138) копит победы per-character, API `class_modifiers`/
  `class_next_threshold`/`class_boss_wins`.
- **Применение** (run-модификаторы только своему классу): `main.gd:647` мерджит
  `class_modifiers(meta_state, selected_character_id)` в skill_mods; `player.gd:621`
  `META_SKILL_MULT_MAP` содержит `class_damage_mult→damage_multiplier` (+ class_*),
  применяется в цикле (634). Ключи `class_*` отдельны от аккаунтных.
- **Гейт** `class_progression_test` — passed: «накопление per-class, изоляция бонусов,
  save/load, 5 порогов» (бонусы НЕ протекают на другие классы).
- **UI** (`build/qa/cap_skill_tree_360.png`): раздел «Классы» вверху — «Берсерк»:
  11 побед над боссами, открыто бонусов 5/5 + детали (урон+9%/HP+3%/скор.атаки+4%/
  мастерство+5%/+2%HP); аккаунтные ветви (Богатства/Знаний/Мощи/Стойкости) ниже, БЕЗ
  наложения, текст читаем.
- **Тесты**: `meta_progression_smoke`, `runtime_smoke_test`, `ui_no_overlap_matrix_test`
  — passed.

Acceptance:
- [x] Прогрессия по классам с бонусами конкретному классу; копится за победы класса; сохраняется.
- [x] Бонусы только выбранному классу (изоляция в гейте); аккаунтные ветви целы.
- [x] UI классовой прогрессии без overlap; meta + runtime smoke зелёные; доки.

Баги: нет.

## Result Summary — 2026-06-14 (Codex Back-end Close-Out)

SCRUM-360 is complete and ready for QA. Final pass aligned the task file with the already implemented core, upgraded the skill tree class-progress UI, added run-start class-modifier coverage, and updated `CHANGELOG.md`, `docs/design/current_game_state.md` and `docs/design/systems/progression_balance.md`.

Verification:
- `git diff --check` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/class_progression_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/meta_skill_tree_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
