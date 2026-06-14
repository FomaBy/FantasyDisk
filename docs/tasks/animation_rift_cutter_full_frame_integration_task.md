# Animator: Rift Cutter full-frame pilot integration

Статус: in_progress
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-363
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 is Design-owned full-frame sheet generation for enemies, elites and
bosses. The full asset set is still open, but Design produced a transparent
pilot sheet for `rift_cutter`:

- `assets/sprites/enemies/full_frame/rift_cutter_full_frame_sheet.png`
- `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`

Animator may integrate this accepted pilot without changing enemy gameplay,
balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the `rift_cutter` full-frame pilot into runtime SpriteFrames.
- Register `rift_cutter` in `FullFrameAnimationRegistry`.
- Add animation smoke coverage for frame counts, loop flags, state aliases and
  enemy `FullFrameBody` activation.
- Create animation-director manifest/contact preview under `build/qa/`.
- Update animation docs and registry notes only for this pilot.

## Acceptance Criteria
- [ ] `rift_cutter` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [ ] Runtime full-frame registry resolves `enemy/rift_cutter` and Enemy scene
      creates visible `FullFrameBody` while hiding legacy fallback body.
- [ ] Animation-director manifest validates.
- [ ] `tests/animation_smoke_test.gd` passes.
- [ ] No gameplay/balance/AI changes.

## Result
Pending.
