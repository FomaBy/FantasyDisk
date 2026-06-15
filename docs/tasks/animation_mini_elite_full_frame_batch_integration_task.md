# Animator: Mini-elite full-frame batch integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-376
QA: in_progress (2026-06-14)
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
- [x] Each mini-elite has runtime `move` 6f loop and
      `attack_primary`/`attack` 6f one-shot.
- [x] Each mini-elite exposes both accepted `skill_*` rows as 6f one-shots plus
      `attack_*` validator aliases.
- [x] Runtime full-frame registry resolves all six `elite/mini_*` entries.
- [x] `mini_elite_kind` refresh creates visible mini-specific `FullFrameBody`
      while preserving route elite fallback when mini frames are missing.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged all six accepted SCRUM-352 mini-elite full-frame sheets into runtime
  SpriteFrames under `assets/sprites/elites/full_frame/`.
- Registered `mini_scavenger_reaper`, `mini_plague_bellringer`,
  `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, and
  `mini_shadow_devourer` under `FullFrameAnimationRegistry` kind `elite`.
- Added 6-frame `move` loops, 6-frame one-shot `attack`/`attack_primary`, two
  6-frame one-shot `skill_*` rows per mini-elite, and validator-facing
  `attack_*` aliases on the same skill frames.
- Extended animation smoke coverage for mini registry resolution, loop flags,
  skill/alias frame counts, `mini_elite_kind` visual override, fallback to base
  route elite visuals, static body hiding, direction flip, and phase-state
  resolution.
- QA artifacts: `build/qa/animation_mini_elite_full_frame_batch_integration/`
  contains the animation manifest, contact sheet and GIF previews.

Verification:
- `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_mini_elite_full_frame_batch_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --editor --quit` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED — батч 6 мини-элит (использует 372 visual-ID хук)

Проверено (фактически):
- **SpriteFrames** (load, все 6 ✓): `mini_scavenger_reaper`, `mini_plague_bellringer`,
  `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer` —
  у КАЖДОГО `move(6,loop=true)`, `attack_primary(6)` + 2 `skill_*` ряда 6f
  (+ attack_* validator-aliases). ALL_OK=true.
- **Реестр**: 12 совпадений (6 mini × id+frames) под kind `elite`
  (visual-only, route-elite fallback цел).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 6 entities».
- **Контакт-лист** `mini_elite_full_frame_contact_sheet.png` + GIF: 24 ряда
  анимаций (6 существ × move/attack/2 skill), distinct full-frame существа с
  пер-кадровой вариацией; не cutout.
- **Тесты**: `animation_smoke_test` (mini registry-резолв, skill/alias frame counts,
  `mini_elite_kind` visual override + fallback на route-elite, FullFrameBody
  activation, flip, phase-state) + `runtime_smoke_test` (gameplay не изменён) —
  passed.

Acceptance:
- [x] Каждая мини-элита: move 6f loop + attack_primary/attack 6f.
- [x] Каждая: оба skill_* ряда 6f + attack_* aliases.
- [x] Registry резолвит все 6 elite/mini_*; mini_elite_kind override + route fallback.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Баги: нет.
