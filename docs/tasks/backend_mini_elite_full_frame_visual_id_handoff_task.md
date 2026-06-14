# Back-end handoff: mini-elite full-frame visual id selection

Статус: done
Приоритет: high
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator (Codex)
Jira: SCRUM-372
Parent: SCRUM-352 / `design_enemy_elite_boss_full_frame_animation_sheets_task.md`

## Context
SCRUM-352 Design has accepted transparent full-frame sheets for mini-elites,
including:

- `mini_scavenger_reaper`: `move`, `attack_primary`, `skill_reaping_dash`,
  `skill_bleed_finish`
- `mini_plague_bellringer`: `move`, `attack_primary`, `skill_bell_toll`,
  `skill_poison_pool`
- `mini_bone_warden`: `move`, `attack_primary`, `skill_shield_bash`,
  `skill_bone_guard`

Animator can package these into SpriteFrames, but current runtime visual identity
for elite scenes is based on `elite_behavior` via
`Enemy._full_frame_entity_id("elite")`. Mini-elites are spawned from existing
elite scenes and get `mini_elite_kind` metadata after instantiation, while their
`elite_behavior` remains the base behavior (`night_stalker`,
`plague_prophet`, `iron_bastion`, etc.). Without a Back-end visual-ID hook,
mini-specific SpriteFrames cannot be selected reliably.

## Request
Add visual-only runtime support so mini-elite instances can select
`FullFrameAnimationRegistry` entries by `mini_elite_kind` when present, without
changing gameplay, balance, targeting, spawn rules, damage or AI.

Suggested safe behavior:
- When configuring a full-frame elite visual, prefer `get_meta("mini_elite_kind")`
  if it is set and `FullFrameAnimationRegistry.sprite_frames_for("elite", id)`
  exists.
- Otherwise fall back to the existing `elite_behavior` / enemy type resolution.
- Ensure mini-elite metadata is available before full-frame visual configuration,
  or reconfigure the visual after `_apply_mini_elite_kind`.
- Preserve existing static/cutout fallback when no mini-specific SpriteFrames
  entry exists.

## Animator Follow-up
After this Back-end support lands, Animator should create/take a child task to
package and register the accepted mini-elite sheets already present in SCRUM-352.

## Acceptance Criteria
- [x] Mini-elites with `mini_elite_kind` can resolve full-frame registry entries
      by that id.
- [x] Existing route elite full-frame visuals continue resolving by
      `elite_behavior`.
- [x] No gameplay/balance/AI changes.
- [x] Runtime smoke covers at least one mini-elite full-frame visual selection or
      a focused test documents the visual-only selection path.

## Result
Done 2026-06-14 (Codex Back-end). Added a visual-only mini-elite full-frame
resolver in `Enemy`: elite full-frame configuration now prefers registered
`mini_elite_kind` SpriteFrames and falls back to the base `elite_behavior` when
mini-specific frames are missing. `combat_director._apply_mini_elite_kind`
refreshes the visual after metadata is assigned, without changing stats, AI,
damage, targeting, rewards, or spawn rules.

Verification:
- `git diff --check` — PASS
- `animation_smoke_test.gd` — PASS; includes registered mini-kind override and
  missing mini-kind fallback coverage
- `runtime_smoke_test.gd` — PASS
