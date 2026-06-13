# Back-end Task: Content Registry Consistency Test

Статус: in_progress (Codex Back-end, dispatched 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178 / SCRUM-175
Jira: SCRUM-200
Эпик: epic_full_project_quality_pass

## Scope

Add automated registry-vs-code-vs-assets checks for canonical IDs and resource paths.

## Requirements

- Validate character IDs, weapon IDs, boss/enemy IDs, artifact IDs and shop IDs.
- Validate static resource paths with `ResourceLoader.exists`.
- Support dynamic path patterns with an explicit manifest.
- Do not delete files in this task.

## Verification

- New test passes headless.
- False positives are documented and allowlisted.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
