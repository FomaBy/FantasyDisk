# SCRUM-985 — Level Up: fit иконок, убрать внешнюю раму, осветлить фон

Статус: done
Jira: SCRUM-985
Версия: 0.2.1
Контур: Codex
Owner: Codex/root
Thread/Worker: current user-facing Codex task (`/root`)
Роль: combined UI Design + Back-end integration (один экран и одинаковые locked paths)
Locked paths: `scripts/ui_screens.gd`; focused Level Up/UI tests; `docs/design/mockups/scrum985_level_up_cleanup/`; `docs/design/references/scrum985_level_up_cleanup/`; `docs/design/previews/scrum985_level_up_cleanup/`; `docs/design/systems/menus_ui.md`; `docs/design/current_game_state.md`; `build/qa/scrum985/`
Branch/worktree: `dev`, `/Users/sergeyfomin/Documents/AI Agent`

## Контекст

Актуальный фидбэк пользователя отменяет прежнюю backlog-формулировку SCRUM-985
про добавление большой золотой рамы. На экране повышения уровня предметная
иконка визуально выходит за орнамент сокета, самая большая внешняя рама экрана
перегружает композицию, а затемнение `0.82` почти скрывает игровой фон.

## Требования

- До runtime-правок создать PixelLab MCP mockup/spec страницы.
- Убрать полноэкранную внешнюю раму `LevelUpFrame`.
- Держать reward/artifact icon целиком внутри заявленной icon safe-zone.
- Сделать фон заметно ярче, сохранив контраст карточек и текста.
- Не накладывать контент на орнаменты оставшихся элементов.
- Сохранить ровно три варианта, advisor-бейджи, hover/focus/pressed и `Позже`.
- Проверить `1280x720`, `1920x1080`, `2560x1440`.

## Acceptance Criteria

- [x] PixelLab MCP mockup/spec и provenance сохранены в репозитории.
- [x] В runtime нет узла `LevelUpFrame` на Level Up overlay.
- [x] Видимый alpha reward/artifact icon не пересекает декоративный сокет.
- [x] Целевой dim заметно ниже SCRUM-892 baseline `0.82`.
- [x] Карточки, заголовок, иконки, effect preview и `Позже` не пересекаются/не клипуются.
- [x] Focus/hover не меняют геометрию.
- [x] Focused UI tests и полный `runtime_smoke_test.gd` проходят.
- [x] Документация обновлена; task commit предназначен для немедленного push в `origin/dev` и перевода Jira в QA.

## Решение

- Planning gate: `ready_for_image`, errors/warnings `0/0`.
- Первый PixelLab full-panel кандидат отклонён из-за повторного появления
  внешней рамы.
- Принят PixelLab component-only layer
  `d3e5030c-b61d-4899-83ba-04fd6ccafaa9`: три локальные карточки, отдельные
  слоты и кнопка на прозрачном холсте.
- Mockup: `docs/design/previews/scrum985_level_up_cleanup/mockup_1920x1080.png`.
- Иконка: `72x72` внутри слота `120x120`; `UIIconRegistry.make_icon()` получил
  backward-compatible флаг отключения readability-scale, и Level Up передаёт
  `false`, чтобы Control всегда совпадал с рассчитанной safe-zone.

## Результат

- `LevelUpFrame` удалён из runtime-композиции; `LevelUpPanel` сохранён только
  как layout-хост с alpha `0.20`, прозрачной рамкой и нулевой толщиной борта.
- Arcane-lab backdrop осветлён (`Color(1.15, 1.12, 1.18)`), shade снижен до
  `0.12`, intro dim — до `0.24` вместо `0.82`.
- Reward icon больше не получает скрытое увеличение `1.45x` и проходит inset
  socket-fit проверку на `1280x720`, `1920x1080`, `2560x1440`.
- Runtime evidence:
  `docs/design/previews/scrum985_level_up_cleanup/runtime_1280x720.png`,
  `runtime_1920x1080.png`, `runtime_2560x1440.png`.
- Проверки PASS: `tests/level_up_advisor_test.gd`,
  `tests/ui_no_overlap_matrix_test.gd`, `tests/dark_fantasy_ui_theme_test.gd`,
  `tests/runtime_smoke_ui_test.gd`, полный `tests/runtime_smoke_test.gd`,
  task-specific visual matrix через `tools/capture_scrum985_level_up.gd`.
- Первый runtime smoke остановился только на посторонних byte-identical duplicate
  sidecars; после их безопасного удаления полный smoke прошёл. Product/runtime
  failures не осталось.
- Disk cleanup: task-generated screenshots и matrix report перенесены в
  committed preview directory; `build/qa/scrum985/` удалён.
- Thread cleanup: not a disposable worker thread.
