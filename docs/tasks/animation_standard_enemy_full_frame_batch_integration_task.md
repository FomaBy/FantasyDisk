# Animator: Standard enemy full-frame batch integration

Статус: in_progress
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-364
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 is still Design-owned and in progress for the full enemy/elite/boss
roster, but its manifest now contains accepted transparent full-frame sheets for
five additional standard enemies after the already integrated `rift_cutter` pilot:

- `ash_marksman`
- `spark_runner`
- `stone_bruiser`
- `bone_caller`
- `void_mage`

Animator may integrate these accepted standard enemy sheets without changing
gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 sheets into runtime SpriteFrames.
- Register the five standard enemies in `FullFrameAnimationRegistry`.
- Add animation smoke coverage for frame counts, loop flags, state aliases and
  enemy scene `FullFrameBody` activation where runtime scenes exist.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Acceptance Criteria
- [ ] Each enemy has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [ ] Runtime full-frame registry resolves all five `enemy/<id>` entries.
- [ ] Existing enemy scenes using these canonical IDs create visible
      `FullFrameBody` while hiding legacy fallback body.
- [ ] Animation-director manifest validates.
- [ ] `tests/animation_smoke_test.gd` passes.
- [ ] No gameplay/balance/AI changes.

## Result
Pending.
