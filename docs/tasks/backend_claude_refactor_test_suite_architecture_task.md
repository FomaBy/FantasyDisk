# Refactor Wave: Runtime Smoke And Focused Test Suite Architecture

Jira: SCRUM-722
Статус: done
Приоритет: P1
Роль: Back-end / test quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.2.0
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

## QA-Вердикт
Статус: PASSED

Проверял claude-qa (2026-06-30) на чистом изолированном worktree от origin/dev HEAD, fdengine slots=1. Коммиты SCRUM-722 `077fdabe` (рефактор) + `9852549c` (mirror) — ancestor origin/dev подтверждён.

Scope review: рефактор-коммит трогает только `tests/runtime_smoke_test.gd` (−801/+450) + `docs/design/systems/technical_architecture.md` (+31, аудит). Gameplay-скрипты НЕ тронуты. `_fail(message, evidence_path)` поведенчески идентичен прежнему триплету `push_error;quit(1);return` (push_error+quit(1) на провале) + детерминированный артефакт `build/qa/runtime_smoke_last_failure.md`, который пишется ТОЛЬКО при провале (зелёный прогон не задевает) → нулевой риск на success-path.

Гейты (fdengine slots=1, все pass):
- `runtime_smoke_test.gd` (умбрелла) → "Duplicate-artifact guard passed (9819 files) / Runtime smoke test passed.", RC=0, peak mem 1.24 GB.
- focus-сьюты: `runtime_smoke_ui_test`, `runtime_smoke_combat_test`, `runtime_smoke_weapon_mechanics_test`, `runtime_smoke_boss_elite_test` → все passed.
- `runtime_smoke_progression_economy_test` → passed **×2** (детерминизм-фикс `_test_ascension_difficulty_ladder` устраняет флак, вскрытый ускорением спавн-пауз SCRUM-784; EV-инвариант 16 событий OK).
- `python3 tests/test_jira_board_sync.py` → Ran 4 tests OK.

Прим.: умбрелла, запущенная ЧЕРЕЗ `tools/godot_gate.py`, периодически отдаёт RC 247 (SIGKILL обёртки flock-семафора) сразу после dup-guard — это артефакт QA-обёртки, НЕ теста: прямой запуск `fdengine` даёт RC=0 + "Runtime smoke test passed.", 0 signals received, peak 1.24 GB (без OOM). Контроль: pre-722 версия файла в том же worktree ведёт себя идентично → SCRUM-722 регрессию НЕ вносит.

→ PASSED.
