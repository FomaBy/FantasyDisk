# Back-end Task: Dynamic Asset Manifest For Unused-Asset Audit

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-194
Эпик: epic_full_project_quality_pass

## Scope

Improve unused-asset auditing so dynamic paths and docs-only preview assets are handled safely.

## Requirements

- Add a manifest for dynamic paths: artifact icons, shop icons, cutout families, route icons, generated previews.
- Group `.import`/`.uid` sidecars with source assets.
- Preserve protected folders from process docs.
- Produce a report before any cleanup.

## Verification

- Audit report has no false-positive deletes for dynamic assets.
