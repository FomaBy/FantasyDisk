# Animation: hit and death state coverage

Статус: done
Версия: 0.1.5
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-185
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-only. Do not change health, damage, loot, death cleanup, collision, or revive/game-over logic.

## Context
`scripts/cutout_rig_2d.gd` has `play_hit()`, `_apply_hit_feedback()`, `play_death()`, and `spawn_death_ghost()`. Current smoke coverage validates enemy death ghost, but hit/death readability is not covered across player, standard enemy, elite, and boss categories.

Started by Animator/Codex on 2026-06-13.

## Tasks
1. Audit hit feedback readability for player, standard enemy, elite, and boss rigs.
2. Add animation smoke coverage for hit tint/shake state without changing gameplay damage.
3. Add death-state smoke coverage for player rigs, elite rigs, boss rigs, and existing enemy death ghost.
4. If any art lacks enough separable parts for a readable collapse, create a Design handoff instead of redrawing.

## Acceptance Criteria
- [x] Hit state is asserted for representative player/enemy/elite/boss rigs.
- [x] Death state is asserted for representative player/enemy/elite/boss rigs.
- [x] Existing death cleanup behavior is unchanged.
- [x] Animation smoke passes.

## Result
Done 2026-06-13 (Animator/Codex): extended `tests/animation_smoke_test.gd` to
assert representative player, standard enemy, elite, and boss rigs enter `hit`
with visible pelvis shake and `death` with collapse/fade state. Existing enemy
death ghost cleanup test remains intact. No gameplay health/damage/loot/death
cleanup logic changed.

Verification:
- `tests/animation_smoke_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed after the parallel SCRUM-207 shop stock
  fix landed in the shared workspace.

## Dispatcher Note (2026-06-13)
Dispatched to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` after user confirmed no feature freeze / backlog is eligible.
