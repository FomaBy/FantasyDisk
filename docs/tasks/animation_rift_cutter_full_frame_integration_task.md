# Animator: Rift Cutter full-frame pilot integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-363
QA: in_progress (2026-06-14)
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
- [x] `rift_cutter` has runtime `move` 6f loop, `attack_primary`/`attack` 6f
      one-shot, `hit` 6f one-shot and `death` 6f one-shot.
- [x] Runtime full-frame registry resolves `enemy/rift_cutter` and Enemy scene
      creates visible `FullFrameBody` while hiding legacy fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged the accepted SCRUM-352 `rift_cutter` pilot into padded `384x384`
  runtime frames under `assets/sprites/enemies/full_frame/rift_cutter/` and
  generated `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres`.
- Registered `enemy/rift_cutter` in `scripts/full_frame_animation_registry.gd`
  as a visual-only full-frame override. Runtime keeps the old static/cutout
  fallback if frames fail to load.
- Added animation smoke coverage for registry resolution, frame counts, loop
  flags, state aliases, `Enemy.tscn` `FullFrameBody` activation, right-facing
  flip and hidden fallback `Body`.
- QA artifacts: `build/qa/animation_rift_cutter_full_frame_integration/`.

Verification:
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_rift_cutter_full_frame_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — первый реальный потребитель FullFrameAnimationRegistry (SCRUM-351):
- **SpriteFrames** (load в Godot) `rift_cutter_spriteframes.tres`: `move(6,loop=true)`,
  `attack_primary(6,loop=false)`, `attack(6,loop=false alias)`, `hit(6,loop=false)`,
  `death(6,loop=false)` — точно по acceptance.
- **Реестр**: `full_frame_animation_registry.gd:39` — `enemy/rift_cutter` →
  spriteframes-путь (visual-only override; при сбое загрузки — старый static/cutout
  fallback).
- **Манифест-валидатор** (skill): «FantasyDisk animation manifest OK: 1 entities».
- **Контакт-лист** `rift_cutter_contact_sheet.png` + 4 GIF: full-frame с реальной
  пер-кадровой вариацией — move (ходьба), attack_primary (замах→пурпурный слэш→
  возврат), hit (реакция), death (прогрессивный коллапс); не cutout.
- **Тесты**: `animation_smoke_test` (registry-резолв / frame counts / loop flags /
  state aliases / `Enemy.tscn` FullFrameBody activation / right-flip / hidden
  fallback Body) + `runtime_smoke_test` (gameplay не изменён) — passed.

Acceptance:
- [x] move 6f loop + attack_primary/attack 6f + hit 6f + death 6f (one-shot).
- [x] Registry резолвит enemy/rift_cutter; FullFrameBody виден, legacy скрыт.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Баги: нет.
