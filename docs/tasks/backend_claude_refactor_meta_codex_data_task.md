# Refactor Wave: Meta Progression, Codex, Achievements And Glossary Data

Jira: SCRUM-719
Статус: new
Приоритет: P2
Роль: Back-end / meta quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-meta, area-codex
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers meta/game data modules that are not part of core combat or progression facade work.

## Scope / Locked Paths

- `scripts/meta_progression.gd`
- `scripts/codex_data.gd`
- `scripts/achievements_data.gd`
- `scripts/glossary.gd`
- `scripts/patch_notes_data.gd`
- Related tests
- `docs/design/systems/progression_balance.md` if meta contracts change

## Required Change

Audit and safely refactor meta/data modules: unlock tracking, achievements, glossary entries, patch notes, Codex data contracts, save compatibility and stale hardcoded IDs. Preserve player-facing Russian text unless fixing a typo/bug with evidence.

## Acceptance Criteria

- Meta/Codex/data audit is recorded.
- Save compatibility and unlock tracking are preserved.
- Stale or missing IDs are fixed or filed with evidence.
- Player-facing text changes are intentional and documented.
- Focused tests cover changed contracts.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/meta_skill_tree_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/achievements_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
