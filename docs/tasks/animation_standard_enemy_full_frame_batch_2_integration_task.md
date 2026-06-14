# Animator: Standard enemy full-frame batch 2 integration

Статус: done
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
- [x] Each enemy has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [x] Runtime full-frame registry resolves both `enemy/<id>` entries.
- [x] Existing enemy scenes using these canonical IDs create visible
      `FullFrameBody` while hiding legacy fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged accepted SCRUM-352 full-frame sheets for `venom_spitter` and
  `rift_shieldbearer` into padded `384x384` runtime frames under
  `assets/sprites/enemies/full_frame/<enemy_id>/`.
- Generated two SpriteFrames resources:
  `assets/sprites/enemies/full_frame/<enemy_id>_spriteframes.tres`.
- Registered both enemies in `scripts/full_frame_animation_registry.gd` as
  visual-only full-frame overrides. Static/cutout fallback remains intact if a
  SpriteFrames resource is missing or invalid.
- Extended `tests/animation_smoke_test.gd` to assert registry resolution,
  frame counts, loop flags, state aliases, right-facing flip, and
  `FullFrameBody` activation for `EnemySpitter` and `EnemyShield`.
- QA artifacts: `build/qa/animation_standard_enemy_full_frame_batch_2_integration/`
  with animation manifest, contact sheet, per-state GIFs, and summary.

Verification:
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_standard_enemy_full_frame_batch_2_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
