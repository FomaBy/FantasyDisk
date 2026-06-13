# Design handoff: animation-ready boss and mini-elite parts

Статус: done (superseded 2026-06-13; covered by SCRUM-156)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-204
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`
Related: SCRUM-156 / `design_codex_new_bosses_mini_elites_sprites_task.md`

## Role / Scope
Design-owned. Animator must not redraw these sprites. Back-end gameplay/balance is out of scope.

## Context
The animation audit found that the new bosses and mini-elites are still documented as placeholder/tinted existing boss or elite visuals until SCRUM-156. This blocks high-quality cutout animation because Animator needs canonical source sprites with clear separable parts.

## Needed Assets
- `assets/sprites/bosses/boss_bone_archon.png`
- `assets/sprites/bosses/boss_brood_mother.png`
- `assets/sprites/bosses/boss_ashen_colossus.png`
- Six mini-elite source sprites matching `scripts/progression_data.gd::MINI_ELITE_KINDS`.

## Animation-Friendly Requirements
- Front/top-down readable dark-fantasy cartoon silhouettes matching existing characters/enemies.
- Transparent background, clean alpha, no square placeholder backing.
- Separable limbs or secondary parts appropriate to the creature: arms, wings, legs, head/torso, shield, tail, swarm abdomen, bone staff, slam fists, or equivalent.
- Clear attack silhouettes for summon/volley/wall, brood/spawn/web/dash, slam/ember/radial burst, and each mini-elite behavior.
- Avoid baked poses that prevent neutral idle assembly.

## Handoff Back To Animator
When Design assets are ready, create or unblock an Animator task for:
- slicing cutout parts;
- updating `scripts/sliced_rig_manifest.gd`;
- adding boss/mini-elite motion profiles and action pose hooks;
- extending animation smoke coverage.

## Acceptance Criteria
- Final source sprites exist at stable paths.
- Contact sheet or preview confirms readable silhouettes and transparent alpha.
- Animator receives a clear unblock note with source paths and any intended separable parts.

## Dispatcher Note (2026-06-13)
Duplicate audit: this scope is covered by active `design_codex_new_bosses_mini_elites_sprites_task.md` / Jira `SCRUM-156`. Requirements were sent to the Design thread as additional acceptance context for SCRUM-156 instead of dispatching a duplicate source task.
