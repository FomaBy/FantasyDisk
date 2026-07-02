# Refactor Wave: Main State Lifecycle And Run Coordinator Audit

Jira: SCRUM-707
Статус: done
Приоритет: P1
Роль: Back-end / quality
Контур: Claude
Owner: Back-end / Claude
Thread/Worker: claude-backend
Версия: 0.2.0
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-main, area-state
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

Пользователь попросил создать много задач для Claude по полному рефакторингу кода FantasyDisk: разные секции игры должны быть проверены, улучшены и исправлены. Эта задача покрывает `Main` как центральный координатор state/lifecycle.

## Dispatch

2026-06-30 17:25 Europe/Vilnius: Jira-pull claimed by `claude-backend` in Jira (`В работе`). Locked paths remain `scripts/main.gd`, optional focused `tests/main_state_*`, and `docs/design/systems/technical_architecture.md` only if the coordinator contract changes.

## Scope / Locked Paths

- `scripts/main.gd`
- Focused tests may be added under `tests/main_state_*`
- `docs/design/systems/technical_architecture.md` only if the coordinator contract changes

## Required Change

Audit and safely refactor the Main coordinator: run state transitions, pause reasons, scene layer ownership, delegated component calls, new-run/return-to-menu/death/victory cleanup and test-only facade methods. Keep `main.gd` a thin coordinator and avoid moving gameplay logic into it.

## Acceptance Criteria

- Main lifecycle audit is recorded in the task result.
- Real low-risk/high-impact issues are fixed with tests.
- `main.gd` remains a coordinator; gameplay/UI/data logic is not moved into it.
- Pause, new run, death, victory, return-to-menu and resume flows keep existing behavior.
- Risky findings become separate Jira follow-up/bug tasks with locked paths.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_combat_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## QA-Вердикт
Статус: PASSED (claude-qa, 2026-06-30)

- Интеграция: 943d89ac влито в origin/dev (git merge-base --is-ancestor -> YES).
- scripts/main.gd: мёртвые обёртки set_game_paused/set_gameplay_paused/is_gameplay_paused + поле _quit_requested удалены; живой game_quit_requested meta на месте; tests/main_state_pause_lifecycle_test.gd присутствует.
- Гейты (изолир. worktree от origin/dev, fdengine-семафор): main_state_pause_lifecycle_test -> passed; runtime_smoke_test -> passed (RC=0).
- Поведение игрока сохранено. Acceptance выполнен.
