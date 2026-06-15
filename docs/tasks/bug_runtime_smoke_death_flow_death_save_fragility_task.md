# BUG: runtime_smoke `_test_death_flow` падает при активном death_save (мета-дерево)

Статус: new
Приоритет: high
Роль: Back-end / QA tooling
Версия: 0.1.6
Создано: 2026-06-15
Автор: Back-end (диагностика регресса «Expected player death to end combat»)

## Симптом
`tests/runtime_smoke_test.gd` детерминированно падает (2/2):
`ERROR: Expected player death to end combat.` (ассерт на строке ~7457,
`_test_death_flow`, `combat_active` остаётся `true` после смертельного урона).

## Root cause (диагностировано фактически)
Тест `_test_death_flow` (7441) бьёт игрока `take_damage(99999)` и ждёт конца боя.
Он нейтрализует **dodge** для детерминизма, но НЕ **death_save**. При активном
капстоне мета-дерева «Вторая жизнь» (`endure_capstone`, `effects.death_save=1.0`)
первый смертельный удар оставляет игрока на 1 HP (player.gd:528-534) → игрок
ЖИВ → бой не кончается → ассерт падает.

Диагностика (изолированный прогон berserk/sword): `death_save: 1.0`,
`health after: 1.0`, `combat_active after: true`. death_save приходит из
`meta_state.skill_nodes` (полное дерево в тест-окружении) →
`skill_modifiers()` → `apply_meta_skill_modifiers()` →
`run_modifiers["death_save"]=1.0`.

**Это НЕ геймплейный баг** — death_save работает по дизайну. Это **хрупкость теста**:
результат зависит от мета-сейва (пустое дерево → проходит; полное дерево/endure →
падает). Тест должен быть детерминированным независимо от мета-разблокировок.

## Фикс (подтверждён эмпирически)
В `_test_death_flow`, сразу после обнуления dodge (≈строки 7451-7453), добавить
нейтрализацию death_save перед `take_damage`:

```gdscript
	var run_mods: Dictionary = player.get("run_modifiers")
	run_mods["death_save"] = 0.0
	run_mods["death_save_used"] = 1.0
	player.set("run_modifiers", run_mods)
```

Подтверждено: после этого `take_damage(99999)` → игрок умирает (queue_free),
`combat_active after: false` → ассерт проходит.

## Почему не применил сам
`tests/runtime_smoke_test.gd` был занят другим воркером (M, правит др. участок —
не death_flow) на момент диагностики. Правка занятого hot-файла = риск коллизии.
Беру правку, как только файл освободится (== HEAD), либо применит владелец.

## Acceptance Criteria
- [ ] `_test_death_flow` нейтрализует death_save (как dodge) перед смертельным ударом.
- [ ] `runtime_smoke_test` зелёный и при полном мета-дереве, и при пустом.
- [ ] Геймплей death_save не тронут (правка только в тесте).
