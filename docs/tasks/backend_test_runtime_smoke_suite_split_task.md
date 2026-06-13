# Back-end Task: Split Runtime Smoke Into Focused Suites

Статус: blocked
Версия: 0.1.4
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
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Blocked / Serialized (2026-06-13)

Blocked by active smoke-surface churn rather than a failing test. Runtime smoke
is still being extended by current content/UI tasks (SCRUM-192 registry
alignment, SCRUM-203 no-overlap matrix already in QA, SCRUM-222 UI theme
dependency). Splitting the umbrella smoke while those checks are moving would
create duplicate maintenance work.

Next unblock: resume once the current focused smoke additions are closed or
accepted by QA. Existing umbrella `tests/runtime_smoke_test.gd` remains the
required smoke command.
