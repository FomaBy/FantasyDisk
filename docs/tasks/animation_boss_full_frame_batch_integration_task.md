# Animator: Boss full-frame batch integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-377
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 Design manifest contains accepted transparent full-frame sheets for
five bosses:

- `rift_warden`: `move`, `attack_primary`, `skill_gravity_well`,
  `skill_rift_zone`
- `disk_devourer`: `move`, `attack_primary`, `skill_vampiric_bite`,
  `skill_rift_zone`
- `bone_archon`: `move`, `attack_primary`, `skill_skull_volley`,
  `skill_bone_prison`
- `brood_mother`: `move`, `attack_primary`, `skill_brood_spawn`,
  `skill_web_zone`
- `ashen_colossus`: `move`, `attack_primary`, `skill_molten_slam`,
  `skill_armor_pulse`

`boss.gd` extends `enemy.gd`, so the existing full-frame visual registry can
activate `FullFrameBody` for boss scenes without gameplay/balance changes.

## Scope
- Slice/package the accepted SCRUM-352 boss sheets into runtime SpriteFrames.
- Register all five bosses in `FullFrameAnimationRegistry` under `boss`.
- Extend animation smoke coverage for frame counts, loop flags, skill-state
  resolution and representative boss scene `FullFrameBody` activation.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Out of Scope
- Gameplay/balance/AI/targeting/spawn changes.
- Adding new boss skill timing callbacks. If runtime skill-specific playback is
  missing beyond registry state resolution, record a Back-end handoff.

## Acceptance Criteria
- [x] Each boss has runtime `move` 6f loop and `attack_primary`/`attack` 6f
      one-shot.
- [x] Each boss exposes both accepted `skill_*` rows as 6f one-shots plus
      `attack_*` validator aliases.
- [x] Runtime full-frame registry resolves all five `boss/<id>` entries.
- [x] Existing boss scenes create visible `FullFrameBody` while hiding legacy
      fallback sprite.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged all five accepted SCRUM-352 boss full-frame sheets into runtime
  SpriteFrames under `assets/sprites/bosses/full_frame/`.
- Registered `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, and
  `ashen_colossus` under `FullFrameAnimationRegistry` kind `boss`.
- Added 6-frame `move` loops, 6-frame one-shot `attack`/`attack_primary`, two
  6-frame one-shot `skill_*` rows per boss, and validator-facing `attack_*`
  aliases on the same skill frames.
- Extended animation smoke coverage for boss registry resolution, loop flags,
  skill/alias frame counts, scene `FullFrameBody` activation, static sprite
  hiding, direction flip and skill-state resolution.
- QA artifacts: `build/qa/animation_boss_full_frame_batch_integration/` contains
  the animation manifest, contact sheet and GIF previews.
- Back-end follow-up needed: boss mechanics do not yet call skill-specific
  full-frame states from their runtime callbacks. Animator created
  `backend_boss_full_frame_skill_state_hooks_task.md` for visual-only hooks.

Verification:
- `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_boss_full_frame_batch_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --editor --quit` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
