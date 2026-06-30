# Refactor Wave: Progression Data Facade And Domain API Contracts

Jira: SCRUM-714
Статус: new
Приоритет: P1
Роль: Back-end / data quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-progression, area-data
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns the progression data facade and domain slices. It is a data/API quality pass, not a balance retune.

## Scope / Locked Paths

- `scripts/progression_data.gd`
- `scripts/progression_data_*.gd`
- Focused progression/content tests
- `docs/design/systems/progression_balance.md`
- `docs/design/content_registry.md` only if entity contracts change

## Required Change

Audit and safely refactor the ProgressionData facade/domain slices: public API stability, character/weapon/reward/shop/ascension/enemy data contracts, duplicate constants, missing IDs, backward-compatible aliases and data validation. Do not silently rename canonical IDs.

## Acceptance Criteria

- Public ProgressionData API remains compatible for runtime/tests.
- Missing/stale IDs are fixed or filed as follow-up with evidence.
- Data validation coverage is strengthened where gaps exist.
- No broad balance value changes are made in this task.
- Docs update only for changed data contracts.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/progression_data_api_surface_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/content_registry_consistency_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/content_rewards_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/class_progression_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
