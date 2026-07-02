# Геймпад: настройки — выбор устройства ввода и ребинд кнопок геймпада

Статус: done
Контур: Claude
Owner: claude-backend (оркестратор)
Thread: n/a
Locked paths: `scripts/ui_screens.gd` (вкладка «Управление», rebind-механизм), `scripts/game_settings.gd` (валидация новых ключей при необходимости), `tests/gamepad_settings_rebind_test.gd`
Версия: 0.1.8
Приоритет: P2
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя: полная поддержка геймпада)
Jira: SCRUM-816
Labels: backend, claude, fantasydisk, foma, gamepad, p2

## Autonomy / Approval
Пользователь заранее одобрил изменения. Не останавливаться для подтверждений.
Jira first: claim через Jira-pull перед правками.

## Пререквизит (self-guard, ОБЯЗАТЕЛЬНО)
Задача опирается на core-задачу пакета SCRUM-811
(`qol_gamepad_core_input_device_manager_task.md`):
autoload `InputDeviceManager` + ключи `input_mode`/`gamepad_bindings` в
game_settings + joypad-дефолты экшенов. Перед стартом проверить на origin/dev
наличие `scripts/input_device_manager.gd`. Если его НЕТ — не брать задачу:
вернуть тикет в «К выполнению» с комментом «ждёт core (InputDeviceManager)» и
взять другую задачу.

## Анти-коллизия ui_screens.gd (ОБЯЗАТЕЛЬНО)
Перед стартом: если `scripts/ui_screens.gd` dirty ИЛИ другой gamepad-/UI-тикет
«В работе» держит `ui_screens.gd` — не брать, вернуть в «К выполнению» с комментом.

## Роль И Границы
Back-end (Claude lane). Только вкладка «Управление» настроек и rebind-механизм.
Фокус-навигация экранов — другие задачи пакета. Арт-глифы — design-задача
(`design_gamepad_input_glyphs_task.md`); здесь текстовые подписи с graceful
fallback, глифы подключить ТОЛЬКО если манифест уже существует.

## Контекст
Пользовательский запрос 2026-07-02: «настройки раскладки геймпада, какие кнопки
за что отвечают» + «в настройках возможность переключения [устройства], в идеале
работает и то, и то одновременно». Вкладка «Управление» уже существует:
`_show_settings_menu()` (~3829), ребинды клавиатуры генерируются циклом по
`game.INPUT_ACTIONS` (строки ~4090–4115) через `_begin_rebind(action)` →
`_handle_rebind_input(event)` → `_show_rebind_conflict()` (~7284), сохранение в
`game_settings.input_bindings`. Core-задача добавляет `input_mode` и
`gamepad_bindings` в game_settings и InputDeviceManager (активное устройство,
имя пада, сигнал device_changed).

## Требования
1. Вкладка «Управление», новая верхняя секция «Устройство ввода»:
   - OptionButton: «Авто (по последнему вводу)» / «Клавиатура и мышь» / «Геймпад»
     → `game_settings.input_mode` (auto/keyboard/gamepad), применяется сразу
     через InputDeviceManager;
   - пояснение под контролом: в любом режиме работают оба устройства, режим
     определяет подсказки/приоритет (текст согласовать с core-поведением);
   - live-строка статуса: «Геймпад: <имя> подключён» / «Геймпад не обнаружен»,
     обновляется по `InputDeviceManager.device_changed` и
     `Input.joy_connection_changed` (подключение/отключение на открытом экране).
2. Секция «Геймпад» (под секцией клавиатурных ребиндов, тот же ScrollContainer):
   - для каждого экшена из `game.INPUT_ACTIONS` строка: label экшена + кнопка с
     текущим биндингом геймпада (текст вида «Y», «RB», «Start», «Стик ←» — helper
     из InputDeviceManager.binding_text либо локальный);
   - клик/A по кнопке → режим прослушивания: следующий `InputEventJoypadButton`
     (или значимое `InputEventJoypadMotion` |value|>0.5 для осей) назначается
     экшену; Esc/B отменяет прослушивание (B в этот момент НЕ назначается);
   - конфликт (кнопка уже занята другим экшеном) → переиспользовать/расширить
     `_show_rebind_conflict()`;
   - назначение заменяет только joypad-события экшена (клавиатурные не трогает);
   - сохранение в `game_settings.gamepad_bindings`; формат core (SCRUM-811,
     реализован): {action: {"buttons": [int], "axes": [{"axis": int, "value": -1.0|1.0}]}}
     — применять через `InputDeviceManager.set_gamepad_bindings()`, восстановление
     на старте уже делает core;
   - БАГ-ФИКС (обнаружен в SCRUM-811, обязателен здесь): `_apply_keycodes_to_action`
     (ui_screens.gd:~7315) делает `action_erase_events` и стирает joypad-события
     экшена при клавиатурном ребинде/применении сохранённых биндов. Исправить:
     удалять/заменять только `InputEventKey`-события; после любого ребинда звать
     `InputDeviceManager.ensure_joypad_bindings()` (get_node_or_null("/root/InputDeviceManager"),
     null-safe для тестов без автолоада);
   - кнопка «Сбросить геймпад по умолчанию» — восстанавливает дефолтную раскладку
     пакета (стик+D-pad движение, Start пауза, Y ульта, RB level-up, Back фидбек);
   - слайдер «Мёртвая зона стика» (0.05–0.5, шаг 0.05, дефолт 0.25) →
     `gamepad_deadzone`; CheckBox «Вибрация» → `gamepad_vibration` (default true).
     Ключи УЖЕ добавлены в game_settings.gd (SCRUM-811) с валидацией — только UI.
3. Раскладка по умолчанию отображается корректно при первом входе (до любых
   ребиндов) — тексты берутся из фактического InputMap, не хардкод.
4. Если существует манифест глифов от design-задачи
   (`assets/sprites/ui/input_glyphs/` + registry) — показывать иконку кнопки
   рядом с текстом; если нет — только текст (никакой зависимости от арта).
5. Секция управляется с геймпада сама по себе (фокус-цепочки в связке с задачей
   меню-навигации; здесь гарантировать focus_mode/соседей для НОВЫХ контролов).
6. Совместимость: клавиатурные ребинды работают как раньше; settings.cfg
   старых версий (без новых ключей) грузится без ошибок.

## Files / Assets / IDs
- `scripts/ui_screens.gd`: `_show_settings_menu` (вкладка «Управление», ~4090+),
  `_begin_rebind`/`_handle_rebind_input`/`_show_rebind_conflict` (~7284),
  `_reset_input_bindings_to_defaults`, `_binding_text`.
- `scripts/game_settings.gd`: ключи `gamepad_deadzone`/`gamepad_vibration`
  (если не добавлены смежными задачами; аддитивно, с валидацией).
- Тест: `tests/gamepad_settings_rebind_test.gd` — headless: открыть настройки,
  начать ребинд, синтетическая JOY-кнопка назначается, конфликт ловится,
  сохранение/загрузка round-trip.

## Acceptance Criteria
- [ ] Переключатель устройства сохраняется и применяется; статус геймпада
      обновляется live при (от)подключении.
- [ ] Каждый экшен ребиндится на кнопку/ось геймпада; конфликты обрабатываются;
      клавиатурные бинды не затираются.
- [ ] Сброс к дефолту восстанавливает канон-раскладку пакета.
- [ ] Deadzone и вибрация сохраняются в settings.cfg и читаются игроком/ядром.
- [ ] Round-trip: перезапуск (повторная загрузка настроек в тесте) сохраняет
      все значения; старый settings.cfg без новых ключей не ломает игру.
- [ ] Тест зелёный (2 прогона); aim_mode_settings_test и runtime_smoke_ui_test зелёные.

## Документация
`docs/design/systems/input_controls.md` — секции «Режим устройства», «Ребинд
геймпада», дефолтная раскладка; `docs/design/systems/menus_ui.md` — обновлённая
вкладка «Управление»; `docs/design/current_game_state.md` — строка.

## Самопроверка
Headless свой тест + aim_mode_settings_test + runtime_smoke_ui_test через
tools/godot_gate.py; скрин/дамп дерева вкладки «Управление» в evidence.

## Реализация (claude-backend, 2026-07-02)
- `scripts/ui_screens.gd`: вкладка «Управление» разбита на секции
  «Устройство ввода» / «Клавиатура» / «Геймпад» (`_add_controls_section_header`).
  Устройство: `SettingsInputModeOption` (→ `input_mode` + `InputDeviceManager.set_input_mode`),
  пояснение, live-строка `SettingsGamepadStatus` (подписка на `device_changed` +
  `Input.joy_connection_changed`, guard по валидности Label). Геймпад: per-action
  `GamepadBindButton_*` (текст из InputMap, глиф из `input_glyph_registry` null-safe),
  режим прослушивания `_begin_gamepad_rebind`/`_handle_gamepad_rebind_input`
  (joypad-кнопка или ось `|value|>0.5`; B/Esc отмена, B не назначается), конфликт
  `_show_gamepad_rebind_conflict`, слайдер `gamepad_deadzone`, чекбокс
  `gamepad_vibration`, «Сбросить геймпад».
- БАГ-ФИКС: `_apply_keycodes_to_action` и `_handle_rebind_input` стирают только
  `InputEventKey` (joypad-часть ядра сохраняется); `_binding_text` показывает лишь
  клавиши. Долив joypad — у вызывающих (reset/rebind), НЕ в примитиве setup-цикла
  (иначе клавиатурные дефолты не-обработанных экшенов пропускались — пойман тестом).
- `scripts/main.gd`: поля `input_mode`/`gamepad_bindings`/`gamepad_deadzone`/
  `gamepad_vibration` + их load/валидация/сохранение в `save_game_settings`
  (иначе `GameSettings.save_settings` перезаписывал бы их дефолтами при любом
  сохранении) + зеркало deadzone/vibration в root-мету для `player.gd`.
- `scripts/game_settings.gd`: ключи уже были (SCRUM-811) — не менял.
- Тест `tests/gamepad_settings_rebind_test.gd`: виджеты вкладки, joypad-ребинд
  кнопки/оси, конфликт, сохранность клавиатуры при joypad-ребинде и joypad при
  клавиатурном, round-trip settings.cfg, legacy-совместимость. Бэкап/restore
  реального сейва; сброс к дефолтам в начале для детерминизма.
- Обновлён устаревший ассерт в `tests/runtime_smoke_test.gd` (клавиша ultimate
  ищется независимо от порядка событий, т.к. joypad теперь сохраняется).

## Результаты тестов (tools/godot_gate.py, headless, GODOT 4.7)
- `gamepad_settings_rebind_test` — PASS (3 прогона зелёные).
- `runtime_smoke_test` — PASS; `runtime_smoke_ui_test` — PASS;
  `aim_mode_settings_test` — PASS; `gamepad_core_input_test` — PASS.

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-02 (claude-qa)
Проверено на origin/dev @ 701f797e (ancestor origin/dev; мердж компилируется чисто).

- Вкладка «Управление»: OptionButton режима ввода + слайдер deadzone + чекбокс
  vibration (_test_controls_tab_widgets); режим применяется live.
- Ребинд кнопки/оси (_test_gamepad_button_rebind/_test_axis_rebind), конфликты
  (_test_gamepad_conflict), клавиатура↔joypad не затираются
  (_test_keyboard_rebind_preserves_joypad — фикс _erase_key_events).
- Сброс к канону; deadzone(0.35)/vibration персистятся и читаются
  (_test_persistence_round_trip); legacy settings.cfg → дефолты
  (_test_legacy_settings_compat). Тест бэкапит реальный сейв.
- Тесты: gamepad_settings_rebind_test PASS ×2, aim_mode_settings_test PASS,
  runtime_smoke_ui_test PASS (exit 0).
- Полный runtime_smoke_test падает на Escape (quit-диалог) — ПРЕДСУЩЕСТВУЮЩАЯ
  регрессия пакета (is_empty-гард _setup_default_input_actions vs joypad-предзасев
  InputDeviceManager из SCRUM-811; гард с v0.1.0), НЕ 816. Заведена SCRUM-830.
  Acceptance 816 требует runtime_smoke_ui_test (subset) — зелёный.
