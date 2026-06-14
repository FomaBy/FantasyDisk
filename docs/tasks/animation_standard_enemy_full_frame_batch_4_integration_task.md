# Animator: Standard enemy full-frame batch 4 integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-367
QA: in_progress (2026-06-14)
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 remains Design-owned and in progress, but its manifest now contains
accepted transparent full-frame sheets for the next standard enemy batch:

- `bone_shaman`
- `winged_spark`

Animator may integrate these accepted standard enemy sheets without changing
gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 sheets into runtime SpriteFrames.
- Register both standard enemies in `FullFrameAnimationRegistry`.
- Extend animation smoke coverage for frame counts, loop flags, state aliases and
  enemy scene `FullFrameBody` activation.
- Preserve `winged_spark` source row `hover_flap`; expose runtime `hit` as a
  visual alias to keep the current enemy hit-state contract intact.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Acceptance Criteria
- [x] `bone_shaman` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [x] `winged_spark` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hover_flap` 6f loop, `hit` 6f alias, and `death` 6f one-shot.
- [x] Runtime full-frame registry resolves both `enemy/<id>` entries.
- [x] Existing enemy scenes using these canonical IDs create visible
      `FullFrameBody` while hiding legacy fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged accepted SCRUM-352 full-frame sheets for `bone_shaman` and
  `winged_spark` into padded `384x384` runtime frames under
  `assets/sprites/enemies/full_frame/<enemy_id>/`.
- Generated two SpriteFrames resources:
  `assets/sprites/enemies/full_frame/<enemy_id>_spriteframes.tres`.
- Registered both enemies in `scripts/full_frame_animation_registry.gd` as
  visual-only full-frame overrides. Static/cutout fallback remains intact if a
  SpriteFrames resource is missing or invalid.
- Preserved `winged_spark` source `hover_flap` row as a looped runtime animation
  and exposed `hit` as a non-loop alias to the same row so existing enemy hit
  state calls keep resolving.
- Extended `tests/animation_smoke_test.gd` to assert registry resolution,
  frame counts, loop flags, state aliases, right-facing flip,
  `winged_spark.hover_flap`, and `FullFrameBody` activation for
  `EnemyBoneShaman` and `EnemyFlyingRunner`.
- QA artifacts: `build/qa/animation_standard_enemy_full_frame_batch_4_integration/`
  with animation manifest, contact sheet, per-state GIFs, and summary.

Verification:
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_standard_enemy_full_frame_batch_4_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — attempted, blocked by unrelated SCRUM-361 Hero Select UI failure: `HeroSelectChooseButton` min height `42.48`, expected at least `72`.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — batch 4 (bone_shaman + winged_spark):
- **SpriteFrames** (load): `bone_shaman` — `move(6,loop=true)`, `attack_primary(6)`,
  `attack(6 alias)`, `hit(6)`, `death(6)`; `winged_spark` — те же + **`hover_flap(6,
  loop=true)`** (парящая левитация для летающего врага), `hit(6)` non-loop alias.
  Точно по acceptance.
- **Реестр**: `full_frame_animation_registry.gd` — оба `enemy/bone_shaman` +
  `enemy/winged_spark` (4 совпадения id+frames; visual-only, fallback цел).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 2 entities».
- **Контакт-лист** `standard_enemy_full_frame_batch_4_contact_sheet.png` + GIF:
  full-frame — bone_shaman (move/спелл-attack/hit/death), winged_spark (move/attack/
  hover_flap махание крыльями/death); не cutout.
- **Тесты**: `animation_smoke_test` (+ `winged_spark.hover_flap`, FullFrameBody для
  EnemyBoneShaman+EnemyFlyingRunner) + `runtime_smoke_test` — **оба passed**
  (прежний блокер SCRUM-361/356 Hero Select choose-button height устранён воркером
  интеграции unified panel; теперь runtime_smoke зелёный).

Acceptance:
- [x] bone_shaman: move 6f loop + attack_primary/attack 6f + hit 6f + death 6f.
- [x] winged_spark: + hover_flap 6f loop, hit 6f alias.
- [x] Registry резолвит оба; FullFrameBody виден; манифест валиден; smoke зелёные;
  gameplay/balance/AI не тронуты.

Баги: нет.
