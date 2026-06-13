# Back-end Task: Refactor `ui_screens.gd` Into Domain UI Modules

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-199
Эпик: epic_full_project_quality_pass

## Scope

Split `scripts/ui_screens.gd` into focused UI modules without behavior changes.

## Required Boundaries

- Preserve public node names used by tests.
- Keep `ui_screens.gd` as compatibility facade until callers are migrated.
- Extract: main menu, hero select, settings, codex, level-up/rewards, shop, noncombat screens, run HUD, common styles.
- Do not change visual design or gameplay behavior.

## Verification

- Runtime smoke, animation smoke, meta progression, meta skill tree, melee targeting, attack VFX, hazard VFX all pass.
- Existing UI no-overlap checks remain green.

## Serialization

High conflict risk. Run only when no active task is editing `scripts/ui_screens.gd` or UI tests.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress. High-conflict task; only start when no active UI edits.
