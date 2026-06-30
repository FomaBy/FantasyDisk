# Refactor Wave: Player Stats, Damage, Equip And Weapon Cleanup

Jira: SCRUM-709
Статус: new
Приоритет: P1
Роль: Back-end / player quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-player, area-weapons
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task isolates the player runtime layer for the Claude refactor wave. It must not overlap the dedicated `class_weapon.gd` and summon tasks except through public contracts.

## Scope / Locked Paths

- `scripts/player.gd`
- `tests/runtime_smoke_weapon_mechanics_test.gd`
- Optional new `tests/player_*`
- `docs/design/systems/characters_weapons.md`
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor Player responsibilities: character configuration, derived stats/modifiers, HP/damage/dodge/defense, weapon equip/unequip, aim direction cache, level-up reward application, ultimate hooks and cleanup of weapon/effect leftovers on character/run transitions.

## Acceptance Criteria

- Player stat/equip/cleanup audit is recorded in the result.
- Real bugs or fragile side effects are fixed with focused tests.
- Weapon cleanup on character swap, death, return to menu and new run is preserved or strengthened.
- No class balance or weapon identity changes are made without explicit evidence.
- Docs update only if player runtime contract changes.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
