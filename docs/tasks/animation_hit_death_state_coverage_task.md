# Animation: hit and death state coverage

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-185
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-only. Do not change health, damage, loot, death cleanup, collision, or revive/game-over logic.

## Context
`scripts/cutout_rig_2d.gd` has `play_hit()`, `_apply_hit_feedback()`, `play_death()`, and `spawn_death_ghost()`. Current smoke coverage validates enemy death ghost, but hit/death readability is not covered across player, standard enemy, elite, and boss categories.

## Tasks
1. Audit hit feedback readability for player, standard enemy, elite, and boss rigs.
2. Add animation smoke coverage for hit tint/shake state without changing gameplay damage.
3. Add death-state smoke coverage for player rigs, elite rigs, boss rigs, and existing enemy death ghost.
4. If any art lacks enough separable parts for a readable collapse, create a Design handoff instead of redrawing.

## Acceptance Criteria
- Hit state is asserted for representative player/enemy/elite/boss rigs.
- Death state is asserted for representative player/enemy/elite/boss rigs.
- Existing death cleanup behavior is unchanged.
- Animation smoke passes.
