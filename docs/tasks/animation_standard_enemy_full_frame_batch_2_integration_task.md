# Animator: Standard enemy full-frame batch 2 integration

Статус: in_progress
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-365
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 remains Design-owned and in progress, but its manifest now contains
accepted transparent full-frame sheets for the next standard enemy batch:

- `venom_spitter`
- `rift_shieldbearer`

Animator may integrate these accepted standard enemy sheets without changing
gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 sheets into runtime SpriteFrames.
- Register both standard enemies in `FullFrameAnimationRegistry`.
- Extend animation smoke coverage for frame counts, loop flags, state aliases and
  enemy scene `FullFrameBody` activation.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Acceptance Criteria
- [ ] Each enemy has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [ ] Runtime full-frame registry resolves both `enemy/<id>` entries.
- [ ] Existing enemy scenes using these canonical IDs create visible
      `FullFrameBody` while hiding legacy fallback body.
- [ ] Animation-director manifest validates.
- [ ] `tests/animation_smoke_test.gd` passes.
- [ ] No gameplay/balance/AI changes.

## Result
Pending.
