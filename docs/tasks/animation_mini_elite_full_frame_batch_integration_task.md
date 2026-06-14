# Animator: Mini-elite full-frame batch integration

Статус: in_progress
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-376
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`
Unblocked by: SCRUM-372 / `backend_mini_elite_full_frame_visual_id_handoff_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 Design manifest contains accepted transparent full-frame sheets for all
six mini-elites, and SCRUM-372 added the runtime visual-id hook so registered
`mini_elite_kind` SpriteFrames can override the base route elite visual:

- `mini_scavenger_reaper`: `move`, `attack_primary`, `skill_reaping_dash`,
  `skill_bleed_finish`
- `mini_plague_bellringer`: `move`, `attack_primary`, `skill_bell_toll`,
  `skill_poison_pool`
- `mini_bone_warden`: `move`, `attack_primary`, `skill_bone_guard`,
  `skill_slam_wave`
- `mini_spark_wight`: `move`, `attack_primary`, `skill_spark_fan`,
  `skill_static_field`
- `mini_rot_hound`: `move`, `attack_primary`, `skill_rot_lunge`,
  `skill_bleed_howl`
- `mini_shadow_devourer`: `move`, `attack_primary`, `skill_shadow_blink`,
  `skill_devour_bite`

## Scope
- Slice/package the accepted SCRUM-352 mini-elite sheets into runtime
  SpriteFrames.
- Register all six mini-elites in `FullFrameAnimationRegistry` under `elite`.
- Extend animation smoke coverage for frame counts, loop flags, skill-state
  resolution, `mini_elite_kind` visual override, fallback behavior and
  representative scene `FullFrameBody` activation.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Out of Scope
- Gameplay/balance/AI/targeting/spawn changes.
- New source art or redraw.

## Acceptance Criteria
- [ ] Each mini-elite has runtime `move` 6f loop and
      `attack_primary`/`attack` 6f one-shot.
- [ ] Each mini-elite exposes both accepted `skill_*` rows as 6f one-shots plus
      `attack_*` validator aliases.
- [ ] Runtime full-frame registry resolves all six `elite/mini_*` entries.
- [ ] `mini_elite_kind` refresh creates visible mini-specific `FullFrameBody`
      while preserving route elite fallback when mini frames are missing.
- [ ] Animation-director manifest validates.
- [ ] `tests/animation_smoke_test.gd` passes.
- [ ] No gameplay/balance/AI changes.

## Result
Pending.
