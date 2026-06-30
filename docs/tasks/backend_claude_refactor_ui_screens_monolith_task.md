# Refactor Wave: ui_screens Runtime-Only Monolith Audit

Jira: SCRUM-716
Статус: new
Приоритет: P1
Роль: Back-end / UI runtime quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-ui, area-runtime
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

`scripts/ui_screens.gd` is the largest runtime file and needs a careful code-quality pass. This task is runtime-only: it must not redesign UI art, layout direction or frame geometry.

## Scope / Locked Paths

- `scripts/ui_screens.gd`
- Focused UI tests
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/ui_technical_requirements.md`

## Required Change

Audit and safely refactor `ui_screens.gd` runtime code without visual redesign: screen lifecycle, node naming contracts, safe-zone containment helpers, HUD snapshots, tooltip ownership, focus/input flow, duplicated button/card helpers and fragile test-only accessors. No new art, no mockup pass, no frame geometry changes; if visual changes are required, create a separate UI-director handoff.

## Acceptance Criteria

- Runtime UI audit is recorded.
- No content overlaps decorative frame art after changes.
- Existing UI screens preserve layout and interaction contracts.
- Duplicated helper code is reduced only when risk is controlled by tests.
- UI no-overlap and theme tests cover touched screens.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd
```

## Hard UI Rule

Content may never overlap decorative frame texture/ornament. Text, icons, buttons, cards and interactive controls must stay inside the real inner content zones. If a UI visual/layout change is needed, stop this task and create a proper UI-director handoff.
