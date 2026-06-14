# Back-end handoff: boss full-frame skill state hooks

Статус: done
Приоритет: medium
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator (Codex)
Jira: SCRUM-378
QA: in_progress (2026-06-14)
Parent: SCRUM-377 / `animation_boss_full_frame_batch_integration_task.md`

## Context
SCRUM-377 integrated accepted SCRUM-352 full-frame SpriteFrames for all five
bosses:

- `rift_warden`: `skill_gravity_well`, `skill_rift_zone`
- `disk_devourer`: `skill_vampiric_bite`, `skill_rift_zone`
- `bone_archon`: `skill_skull_volley`, `skill_bone_prison`
- `brood_mother`: `skill_brood_spawn`, `skill_web_zone`
- `ashen_colossus`: `skill_molten_slam`, `skill_armor_pulse`

The registry resolves these states, and boss scenes create `FullFrameBody`.
However, current boss mechanics callbacks mostly spawn hazards/projectiles/zones
without explicitly playing the skill-specific visual states. Animator should not
edit boss gameplay/timing logic directly.

## Request
Add visual-only boss skill playback hooks so boss mechanics can request the
matching full-frame skill state without changing damage, balance, targeting,
cooldowns, spawn rules or hazard timing.

Suggested mapping:
- `rift_warden`: gravity well -> `skill_gravity_well`; rift zone/wave -> `skill_rift_zone`
- `disk_devourer`: vampiric bite -> `skill_vampiric_bite`; rift zone/wave -> `skill_rift_zone`
- `bone_archon`: skull volley -> `skill_skull_volley`; bone prison -> `skill_bone_prison`
- `brood_mother`: summon/brood spawn -> `skill_brood_spawn`; web zone -> `skill_web_zone`
- `ashen_colossus`: slam/molten zone -> `skill_molten_slam`; armor pulse -> `skill_armor_pulse`

Use existing `FullFrameAnimationRegistry.play_state` / `_play_full_frame_state`
where possible; if no full-frame body exists, keep current cutout/static fallback.

## Acceptance Criteria
- [ ] Boss mechanics request the matching visual skill state when a registered
      full-frame boss SpriteFrames resource exists.
- [ ] Existing damage, hazards, cooldowns, targeting and spawn behavior are
      unchanged.
- [ ] Animation smoke or runtime smoke covers at least one boss skill-state hook.

## Result
Done 2026-06-14 (Back-end).

Implemented visual-only boss skill playback hooks in `scripts/boss.gd`:
- `rift_warden`: gravity well and rift zone/wave request `skill_gravity_well` / `skill_rift_zone`;
- `disk_devourer`: vampiric bite and rift zone/wave request `skill_vampiric_bite` / `skill_rift_zone`;
- `bone_archon`: skull volley and bone prison request `skill_skull_volley` / `skill_bone_prison`;
- `brood_mother`: brood spawn and web zones request `skill_brood_spawn` / `skill_web_zone`;
- `ashen_colossus`: molten slam and armor pulse request `skill_molten_slam` / `skill_armor_pulse`.

The hook first tries the registered `FullFrameBody` state and falls back to the
previous rig action (`cast`/`attack`/`shoot`) when no full-frame visual exists.
Damage, hazards, cooldowns, targeting, spawn counts, telegraph durations and
balance values were not changed.

Updated `tests/animation_smoke_test.gd` to verify representative boss
skill-state hook playback, and updated CHANGELOG plus animation/content/current
state/enemy-boss docs.

Verification:
- `git diff --check` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_boss_elite_test.gd` — passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED — visual-only skill-playback хуки боссов (закрывает follow-up 377)

Проверено (фактически):
- **Хуки** (boss.gd): `_play_boss_skill_visual(...)` вызывается для всех skill-
  состояний — `skill_gravity_well`(207), `skill_vampiric_bite`(246),
  `skill_bone_prison`(279), `skill_armor_pulse`(295), `skill_skull_volley`(389),
  `skill_molten_slam`(450), `skill_web_zone`(492), `skill_brood_spawn`(567),
  `skill_rift_zone`(587). Маппинг 5 боссов × 2 скилла покрыт.
- **Visual-only + fallback**: хелпер (580) `if skill_state != "" and
  _play_full_frame_state(skill_state, direction)` — сначала full-frame состояние,
  иначе откат на rig-action (`cast`/`attack`/`shoot`). Без правки damage/hazards/
  cooldowns/targeting/spawn/telegraph.
- **Тесты**: `animation_smoke_test` (boss skill-state hook playback) +
  `runtime_smoke_test` + `runtime_smoke_boss_elite_test` (boss/elite suite) —
  все passed.

Acceptance:
- [x] Боссовые механики запрашивают matching visual skill-state при наличии
  registered full-frame SpriteFrames.
- [x] damage/hazards/cooldowns/targeting/spawn не изменены (visual-only).
- [x] Animation/runtime smoke покрывают boss skill-state хук.

Баги: нет. Этим закрыт документированный follow-up из SCRUM-377 — full-frame
конвейер боссов полностью завершён (ассеты + интеграция + skill-visual хуки).
