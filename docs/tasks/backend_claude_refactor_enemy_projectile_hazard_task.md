# Refactor Wave: Enemy, Projectile And Hazard Runtime Cleanup

Jira: SCRUM-712
Статус: new
Приоритет: P1
Роль: Back-end / enemy quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-enemies, area-projectiles
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns normal enemy runtime, projectiles, hazards and enemy HP bars. Boss and elite pattern logic has a separate task.

## Scope / Locked Paths

- `scripts/enemy.gd`
- `scripts/enemy_projectile.gd`
- `scripts/projectile.gd`
- `scripts/hazard_vfx.gd`
- `scripts/enemy_health_bar.gd`
- Enemy/projectile scenes only if needed
- `docs/design/systems/enemies_bosses.md`
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor normal enemy runtime, player/enemy projectiles, hazard VFX and health bars: contact damage, movement animation cache, status effects, damage feedback labels, projectile bounds cleanup, pause/death behavior and resource loading. Preserve enemy roster and tuning unless a bug is proven.

## Acceptance Criteria

- Enemy/projectile/hazard lifecycle audit is recorded.
- No stale projectile/hazard/feedback nodes remain after cleanup paths.
- HP bar and damage feedback behavior remain correct for normal enemies, summoned enemies and scaled enemies.
- Resource loading in hot paths is removed or justified.
- Focused tests cover any fixed contract.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_projectile_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/projectile_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/hazard_vfx_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_content_integrity_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
