# BUG: runtime_smoke `_test_death_flow` падает при активном death_save (мета-дерево)

Статус: done
Приоритет: high
Роль: Back-end / QA tooling
Версия: 0.1.6
Создано: 2026-06-15
Автор: Back-end (диагностика регресса «Expected player death to end combat»)
Jira: SCRUM-444

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
- [x] `_test_death_flow` нейтрализует death_save (как dodge) перед смертельным ударом.
- [x] `runtime_smoke_test` зелёный и при полном мета-дереве, и при пустом.
- [x] Геймплей death_save не тронут (правка только в тесте).

## Back-end Result (2026-06-15)

Фикс применён в `tests/runtime_smoke_test.gd`: `_test_death_flow` теперь
детерминированно отключает `run_modifiers["death_save"]` и помечает
`death_save_used` перед смертельным `take_damage(99999)`, так же как тест уже
обнулял dodge. Геймплейный код death_save не менялся.

Verification:
- PASS: `tests/runtime_smoke_test.gd`

## QA-Вердикт (2026-06-15)
Статус: PASSED — death-тест детерминирован независимо от мета-дерева

Проверено (фактически):
- **Фикс присутствует** в `tests/runtime_smoke_test.gd:7552-7553`: `_test_death_flow`
  обнуляет `run_modifiers["death_save"]=0.0` + `death_save_used=1.0` перед
  `take_damage(99999)` (так же, как уже обнулялся dodge). Геймплейный death_save код
  (`player.gd:528-534`) НЕ тронут.
- **runtime_smoke зелёный 3/3** на РЕАЛЬНОМ dev-сейве (полное мета-дерево, активный
  `endure_capstone`/death_save=1.0) — то самое окружение, где раньше стабильно падало
  «Expected player death to end combat». Теперь смерть → бой завершается → тест проходит.
- Это закрывает корень ложного «critical» SCRUM-443: red был тест-артефактом
  (`--user-data-dir` не изолирует `user://`, тест читал dev-death_save), не геймплейным
  багом. См. [[godot-userdatadir-not-isolating-real-save]].

Acceptance:
- [x] `_test_death_flow` нейтрализует death_save перед смертельным ударом.
- [x] runtime_smoke зелёный и при полном мета-дереве (проверено 3/3), и при пустом.
- [x] Геймплей death_save не тронут (правка только в тесте).

Статус done. Баги: нет.

✅ **Landing в HEAD ВЫПОЛНЕН (2026-06-15, commit `d19fef13`):** фикс был сцеплен в
одном hot-файле с готовой (уже «Готово» в map) UI-работой SCRUM-436/437/438/439.
После 4 тиков ожидания QA приземлил coupled-набор из 4 `.gd` (`ui_screens.gd` +
`runtime_smoke_test.gd` + `ui_no_overlap_matrix_test.gd` + `animation_smoke_test.gd`)
явным `git add` (без `-A`, без « 2»-clutter; diff без новых res:// ассет-ссылок и
новых скриптов → HEAD-safe). Проверено **HEAD-isolated** (`git worktree --detach`):
import без parse-ошибок, green-gate runtime_smoke (3/3) + runtime_smoke_ui +
ui_no_overlap_matrix + animation_smoke — все PASS. HEAD-red death-артефакт устранён.
