# Animator: Standard enemy full-frame batch 3 integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-366
QA: in_progress (2026-06-14)
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
- [x] `small_biter` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [x] Runtime full-frame registry resolves `enemy/small_biter`.
- [x] `EnemyBiter.tscn` creates visible `FullFrameBody` while hiding legacy
      fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged the accepted SCRUM-352 full-frame sheet for `small_biter` into padded
  `384x384` runtime frames under `assets/sprites/enemies/full_frame/small_biter/`.
- Generated `assets/sprites/enemies/full_frame/small_biter_spriteframes.tres`.
- Registered `small_biter` in `scripts/full_frame_animation_registry.gd` as a
  visual-only full-frame override. Static/cutout fallback remains intact if the
  SpriteFrames resource is missing or invalid.
- Extended `tests/animation_smoke_test.gd` to assert registry resolution,
  frame counts, loop flags, state aliases, right-facing flip, and
  `FullFrameBody` activation for `EnemyBiter`.
- QA artifacts: `build/qa/animation_standard_enemy_full_frame_batch_3_integration/`
  with animation manifest, contact sheet, per-state GIFs, and summary.

Verification:
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_standard_enemy_full_frame_batch_3_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — batch 3 (small_biter):
- **SpriteFrames** (load) `small_biter_spriteframes.tres`: `move(6,loop=true)`,
  `attack_primary(6)`, `attack(6 alias)`, `hit(6)`, `death(6)` — точно по acceptance.
- **Реестр**: `full_frame_animation_registry.gd:87` — `enemy/small_biter`
  (visual-only override, fallback цел).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 1 entities».
- **Контакт-лист** `small_biter_full_frame_contact_sheet.png` + GIF — full-frame.
- **Тесты**: `animation_smoke_test` — passed (registry-резолв / frame counts /
  loop flags / aliases / right-flip / FullFrameBody для EnemyBiter).

Acceptance:
- [x] small_biter: move 6f loop + attack_primary/attack 6f + hit 6f + death 6f.
- [x] Registry резолвит enemy/small_biter; FullFrameBody виден, legacy скрыт.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Примечание: на момент QA `runtime_smoke_test.gd` падал на Parse Error
(`_scaled_source_rect()` not found) — это АКТИВНЫЙ churn другого воркера (файл
Modified/uncommitted, mid-edit hero-select хелпера), НЕ изменение SCRUM-366 (трогал
только spriteframes + 1 строку реестра). Коммит вердикта green-gated до зелёного
runtime_smoke. Баги: нет (по 366).
