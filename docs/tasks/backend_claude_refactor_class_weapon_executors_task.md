# Refactor Wave: Class Weapon Executor Registry And Attack Modes

Jira: SCRUM-710
Статус: new
Приоритет: P1
Роль: Back-end / weapon quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-weapons, area-combat
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns the non-Berserk class weapon runtime. It is intentionally separated from `player.gd`, Berserk melee and SummonerWeapon work to avoid locked-path overlap.

## Scope / Locked Paths

- `scripts/class_weapon.gd`
- Class weapon scenes under `scenes/*` only when the scene belongs to a touched weapon
- `tests/weapon_scene_integrity_test.gd`
- `docs/design/systems/characters_weapons.md`

## Required Change

Audit and safely refactor non-Berserk class weapon execution: `ATTACK_MODE_EXECUTORS`, `_fire_*` methods, damage type routing, VFX metadata, target query usage, deployable cleanup, attack cooldown state and data-driven config contracts for all 51 weapons.

## Acceptance Criteria

- Attack mode registry remains complete for every data-driven weapon mode.
- No weapon silently falls through or uses a wrong proxy scene/texture.
- Cleanup groups for deployables, temporary effects and projectiles remain reliable.
- Any behavior change is a verified bugfix, not an untracked balance/design change.
- Focused weapon tests are updated or added for changed contracts.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_scene_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
