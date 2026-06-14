# Animator: Boss full-frame batch integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-377
QA: in_progress (2026-06-14)
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

## QA-Вердикт (2026-06-14)
Статус: PASSED — батч 5 БОССОВ (завершает full-frame конвейер 26 сущностей SCRUM-352)

Проверено (фактически):
- **SpriteFrames** (load, все 5 ✓): `rift_warden`, `disk_devourer`, `bone_archon`,
  `brood_mother`, `ashen_colossus` — у КАЖДОГО `move(6,loop=true)`,
  `attack_primary(6)` + 2 `skill_*` ряда 6f (+ attack_* validator-aliases).
  ALL_OK=true.
- **Реестр**: 10 совпадений (5 boss × id+frames) под kind `boss`
  (`boss.gd extends enemy.gd` → наследует FullFrameBody-путь; legacy fallback цел).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 5 entities».
- **Контакт-лист** `boss_full_frame_contact_sheet.png` + GIF: 20 рядов анимаций
  (5 боссов × move/attack/2 skill), distinct full-frame боссы с пер-кадровой
  вариацией; не cutout.
- **Тесты**: `animation_smoke_test` (boss registry-резолв, skill/alias frame counts,
  FullFrameBody activation, static-sprite hiding, flip, skill-state) +
  `runtime_smoke_test` (gameplay не изменён) — passed.

Acceptance:
- [x] Каждый босс: move 6f loop + attack_primary/attack 6f.
- [x] Каждый: оба skill_* ряда 6f + attack_* aliases.
- [x] Registry резолвит все 5 boss/<id>; FullFrameBody виден, legacy скрыт.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Примечание: рантайм-вызов skill-специфичных full-frame состояний из боссовых
коллбэков — документированный Back-end follow-up
(`backend_boss_full_frame_skill_state_hooks_task.md`), visual-only; registry
state-resolution уже работает. Не дефект 377. Баги: нет.

**Веха**: full-frame конвейер SCRUM-352 завершён — все 26 сущностей
(11 врагов + 4 route-элиты + 6 мини-элит + 5 боссов) интегрированы через registry
SCRUM-351 (363/364/365/366/367/368/371/376/377), gameplay не тронут.
