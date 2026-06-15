# Animator: Route elite full-frame batch integration

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator heartbeat watcher
Jira: SCRUM-368
QA: in_progress (2026-06-14)
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope Animator work. Не спрашивать подтверждение.

## Context
SCRUM-352 remains Design-owned and in progress, but its manifest now contains
accepted transparent full-frame sheets for route elites:

- `iron_bastion`: `move`, `attack_primary`, `skill_shield_block`, `skill_slam_wave`
- `night_stalker`: `move`, `attack_primary`, `skill_shadow_strike`, `skill_phase_dash`
- `plague_prophet`: `move`, `attack_primary`, `skill_poison_volley`, `skill_plague_aura`

These satisfy the `fantasydisk-animation-director` elite rule: full-frame
production sheets with 5+ movement frames, 5+ primary attack frames, and 2+
skill-specific attack rows. Animator may integrate these accepted sheets without
changing gameplay, balance, targeting, damage, spawn rules or AI.

## Scope
- Slice/package the accepted SCRUM-352 elite sheets into runtime SpriteFrames.
- Register all three route elites in `FullFrameAnimationRegistry` under `elite`.
- Extend animation smoke coverage for frame counts, loop flags, skill-state
  resolution and elite scene `FullFrameBody` activation.
- Create animation-director manifest/contact previews under `build/qa/`.
- Update animation docs and registry notes only for these accepted sheets.

## Acceptance Criteria
- [x] Each elite has runtime `move` 6f loop and `attack_primary`/`attack` 6f
      one-shot.
- [x] Each elite exposes both accepted `skill_*` rows as 6f one-shots.
- [x] Runtime full-frame registry resolves all three `elite/<id>` entries.
- [x] Existing elite scenes create visible `FullFrameBody` while hiding legacy
      fallback body.
- [x] Animation-director manifest validates.
- [x] `tests/animation_smoke_test.gd` passes.
- [x] No gameplay/balance/AI changes.

## Result
Done 2026-06-14.

- Packaged accepted SCRUM-352 full-frame elite sheets into runtime SpriteFrames:
  `iron_bastion_spriteframes.tres`, `night_stalker_spriteframes.tres`, and
  `plague_prophet_spriteframes.tres`.
- Registered all three route elites under `FullFrameAnimationRegistry` kind
  `elite`; legacy `Body` remains fallback and is hidden only when the registry
  SpriteFrames load successfully.
- Added 6-frame `move` loops, 6-frame one-shot `attack`/`attack_primary`,
  two 6-frame one-shot `skill_*` rows per elite, and validator-facing
  `attack_*` aliases on the same skill frames.
- Extended full-frame animation smoke coverage for elite registry resolution,
  loop flags, skill/alias frame counts, scene `FullFrameBody` activation,
  static body hiding, direction flip, and backend phase string resolution
  (`<elite_behavior>:<attack_id>:<phase>` -> accepted skill row).
- QA artifacts: `build/qa/animation_route_elite_full_frame_batch_integration/`
  contains the animation manifest, contact sheet and GIF previews.

Verification:
- `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_route_elite_full_frame_batch_integration/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --editor --quit` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED — первый ЭЛИТНЫЙ full-frame батч (2+ skill-ряда, elite-правило)

Проверено (фактически):
- **SpriteFrames** (load, у каждого elite ≥7 анимаций): `iron_bastion` —
  `move(6,loop)`, `attack_primary(6)`, `skill_shield_block(6)`, `skill_slam_wave(6)`;
  `night_stalker` — move/attack_primary + `skill_shadow_strike(6)`,
  `skill_phase_dash(6)`; `plague_prophet` — move/attack_primary +
  `skill_poison_volley(6)`, `skill_plague_aura(6)`. Все 6-кадровые; 2+ skill-ряда
  (elite full-frame правило выполнено).
- **Реестр**: `full_frame_animation_registry.gd:107/113/120` — все 3 под kind
  `elite` (visual-only, legacy Body fallback при сбое загрузки).
- **Манифест-валидатор**: «FantasyDisk animation manifest OK: 3 entities».
- **Контакт-лист** `route_elite_full_frame_contact_sheet.png` + GIF: full-frame,
  каждый skill — отдельный паттерн с реальной вариацией (shield-block/slam-wave,
  shadow-strike/phase-dash, poison-volley/plague-aura); не cutout.
- **Тесты**: `animation_smoke_test` (elite registry-резолв, skill/alias frame counts,
  FullFrameBody activation, flip, backend phase-string `<elite_behavior>:<attack_id>:
  <phase>` → skill-ряд) + `runtime_smoke_test` (gameplay не изменён) — passed.

Acceptance:
- [x] Каждый elite: move 6f loop + attack_primary/attack 6f.
- [x] Каждый elite: оба skill_* ряда как 6f one-shot.
- [x] Registry резолвит все 3 elite/<id>; FullFrameBody виден, legacy скрыт.
- [x] Манифест валиден; animation_smoke зелёный; gameplay/balance/AI не тронуты.

Баги: нет.
