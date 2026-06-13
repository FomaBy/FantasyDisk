# Back-end Task: Split Runtime Smoke Into Focused Suites

Статус: in_progress (Codex Back-end, dispatched 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178
Jira: SCRUM-202
Эпик: epic_full_project_quality_pass

## Scope

Split `tests/runtime_smoke_test.gd` into focused suites while keeping an umbrella smoke path.

## Target Suites

- UI/menu smoke.
- Combat smoke.
- Progression/economy smoke.
- Weapon mechanics smoke.
- Boss/elite smoke.

## Verification

- Existing runtime smoke command remains available.
- All new focused suites pass headless.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
