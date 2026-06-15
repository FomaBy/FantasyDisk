# Back-end: Full-frame death playback lifecycle before cleanup

Статус: done
Приоритет: high
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-370
Jira: SCRUM-379
QA: in_progress (2026-06-14)

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
- [x] Standard full-frame enemies play `death` before removal.
- [x] Fallback death ghost still works for missing death rows.
- [x] Player/ally/enemy lifecycle remains stable; no duplicate loot/score/cleanup.
- [x] `tests/animation_smoke_test.gd` and `tests/runtime_smoke_test.gd` pass.

## Result
Done 2026-06-14.

- `Enemy.take_damage()` now emits rewards/death once, then uses explicit
  `FullFrameBody.death` playback before delayed cleanup when available.
- Full-frame dying enemies immediately leave combat groups, stop processing,
  disable collision, hide HP bars and old cutout rigs, so combat/boss cleanup
  does not wait on a visual-only corpse.
- Missing full-frame death rows keep the existing `DeathGhostRig` fallback.
- `AllyMinion` already has matching full-frame death lifecycle support and keeps
  immediate cleanup when no `death` row is present.
- `tests/animation_smoke_test.gd` now proves both explicit full-frame death and
  fallback ghost behavior.

Verification:
- `git diff --check` — PASS
- `Godot --headless --script res://tests/animation_smoke_test.gd` — PASS
- `Godot --headless --script res://tests/summoner_strengthening_test.gd` — PASS
- `Godot --headless --script res://tests/runtime_smoke_boss_elite_test.gd` — PASS
- `Godot --headless --script res://tests/runtime_smoke_test.gd` — PASS

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — death-lifecycle с защитой инвариантов:
- **Once-only guard** (enemy.gd:218): `if _death_lifecycle_started: return` в начале
  `take_damage` — повторный урон по умирающему НИЧЕГО не делает (нет двойной смерти/
  наград/cleanup). Флаг ставится сразу при health<=0 (237).
- **Награды один раз** (240): `died.emit(self)` ровно однократно под guard —
  loot/score/XP выдаются независимо от визуала смерти (комментарий подтверждает).
- **Death-playback или fallback** (243-249): при ЯВНОЙ full-frame `death` →
  `_play_full_frame_death_then_free`; иначе `spawn_death_ghost()` + queue_free.
- **Мёртвый враг не мешает cleanup** (252-274): set_physics_process/process(false),
  remove_from_group по ВСЕМ combat-группам (enemies/bosses/elite_enemies/
  summoned_enemies, 258-260), collision disabled (261-263), HP-бар + cutout rig
  скрыты (264-269) → бой/босс не ждут визуальный труп, врага нельзя добить повторно;
  death играет (270), free по длительности (clamp 0.25-1.2с).
- **Ally** (ally_minion.gd:247-259): аналогичный full-frame death + immediate cleanup
  при отсутствии death-ряда.
- **Тесты**: `animation_smoke_test` (explicit full-frame death + fallback ghost) +
  `runtime_smoke_test` + `runtime_smoke_boss_elite_test` + `summoner_strengthening_test`
  — все passed.

Acceptance:
- [x] Стандартные full-frame враги играют death до удаления.
- [x] Fallback death-ghost для отсутствующих death-рядов.
- [x] Lifecycle стабилен; НЕТ дублей loot/score/cleanup (guard + once-emit + group-leave).
- [x] animation_smoke + runtime_smoke зелёные.

Баги: нет. (Балансовый scope не тронут — урон/таргетинг/loot-значения без изменений.)
