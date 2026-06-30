# Refactor Wave: Runtime Smoke And Focused Test Suite Architecture

Jira: SCRUM-722
Статус: done
Приоритет: P1
Роль: Back-end / test quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-tests, area-quality
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

The umbrella smoke and focused smoke suite are now large enough to deserve their own quality pass. This task must improve tests without rewriting gameplay.

## Scope / Locked Paths

- `tests/runtime_smoke_test.gd`
- Focused `tests/runtime_smoke_*`
- `tests/test_jira_board_sync.py`
- Optional test helpers under `tests/`
- `docs/design/systems/technical_architecture.md`

## Required Change

Audit and safely refactor the test suite architecture: reduce duplicated setup in the huge umbrella smoke, keep focused suites aligned, remove flaky waits, improve assertion messages/evidence dumps and ensure tests fail on missing critical UI/content instead of silently passing. Do not change gameplay code except tiny testability hooks with strict review evidence.

## Acceptance Criteria

- Test-suite audit is recorded.
- Umbrella smoke remains representative and focused suites remain fast enough for role agents.
- Assertion failures identify the broken screen/system and evidence path.
- No gameplay behavior is changed for test convenience without explicit justification.
- All changed tests pass under `tools/godot_gate.py`.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_combat_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd
```

## Process Notes

This task touches shared test files and should not run in parallel with another task actively editing `tests/runtime_smoke_test.gd`.
