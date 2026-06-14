# Animator: Shard Marshal full-frame integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-371
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 Design manifest now contains an accepted transparent full-frame sheet
for `shard_marshal`:

- `shard_marshal`: `move`, `attack_primary`, `skill_shard_fan`,
  `skill_command_pulse`

This satisfies the `fantasydisk-animation-director` elite rule: full-frame
production sheet with 5+ movement frames, 5+ primary attack frames, and 2+
skill-specific attack rows. Animator may integrate this accepted sheet without
changing gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 `shard_marshal` sheet into runtime
  SpriteFrames.
- Register `shard_marshal` in `FullFrameAnimationRegistry` under `elite`.
- Extend animation smoke coverage for frame counts, loop flags, skill-state
  resolution and `EliteCommander.tscn` `FullFrameBody` activation.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for this accepted sheet.

## Out of Scope
- Gameplay/balance/AI/targeting changes.
- Mini-elite runtime visual-ID selection. Mini-elite sheets are present in
  SCRUM-352 but require runtime support to prefer `mini_elite_kind` over base
  `elite_behavior`; this should be handled as a Back-end visual-registry handoff.

## Acceptance Criteria
- [x] `shard_marshal` has runtime `move` 6f loop and `attack_primary`/`attack`
      6f one-shot.
- [x] `shard_marshal` exposes `skill_shard_fan` and `skill_command_pulse` as
      6f one-shots plus `attack_*` validator aliases.
- [x] Runtime full-frame registry resolves `elite/shard_marshal`.
- [x] `EliteCommander.tscn` creates visible `FullFrameBody` while hiding legacy
      fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged the accepted SCRUM-352 `shard_marshal` full-frame sheet into runtime
  SpriteFrames: `assets/sprites/elites/full_frame/shard_marshal_spriteframes.tres`.
- Registered `shard_marshal` under `FullFrameAnimationRegistry` kind `elite`;
  legacy `Body` remains fallback and is hidden only when the registry
  SpriteFrames load successfully.
- Added 6-frame `move` loop, 6-frame one-shot `attack`/`attack_primary`,
  `skill_shard_fan`, `skill_command_pulse`, and matching `attack_*` validator
  aliases on the same skill frames.
- Extended full-frame animation smoke coverage for `EliteCommander.tscn`
  activation, skill/alias frame counts, loop flags, direction flip, and backend
  phase string resolution (`shard_marshal:shard_fan:windup` ->
  `skill_shard_fan`).
- QA artifacts: `build/qa/animation_shard_marshal_full_frame_integration/`
  contains the animation manifest, contact sheet and GIF previews.

Verification:
- `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_shard_marshal_full_frame_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --editor --quit` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
