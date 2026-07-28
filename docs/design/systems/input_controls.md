# Input Controls

Обновлено: 2026-07-25

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
- API для потребителей пакета: `active_kind()` для UI-предпочтения,
  `physical_kind()` для последнего значимого physical input в gameplay,
  `gamepad_connected()`, `gamepad_name()`, `binding_text(action)` (читаемое имя
  биндинга активного устройства), `set_input_mode()`, `set_gamepad_bindings()`
  (формат — как `DEFAULT_GAMEPAD_BINDINGS`; кастомизируются только игровые
  actions из этого словаря, а `ui_accept/ui_cancel/ui_up/down/left/right`
  всегда остаются канон-раскладкой A/B/стик/крестовина; пустые/битые saved
  entries игнорируются и не стирают дефолт), `reset_gamepad_bindings_to_defaults()`
  — всё для SCRUM-816/SCRUM-846.
- Персистенс (в `user://settings.cfg` через `scripts/game_settings.gd`):
  `input_mode` (`auto`), `gamepad_bindings` (`{}`), `gamepad_deadzone` (`0.25`,
  кламп `0.05..0.5`), `gamepad_vibration` (`true`). Владелец UI сохранения —
  SCRUM-816; менеджер читает значения на старте.

## Настройки: устройство ввода и ребинд геймпада (SCRUM-816)

Вкладка «Управление» (`ui_screens._show_settings_menu`) разбита на секции
(`_add_controls_section_header`): «Устройство ввода», «Клавиатура», «Геймпад».

### Режим устройства
- `OptionButton` `SettingsInputModeOption`: «Авто (по последнему вводу)» /
  «Клавиатура и мышь» / «Геймпад» → `game.input_mode` (`auto`/`keyboard`/
  `gamepad`). Применяется сразу через `InputDeviceManager.set_input_mode()` и
  сохраняется (`game.save_game_settings`). Оба устройства работают в любом
  режиме — режим лишь определяет приоритет подсказок/глифов.
- Live-строка `SettingsGamepadStatus`: «Геймпад: <имя> подключён» / «Геймпад не
  обнаружен». Обновляется по `InputDeviceManager.device_changed` и
  `Input.joy_connection_changed` (hot-plug на открытом экране; коллбэки гардят
  валидность Label, ссылка обнуляется при выходе из настроек).

### Ребинд геймпада
- Для каждого экшена `game.INPUT_ACTIONS` — строка `GamepadBindRow_<action>` с
  кнопкой `GamepadBindButton_<action>`; текст берётся из фактического InputMap
  (`_gamepad_binding_text`, не хардкод), поэтому канон-раскладка показывается
  корректно уже при первом входе. Если существует манифест глифов
  (`scripts/ui/input_glyph_registry.gd`), рядом с текстом рисуется иконка
  (null-safe: нет ассета → только текст).
- Клик по кнопке → режим прослушивания (`_begin_gamepad_rebind`): следующий
  `InputEventJoypadButton` или значимое `InputEventJoypadMotion` (`|value| > 0.5`)
  назначается экшену; `B`/`Esc` отменяют (B в этот момент не назначается).
- Конфликт (кнопка/ось занята другим экшеном) → диалог `_show_gamepad_rebind_conflict`
  («Выбрать другую» / «Настройки»); биндинг не меняется.
- Назначение заменяет только joypad-часть экшена (клавиатурные события не
  трогаются) и применяется через `InputDeviceManager.set_gamepad_bindings()`,
  сохраняясь в `game.gamepad_bindings` (формат ядра SCRUM-811).
- Кнопка `SettingsResetGamepadButton` («Сбросить геймпад») →
  `InputDeviceManager.reset_gamepad_bindings_to_defaults()` (канон-раскладка).
- Слайдер `SettingsGamepadDeadzoneSlider` (`0.05..0.5`, шаг `0.05`, дефолт `0.25`)
  → `gamepad_deadzone`; CheckBox `SettingsGamepadVibrationToggle` →
  `gamepad_vibration`. Оба зеркалятся в root-мету (player.gd читает через
  `_runtime_setting`) и сохраняются в `settings.cfg`.

### Персистенс (баг-фикс)
`main.save_game_settings()` теперь пишет `input_mode`/`gamepad_bindings`/
`gamepad_deadzone`/`gamepad_vibration` (иначе `GameSettings.save_settings`
перезаписал бы их дефолтами при любом сохранении — прицеливание/громкость/
клавиатурный ребинд — и раскладка геймпада бы слетала). `_load_game_settings()`
читает и валидирует их, зеркаля deadzone/vibration в root-мету. Старый
`settings.cfg` без новых ключей грузится с дефолтами без ошибок.

SCRUM-846 усилил этот контракт: если старый или вручную повреждённый
`settings.cfg` содержит пустой saved binding (`buttons=[]`, `axes=[]`), неверные
типы или попытку переопределить `ui_accept`, менеджер отбрасывает такую запись и
оставляет канон. Это защищает A/confirm, B/cancel и левый стик от сценария
«фокус ходит, но выбрать/двигаться нельзя».

## Ручное прицеливание: курсор и правый стик (FAN-1449)

Вся геометрия наводки живёт в каноническом провайдере
`scripts/input/aim_controller.gd`. `player.gd` остаётся тонким адаптером:
публичный контракт оружия не менялся, поэтому все 51 оружие получают ручное
прицеливание без правок боевых механик.

### Контракт для оружия (без изменений)
- `attack_aim_mode() -> String` — `nearest` (авто) или `cursor` (ручной режим).
  Значение `cursor` историческое: под этим ключом режим лежит в `settings.cfg`
  и в root-мете `aim_mode`, ломать его нельзя.
- `attack_aim_position(range_limit) -> Vector2` — точка прицела в мире,
  обрезанная дальностью оружия.
- `attack_aim_direction(default_direction, range_limit) -> Vector2` — в ручном
  режиме направление на точку прицела, иначе переданное оружием направление
  (fallback: facing → `Vector2.RIGHT`; нулевого вектора не возвращает никогда).

Потребители: общий путь атаки `class_weapon._attack()`, а также собственные
пути `berserk_weapon._target_direction()` и `summoner_weapon._target_candidates()`.

### Режимы и персистенс
- Дефолт — авто-наводка (`nearest`), она же fallback при битом значении.
  Хранится в `user://settings.cfg` (`scripts/game_settings.gd`), зеркалится в
  root-мету `aim_mode` (`main.gd`) и читается провайдером каждый кадр.
- Формулировки в настройках device-neutral: «Автонаводка на ближайшего» /
  «Ручное: курсор / стик». Подсказка `SettingsAimModeHint` под строкой
  «Прицеливание» меняет текст по факту подключения пада и обновляется по тем же
  сигналам (`InputDeviceManager.device_changed`, `Input.joy_connection_changed`),
  что и live-строка `SettingsGamepadStatus`.

### Мышь
Точка прицела — мировая позиция курсора; если она дальше `attack_range`,
точка прижимается к границе дальности (поведение до FAN-1449 сохранено 1:1).
Виртуальный прицел для мыши не рисуется — у неё свой курсор.

### Правый стик
- Экшены `aim_left/aim_right/aim_up/aim_down` (`JOY_AXIS_RIGHT_X/Y`) доливаются
  идемпотентно `AimController.ensure_aim_actions()` — из
  `InputDeviceManager.ensure_joypad_bindings()` и из `player._ready()`, поэтому
  пакет работает и в изолированном прогоне. Как и `ui_*`, эти экшены **не**
  ребиндятся и не стираются сбросом раскладки геймпада.
- Радиальная мёртвая зона берётся из настройки `gamepad_deadzone` и
  нормализуется: сразу за порогом сила наводки около нуля, а не скачком.
- Наклон задаёт и угол, и дистанцию точки: от `RETICLE_MIN_DISTANCE` до
  дальности оружия (`RETICLE_MAX_DISTANCE`, если дальность не ограничена). Это
  нужно ловушкам/деплою, где важна именно точка, а не только направление.
- **Нейтраль удерживает последнюю наводку.** Отпущенный стик, дрожание внутри
  deadzone и любой неизвестный нулевой ввод не сбрасывают направление: прицел
  не дрожит между кадрами и не множит число атак.
- Точка прицела клампится дальностью оружия и видимой областью камеры, поэтому
  прицел не уезжает за кадр.

### Выбор устройства и hot-plug
- Устройство наводки следует за `InputDeviceManager.physical_kind()`: правый
  стик отдаёт наводку геймпаду, клавиша или клик мыши возвращают её курсору при
  любом `input_mode`. `active_kind()` по-прежнему остаётся UI-предпочтением для
  подсказок и глифов. Без менеджера (изолированные прогоны) решает сам факт
  наводки стиком.
- Отсутствие подключённого пада отменяет геймпадную наводку целиком.
  `Input.joy_connection_changed` при отключении последнего пада мгновенно гасит
  прицел и возвращает ввод мыши (`player._on_aim_joy_connection_changed`).
- Дебажные ПКМ / Shift+ЛКМ (`main._input` → `player.debug_set_move_target`)
  живут на кнопках мыши и с наводкой не конфликтуют: клик ставит точку движения
  и штатно возвращает наводку курсору, следующий наклон стика забирает её
  обратно, дебажная точка при этом не меняется.

### Виртуальный прицел
`scripts/ui/virtual_reticle.gd` — `Node2D` с `top_level = true`, ребёнок игрока
(`VirtualReticle`), поэтому стоит ровно в мировой точке прицела и не наследует
трансформ героя. Виден только в ручном режиме на геймпаде.

### Паритет авто и ручного режима
Ручная наводка меняет только направление и точку. Перезарядка, урон, радиусы,
дальность и капы у авто- и ручного режима совпадают; один тик атаки остаётся
одним кастом в обоих режимах.

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
- FAN-1096/FAN-1107: новый боевой `Player` принимает направление только после
  того, как все четыре общих `move_*` actions (включая физические `ui_*`
  клавиши/D-pad/стик, забинденные в них) одновременно вернулись внутрь movement
  deadzone. Нулевой результирующий вектор от противоположных удержанных actions
  (`Up+Down` или `Left+Right`) нейтралью не считается. Поэтому ввод из
  обязательного предбоевого выбора не протекает в начавшийся бой: герой остаётся
  на месте до полного отпускания, а следующий свежий ввод двигает его штатно.
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
- `tests/scrum926_priest_prayer_choice_test.gd` дополнительно держит FAN-1096
  regression: удержанный `Up` на экране молитвы не двигает героя после выбора,
  нейтраль перевооружает ввод, а свежий press/release снова двигает и
  останавливает персонажа.
- `tests/gamepad_core_input_test.gd` (SCRUM-811): autoload зарегистрирован;
  клавиатурные события выживают, joypad-события долиты во все 8 игровых и 6
  `ui_*` экшенов по канон-раскладке; `ensure_joypad_bindings()` идемпотентен;
  классификация устройства (кнопка/стик>0.3 → gamepad, дрожание 0.1 —
  игнор, клавиша → keyboard) + сигнал `device_changed`; режимы фиксируют
  `active_kind()` без блокировки физического ввода в InputMap; `binding_text`
  для обоих устройств; кастомные бинды замещают joypad-часть и сбрасываются к
  канону; SCRUM-846 проверяет fallback с пустых/битых saved bindings и запрет
  saved override для `ui_accept`; отключение пада возвращает keyboard;
  settings-ключи валидны.
- `tests/gamepad_menu_focus_test.gd` (SCRUM-813): фокус мета-меню + LB/RB вкладки/секции.
- `tests/gamepad_inrun_ui_test.gd` (SCRUM-812): фокус внутризабеговых экранов + карта маршрута.
- `tests/gamepad_full_flow_smoke_test.gd` (SCRUM-815): сквозной joypad-only сценарий
  «игра проходима с геймпада» a–h (меню→герой→бой→движение стиком→пауза→feedback
  Back/B/Start→level-up→смерть→настройки LB/RB→детект устройства). После
  SCRUM-824/SCRUM-825/SCRUM-846 Start→пауза, RB→level-up и Back→feedback являются
  строгими проверками, не soft-дефектами. Гейт приёмки любых UI/ввод-задач.
- `tests/gamepad_combat_actions_test.gd` (SCRUM-824/SCRUM-825/SCRUM-846): focused
  battle regression для synthetic `InputEventJoypadButton` Start/RB/Back и
  клавиатурной паритетности Escape/Space/P.
- `tests/aim_controller_contract_test.gd` (FAN-1449): контракт провайдера —
  нормализация режима, геометрия мыши, deadzone и удержание нейтрали,
  клампы дальности и кадра, hot-unplug, идемпотентность экшенов `aim_*`.
- `tests/aim_controller_weapon_matrix_test.gd` (FAN-1449): матрица 51/51 —
  каждое оружие проекта прогоняется в авто, ручной мыши и ручном стике;
  проверяются обращение к провайдеру, геометрия направления/точки, паритет
  перезарядки, урона, радиусов и капов и «один тик — один каст».
  `tests/aim_mode_settings_test.gd` (SCRUM-241) остаётся в силе как проверка
  персистенса `aim_mode`.
- `tests/aim_controller_runtime_test.gd` (FAN-1449): боевая проводка в Player —
  выбор устройства, виртуальный прицел, удержание наводки на нейтрали стика,
  hot-unplug и отсутствие конфликта с дебажными ПКМ / Shift+ЛКМ.

## Карта управления (клавиатура + геймпад)

Раскладка задаётся в `InputDeviceManager.INPUT_ACTIONS`/`UI_ACTIONS` (SCRUM-811);
клавиатурные дефолты — `main.INPUT_ACTIONS`. Все ui_*-экшены имеют joypad-события,
поэтому фокус-навигация меню/экранов работает с крестовиной/стиком «из коробки».

Игровые экшены (в бою):
| Экшен | Клавиатура | Геймпад |
|---|---|---|
| move_up/down/left/right | WASD / стрелки | крестовина + левый стик (deadzone 0.25) |
| aim_up/down/left/right (ручное прицеливание) | позиция курсора мыши | правый стик (deadzone из `gamepad_deadzone`; не ребиндится) |
| pause | Esc | Start `JOY_BUTTON_START` |
| ultimate | (клавиша по биндингу) | Y `JOY_BUTTON_Y` |
| open_level_up | (клавиша по биндингу) | RB `JOY_BUTTON_RIGHT_SHOULDER` |
| feedback | (клавиша по биндингу) | Select `JOY_BUTTON_BACK` |

UI-навигация (все экраны/попапы):
| Действие | Клавиатура | Геймпад |
|---|---|---|
| перемещение фокуса | стрелки | крестовина / левый стик (ui_up/down/left/right) |
| подтвердить (ui_accept) | Enter / Space | A `JOY_BUTTON_A` |
| отмена/назад (ui_cancel) | Esc | B `JOY_BUTTON_B` |
| листать вкладки настроек / секции кодекса | клик по вкладке | LB/RB `JOY_BUTTON_LEFT/RIGHT_SHOULDER` |
| слайдеры (громкость) | стрелки при фокусе | ui_left/right при фокусе (из коробки HSlider) |

Экранная карта фокуса — `docs/design/systems/menus_ui.md` (мета-меню SCRUM-813,
внутризабеговые SCRUM-812).

## Dev Console

- Runtime console (`scripts/dev_console.gd`, SCRUM-831/SCRUM-845) toggles on the physical key left of `1`: `KEY_QUOTELEFT` (`/~`/`Ё`) or `KEY_SECTION` (`§` on Mac ISO).
- While open, `main._input` returns early so console typing does not fire unrelated global hotkeys such as feedback, level-up, F12 or run pause.
- The console is not a pause source. It must not add `dev_console` to `pause_reasons` and must not set `SceneTree.paused`; active combat, enemies, timer and player movement continue under the overlay.

## Исправленные gamepad regression bugs (2026-07-02/2026-07-03)

- **SCRUM-824 / Start→пауза в бою**: `main._input` больше не гейтит `pause` только
  на `InputEventKey`; общий helper `_is_fresh_action_press()` принимает
  `InputEventJoypadButton` Start через `InputMap`, сохраняя keyboard guard
  `pressed && !echo` для Escape.
- **SCRUM-825 / RB→level-up в бою**: тот же action helper используется для
  `open_level_up`, поэтому RB (`JOY_BUTTON_RIGHT_SHOULDER`) открывает сохранённый
  pending level-up в бою. Клавиатурный Space-путь сохранён.
- **Ребинд геймпада** — реализовано в **SCRUM-816** (см. секцию «Настройки:
  устройство ввода и ребинд геймпада» ниже). Заодно устранён баг с
  `action_erase_events`: клавиатурный ребинд/сброс больше не стирают joypad-часть
  экшена (`_apply_keycodes_to_action`/`_handle_rebind_input` трогают только
  `InputEventKey`).
- **SCRUM-846 / глобальные gamepad actions**: `feedback` теперь открывается
  через общий action helper, поэтому Back/Select работает так же, как клавиша P;
  открытый feedback закрывается B (`ui_cancel`) или Start/Esc (`pause`). Helper
  также принимает `InputEventJoypadMotion` для axis-rebind игровых actions.
- **SCRUM-846 / битые saved bindings**: `InputDeviceManager` нормализует
  `gamepad_bindings`, игнорирует пустые/невалидные entries и не позволяет
  saved config переопределять `ui_*` actions. Если ранее кастомный игровой бинд
  стал пустым, stale joypad-события удаляются и возвращается дефолт.
