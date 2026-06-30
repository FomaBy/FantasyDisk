# Refactor Wave: Stat Formulas And Balance Harness Reliability

Jira: SCRUM-715
Статус: done
Приоритет: P1
Роль: Back-end / balance quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-balance, area-formulas
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers formula and harness reliability. If class/weapon balance itself needs tuning, Claude must produce evidence and preferably create a separate balance task.

## Scope / Locked Paths

- `scripts/stat_formulas.gd`
- Balance tools under `tools/*balance*.gd`, `tools/class_damage_table_3variants.gd` only if needed
- Balance tests/reports
- `docs/design/systems/progression_balance.md`

## Required Change

Audit and safely refactor formulas and harnesses: derived parameter explanations, diminishing returns, balance report determinism, class/weapon budget gates, live simulation assumptions and stale report generation. Preserve tuned values unless the harness proves a current bug.

## Acceptance Criteria

- Formula/harness audit is recorded.
- Harnesses are deterministic and fail with useful evidence.
- Formula descriptions and runtime derived parameters stay in sync.
- No silent retune is made without before/after report.
- Updated reports are committed only when regenerated intentionally.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/stat_formulas_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/class_damage_table_3variants_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
