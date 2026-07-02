# Геймпад: настройки — выбор устройства ввода и ребинд кнопок геймпада

Статус: new
Контур: Claude
Owner: unassigned
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
   - сохранение в `game_settings.gamepad_bindings` (формат совместим с core-задачей:
     {action: {"type": "button"|"axis", "index": int, "sign": -1|1}} или принятый
     в core — свериться с реализацией), восстановление на старте уже делает core;
   - кнопка «Сбросить геймпад по умолчанию» — восстанавливает дефолтную раскладку
     пакета (стик+D-pad движение, Start пауза, Y ульта, RB level-up, Back фидбек);
   - слайдер «Мёртвая зона стика» (0.05–0.5, шаг 0.05, дефолт 0.25) →
     `gamepad_deadzone`; CheckBox «Вибрация» → `gamepad_vibration` (default true).
     Если этих ключей нет в DEFAULTS game_settings — добавить с валидацией.
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
