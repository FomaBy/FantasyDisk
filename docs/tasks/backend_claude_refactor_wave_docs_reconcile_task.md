# Refactor Wave: Documentation Reconcile After Code Cleanup Batch

Jira: SCRUM-724
Статус: done
Приоритет: P2
Роль: Back-end / documentation quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-docs, area-quality
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This is the final documentation reconciliation task for the refactor wave. It should run after implementation tasks have produced results; it is not a code-feature task.

## Scope / Locked Paths

- `docs/design/current_game_state.md`
- `docs/design/systems/*.md`
- `docs/design/mechanics_extract.md`
- `docs/design/content_registry.md`
- `docs/process/task_board.md` only as Jira mirror sync

## Required Change

After the refactor wave has produced implementation results, reconcile design/domain documentation with actual code behavior: current game state, technical architecture, combat, UI, progression, persistence, animation and content registry. This is a docs-only finalization task; do not implement code features here.

## Acceptance Criteria

- Documentation reflects the implemented state after the refactor wave.
- Domain docs under `docs/design/systems/` are consistent with code and tests.
- No stale version references, old filenames or closed-task claims remain in updated sections.
- Jira/local mirror references are synchronized where they are touched.
- No gameplay/UI/code changes are made in this docs-only task.
- Final Jira comment includes branch/commit, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/jira_board_sync.py --no-create --allow-broad-status-sync
rg -n "0.1.7|0.1.8|TODO|устарел|deprecated" docs/design docs/process | head -200
```

## Process Notes

Run this after the relevant refactor implementation results exist. If no implementation tasks are done yet, leave the Jira issue in `К выполнению` and do not claim it early.
