# Design: Full-frame death rows for allies, elites, mini-elites, and bosses

Статус: in_progress
Приоритет: high
Роль: Design
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-370
Jira: SCRUM-380

## Context
Animator coverage audit for SCRUM-370 found that current standard enemy
SpriteFrames already include explicit 6-frame `death` animations, but allies,
route elites, mini-elites, and bosses do not. They have accepted full-frame
`move`, `attack_primary`, and skill rows, so runtime cannot satisfy the new
director standard for drawn death animation without new source rows.

Audit artifact:
`build/qa/animation_integrate_all_move_attack_death_states/coverage.md`

## Scope
Create transparent full-frame `death` source rows/frames for the existing accepted
visual kits, preserving established scale, silhouette, frame size, naming, and
dark fantasy style. Do not change gameplay, balance, enemy behavior, or runtime
cleanup.

Required entities:
- Allies: `druid_beast`, `druid_pack_spirit`, `homunculus`, `leadership_echo`.
- Route elites: `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`.
- Mini-elites: `mini_scavenger_reaper`, `mini_plague_bellringer`,
  `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`,
  `mini_shadow_devourer`.
- Bosses: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`,
  `ashen_colossus`.

## Requirements
- Use the mandatory `fantasydisk-asset-generator` path for any generated art.
- Each `death` row must be full-frame, transparent PNG, 5+ frames, non-loop.
- Bosses/elites must remain production full-frame sprite sheet work, not cutout
  deformation of a static sprite.
- Keep existing frame-safe contact previews inside empty preview zones; do not
  place animated content on decorative frame borders.
- Preserve existing SpriteFrames paths and source sheet families where possible.
  Animator will integrate final rows into `.tres` resources after Design review.

## Acceptance Criteria
- [ ] 19 entities above have accepted transparent `death` rows/source frames.
- [ ] Contact sheet/preview shows readable death motion and no dirty background.
- [ ] Asset manifest records frame sizes, paths, and intended animation name
  `death`.
- [ ] Task is handed back to Animator/SCRUM-370 for SpriteFrames integration.
