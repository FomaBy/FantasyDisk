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

## Blocked / Serialized (2026-06-13)

Blocked by active UI dependency churn. SCRUM-222 is waiting on the accepted
SCRUM-147 UI frame kit, and current UI no-overlap/theme work still depends on
stable screen/style behavior. Splitting `scripts/ui_screens.gd` while UI assets
and tests are still settling would create high-conflict noise.

Next unblock: resume after SCRUM-147/SCRUM-222 is unblocked and active UI edits
are closed. No UI module split was started.

## Dispatcher Unblock / Dispatch (2026-06-13)

Unblocked for a serialized Back-end refactor window: SCRUM-222 is `Готово`,
SCRUM-147/SCRUM-229 are in QA rather than active code work, SCRUM-203 is
`Готово`, and `scripts/ui_screens.gd` was clean in git status. Dispatched to
Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as item 4 after
SCRUM-202, SCRUM-196 and SCRUM-198. Keep reasoning High/no low; do not change
visual design or absorb Design/Animator scope.

## Blocked / Release Freeze (2026-06-13)

Blocked for the v0.1.4 stabilization freeze. This is a high-conflict structural
refactor of `scripts/ui_screens.gd`, not a bug, QA defect, regression or release
blocker. It also conflicts with the just-landed SCRUM-231 hero-select bugfix in
the same file, so starting the module split now would add unnecessary release
risk.

Next unblock: resume after v0.1.4 release / feature-freeze lift, or if PM
explicitly reclassifies the UI module split as a release blocker. No UI module
split was started in this window.

## PM Override / Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Release-freeze blocker снят именно для уже существующих board-задач. Redispatch
в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` как
последовательный queue item после SCRUM-230 и SCRUM-198. Keep reasoning High/no
low. Не начинать параллельно с работой, которая меняет `scripts/ui_screens.gd`
или UI smoke tests; сохранить визуал/поведение, закрыть task/board/Jira sync
перед переходом к следующей queued задаче. Если всплывает motion/animation
scope, создать/update Animator handoff вместо выполнения animation work.
