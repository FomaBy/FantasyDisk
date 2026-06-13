# Back-end Task: Content Registry Consistency Test

Статус: new
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
