# Backend: contact-stuck enemies must remain hittable by all player attacks

Статус: done
Контур: Codex
Owner: backend/codex-contact-stuck-attack-fix
Thread/Worker: codex-contact-stuck-attack-fix
Executor: Codex
Branch/worktree: `codex/scrum-monster-contact-attack-fix` at `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-monster-contact-attack-fix`
Locked paths: `scripts/combat_target_query.gd`, `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `tests/combat_target_query_cache_test.gd`, `tests/contact_stuck_attack_deadzone_test.gd`, focused weapon/runtime tests, relevant combat/balance docs, `docs/process/task_board.md`, `docs/process/jira_sync_map.json`
Jira: SCRUM-886

## Context / Problem

Пользователь сообщил: у всех персонажей атаки ломаются, когда монстр «прилипает»
к персонажу; из-за этого его невозможно ударить. Runtime-контракт оружия: все
атаки целятся в ближайшего живого врага, но контактный враг может оказаться
почти в позиции игрока, где направление до цели становится нулевым/слишком
коротким, а corridor/beam/melee полосы стартуют с offset перед игроком.

Эта задача — Back-end gameplay bugfix, не visual redraw и не numeric rebalance.

## Required Change

1. Сделать contact-stuck / overlapped enemy гарантированно валидной целью для
   всех классовых weapon modes и melee-форм, если он находится в пределах
   фактической ближней зоны оружия.
2. Убрать dead-zone от offset-start beams/corridors/strips: враг вплотную к
   игроку не должен оказаться «позади» первого пикселя луча/полосы.
3. Сохранить текущие attack ranges, cooldowns, DPS, target caps, falloff и
   weapon identities.
4. Не превращать это в enemy movement/pathfinding rewrite; если дополнительно
   нужен анти-залипательный movement pass, оформить отдельный follow-up.
5. Обновить focused tests и документацию.

## Acceptance Criteria

- Contact-stuck enemy at or near player center receives damage from representative
  weapon families: Berserk strip/sweep, class beam/corridor/wave, projectile or
  target-centered mode, and radial pulse.
- Existing melee/corridor range and angle rejection still passes for normal
  targets outside weapon geometry.
- `CombatTargetQuery` preserves sorted corridor results and cache behavior.
- No balance numbers or weapon config budgets are changed.
- Focused tests pass, plus runtime smoke green-gate before push.

## Verification Plan

- Add regression coverage for zero-distance/near-contact enemies in query and
  weapon targeting tests.
- Run focused smokes:
  - `tests/combat_target_query_cache_test.gd`
  - `tests/melee_weapon_targeting_test.gd`
  - `tests/runtime_smoke_weapon_mechanics_test.gd`
  - `tests/global_damage_balance_smoke_test.gd`
  - `tests/runtime_smoke_test.gd`

## Result / Evidence

- `CombatTargetQuery.in_segment()` now supports the same optional
  `back_allowance` contract as corridors.
- `ClassWeapon` uses a 40px back allowance only for line/corridor/segment starts
  that originate near the owner, covering beams, dot beams, vents, bayonet,
  suppression, compression and related player-origin line attacks without
  widening distant rifts/shards.
- `BerserkWeapon` accepts enemies inside a 40px contact rescue radius before
  strip/sweep/frustum rejection.
- Added `tests/contact_stuck_attack_deadzone_test.gd` covering Berserk strip,
  AoE projectile, boomerang, stab flurry, beam, dot beam, drain link, sound wave,
  bayonet brace, sniper lockshot, robot compression line, reactor vent and
  suppression burst against an enemy standing on the player.
- Updated combat/current-state/mechanics docs. No weapon config, DPS, cooldown,
  range, target cap, falloff or enemy movement values changed.

Verification:
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/contact_stuck_attack_deadzone_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/combat_target_query_cache_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` (Godot dummy renderer emitted a non-fatal texture warning during screenshot capture; umbrella smoke printed `Runtime smoke test passed.`)

Disk cleanup: transient Godot import cache removed before final report; task worktree removed after push to `origin/dev`.
