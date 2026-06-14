# Animator: Standard enemy full-frame batch 3 integration

Статус: in_progress
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: pending sync
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 remains Design-owned and in progress, but its manifest now contains an
accepted transparent full-frame sheet for the next standard enemy:

- `small_biter`

Animator may integrate this accepted standard enemy sheet without changing
gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 sheet into runtime SpriteFrames.
- Register `small_biter` in `FullFrameAnimationRegistry`.
- Extend animation smoke coverage for frame counts, loop flags, state aliases and
  `EnemyBiter` `FullFrameBody` activation.
- Create animation-director manifest/contact preview under `build/qa/`.
- Update animation docs and registry notes only for this accepted sheet.

## Acceptance Criteria
- [ ] `small_biter` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [ ] Runtime full-frame registry resolves `enemy/small_biter`.
- [ ] `EnemyBiter.tscn` creates visible `FullFrameBody` while hiding legacy
      fallback body.
- [ ] Animation-director manifest validates.
- [ ] `tests/animation_smoke_test.gd` passes.
- [ ] No gameplay/balance/AI changes.

## Result
Pending.
