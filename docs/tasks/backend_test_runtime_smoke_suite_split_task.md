# Back-end Task: Split Runtime Smoke Into Focused Suites

Статус: new
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
