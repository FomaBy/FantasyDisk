# Animation: enemy archetype motion coverage

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-184
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-only. Do not change enemy stats, attacks, spawn rules, collision, targeting, or Backend behavior.

## Context
The audit found broad cutout-rig coverage for enemies, but smoke assertions currently sample only a subset: baseline melee, flying wings, elite phases, boss rig, and enemy death ghost. Several enemies have intentionally partial rigs, so each archetype needs tailored motion coverage.

## Entities To Cover
- `ash_marksman`
- `spark_runner`
- `stone_bruiser`
- `bone_caller`
- `void_mage`
- `venom_spitter`
- `rift_shieldbearer`
- `small_biter`
- `bone_shaman`
- `winged_spark` attack readability
- `disk_devourer` boss body-squash/attack readability

## Tasks
1. Add or refine archetype-specific motion/attack/cast/shoot poses where the current fallback is too generic.
2. Respect partial rigs: use torso, shield, weapon, wing, tail, or body squash when arms/legs are absent.
3. Extend animation smoke tests with one readable movement and one readable action assertion per archetype.
4. Keep `HeroFull` hidden source art architecture intact.

## Acceptance Criteria
- Every listed entity has a tested movement/readability assertion.
- Every listed entity has a tested action silhouette appropriate to its available parts.
- Animation smoke passes.
- Runtime smoke is run only if shared enemy runtime hooks change.
