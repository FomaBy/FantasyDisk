# Animator: Standard enemy full-frame batch integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-364
QA: in_progress (2026-06-14)
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
- [x] Each enemy has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [x] Runtime full-frame registry resolves all five `enemy/<id>` entries.
- [x] Existing enemy scenes using these canonical IDs create visible
      `FullFrameBody` while hiding legacy fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged accepted SCRUM-352 full-frame sheets for `ash_marksman`,
  `spark_runner`, `stone_bruiser`, `bone_caller`, and `void_mage` into padded
  `384x384` runtime frames under `assets/sprites/enemies/full_frame/<enemy_id>/`.
- Generated five SpriteFrames resources:
  `assets/sprites/enemies/full_frame/<enemy_id>_spriteframes.tres`.
- Registered all five enemies in `scripts/full_frame_animation_registry.gd` as
  visual-only full-frame overrides. Static/cutout fallback remains intact if a
  SpriteFrames resource is missing or invalid.
- Extended `tests/animation_smoke_test.gd` to assert registry resolution,
  frame counts, loop flags, state aliases, right-facing flip, and
  `FullFrameBody` activation for `EnemyShooter`, `EnemyRunner`, `EnemyBruiser`,
  `EnemySummoner`, and `EnemyMage`.
- QA artifacts: `build/qa/animation_standard_enemy_full_frame_batch_integration/`
  with animation manifest, contact sheet, per-state GIFs, and summary.

Verification:
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_standard_enemy_full_frame_batch_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — batch 1 (5 врагов) потребителей FullFrameAnimationRegistry:
- **SpriteFrames** (load, проверка структуры): `ash_marksman`, `spark_runner`,
  `stone_bruiser`, `bone_caller`, `void_mage` — у КАЖДОГО `move(6,loop=true)`,
  `attack_primary(6,non-loop)`, `hit(6)`, `death(6)` — точно по acceptance (все 5 ✓).
- **Реестр**: `full_frame_animation_registry.gd` — все 5 `enemy/<id>` (10 совпадений
  id+frames; visual-only override, static/cutout fallback цел).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 5 entities».
- **Контакт-лист** `standard_enemy_full_frame_batch_contact_sheet.png` + GIF:
  full-frame, реальная пер-кадровая вариация (ash_marksman/spark_runner/stone_bruiser/
  bone_caller/void_mage — move/attack/hit/death); не cutout.
- **Тесты**: `animation_smoke_test` (registry-резолв / frame counts / loop flags /
  aliases / right-flip / FullFrameBody для EnemyShooter/Runner/Bruiser/Summoner/Mage)
  + `runtime_smoke_test` (gameplay не изменён) — passed.

Acceptance:
- [x] Каждый из 5 врагов: move 6f loop + attack_primary/attack 6f + hit 6f + death 6f.
- [x] Registry резолвит все 5 enemy/<id>; FullFrameBody виден, legacy скрыт.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Баги: нет.
