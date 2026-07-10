# BUG: Robot delayed attack callbacks emit freed lambda-capture errors

Статус: new
Приоритет: high
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-1034
Спринт: 0.2.1
Найдено QA при тестировании: SCRUM-914, SCRUM-915, SCRUM-916, SCRUM-918
Locked paths: `scripts/class_weapon.gd`, `tests/robot_kit_test.gd`, `tests/runtime_smoke_weapon_mechanics_test.gd`, Robot lifecycle evidence

## Воспроизведение

1. Взять `origin/dev` не ранее `da98e69cf`; убедиться, что в истории есть
   `8377a24ce`, `4fc0472ac`, `ebbe8a216`.
2. Запустить:
   `python3 tools/godot_gate.py --headless --path . --script res://tests/robot_kit_test.gd`.
3. Увидеть exit `0` и `Robot kit test passed`, но одновременно:
   `ERROR: Lambda capture at index 3 was freed. Passed "null" instead.`
4. Ошибка также воспроизводится дважды в
   `tests/runtime_smoke_weapon_mechanics_test.gd` и полном
   `tests/runtime_smoke_test.gd`, шесть раз в `tools/live_combat_harness.gd` на
   Robot-секции.

## Ожидание / Реальность

Ожидание: delayed Robot attacks и VFX teardown завершаются без engine/SCRIPT
ERROR, утечек и обращения к освобождённым объектам; тесты не false-green.

Реальность: новые delayed callbacks Robot удерживают прямые Node-captures после
освобождения VFX; Godot подставляет `null`, пишет engine ERROR, а suite всё равно
возвращает `0`.

## Acceptance Criteria

- Убрать freed Node captures через instance IDs + `Callable.bind` либо
  эквивалентный lifecycle-safe node-owned teardown.
- Не менять принятые damage/pull/compression/elite-boss/rotation контракты.
- `robot_kit_test`, `runtime_smoke_weapon_mechanics_test`, полный
  `runtime_smoke_test` и `live_combat_harness` чисты от Lambda capture,
  `SCRIPT ERROR`, `ObjectDB instances were leaked` и `resources still in use`.
- Усилить focused lifecycle assertion так, чтобы этот дефект не оставался
  exit-0 false-green.
- Результат закоммичен, запушен в `origin/dev` и возвращён на независимый QA.
