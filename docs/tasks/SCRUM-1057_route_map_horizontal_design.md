# SCRUM-1057 — Route Map Horizontal Design Handoff

Статус: done
Контур: Codex
Owner: Design/Codex
Thread: `/root/scrum1057_route_mockup`
Locked paths: `docs/design/mockups/scrum1057_route_map_horizontal/**`, `docs/design/references/scrum1057_route_map_horizontal/**`, `docs/design/previews/scrum1057_route_map_horizontal/**`, this mirror
Jira: SCRUM-1057

## Контекст

PixelLab capacity восстановлен. Design формирует обязательный UI Director mockup/spec для горизонтальной карты слева направо до любых runtime-изменений.

## Design Scope

- PixelLab MCP textless art/layout layer;
- exact content zones and five-resolution responsive matrix;
- content-composited preview, debug overlay and fit reports;
- source/provenance manifest;
- отдельный Jira/Markdown handoff Back-end для runtime implementation.

Runtime scripts, gameplay route data, input and tests этим Design-owner не изменяются.

## Evidence

- Spec: `docs/design/mockups/scrum1057_route_map_horizontal/spec.md`
- Plan: `docs/design/mockups/scrum1057_route_map_horizontal/ui_plan.json`
- Planning report: `docs/design/mockups/scrum1057_route_map_horizontal/ui_plan.report.json`
- Responsive matrix: `docs/design/mockups/scrum1057_route_map_horizontal/responsive_matrix.json`
- PixelLab v2 source ID: `0a5d3c83-3592-430d-b733-82128c86aa5b`

## Result

- Planning/content fit: PASS (`ready_for_image`, zero errors/warnings; compositor report `ok=true`).
- PixelLab v1 `4f25f4c6-347d-4278-b5f8-5d20bb964e84`: rejected for baked checkerboard and retained only as provenance.
- PixelLab v2 `0a5d3c83-3592-430d-b733-82128c86aa5b`: accepted; solid calm horizontal viewport, exact header wells, bottom horizontal lane, no vertical lane.
- Full preview/debug exported; all sample text, lines and canonical node icons remain inside declared zones.
- Runtime untouched. Back-end Jira handoff created: SCRUM-1079; mirror: `docs/tasks/backend_scrum1079_route_map_horizontal_integration.md`.

## QA-Вердикт: PASSED

Статус: PASSED
Дата: 2026-07-12
QA: Codex `/root/scrum1068_runtime_review`

Design contract повторно принят по фактической runtime-реализации
SCRUM-1079 и text-fit исправлению SCRUM-1086 на `origin/dev`
`a9d4ff61ac24196bd48e9cb5bdc77f26fdfd3691`.

- все exact responsive zones верифицированы на 1152/1280/1600/1920/2560;
- title/progress, resource HUD, nodes, lines и horizontal lane остаются
  в пустых внутренних зонах; рамка, орнамент и local rails
  не перекрыты;
- PixelLab/source package не изменялся, implementation deviations от
  accepted geometry не найдены;
- visual review и весь focused/full Godot gate набор прошли.

Disk cleanup: QA cache/sidecars/temp user-data and disposable worktree removed
after verdict push/Jira sync.
