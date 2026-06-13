# Animation: legacy player weapon pose hooks

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-186
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-only. Do not change gameplay balance, weapon damage, targeting, projectile logic, or Design art direction.

## Context
The animation audit found that `berserk` and the newest class wave have bespoke weapon-action silhouettes, while older playable classes mostly use generic `attack`, `shoot`, or `cast` fallbacks.

## Classes To Cover
- `dark_mage`: `dark_book`, `curse_orb`, `void_staff`.
- `guitarist`: `sound_wave_guitar`, `shock_riff`, `amp_totem`.
- `assassin`: `shadow_chakram`, `venom_dagger`, `death_mark`.
- `ranger`: `thorn_bow`, `hawk_companion`, `snare_trap`.
- `doctor`: `healing_staff`, `plague_mask`, `syringe_dart`.
- `chemist`: `acid_flask`, `volatile_orb`, `transmute_trap`.
- `knight`: `guardian_lance`, `shield_bash`, `banner_aura`.
- `druid`: `root_staff`, `wolf_charm`, `raven_totem`.

## Tasks
1. Add per-class action pose hooks in `scripts/cutout_rig_2d.gd`, using existing cutout parts and weapon socket only.
2. Keep walk/idle profiles distinct; do not flatten old profiles into one shared caster/ranged template.
3. Extend `tests/animation_smoke_test.gd` with readable silhouette assertions for each class's three weapon variants.
4. Update `docs/design/systems/animation.md` and this task with results.

## Acceptance Criteria
- Each listed class has three distinct weapon-action poses.
- Weapon socket remains readable near the acting hand/tool for all sampled poses.
- Animation smoke passes.
- Runtime smoke is run if shared runtime behavior changes; otherwise note why it was not needed.
