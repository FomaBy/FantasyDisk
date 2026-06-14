# Back-end: Full-frame death playback lifecycle before cleanup

Статус: new
Приоритет: high
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-370
Jira: SCRUM-379

## Context
SCRUM-370 requires drawn full-frame death animations to play before entity
removal. Animator audit confirmed the registry already supports the `death`
state, and standard enemy SpriteFrames already include explicit death rows.
However runtime death paths still call `spawn_death_ghost()` directly for enemy
and player death, while ally minion death has no full-frame playback lifecycle.

Audit artifact:
`build/qa/animation_integrate_all_move_attack_death_states/coverage.md`

Relevant files:
- `scripts/full_frame_animation_registry.gd`
- `scripts/enemy.gd`
- `scripts/player.gd`
- `scripts/ally_minion.gd`
- `tests/animation_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

## Scope
Implement Back-end runtime lifecycle support only. Do not generate art, change
balance, damage, targeting, spawn rules, loot values, score values, or UI.

## Requirements
- When an entity has a `FullFrameBody` with explicit `death` animation, play
  `FullFrameAnimationRegistry.play_state(body, "death", last_direction)` before
  freeing/removing the entity.
- Keep existing `spawn_death_ghost()` as fallback for entities without explicit
  full-frame `death`.
- Preserve loot drops, score/XP awards, death save, cleanup timers, and pause
  compatibility.
- Add/update tests so standard enemies prove full-frame death is selected before
  cleanup, while fallback ghost behavior still works when no death frames exist.
- If a tiny signal/API is needed for Animator-owned timing validation, document it
  in the task result; do not alter animation art.

## Acceptance Criteria
- [ ] Standard full-frame enemies play `death` before removal.
- [ ] Fallback death ghost still works for missing death rows.
- [ ] Player/ally/enemy lifecycle remains stable; no duplicate loot/score/cleanup.
- [ ] `tests/animation_smoke_test.gd` and `tests/runtime_smoke_test.gd` pass.
