# Animation: weapon timing and VFX sync audit follow-up

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Animator audit SCRUM-173
Jira: SCRUM-187
Parent: SCRUM-173 / `audit_animation_rig_coverage.md`

## Role / Scope
Animator-owned timing polish and pose specs only. If new gameplay callbacks, weapon event APIs, or VFX emission hooks are required, create a Back-end handoff instead of implementing weapon logic here.

## Context
Elite attacks expose windup/strike/recover phases to animation. Player class weapons mostly trigger a single `shoot` or `cast` action with `weapon_id` as variant, which gives a readable pose but not a formal multi-beat timing track for deploys, pulses, delayed effects, or repeated bursts.

Started by Animator/Codex on 2026-06-13. This task will implement only
Animator-owned timing polish available through existing `action_id`,
`action_variant`, and action duration data. Missing runtime event/VFX APIs will
be documented as Back-end handoff instead of added here.

## Tasks
1. Review class weapon modes with delayed, pulsed, deploy, beam, chain, or multi-hit behavior.
2. Define which modes need additional pose timing beats beyond the initial action pose.
3. Add Animator-side pose timing only where existing hooks already provide enough data.
4. Create a Back-end handoff for any required runtime event hooks or VFX timing API.
5. Add smoke assertions for any new timing states that remain Animator-owned.

## Acceptance Criteria
- [x] Weapon-action timing gaps are mapped by mode.
- [x] Animator-only timing polish is implemented where possible.
- [x] Back-end handoff exists for missing API/event hooks.
- [x] Animation smoke passes after implementation.

## Result
Done 2026-06-13 (Animator/Codex): Animator-owned timing polish now uses the
existing `action_id`, `action_variant`, and normalized action progress inside
`scripts/cutout_rig_2d.gd` for legacy player poses and enemy archetype poses.
Delayed/multi-pulse/deploy/channel modes that need exact runtime event timing
are mapped in Back-end handoff
`docs/tasks/backend_animation_weapon_timing_event_hooks_task.md`.

Verification:
- `tests/animation_smoke_test.gd` passed.
- `tests/runtime_smoke_test.gd` passed after the parallel SCRUM-207 shop stock
  fix landed in the shared workspace.

## QA-Вердикт
Ожидает QA. Если QA вернет PASSED, Jira SCRUM-187 можно переводить в
`Готово`; если FAILED, задачу нужно открыть заново с конкретным дефектом.
Jira sync note 2026-06-13: direct read/update from this environment is blocked
by Jira response `404 Issue does not exist or you do not have permission to see
it` for SCRUM-187; local source task is ready for QA verdict sync.

## Dispatcher Note (2026-06-13)
Dispatched to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` after user confirmed no feature freeze / backlog is eligible.
