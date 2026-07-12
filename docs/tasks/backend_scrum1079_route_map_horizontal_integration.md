# Задача Для Back-end-Агента: Горизонтальная Route Map По SCRUM-1057 Spec

Статус: review
Контур: Codex
Owner: Back-end/Codex
Thread: /root/scrum1079_route_backend
Locked paths при claim: `scripts/route_map_screen.gd`; focused Route Map geometry/gold-shell/no-overlap/gamepad/runtime test hunks; Route Map sections of `docs/design/systems/menus_ui.md` and `docs/design/current_game_state.md`; this mirror
Jira: SCRUM-1079
Parent Jira: SCRUM-1057

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. После claim агент автономно синхронизирует fresh `origin/dev`, реализует, тестирует, обновляет Jira/docs, коммитит и пушит только task-owned files. Routine confirmations не нужны.

## Контекст

Design/UI Director phase SCRUM-1057 подготовил PixelLab-generated горизонтальный mockup, exact content zones и responsive contract. Runtime-код Design-owner не менял.

## Что Уже Сделано

- Spec: `docs/design/mockups/scrum1057_route_map_horizontal/spec.md`
- Base plan/report: `docs/design/mockups/scrum1057_route_map_horizontal/ui_plan.json`, `ui_plan.report.json`
- Responsive matrix: `docs/design/mockups/scrum1057_route_map_horizontal/responsive_matrix.json`
- Accepted PixelLab source: `docs/design/references/scrum1057_route_map_horizontal/pixellab_route_map_horizontal_688x384.png`
- Preview/debug: `docs/design/previews/scrum1057_route_map_horizontal/route_map_horizontal_composited_688x384.png`, `route_map_horizontal_composited_688x384_debug.png`
- PixelLab source ID: `0a5d3c83-3592-430d-b733-82128c86aa5b`

## Что Нужно От Back-end

1. Развернуть route geometry на 90° по часовой стрелке: start слева, boss справа, step X строго возрастает, ветви одного step распределяются по Y.
2. Сохранить route generation, `next_branches`, типы/награды/состояния узлов, акты, tooltips и existing drag-click suppression.
3. Перевести canvas, auto-position и drag/pan на горизонтальную ось. Вертикальный scrollbar отключён, `scroll_vertical == 0`; нижняя horizontal lane используется только при необходимости.
4. Поднять title/progress/resource HUD в exact responsive zones из spec.
5. Соединять exact centers узлов; line layer не перехватывает mouse input.
6. Сохранить mouse/keyboard/gamepad, initial focus на available node и видимость current available column при open/return/live resize.
7. Не класть ни один label/node/line/tooltip/focus/FAB на frame ornament или local rails.

## Acceptance Criteria

- PASS на 1152×648, 1280×720, 1600×900, 1920×1080 и 2560×1440, включая live resize.
- Horizontal-only scrolling; vertical scrollbar не существует/невидим, `scroll_vertical=0`.
- Start/boss и все route columns соответствуют left-to-right contract.
- Hitboxes/tooltips/focus соответствуют видимым узлам; drag выше threshold не активирует узел.
- Focused horizontal Route Map geometry test, SCRUM-981 gold shell, UI no-overlap matrix, gamepad, runtime UI/full smoke зелёные через `tools/godot_gate.py`.
- Обновлены Route Map sections product docs и Jira evidence.

## Документация

Back-end обновляет `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md` и при необходимости focused task evidence. Design source package меняется только если implementation докажет необходимость deviation; тогда сначала обновить spec и причину.

## Результат Back-end (2026-07-12)

- `scripts/route_map_screen.gd` переведён на left-to-right step columns,
  горизонтальные canvas/pan/wheel/focus-follow и жёсткий
  `vertical_scroll_mode=DISABLED`, `scroll_vertical=0`.
- Пять exact responsive matrices из SCRUM-1057 управляют header,
  title/progress, resource HUD, route body, node viewport, horizontal lane и FAB.
- Node sizes: `56/60/68/72/88`; boss: `64/68/76/88/104`. Y-packing
  гарантирует node+gap без пересечения даже для 4 веток @1152×648.
- Exact-center lines остаются под нодами и `MOUSE_FILTER_IGNORE`;
  Left/Right ищут ближайшую focusable column, Up/Down ходят по веткам.
- Legacy node name `VerticalRouteMap` сохранён только для обратной
  совместимости tests/tooling; runtime metadata публикует
  `route_orientation=horizontal`.
- Metal screenshot matrix visually inspected after correcting compact-column
  packing: `docs/design/previews/scrum1079_route_map_horizontal_runtime/`.

### Verification

- `tests/scrum1079_route_map_horizontal_test.gd`: PASS, all five targets.
- `tests/scrum981_route_map_gold_shell_test.gd`: PASS, updated five-target shell gate.
- `tests/ui_no_overlap_matrix_test.gd`: PASS.
- `tests/gamepad_inrun_ui_test.gd`: PASS.
- `tests/route_node_threat_badge_test.gd`: PASS.
- `tests/runtime_smoke_ui_test.gd`: PASS (known headless dummy-texture capture
  warning remains non-fatal and outside Route Map).
- `tests/runtime_smoke_test.gd`: PASS after fresh `origin/dev` rebase.
- `git diff --check`: PASS.

Commit/push: the commit containing this report is pushed directly to
`origin/dev`; exact SHA is recorded in the Jira result comment.

Disk cleanup: generated `.uid` sidecars and isolated HOME directories removed;
disposable worktree and `.godot` cache are removed after push/Jira bookkeeping.
