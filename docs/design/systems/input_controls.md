# Input Controls

Обновлено: 2026-07-02

Этот документ фиксирует runtime-контракт управления игроком. Настройки и UI
описаны в `docs/design/systems/menus_ui.md`, а фактический snapshot игры — в
`docs/design/current_game_state.md`.

## Ядро: InputDeviceManager (SCRUM-811)

- Autoload `InputDeviceManager` (`scripts/input_device_manager.gd`, регистрация в
  `project.godot`) — единый владелец joypad-раскладки и активного устройства.
- **Гибридный ввод**: клавиатура/мышь и геймпад физически работают одновременно
  всегда. Настройка `input_mode` (`auto` | `keyboard` | `gamepad`) влияет только
  на `active_kind()` — чьи подсказки/глифы показывать. `auto` = по последнему
  значимому вводу (клавиша/клик → keyboard; кнопка пада или стик с наклоном
  `> 0.3` → gamepad; движение мыши намеренно игнорируется).
- **Hot-plug**: `Input.joy_connection_changed` — подключение пада доливает
  joypad-бинды; отключение последнего пада мгновенно возвращает `keyboard`.
  Сигнал `device_changed(kind)` — для live-подписок UI (статус в настройках,
  контекстные подсказки).
- **Канон-раскладка по умолчанию** (`DEFAULT_GAMEPAD_BINDINGS`):
  движение — левый стик + крестовина; `pause` — Start; `ultimate` — Y;
  `open_level_up` — RB; `feedback` — Back/Select. Встроенные UI-экшены:
  `ui_accept` — A, `ui_cancel` — B, `ui_up/down/left/right` — крестовина +
  левый стик (`UI_ACTION_BINDINGS`).
- **Порядок инициализации**: `ui._setup_default_input_actions()` (main.gd:500)
  стирает события экшена при применении сохранённых клавиатурных ребиндов,
  поэтому менеджер доливает joypad-события идемпотентно после первого
  `process_frame` и повторно страхуется (`ensure_joypad_bindings()`) при
  подключении пада и при переходе raw-устройства на gamepad.
- API для потребителей пакета: `active_kind()`, `gamepad_connected()`,
  `gamepad_name()`, `binding_text(action)` (читаемое имя биндинга активного
  устройства), `set_input_mode()`, `set_gamepad_bindings()` (формат — как
  `DEFAULT_GAMEPAD_BINDINGS`; joypad-часть экшена замещается, клавиатурная не
  трогается), `reset_gamepad_bindings_to_defaults()` — всё для SCRUM-816.
- Персистенс (в `user://settings.cfg` через `scripts/game_settings.gd`):
  `input_mode` (`auto`), `gamepad_bindings` (`{}`), `gamepad_deadzone` (`0.25`,
  кламп `0.05..0.5`), `gamepad_vibration` (`true`). Владелец UI сохранения —
  SCRUM-816; менеджер читает значения на старте.

## Движение Игрока

- Боевое движение живет в `scripts/player.gd`.
- `move_up`, `move_down`, `move_left`, `move_right` читаются через
  `Input.get_vector("move_left", "move_right", "move_up", "move_down", deadzone)`.
- Клавиатура (WASD + стрелки) и D-pad дают полный вектор движения.
- Левый стик геймпада использует `JOY_AXIS_LEFT_X` / `JOY_AXIS_LEFT_Y` и дает
  пропорциональную скорость: частичный наклон двигает медленнее, диагональ не
  превышает текущую максимальную скорость персонажа.
- Deadzone по умолчанию `0.25`; runtime может переопределить его через setting
  key/root meta `gamepad_deadzone`.
- `_ensure_default_input_actions()` идемпотентно добавляет keyboard, left-stick
  и D-pad events к `move_*` actions без удаления существующих биндингов и без
  дублей при повторном init.
- Facing, walk/idle animation choice and sprite flip continue to derive from
  the resulting movement velocity.

## Вибрация Геймпада

- Вибрация включена по умолчанию; runtime может отключить ее через setting
  key/root meta `gamepad_vibration = false`.
- Без подключенного геймпада и в headless-среде helper ничего не делает.
- Получение урона игроком: weak magnitude `0.6`, duration `0.25с`.
- Смерть игрока: strong magnitude `0.8`, duration `0.5с`.
- Активация ultimate: weak magnitude `0.4`, duration `0.15с`.

## Regression Coverage

- `tests/gamepad_player_movement_test.gd` проверяет synthetic left-stick axis
  `0.7`, deadzone axis `0.1`, D-pad movement, no-op vibration helper and
  отсутствие дублей input events после repeated init.
- `tests/gamepad_core_input_test.gd` (SCRUM-811): autoload зарегистрирован;
  клавиатурные события выживают, joypad-события долиты во все 8 игровых и 6
  `ui_*` экшенов по канон-раскладке; `ensure_joypad_bindings()` идемпотентен;
  классификация устройства (кнопка/стик>0.3 → gamepad, дрожание 0.1 —
  игнор, клавиша → keyboard) + сигнал `device_changed`; режимы фиксируют
  `active_kind()` без блокировки физического ввода в InputMap; `binding_text`
  для обоих устройств; кастомные бинды замещают joypad-часть и сбрасываются к
  канону; отключение пада возвращает keyboard; settings-ключи валидны.
