# Back-end Task: Safe Cleanup Follow-up For Legacy Asset Candidates

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-193
Эпик: epic_full_project_quality_pass

## Scope

Review and safely move likely unused legacy assets after the dynamic asset manifest task is complete.

## Candidate Groups

- `.DS_Store` under assets.
- old `*_placeholder.png` character sprites.
- legacy root enemy duplicates under `assets/sprites/`.
- legacy `assets/sprites/boss_warden.png`.

## Requirements

- No irreversible delete.
- Tracked candidates use `git rm` only after backup.
- Untracked candidates move to backup.
- Runtime and animation smoke pass after cleanup.

## Dependency

Blocked until `backend_content_unused_asset_audit_manifest_task.md` is done.
