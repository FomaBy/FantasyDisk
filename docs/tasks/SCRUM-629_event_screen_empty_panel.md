# SCRUM-629 - Random Event Empty Panel Bugfix

Статус: done
Owner: main-codex-event-ui-bugfix
Jira: SCRUM-629

## Problem

При входе в random event игрок видел фон и большую event-рамку, но без
заголовка, описания и кнопок выбора. Визуально это выглядело как пустая серая
панель внутри `evt_panel`.

## Fix

- Сохранил `MenuPanel_event` как реальную event-панель, а `EventScreen` теперь
  назначается внешнему root-контейнеру, не затирая имя панели.
- Добавил event-specific safe-zone layout: `EventContent`, `EventTitle` и
  `EventStory` фиксируются внутри content-зоны `evt_panel`.
- Отключил `ScrollContainer.follow_focus` для event-экрана, чтобы фокус первой
  карточки не прокручивал стартовый контент из видимой области.
- Расширил `ui_no_overlap_matrix_test.gd`: тест теперь падает, если event-панель
  отсутствует, title/story пустые или невидимые, меньше двух choices видимы, или
  event controls клипуются за пределы панели.

## Verification

- `Godot_v4.7-stable_win64_console.exe --headless --path D:\FantasyDisk_worktrees\event-ui-bugfix-wt --import`
- `Godot_v4.7-stable_win64_console.exe --headless --path D:\FantasyDisk_worktrees\event-ui-bugfix-wt --script tests/ui_no_overlap_matrix_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path D:\FantasyDisk_worktrees\event-ui-bugfix-wt --script tests/runtime_smoke_ui_test.gd`
- `Godot_v4.7-stable_win64_console.exe --headless --path D:\FantasyDisk_worktrees\event-ui-bugfix-wt --script tests/runtime_smoke_test.gd`
