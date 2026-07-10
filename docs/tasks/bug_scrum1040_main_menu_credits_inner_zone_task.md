# BUG: Main Menu Credits button violates authored gold-shell inner reserve

Статус: done
Приоритет: high
Роль: Back-end (UI runtime/tests)
Контур: Codex
Исполнитель: Codex
Owner: Back-end / Codex
Thread/Worker: root-scrum-1039-1040-ui-resize
Jira: SCRUM-1040
Версия: 0.2.1
Найдено post-review: SCRUM-968
Locked paths: `scripts/ui_screens.gd`;
`tests/scrum981_gold_menu_shell_test.gd`;
`tests/ui_no_overlap_matrix_test.gd`; this mirror/evidence

Branch/worktree: `codex/scrum-1039-1040-ui-resize` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1039-1040-ui-resize`

## Контекст

SCRUM-968 добавил `MainMenuCreditsButton` в сырой `gold_shell_content_rect` с
отступом 12px. После SCRUM-1036 обязательная authored content-zone начинается
ещё на 24px (32px для 2K tier) глубже рамы. Поэтому кнопка визуально находится
в запрещённой полосе орнамента на 12px / 20px, хотя базовый safe-rect соблюдён.

## Acceptance Criteria

- [x] Полный rect `MainMenuCreditsButton` находится внутри authored inner rect
      после резерва 24/32px на 1280x720, 1920x1080 и 2560x1440.
- [x] Точная зона: верхний правый угол inner rect, внутренний pad 12px, размер
      240x36 (или уже, если inner rect меньше).
- [x] Кнопка не пересекает логотип, сетку действий и версию.
- [x] Fresh и live-resize раскладки совпадают.
- [x] Focused SCRUM-981 и no-overlap matrix имеют независимые геометрические
      проверки inner containment и exact placement.
- [x] Результат прошёл UI/runtime гейты, запушен в `origin/dev` и передан QA.

## Implementation result (2026-07-10)

- Credits вычисляется напрямую от `_gold_shell_inner_rect_for_size(root.size)`
  и получает exact `240x36` hitbox с внутренним pad 12px.
- У text-link сняты унаследованные stylebox margins, которые ранее физически
  расширяли 36px authored zone до 39px.
- Подтверждённые зоны: `1280 (871,149,240,36)`,
  `1920 (1444,205,240,36)`, `2560 (2009,269,240,36)`; пересечений с
  logo/actions/version нет, live-resize совпадает с fresh layout.
- Focused SCRUM-981 и no-overlap matrix независимо проверяют exact placement,
  authored inner containment и peer disjointness.
- Независимый read-only subagent review: PASSED, blocking findings отсутствуют.

Green gate: SCRUM-981 focused; exact Route Map; UI no-overlap matrix;
dark-fantasy UI theme; runtime UI; gamepad full-flow 3/3; audio integration;
full runtime — PASSED. Full runtime содержит только известные non-fatal headless
lambda/dummy-renderer diagnostics.

Commit/push: `9f04dc59e` → `origin/dev`. Jira: `Контроль качества`.
Disk cleanup: removed task `.godot` cache (445 MB); generated UID sidecars
removed; clean disposable worktree is removed after final routing sync.
