# Back-end handoff: full-frame animation state registry

Статус: done
Приоритет: high
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator audit `animation_full_frame_pipeline_coverage_audit_task.md`
Исполнитель: Back-end
Jira: SCRUM-351
QA: in_progress (2026-06-14)
Parent: SCRUM-350 / `animation_full_frame_pipeline_coverage_audit_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Back-end работает автономно; если
обнаружится Animator-only motion polish, вернуть handoff в Animator.

## Role / Scope
Back-end runtime architecture only. Do not change balance, damage, targeting,
spawn rules, or Design art direction. Animator owns motion quality and final
state/pattern coverage once runtime hooks exist.

## Context
Current runtime broadly supports cutout rigs and `AllyMinion` SpriteFrames for
animated summons. The new animation standard needs a reusable full-frame state
registry for heroes/enemies/elites/bosses so Animator can map:

- `move` / `walk` / `run` / `levitate`;
- `attack_primary`;
- skill/phase attacks such as `attack_slam_wave`, `attack_shadow_strike`,
  boss phase attacks, and future class/summon patterns;
- hit/death fallback behavior without gameplay side effects.

Existing work SCRUM-208/SCRUM-239 exposes weapon phase events for cutout rig pose
sync, but it is not a general SpriteFrames state registry for non-player enemies
and bosses.

## Requirements
1. Add a data-driven full-frame animation registry or equivalent resource lookup
   that can coexist with current cutout rig fallback.
2. Support entity-kind IDs (`hero`, `enemy`, `summon`/`ally`, `elite`, `boss`) and
   canonical entity IDs without hardcoding every state in gameplay code.
3. Let Animator/Design-provided SpriteFrames play `move` loop and one-shot attack
   states without altering damage windows, targeting, or cooldowns.
4. Boss/elite skill phases must be addressable by animation state name/variant
   while gameplay remains the source of truth for actual mechanics.
5. Add smoke coverage that verifies missing SpriteFrames fall back cleanly and
   provided SpriteFrames do not crash runtime.

## Acceptance Criteria
- [x] Runtime can select full-frame SpriteFrames per entity/state when present.
- [x] Cutout rig fallback remains intact for entities without sheets.
- [x] Boss/elite skill animation state names can be passed through without
      changing skill mechanics.
- [x] Animation/runtime smoke tests pass.
- [x] Documentation and Jira/task board are synced.

## Result
Done 2026-06-14 by Back-end.

- Added `scripts/full_frame_animation_registry.gd`, a data-driven SpriteFrames
  registry/state adapter for `hero`, `enemy`, `ally`, `elite`, and `boss`
  entity kinds.
- Integrated `AllyMinion` with registry-backed source-specific full-frame
  visuals while preserving static PNG fallback.
- Integrated optional `FullFrameBody` lookup into `Enemy`/`Boss`; entities with
  no registered SpriteFrames continue using the existing cutout rig/static body.
- Elite attack phases can now pass animation state variants such as
  `<elite_behavior>:<attack_id>:<phase>` without changing mechanics, damage,
  targeting, cooldowns, or spawn rules.
- Extended `tests/animation_smoke_test.gd` with registry coverage for present
  SpriteFrames, missing-resource fallback, alias/state resolution, facing flip
  and enemy cutout fallback.

Verification:
- PASS `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`
- PASS `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Реестр** `scripts/full_frame_animation_registry.gd`: data-driven с 5 видами
  сущностей — `ally` (заполнен summon-записями), `enemy`/`elite`/`boss`/`hero`
  (пустые-но-готовые карты для будущей регистрации); `_resolve_animation_name`
  для alias/state-резолвинга; safe fallback (false/null) при отсутствии sheet.
- **Интеграция**: `ally_minion.gd` (registry-backed визуалы + static PNG
  fallback), `enemy.gd` (optional `FullFrameBody` lookup), `boss.gd extends
  enemy.gd` → наследует тот же путь; без зарегистрированных sheet → existing
  cutout-rig/static body (fallback цел).
- **Elite/boss фаза-варианты**: `elite_behavior` meta (enemy.gd:103) позволяет
  адресовать состояния `<behavior>:<attack>:<phase>` без правки механик/урона/
  targeting/cooldown/spawn.
- **Тесты**: `animation_smoke_test` (`_test_full_frame_animation_registry` —
  present sheets / missing-resource fallback / alias-резолв / facing flip / enemy
  cutout fallback) + `runtime_smoke_test` — оба passed.

Acceptance:
- [x] Runtime выбирает full-frame SpriteFrames по entity/state при наличии.
- [x] Cutout-rig fallback цел для сущностей без sheet.
- [x] Boss/elite имена состояний прокидываются без изменения механик.
- [x] animation/runtime smoke зелёные; доки/Jira синканы.

Баги: нет.
