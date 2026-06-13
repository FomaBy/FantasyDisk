# Back-end Task: Content Registry Consistency Test

Статус: new (PM 2026-06-13: сброшен из залипшего in_progress — claim >3ч без коммитов, Codex-dispatch не дал прогресса; готов к взятию воркером)
Версия: 0.1.4
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
