# SCRUM-985 — Level Up: fit иконок, убрать внешнюю раму, осветлить фон

Статус: blocked (QA FAILED; исправление SCRUM-1032 в работе)
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

## QA-Вердикт (2026-07-10)

Статус: FAILED

Проверено на свежем `origin/dev` (`23e15aed0`, реализация `df25462f3`):

- PixelLab planning/spec/provenance корректны: принят component-only source
  `d3e5030c-b61d-4899-83ba-04fd6ccafaa9`, отклонённый outer-shell candidate
  записан в manifest;
- live Metal capture и rect matrix повторены независимо для `1280x720`,
  `1920x1080`, `2560x1440`: `LevelUpFrame` отсутствует, dim=`0.24`,
  shade=`0.12`, panel alpha=`0.20`, иконки сами по себе остаются внутри
  socket safe-zone;
- PASS: `level_up_advisor_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `dark_fantasy_ui_theme_test.gd`, `runtime_smoke_ui_test.gd`, полный
  `runtime_smoke_test.gd`, `animation_smoke_test.gd`,
  `meta_progression_smoke_test.gd`, `melee_weapon_targeting_test.gd`,
  `gamepad_inrun_ui_test.gd`, `gamepad_menu_focus_test.gd`,
  `gamepad_core_input_test.gd` и `gamepad_full_flow_smoke_test.gd` два раза;
  gamepad-flow реально открывает Level Up через RB, меняет карточку D-pad и
  применяет выбор через A.

Блокирующий дефект: `SCRUM-1032`. На `1280x720` advisor-бейдж первой карточки
лежит поверх орнамента сокета и закрывает верх наградной иконки:

- badge: `Rect2(334,259,150,31)`;
- socket: `Rect2(379,259,60,60)`;
- badge/socket intersection: `Rect2(379,259,60,31)`;
- icon: `Rect2(392,272,34,34)`;
- badge/icon intersection: `Rect2(392,272,34,18)`.

Стабильный скриншот:
`docs/design/previews/scrum985_level_up_cleanup/runtime_1280x720.png`.
Текущие focused/no-overlap тесты являются false-green: они проверяют icon
containment, но не sibling-disjointness бейджа с сокетом/иконкой. Это нарушает
обязательное правило «контент только в пустой зоне фрейма», поэтому SCRUM-985
возвращён в Jira в `К выполнению`. Исправление и regression assertions переданы
`/root` как combined scope с уже активным SCRUM-981 и идентичными locks.

Disk cleanup: disposable QA `.godot`, `build/qa/scrum985`, временные логи,
worktree и локальная QA-ветка удаляются после commit/push этого verdict mirror.
Thread cleanup: not a disposable standalone Codex thread; subagent returns to
the parent dispatcher after cleanup.
