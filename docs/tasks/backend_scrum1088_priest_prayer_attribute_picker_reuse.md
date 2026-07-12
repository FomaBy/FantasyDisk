# Priest: Переиспользовать Выбор Атрибутов Для Стартовой Молитвы

Статус: done
Контур: Codex
Owner: Back-end /root
Thread: /root
Locked paths: `scripts/ui_screens.gd`, обнаруженные вызовы стартового выбора в `scripts/main.gd`/смежных runtime-файлах, focused Priest prayer-choice tests, `docs/design/mockups/scrum1088_priest_prayer_attribute_picker/`, `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`
Jira: SCRUM-1088

## Контекст

По прямому запросу пользователя стартовый выбор улучшения/молитвы Священника
должен использовать тот же экран и паттерн взаимодействия, что и выбор
атрибутов при повышении уровня. Отдельный интерфейс для молитв больше не нужен.

## Решение

- Переиспользовать существующий level-up attribute picker shell/card layout и
  его responsive/input-контракт.
- Сохранить канонические молитвы, порядок, эффекты, обязательную паузу перед
  стартом боя и exactly-once применение.
- Не добавлять новую визуальную семью, рамки или кнопки.
- Обновить PixelLab mockup/spec как спецификацию переиспользования существующего
  экрана до runtime-правок.

## Acceptance Criteria

- Священник в начале боя получает три молитвы через тот же UI shell/card layout,
  который используется для выбора атрибутов при level-up.
- Отдельный prayer-specific дизайн/экран не остаётся источником layout/style.
- Canonical IDs/order/effects не меняются; выбор применяется ровно один раз.
- Mouse, keyboard и gamepad сохраняют рабочую навигацию/подтверждение; cancel не
  обходит обязательный выбор.
- Не-Священник продолжает старт боя без этого модального шага.
- На 1280x720, 1920x1080 и 2560x1440 нет overlap, clipping или контента на
  орнаменте фрейма.
- Focused tests и `tests/runtime_smoke_test.gd` проходят.
- `menus_ui.md` и `current_game_state.md` обновлены.

## Evidence / Result

Реализовано:

- `show_battle_prayer_choice()` теперь создаёт тот же `LevelUpOverlay`,
  `LevelUpPanel`, `LevelUpRewardsRow` и `LevelUpRewardButton0..2`, что обычный
  выбор при повышении уровня.
- Удалена runtime-зависимость от отдельного 688×384 prayer frame, фиксированных
  prayer card rects и bespoke label/focus styles. Исторический asset сохранён
  только как прежнее evidence и больше не рендерится.
- Сохранены canonical prayer IDs/order/effects, обязательная пауза, physical
  Escape/keyboard cancel/gamepad B guard, exactly-once selection и синхронный
  fast path других классов.
- Display-only строки effect-field сокращены без изменения механики и полностью
  помещаются без ellipsis на 720p/1080p/2K.
- PixelLab mockup/spec: `docs/design/mockups/scrum1088_priest_prayer_attribute_picker/`;
  source/provenance: `docs/design/references/scrum1088_priest_prayer_attribute_picker/`;
  Metal runtime matrix: `docs/design/previews/scrum1088_priest_prayer_attribute_picker/runtime/`.

Проверки (PASS):

- `python3 tools/godot_gate.py --headless --path . --script res://tests/scrum926_priest_prayer_choice_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/priest_kit_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_inrun_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- `python3 tools/godot_gate.py --path . --script res://tests/scrum926_priest_prayer_capture_test.gd` (Metal screenshot matrix)

Known diagnostic: headless screenshot probe logs the existing dummy-renderer
`texture_2d_get` warning; both runtime smoke suites exit 0 and print PASS.

Disk cleanup: none created; work stayed in the main checkout, with no disposable
worktree, clone or isolated userdata directory. Generated screenshots are
committed task evidence.

Thread cleanup: not a disposable worker thread.
