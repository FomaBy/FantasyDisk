# BUG: Robot delayed attack callbacks emit freed lambda-capture errors

Статус: done
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

## Результат (SCRUM-1034)

Root cause: отложенные удары `_fire_robot_magnetic_anchor` и
`_fire_robot_compression_line` вызывали импакт из `tween_callback`-лямбды,
которая ПРЯМО захватывала Node-ссылки на VFX (telegraph/tether и left/right).
Эти VFX само-освобождаются раньше `grenade_delay`, поэтому Godot подставлял
`null` и печатал engine-ERROR «Lambda capture at index N was freed», а suite всё
равно возвращал exit 0 (false-green).

Фикс (канон SCRUM-551, как `_fire_prism_rift`/`_fire_reactor_vent_step`): твины
теперь зовут именованные методы `_resolve_robot_anchor` / `_resolve_robot_press`
через `Callable(self, ...).bind()` только по instance id (owner + id VFX);
VFX резолвятся `_release_effect_by_id`, владелец — `instance_from_id`. Оба
резолвера отсекаются на `_effects_shutdown` (отложенный удар не наносится после
`cleanup_effects`). Damage/pull/compression/rotation-числа и путь Реактора не
тронуты.

Усиление теста: `tests/robot_kit_test.gd::_test_delayed_callbacks_survive_vfx_teardown`
принудительно рвёт все `player_weapon_effects` VFX ДО удара, прогоняет твин и
проверяет, что отложенный урон всё равно ложится (teardown-safe), а после
`cleanup_effects` — shutdown-гард гасит удар (старая лямбда без гарда ударила бы).

Доказательство (fdengine, `tools/godot_gate.py`, `${pipestatus[1]}`+текст):
- `robot_kit_test`: exit 0, «Lambda capture» 0 (было 1), SCRIPT ERROR/leaks 0, `Robot kit test passed`.
- `runtime_smoke_weapon_mechanics_test`: exit 0, «Lambda capture» 0 (было 2), `passed`.
- `runtime_smoke_test`: exit 0, «Lambda capture» 0, `Runtime smoke test passed`.
- `weapon_integrity_test`: exit 0, `passed (17 classes, 51 weapons)`.
- `global_survivability_balance_smoke_test`: exit 0, `passed` (митигация<98%, бессмертие недостижимо).
- `live_combat_harness` (Robot-секция): «Lambda capture» 0 (было 6).

Коммит: `3d3446924` (scripts/class_weapon.gd, tests/robot_kit_test.gd).
Disk cleanup: none created (worktree убирает оркестратор).
