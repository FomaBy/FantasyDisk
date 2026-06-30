# Refactor Wave: Boss And Elite Runtime Patterns Audit

Jira: SCRUM-713
Статус: new
Приоритет: P1
Роль: Back-end / boss quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-boss, area-elite
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task isolates boss and elite runtime patterns from normal enemy/projectile cleanup. It should improve reliability without changing boss fantasy or encounter design.

## Scope / Locked Paths

- `scripts/boss.gd`
- Boss/elite scenes `scenes/Boss*.tscn`, `scenes/Elite*.tscn` only if needed
- `tests/runtime_smoke_boss_elite_test.gd`
- `docs/design/systems/enemies_bosses.md`

## Required Change

Audit and safely refactor boss/elite runtime patterns: phase transitions, hazard ownership, boss HUD/HP bar sync, summon caps, route elite vs mini-elite config, victory/death signaling and cleanup. Keep boss identities and visible mechanics intact unless fixing a verified defect.

## Acceptance Criteria

- Boss/elite pattern audit is recorded.
- Phase transitions, summon caps and cleanup are covered by focused tests.
- Victory/death signaling does not double-fire or leave stale nodes.
- Boss/elite identity, hazards and tuning remain stable unless fixing a proven defect.
- Docs update only if runtime contract changes.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/boss_summon_cap_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/mini_elite_roster_spawn_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/boss_elite_ttk_gate.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
