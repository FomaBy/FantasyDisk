# Bug SCRUM-1086: Route Map Compact Header Text Fit

Статус: done
Контур: Codex
Owner: Back-end/Codex
Thread: /root/scrum1079_route_backend
Locked paths: `scripts/route_map_screen.gd`; `tests/scrum1086_route_map_header_text_fit_test.gd`; refreshed `docs/design/previews/scrum1079_route_map_horizontal_runtime/**`; focused Route Map docs; this mirror
Jira: SCRUM-1086
Related: SCRUM-1079, SCRUM-1057

## Defect

Independent visual QA found that the 1152×648 `RouteMapStageLabel` rendered the
selected-path warning as `Выбранны...`. Rectangle containment passed, but
the runtime copy did not fit its authored title/progress content zone.

## Acceptance

- 1152×648 and 1280×720 show complete, meaningful progress/route-strength/next-
  battle/permanent-choice status with no ellipsis or clipping.
- 1600×900, 1920×1080 and 2560×1440 retain the full existing copy.
- The title/progress zone geometry from SCRUM-1057 remains unchanged.
- A focused test measures the rendered themed-font width at all five targets and
  fails on overflow or ellipsis.
- Refreshed Metal screenshots and all Route Map/runtime gates pass.

## Результат (2026-07-12)

- Added `_route_map_stage_status_text()` and live-resize refresh in
  `scripts/route_map_screen.gd`.
- 1152/1280 copy is `Шаг N/8 · Сила N · Бой Ns · Выбор пути
  необратим`; 1600/1920/2560 retain the previous full copy.
- `RouteMapStageLabel` now has a stable runtime name and updates between compact
  and large copy without changing the SCRUM-1057 title-zone rectangles.
- `tests/scrum1086_route_map_header_text_fit_test.gd` measures the actual themed-
  font rendered width at all five targets and after 1920→1152 live resize; it
  also requires all meaningful tokens and rejects literal/rendered overflow.
- Refreshed Metal screenshots are committed in
  `docs/design/previews/scrum1079_route_map_horizontal_runtime/`; compact visual
  review shows no ellipsis, clipping or HUD overlap.

Verification PASS: SCRUM-1086 text fit, SCRUM-1079 horizontal geometry,
SCRUM-981 gold shell, UI no-overlap matrix, gamepad in-run UI, runtime UI smoke,
full runtime smoke, `git diff --check`.

Commit/push: exact origin/dev SHA recorded in Jira after push.

Disk cleanup: generated `.uid`/`.import`, isolated HOME and disposable `.godot`
cache/worktree removed after push and Jira sync.
