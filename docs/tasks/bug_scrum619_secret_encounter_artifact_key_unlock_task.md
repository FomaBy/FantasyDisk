# BUG: SCRUM-619 Secret Encounter Key Artifact Does Not Unlock

Статус: new
Приоритет: high
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread: n/a
Jira: SCRUM-623
Найдено QA при тестировании: SCRUM-619

## Суть

Ветка разблокировки секретного боя через артефакт-ключ не работает с живыми
данными забега. `Meta.secret_encounter_unlocked()` проверяет
`artifacts.has("rift_key")`, но runtime хранит артефакты как словари
`{"id": ..., "title": ...}` и переносит этот массив словарей в
`run_metrics.artifacts`.

Дополнительно `rift_key` сейчас не найден как реальный контентный artifact/shop
item id: он есть только как `SECRET_ENCOUNTER_ARTIFACT_KEY` и в тесте
`tests/secret_encounter_test.gd`.

## Воспроизведение

1. Взять current `dev` с реализацией SCRUM-619.
2. Подготовить meta state с `ascension >= 3`.
3. Вызвать `secret_encounter_unlocked(state, {"damage_taken": max + 999, "artifacts": [{"id": "rift_key", "title": "Rift Key"}]}, "berserk")`.
4. Сравнить с контролем `artifacts: ["rift_key"]`.

## Ожидание / Реальность

Ожидание: если артефакт-ключ является acceptance-путём SCRUM-619, live-форма
артефакта с `id == "rift_key"` должна открывать секретный бой даже при большом
полученном уроне, а сам ключ должен существовать в контенте или требование
должно быть пересмотрено.

Реальность: dictionary-форма возвращает `false`, raw string возвращает `true`.
Live gameplay использует dictionary-форму, поэтому key-artifact ветка недостижима.

## QA Evidence

- `python3 tools/godot_gate.py --headless --path . --script res://tests/secret_encounter_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_points_per_ascension_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/class_progression_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` - PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd` - PASS.
- Focused temporary probe:
  - `dict_artifact_unlock=false`
  - `raw_string_unlock=true`

## Notes

QA worktree contained unrelated dirty SCRUM-593/SCRUM-586 UI tooltip WIP. QA did
not modify production files.
