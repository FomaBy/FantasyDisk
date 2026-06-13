# Animation: enemy archetype motion coverage

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-184
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-only. Do not change enemy stats, attacks, spawn rules, collision, targeting, or Backend behavior.

## Context
The audit found broad cutout-rig coverage for enemies, but smoke assertions currently sample only a subset: baseline melee, flying wings, elite phases, boss rig, and enemy death ghost. Several enemies have intentionally partial rigs, so each archetype needs tailored motion coverage.

Started by Animator/Codex on 2026-06-13.

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
- [x] Every listed entity has a tested movement/readability assertion.
- [x] Every listed entity has a tested action silhouette appropriate to its available parts.
- [x] Animation smoke passes.
- [x] Runtime smoke passes.

## Result
Done 2026-06-13 (Animator/Codex): added enemy archetype action pose layer in
`scripts/cutout_rig_2d.gd` for marksman, runner, bruiser, summoner, mage,
spitter, shieldbearer, biter, bone shaman, winged spark, and Disk Devourer.
Extended `tests/animation_smoke_test.gd` with movement + action readability
coverage per listed archetype. No enemy stats, attacks, spawn rules, collision,
or targeting changed.

Verification:
- `tests/animation_smoke_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed after the parallel SCRUM-207 shop stock
  fix landed in the shared workspace.

## Dispatcher Note (2026-06-13)
Dispatched to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` after user confirmed no feature freeze / backlog is eligible.
