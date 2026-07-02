# Геймпад: ядро — InputDeviceManager, автодетект устройства, joypad-биндинги базовых экшенов

Статус: new
Контур: Claude
Owner: unassigned
Thread: n/a
Locked paths: `scripts/input_device_manager.gd` (новый), `project.godot` ([autoload]+[input]), `scripts/main.gd` (INPUT_ACTIONS/setup), `scripts/player.gd` (_ensure_default_input_actions), `scripts/game_settings.gd`, `tests/gamepad_core_input_test.gd`
Версия: 0.1.8
Приоритет: P1
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя: полная поддержка геймпада)
Jira: SCRUM-811
Labels: backend, claude, fantasydisk, foma, gamepad, p1

## Autonomy / Approval
Пользователь заранее одобрил изменения. Не останавливаться для подтверждений.
Jira first: claim через Jira-pull перед правками.

## Роль И Границы
Back-end (Claude lane). Только код/тесты/доки. Никакого арта. UI-экраны
(фокус-навигация, настройки) — ДРУГИЕ задачи этого же пакета, их scope не трогать.

## Контекст
Пользовательский запрос 2026-07-02: полная поддержка геймпада. Сейчас геймпад не
поддерживается вообще (0 упоминаний joypad/gamepad в проекте). Ввод построен так:
- `scripts/main.gd:304` — `INPUT_ACTIONS` (move_up/down/left/right, pause,
  ultimate, open_level_up, feedback), только `default_key`/`alternate_key` клавиатуры.
- `scripts/player.gd:1756` — `_ensure_default_input_actions()` — fallback-создание
  move_* экшенов, тоже только клавиатура.
- `scripts/game_settings.gd` — `user://settings.cfg`, уже хранит `input_bindings`
  (клавиатурные ребинды), система ребинда живёт в ui_screens.gd (не трогать здесь).
- В `project.godot` секции `[input]` нет; единственный autoload — AudioManager.
Эта задача — фундамент пакета: биндинги геймпада на все экшены + менеджер
автоопределения устройства. Остальные задачи пакета (меню, in-run UI, настройки)
опираются на неё.

## Требования
1. Новый autoload `InputDeviceManager` (`scripts/input_device_manager.gd`,
   зарегистрировать в `project.godot` [autoload] рядом с AudioManager):
   - `signal device_changed(kind: String)` — kind: `"keyboard"` | `"gamepad"`;
   - определяет активное устройство по ПОСЛЕДНЕМУ вводу: в `_input(event)`
     InputEventKey/InputEventMouseButton → keyboard; InputEventJoypadButton или
     InputEventJoypadMotion c `abs(value) > 0.3` → gamepad; сигнал только при смене;
   - `func active_kind() -> String`, `func gamepad_connected() -> bool`
     (через `Input.get_connected_joypads()`), `func gamepad_name() -> String`;
   - подписка на `Input.joy_connection_changed`: геймпад подключили — при
     первом же вводе с него активируется; отключили — немедленно
     `device_changed("keyboard")`;
   - режим из настроек `input_mode` (`"auto"|"keyboard"|"gamepad"`):
     auto — по последнему вводу (клавиатура и геймпад работают ОДНОВРЕМЕННО,
     режим влияет только на то, чьи подсказки/глифы показывать); keyboard/gamepad —
     `active_kind()` принудительно возвращает выбранное; физически ввод с обоих
     устройств НЕ блокируется ни в одном режиме (требование пользователя);
   - `func binding_text(action: String) -> String` — человекочитаемое имя
     текущего биндинга экшена для активного устройства («R», «Y», «Крестовина ↑»)
     — для подсказок в UI-задачах пакета.
2. Дефолтная раскладка геймпада (добавить в `INPUT_ACTIONS` main.gd поля
   `default_joy_button`/`default_joy_axis` и применять в той же точке, где
   применяются клавиатурные дефолты; player.gd `_ensure_default_input_actions`
   расширить аналогично, идемпотентно — не дублировать события):
   - move_up/down/left/right: левый стик `JOY_AXIS_LEFT_Y/X` (значения -1/+1,
     deadzone 0.25) И D-pad `JOY_BUTTON_DPAD_UP(11)/DOWN(12)/LEFT(13)/RIGHT(14)`;
   - pause: `JOY_BUTTON_START(6)`; ultimate: `JOY_BUTTON_Y(3)`;
   - open_level_up: `JOY_BUTTON_RIGHT_SHOULDER(10)`; feedback: `JOY_BUTTON_BACK(4)`.
3. Встроенные UI-экшены: гарантировать (добавить, если отсутствуют) joypad-события:
   `ui_accept` ← `JOY_BUTTON_A(0)`; `ui_cancel` ← `JOY_BUTTON_B(1)`;
   `ui_up/ui_down/ui_left/ui_right` ← D-pad + левый стик (axis 0/1, deadzone 0.5).
   Проверять через `InputMap.action_get_events()` — без дублей при повторном входе.
4. `game_settings.gd` DEFAULTS: `"input_mode": "auto"`, `"gamepad_bindings": {}`
   (+валидация: input_mode ∈ auto/keyboard/gamepad, gamepad_bindings — Dictionary).
   Применение сохранённых gamepad_bindings на старте (симметрично существующему
   механизму input_bindings; сам UI ребинда — отдельная задача пакета, не здесь).
5. Ничего не ломать: текущее клавиатурное управление и клавиатурные ребинды
   работают как раньше; изменение только аддитивное.

## Files / Assets / IDs
- Новый: `scripts/input_device_manager.gd`; правки: `project.godot`,
  `scripts/main.gd`, `scripts/player.gd`, `scripts/game_settings.gd`.
- Тест: `tests/gamepad_core_input_test.gd` (headless, по образцу
  `tests/runtime_smoke_ui_test.gd` — синтез InputEvent, проверка InputMap).

## Acceptance Criteria
- [ ] После старта у всех 8 экшенов есть joypad-события по раскладке из п.2,
      клавиатурные события сохранены; повторная инициализация не создаёт дубли.
- [ ] ui_accept/ui_cancel/ui_up/down/left/right имеют joypad-события (A/B/D-pad/стик).
- [ ] Синтетический `InputEventJoypadButton` переводит `active_kind()` в
      "gamepad" и эмитит `device_changed`; `InputEventKey` возвращает "keyboard".
- [ ] `input_mode`="keyboard"/"gamepad" фиксирует `active_kind()`, но синтетический
      ввод с обоих устройств продолжает проходить в экшены (Input.is_action_pressed).
- [ ] settings.cfg сохраняет/восстанавливает input_mode и gamepad_bindings.
- [ ] Тест `tests/gamepad_core_input_test.gd` зелёный headless; существующие
      smoke-тесты (runtime_smoke_ui_test, aim_mode_settings_test) не сломаны.

## Документация
`docs/design/current_game_state.md` — раздел «Управление»: геймпад поддержан,
раскладка по умолчанию; новый `docs/design/systems/input_controls.md` — карта
экшенов/устройств/режимов input_mode (создать, кратко).

## Самопроверка
Headless: `--import` прогрев, затем свой тест + runtime_smoke_ui_test +
aim_mode_settings_test через tools/godot_gate.py (один Godot-процесс, память о
параллельных инстансах). Отчёт: список экшенов с событиями до/после.
