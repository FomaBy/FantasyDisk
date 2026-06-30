# Refactor Wave: Combat Director Spawn, Arena, Rewards And Cleanup

Jira: SCRUM-708
Статус: new
Приоритет: P1
Роль: Back-end / combat quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-combat, area-spawn
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This is part of the Claude refactor wave for checking and improving the whole game by isolated sections. This task owns the combat lifecycle module, not player weapons or enemy internals.

## Scope / Locked Paths

- `scripts/combat_director.gd`
- `tests/runtime_smoke_combat_test.gd`
- Optional new `tests/combat_director_*`
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor CombatDirector around arena setup, spawn pacing, route scaling, combat timers, pickup/reward emission, world cleanup groups, hit-stop/shake ownership and combat end transitions. Preserve current balance values unless a concrete bug is found and covered.

## Acceptance Criteria

- Arena/spawn/reward cleanup contracts are reviewed and improved where safe.
- No broad balance retune is included without harness evidence.
- World cleanup removes temporary combat nodes without deleting persistent UI/run state.
- Focused combat tests cover any changed lifecycle behavior.
- Docs update only if runtime contract changes.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_combat_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_progression_economy_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
