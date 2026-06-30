# UX: Escape в забеге открывает доску персонажа с левым меню

Статус: review
Приоритет: medium
Роль: Back-end (UI)
Контур: Codex
Owner: Back-end Codex
Thread/Worker: backend-board-watcher-20260630T105412Z
Версия: 0.1.8
Создано: 2026-06-30
Автор: User request via Codex
Jira: SCRUM-693
Связано: SCRUM-215
Locked paths: scripts/main.gd; scripts/ui_screens.gd; scripts/pause_stats_menu.gd; tests/runtime_smoke_ui_test.gd; tests/ui_no_overlap_matrix_test.gd; tests/runtime_smoke_test.gd; CHANGELOG.md; docs/design/current_game_state.md; docs/design/systems/menus_ui.md

## Контекст

В активном забеге нажатие `Esc` сейчас открывает только обычное меню паузы. Нужно,
чтобы `Esc` открывал окно доски персонажа вместе с уже существующим меню в левом
углу. Отдельное обычное меню можно убрать или сделать недоступным, если новый
комбинированный flow полностью его заменяет.

## Требуемое изменение

1. В активном gameplay `Esc` открывает доску персонажа/окно персонажа и оставляет
   доступным текущее левое меню в углу.
2. Игра остаётся на паузе, пока открыт этот overlay; `Resume`/назад/повторный
   `Esc` возвращают в тот же забег без изменения состояния персонажа, предметов,
   таймеров и прогресса.
3. Старое standalone-меню паузы не должно появляться поверх или вместо доски
   персонажа.
4. Поведение `Esc` вне активного забега не ломать: главное меню/подтверждение
   выхода, выбор героя/оружия, настройки/кодекс, магазин/награды/события,
   победа и смерть.
5. Глобальное правило фреймов обязательно: кнопки, текст, иконки, hit areas и
   карточки не накладываются на декоративные рамки/орнамент.

## Implementation Notes

- Это runtime/UI behavior scope, без нового арта.
- Если при реализации окажется, что нужен новый визуальный макет или новые
  фреймы, завести отдельный Design/UI task через `fantasydisk-ui-director`, а в
  этой задаче не генерировать ассеты.
- Вероятные места изменения: `scripts/main.gd`, `scripts/ui_screens.gd`,
  `scripts/pause_stats_menu.gd` и focused UI smoke/no-overlap тесты.
- Jira Fix Version не проставлен при создании, потому что Jira release `0.1.8`
  отсутствует; issue добавлен в active sprint `Спринт 0.1.8`.

## Acceptance Criteria

- [x] В активном забеге `Esc` открывает доску персонажа + левое меню, а не старое
      отдельное меню паузы.
- [x] Действия левого меню остаются доступны и работают как до изменения.
- [x] Пока overlay открыт, gameplay надёжно paused; закрытие возвращает в тот же
      run state без потери/изменения данных персонажа.
- [x] Повторный `Esc`, back/resume и focus navigation не создают дубли модалок,
      невидимых click-blockers или застреваний фокуса.
- [x] Все существующие `Esc`/back flows вне активного забега сохраняют текущую
      семантику.
- [x] No-overlap/safe-zone проверка подтверждает, что контент не лежит на
      орнаменте рамок на поддерживаемых разрешениях.
- [x] Добавлена или обновлена focused smoke-проверка для active-run `Esc` flow.
- [x] Пройдены `runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd` и
      `runtime_smoke_test.gd` через `tools/godot_gate.py` или одиночный Godot run.
- [x] Обновлены `CHANGELOG.md`, `docs/design/current_game_state.md` и
      `docs/design/systems/menus_ui.md`.

## Результат

2026-06-30, Back-end Codex (`backend-board-watcher-20260630T105412Z`):

- Active combat `Esc` now opens `PauseStatsMenuRoot` / character board directly
  via `scripts/ui_screens.gd`, while `RunPauseMenuRoot` remains reserved for
  noncombat run overlays such as level-up, shop, event and route contexts.
- Resume, repeated `Esc`, and Settings -> Back return to the same paused run
  surface without changing combat state, timer, player node/position, route
  stage or selected build.
- Focused and umbrella smokes updated to assert that active-run `Esc` does not
  show the old standalone pause menu and that no-overlap safe zones still pass.

Проверки:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Disk cleanup: none created; existing main-checkout `.godot/` cache and unrelated
pre-existing `.import` sidecars were left untouched.
