# Back-end handoff: weapon animation timing event hooks

Статус: blocked (PM/Jira sync required before dispatch)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Animator handoff from SCRUM-187
Jira: TBD (PM/task owner must create/sync before dispatcher can route)

## Dispatcher Note (2026-06-13)
Not dispatched. This handoff has a task file and board row, but no Jira key.
Dispatcher must not create Jira issues; PM/task owner needs to create/sync the
SCRUM issue and update this file plus `docs/process/task_board.md` before the
Back-end thread can receive it.

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
