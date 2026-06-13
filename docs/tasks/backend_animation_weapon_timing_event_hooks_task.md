# Back-end handoff: weapon animation timing event hooks

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-13
Автор: Animator handoff from SCRUM-187
Jira: SCRUM-208

## Dispatcher Note (2026-06-13)
Jira sync blocker resolved: SCRUM-208 is now the source Jira issue for this
existing handoff. Ready for Back-end routing.

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Role / Scope
Back-end owns runtime weapon event APIs, VFX emission timing, and gameplay
phase callbacks. Animator owns pose curves and Animation smoke assertions.

Do not change weapon balance, damage, targeting, or spawn rules as part of this
handoff unless a separate Back-end task explicitly requests it.

## Context
SCRUM-187 added Animator-owned timing polish using existing
`action_id`/`action_variant` progress in `scripts/cutout_rig_2d.gd`. That is
enough for initial windup/release silhouettes, but several weapon modes have
delayed or repeated gameplay beats that Animator cannot sync to without a
runtime event surface.

## Modes Needing Event Hooks
- Delayed area/deploy: `grenade_cook`, `smoke_bomb`, `prism_rift`,
  `meteor_shards`, `hunter_trap`, `sound_amp`, `raven_totem`,
  `engineer_pressure_mines`.
- Multi-pulse/burst: `suppression_burst`, `priest_ward`, `bio_spore_bloom`,
  `bio_sample_dart`, `elemental_orbit`, `engineer_sentry_link`.
- Channel/beam/chain: `drain_link`, `beam`, `dot_beam`,
  `priest_prayer_chain`, `bio_symbiote_web`, `engineer_repair_drone`.

## Proposed API Shape
Expose optional animation timing events without changing existing gameplay
outputs:
- `play_action_animation(action_id, direction, phase := "", duration := 0.0)`
  or equivalent side-channel on the player rig owner.
- Suggested phase names: `windup`, `release`, `pulse`, `recover`.
- Duration should be derived from existing weapon timing (`grenade_delay`,
  `burst_interval`, `amp_lifetime`, etc.), not new Animator constants.

## Acceptance Criteria
- Animator can receive phase/timing metadata for delayed, pulse, and channel
  weapon modes without reading weapon internals directly.
- Existing weapon behavior and balance remain unchanged.
- Runtime smoke and animation smoke pass after integration.
- `docs/design/systems/animation.md` documents the final API once implemented.
