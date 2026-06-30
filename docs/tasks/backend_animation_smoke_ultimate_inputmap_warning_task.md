# Задача Для Back-end-Агента: Убрать InputMap Warning В Animation Smoke

Статус: done
Создано: 2026-06-12
Автор: Design handoff
Роль: Back-end
Приоритет: medium
Dispatch note: 2026-06-12 routed by dispatcher to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Подтверждение не требуется.

## Контекст

Во время Design-задачи `design_weapon_art_v2_proportions_knight_task.md` был запущен:

```text
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Тест завершился с exit code `0` и вывел `Animation smoke test passed.`, но Godot также залогировал ошибку:

```text
ERROR: The InputMap action "ultimate" doesn't exist.
   at: is_action_just_pressed (core/input/input.cpp:393)
   GDScript backtrace:
       [0] _physics_process (res://scripts/player.gd:280)
```

Это не связано с заменой оружейного арта, но мешает считать animation smoke полностью чистым.

## Что Уже Сделано

- Design заменил Knight art/weapon art и прогнал runtime smoke + animation smoke.
- Runtime smoke green.
- Animation smoke функционально проходит, но пишет InputMap warning/error.

## Что Нужно От Back-end

- Проверить, почему `animation_smoke_test.gd` запускает `Player._physics_process()` до регистрации action `ultimate`.
- Исправить тестовую инициализацию или общий input setup так, чтобы `Input.is_action_just_pressed("ultimate")` не логировал ошибку.
- Не менять gameplay/balance.

## Files / Assets / IDs

- `tests/animation_smoke_test.gd`
- `scripts/player.gd`
- `scripts/game_settings.gd` / input setup, если relevant
- `project.godot` input actions, если relevant

## Acceptance Criteria

- [x] `tests/animation_smoke_test.gd` проходит без `InputMap action "ultimate" doesn't exist`.
- [x] `tests/runtime_smoke_test.gd` остается зеленым.
- [x] Документация/CHANGELOG обновлены только если меняется системное поведение.

## Result Summary

Закрыто 2026-06-12.

- `Player._physics_process()` теперь проверяет `InputMap.has_action("ultimate")` перед `Input.is_action_just_pressed("ultimate")`, чтобы standalone/headless тесты, создающие Player без Main/UI setup, не логировали предупреждение.
- Gameplay не менялся: в обычном запуске `ultimate` по-прежнему регистрируется через стандартный input setup.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — passed, warning absent.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт
Статус: PASSED
Легаси-задача, работа выполнена и в игре (подтверждено архивным ревью QA-кладбища 2026-06-28). Повторный дрейф в QA = board-sync revert из-за отсутствия PASSED-блока. Релевантные smoke (animation_smoke_test / runtime_smoke_test) зелёные на origin/dev 2026-06-30. Блок дописан, чтобы остановить дрейф.
