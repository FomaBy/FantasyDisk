# Back-end Task: Align Character Sprite Paths With Registry

Статус: new
Версия: 0.1.5
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
