# Back-end Task: Align Character Sprite Paths With Registry

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-192
Эпик: epic_full_project_quality_pass

## Scope

Fix character `sprite_path` drift between `scripts/progression_data.gd`, `docs/design/content_registry.md` and actual asset files.

## Known Drift

`thief`, `elementalist`, `sniper`, `priest`, `biologist` and `engineer` have final PNG files, but current config points at older proxy class sprites.

## Requirements

- Update code paths only if final files exist.
- Add a regression test that each `CHARACTER_CONFIGS[id].sprite_path` exists and matches registry expectation.
- Update docs if any intentional fallback remains.

## Verification

- Runtime smoke and animation smoke pass.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.
