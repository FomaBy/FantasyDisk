# Back-end handoff: boss full-frame skill state hooks

Статус: in_progress
Приоритет: medium
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator (Codex)
Jira: SCRUM-378
Parent: SCRUM-377 / `animation_boss_full_frame_batch_integration_task.md`

## Context
SCRUM-377 integrated accepted SCRUM-352 full-frame SpriteFrames for all five
bosses:

- `rift_warden`: `skill_gravity_well`, `skill_rift_zone`
- `disk_devourer`: `skill_vampiric_bite`, `skill_rift_zone`
- `bone_archon`: `skill_skull_volley`, `skill_bone_prison`
- `brood_mother`: `skill_brood_spawn`, `skill_web_zone`
- `ashen_colossus`: `skill_molten_slam`, `skill_armor_pulse`

The registry resolves these states, and boss scenes create `FullFrameBody`.
However, current boss mechanics callbacks mostly spawn hazards/projectiles/zones
without explicitly playing the skill-specific visual states. Animator should not
edit boss gameplay/timing logic directly.

## Request
Add visual-only boss skill playback hooks so boss mechanics can request the
matching full-frame skill state without changing damage, balance, targeting,
cooldowns, spawn rules or hazard timing.

Suggested mapping:
- `rift_warden`: gravity well -> `skill_gravity_well`; rift zone/wave -> `skill_rift_zone`
- `disk_devourer`: vampiric bite -> `skill_vampiric_bite`; rift zone/wave -> `skill_rift_zone`
- `bone_archon`: skull volley -> `skill_skull_volley`; bone prison -> `skill_bone_prison`
- `brood_mother`: summon/brood spawn -> `skill_brood_spawn`; web zone -> `skill_web_zone`
- `ashen_colossus`: slam/molten zone -> `skill_molten_slam`; armor pulse -> `skill_armor_pulse`

Use existing `FullFrameAnimationRegistry.play_state` / `_play_full_frame_state`
where possible; if no full-frame body exists, keep current cutout/static fallback.

## Acceptance Criteria
- [ ] Boss mechanics request the matching visual skill state when a registered
      full-frame boss SpriteFrames resource exists.
- [ ] Existing damage, hazards, cooldowns, targeting and spawn behavior are
      unchanged.
- [ ] Animation smoke or runtime smoke covers at least one boss skill-state hook.

## Result
Pending Back-end.
