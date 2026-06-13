# Back-end Task: Split `progression_data.gd` Into Domain Data Files

Статус: done
Версия: 0.1.4
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
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress. High-conflict task; serialize after active balance/content tasks as needed.

## Blocked / Serialized (2026-06-13)

Blocked by serialization. `scripts/progression_data.gd` is still receiving
content/balance alignment fixes in the current 0.1.4 queue, including SCRUM-192.
Splitting the domain data now would create avoidable conflicts and make Jira
look active without a safe isolated refactor window.

Next unblock: resume after active content/balance tasks that modify
`ProgressionData` are closed or explicitly paused. No domain split was started.

## Dispatcher Unblock / Dispatch (2026-06-13)

Unblocked for a serialized Back-end refactor window: SCRUM-192 is `Готово`, no
active content/balance task is editing `ProgressionData`, and
`scripts/progression_data.gd` was clean in git status. Dispatched to Back-end
thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as item 3 after SCRUM-202 and
SCRUM-196. Keep reasoning High/no low; preserve balance exactly and close/Jira-
sync each earlier queued task before starting.

## Blocked / Release Freeze (2026-06-13)

Blocked for the v0.1.4 stabilization freeze. This is a high-conflict structural
refactor of `scripts/progression_data.gd`, not a bug, QA defect, regression or
release blocker. Starting it during release stabilization would expand scope and
risk destabilizing balance/content data after SCRUM-196 and SCRUM-231 were
closed.

Next unblock: resume after v0.1.4 release / feature-freeze lift, or if PM
explicitly reclassifies this refactor as a release blocker. No domain split was
started in this window.

## PM Override / Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Release-freeze blocker снят именно для уже существующих board-задач. Redispatch
в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` как
последовательный queue item после SCRUM-230. Keep reasoning High/no low.
Не начинать параллельно с работой, которая меняет `scripts/progression_data.gd`;
сохранить поведение и баланс, закрыть task/board/Jira sync перед переходом к
следующей queued задаче.

## Animator Blocker Handoff (2026-06-13)

SCRUM-239 Animator implementation is complete, but final animation/runtime smoke
verification is blocked by the current `ProgressionData` facade parse state:
Godot reports missing `res://scripts/progression_data_meta.gd`,
`ProgressionData.SHOP_ITEMS` compatibility errors in `tests/runtime_smoke_test.gd`,
and dependent `player.gd` compile failure before animation smoke/runtime smoke
can make a valid pass.

Back-end owner should restore the compatibility facade/imports for the split
data files and keep old public constants/functions used by umbrella smoke until
all tests are migrated. Animator should rerun SCRUM-239 verification after this
parse blocker is fixed; no gameplay/balance changes are requested from Animator.

Jira sync 2026-06-13: blocker comment added to SCRUM-198; live Jira status is
`В работе`, Fix Version `0.1.4`.

## Result (2026-06-13)

Done. `scripts/progression_data.gd` is now a compatibility facade over focused
domain data owners:

- `scripts/progression_data_characters.gd` — stats, character configs, class
  interpretations, class priority metadata, ultimate configs.
- `scripts/progression_data_weapons.gd` — class weapon definitions and
  `WEAPONS_BY_CLASS`.
- `scripts/progression_data_content.gd` — rewards, artifacts and level-up pools.
- `scripts/progression_data_shop.gd` — shop item data.
- `scripts/progression_data_ascension.gd` — ascension levels and modifiers.
- `scripts/progression_data_balance.gd` — balance budgets, stage scale,
  economy, XP and drop constants.
- `scripts/progression_data_enemies.gd` — mini-elite data.

The old public `ProgressionData` constants and static methods remain available
for runtime, tests, and legacy callers, including individual class weapon
constants and `SHOP_ITEMS`. The stale `progression_data_meta.gd` split artifact
was removed after all imports were migrated. Balance estimators remain exposed
through the facade for compatibility, but their constants live in the balance
domain file and no balance values were intentionally changed.

This fixes the SCRUM-239 release blocker from the missing facade/meta import
state: Godot now parses the facade and `ProgressionData.SHOP_ITEMS` resolves
again.

Verification passed:

- `tests/progression_data_api_surface_test.gd`
- `tests/content_registry_consistency_test.gd`
- `tests/runtime_smoke_progression_economy_test.gd`
- `tools/balance_harness.gd`
- `tests/runtime_smoke_test.gd`

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`,
`docs/design/systems/technical_architecture.md`,
`docs/design/mechanics_extract.md`.
