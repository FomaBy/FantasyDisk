# Back-end Task: Split `progression_data.gd` Into Domain Data Files

Статус: in_progress (Codex Back-end, dispatched 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-198
Эпик: epic_full_project_quality_pass

## Scope

Split `scripts/progression_data.gd` into character, weapon, reward, artifact, shop, ascension and balance-model data owners.

## Requirements

- Keep `ProgressionData` as compatibility facade.
- No balance changes.
- Move budget-only estimators out of production data where practical.
- Update docs references after split.

## Verification

- Runtime smoke and balance harness pass.
- Content registry consistency test passes after migration.

## Serialization

High conflict risk. Serialize after active balance/content tasks.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
