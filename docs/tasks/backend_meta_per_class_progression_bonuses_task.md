# FEATURE: Прогрессия по классам в дереве меты (бонусы за класс, реиграбельность)

Статус: in_progress
Приоритет: high
Роль: Back-end (прогрессия)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-360

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

**Осталось (интеграция — требует общих файлов):**
- main.gd (занят): передать `class_modifiers(meta_state, selected_character_id)`
  игроку рядом со `skill_modifiers` (main.gd:644-646).
- player.gd (свободен): обработать ключи `class_*` в `apply_meta_skill_modifiers`
  (склад в run_modifiers как 1.0+sum) — делать вместе с main.gd-передачей.
- ui_screens.gd `_show_skill_tree_screen`: раздел «Классы» (прогресс выбранного
  класса через `class_next_threshold`/`class_unlocked_tiers`), no-overlap.
Взять, как только main.gd/ui_screens.gd освободятся.

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
- [ ] В дереве меты есть прогрессия по классам с бонусами для конкретного класса; копится за игру классом, сохраняется.
- [ ] Бонусы применяются только выбранному классу; аккаунтные ветви целы.
- [ ] UI классовой прогрессии без overlap; meta + runtime smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/progression_balance.md, current_game_state.
