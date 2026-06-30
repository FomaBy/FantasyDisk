# Refactor Wave: UI Theme Paths, Icons And Pause Stats Helpers

Jira: SCRUM-717
Статус: new
Приоритет: P2
Роль: Back-end / UI runtime quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-ui, area-icons
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers supporting UI modules and should not overlap the main `ui_screens.gd` monolith pass except through public helpers.

## Scope / Locked Paths

- `scripts/ui/*.gd`
- `scripts/ui_icon_registry.gd`
- `scripts/pause_stats_menu.gd`
- UI theme/icon tests
- `docs/design/systems/menus_ui.md`

## Required Change

Audit and safely refactor supporting UI modules: theme path registries, metadata/content-margin maps, icon texture cache, hero stat radar constants, shop constants and pause stats grouping/tooltips. Preserve existing visual assets and frame-rule safe margins.

## Acceptance Criteria

- Supporting UI module audit is recorded.
- Theme and icon registries remain deterministic and cache-safe.
- Pause stats still group/describe derived stats correctly.
- No new art, no visual redesign and no one-axis stretching are introduced.
- Focused tests cover changed registry/helper behavior.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ui_icon_registry_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
```

## Hard UI Rule

Content may never overlap decorative frame texture/ornament. Runtime constants must preserve documented content margins and safe zones.
