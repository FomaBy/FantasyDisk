# Геймпад: аналоговое движение стиком, deadzone и вибрация

Статус: done
Контур: Codex
Owner: Back-end/Codex
Thread: codex-backend-scrum814-gamepad-movement
Исполнитель: Codex
Locked paths: `scripts/player.gd` (движение+вибрация), `tests/gamepad_player_movement_test.gd`, `docs/design/current_game_state.md`, `docs/design/systems/input_controls.md`
Версия: 0.2.0
Приоритет: P1
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя: полная поддержка геймпада)
Jira: SCRUM-814
Labels: backend, codex, fantasydisk, foma, gamepad, p1

## Autonomy / Approval
Пользователь заранее одобрил изменения. Не останавливаться для подтверждений.
Jira first: claim через Jira-pull перед правками. Результат влить в origin/dev
(НЕ оставлять на feature-ветке: QA проверяет `git merge-base --is-ancestor <commit>
origin/dev`).

## Роль И Границы
Back-end (Codex lane), файл-изолированная задача: только `scripts/player.gd` и
свой тест. НЕ трогать: `scripts/ui_screens.gd`, `scripts/main.gd`,
`scripts/game_settings.gd`, `project.godot` (ими занимаются параллельные задачи
пакета). Если нужных экшен-событий геймпада нет — добавить их ЛОКАЛЬНО в
`_ensure_default_input_actions()` player.gd идемпотентно (см. Требования п.1).

## Контекст
Пользовательский запрос 2026-07-02: полная поддержка геймпада. Движение игрока
сейчас дискретное: `scripts/player.gd:395-403` читает
`Input.is_action_pressed("move_left"/...)` по отдельности; экшены создаются в
`_ensure_default_input_actions()` (`player.gd:1756`) только с клавиатурными
событиями (WASD+стрелки). Параллельная core-задача пакета добавляет joypad-события
в main.gd/INPUT_ACTIONS; эта задача делает само движение аналоговым и добавляет
вибрацию. Атака в игре автоматическая, прицеливание — настройка aim_mode
(nearest/cursor), мышь для движения не используется.

## Требования
1. `_ensure_default_input_actions()` (player.gd:1756): расширить идемпотентно —
   если у move_* экшенов нет joypad-событий, добавить: левый стик
   (`InputEventJoypadMotion`, `JOY_AXIS_LEFT_X(0)`/`LEFT_Y(1)`, axis_value -1/+1
   соответственно стороне) и D-pad (`JOY_BUTTON_DPAD_UP(11)/DOWN(12)/LEFT(13)/RIGHT(14)`).
   Существующие клавиатурные события не трогать; повторный вызов не дублирует.
2. Движение перевести на `Input.get_vector("move_left","move_right","move_up",
   "move_down", deadzone)`: диагонали и промежуточные направления стика дают
   плавный вектор; длина вектора клампится (скорость персонажа не превышает
   текущую при клавиатуре); поведение WASD не меняется (полный вектор).
   Deadzone по умолчанию 0.25, читать из settings-словаря, который прокидывается
   в player (если параметра нет — константа-дефолт; ключ `gamepad_deadzone`).
3. Анимации/facing: `_facing_direction`, walk-анимации и flip работают от нового
   вектора так же, как раньше (см. `_update_movement_animation`, player.gd:1776).
4. Вибрация геймпада (`Input.start_joy_vibration(device, weak, strong, duration)`):
   - получение урона игроком: weak 0.6, 0.25s;
   - смерть игрока: strong 0.8, 0.5s;
   - активация ультимейта: weak 0.4, 0.15s;
   - уважать настройку `gamepad_vibration` (bool, default true) из settings-словаря
     (ключ может отсутствовать — тогда true); при отсутствии геймпада — no-op;
   - точки вызова искать по существующим обработчикам урона/смерти/ульты в player.gd.
5. Никаких регрессий клавиатурного управления и авто-атаки.

## Files / Assets / IDs
- `scripts/player.gd` (строки 395-403 движение; 1756+ экшены; обработчики
  урона/смерти/ульты для вибрации).
- Тест: `tests/gamepad_player_movement_test.gd` — headless: инстанс player,
  синтетический `InputEventJoypadMotion` (axis 0, value 0.7) →
  `Input.parse_input_event()` → velocity направлен вправо и |v| промасштабирован;
  deadzone: value 0.1 → нулевой вектор; D-pad кнопка → движение; вибрация —
  вызов не падает headless без геймпада.

## Acceptance Criteria
- [x] Стик двигает игрока во все стороны с плавными диагоналями; deadzone 0.25;
      наклон стика на 50% даёт пропорционально меньшую скорость, макс. скорость
      равна клавиатурной.
- [x] D-pad двигает игрока как WASD (полная скорость).
- [x] WASD/стрелки работают ровно как до задачи (smoke без регрессий).
- [x] Вибрация на урон/смерть/ульту, отключается настройкой gamepad_vibration,
      headless/без геймпада не падает.
- [x] Повторная инициализация экшенов не создаёт дублей событий.
- [x] Тест gamepad_player_movement_test.gd зелёный (2 прогона), существующие
      player/combat smoke зелёные.

## Документация
`docs/design/current_game_state.md` — строка про аналоговое движение и вибрацию;
`docs/design/systems/input_controls.md` (если уже создан core-задачей) — раздел
«Движение и вибрация», иначе отметить в current_game_state.

## Самопроверка
Headless свой тест + существующие player-тесты через tools/godot_gate.py; краткий
отчёт с velocity-значениями при разных axis_value в результате задачи.

## Результат
2026-07-02, Back-end/Codex worker `codex-backend-scrum814-gamepad-movement`.

- `scripts/player.gd`: движение переведено на `Input.get_vector(...)` с runtime
  deadzone setting/root meta `gamepad_deadzone` и fallback `0.25`; скорость
  аналогового стика масштабируется пропорционально, D-pad/keyboard остаются
  full-speed, facing/walk animation продолжают идти от velocity.
- `_ensure_default_input_actions()` теперь идемпотентно добавляет keyboard,
  left-stick `JOY_AXIS_LEFT_X/Y` и D-pad events к `move_*` без дублей.
- Добавлен no-op-safe helper вибрации с setting/root meta `gamepad_vibration`
  default `true`: damage weak `0.6/0.25с`, death strong `0.8/0.5с`, ultimate weak
  `0.4/0.15с`.
- Документация обновлена в `docs/design/current_game_state.md`; добавлен доменный
  runtime-контракт `docs/design/systems/input_controls.md`.

Проверки:
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-814-gamepad-movement --script res://tests/gamepad_player_movement_test.gd` (2 раза).
  Значения: axis `0.7` -> velocity `(187.8, 0.0)` при speed `313.00`; axis `0.1`
  -> `(0.0, 0.0)`; D-pad right -> `(313.0, 0.0)`.
- PASS `tests/player_configure_reset_test.gd`.
- PASS `tests/runtime_smoke_combat_test.gd`.
- PASS `tests/runtime_smoke_test.gd`.

Disk cleanup: `.godot/` import cache generated by the dedicated worktree will be
removed before the final Jira comment; no task-owned build artifacts are needed.

## QA-Вердикт: PASSED
Статус: PASSED
QA claude-qa 2026-07-02 (изолированный worktree от origin/dev, fdengine-семафор):
- Аналоговое движение: `Input.get_vector(...deadzone)`, `velocity = direction.limit_length(1.0) * speed_factor`. Runtime: axis `0.7` → velocity `(187.8, 0.0)` = 0.6× speed (deadzone-ремап 0.45/0.75, пропорционально); deadzone `0.25` → axis `0.1` даёт нулевой вектор; D-pad right → полная скорость `(313.0, 0.0)`.
- Идемпотентная привязка экшенов (joy-motion по оси+знаку, D-pad по индексу, клавиши по keycode) — повторный вызов не дублирует; клавиатура/авто-атака без регрессий.
- Вибрация: damage weak 0.6/0.25с, death strong 0.8/0.5с, ultimate weak 0.4/0.15с; уважает `gamepad_vibration` (default true); no-op headless/без геймпада (тесты не падают).
- Тесты: gamepad_player_movement_test ×2 PASS, player_configure_reset_test PASS, runtime_smoke_combat_test PASS, runtime_smoke_test PASS (14403 файла, dup-guard OK).
- Коммиты в origin/dev (merge-base ancestor OK): 947680c9 feat, 8166c983 docs.
