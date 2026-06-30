# Refactor Wave: Route Map, Node Rewards And Autosave Checkpoints

Jira: SCRUM-718
Статус: done
Приоритет: P1
Роль: Back-end / route quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-route, area-persistence
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns route map logic and run autosave checkpoints. It must preserve player progression and save compatibility.

## Scope / Locked Paths

- `scripts/route_map_screen.gd`
- `scripts/run_autosave.gd`
- Route/autosave tests
- `docs/design/systems/route_map.md`
- `docs/design/systems/persistence.md`

## Required Change

Audit and safely refactor route map and autosave flow: map generation/render cache, scroll/click/focus handling, node preview/threat badges, route rewards, act transitions, checkpoint save/load schema, continue/new run behavior and autosave cleanup after death/victory.

## Acceptance Criteria

- Route/autosave audit is recorded.
- Continue/new run behavior and act transitions remain compatible.
- Autosave writes remain atomic and schema-safe.
- Route map interaction remains stable at supported resolutions.
- Focused route/autosave tests cover any changed behavior.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/run_autosave_persistence_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/route_node_preview_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/route_node_threat_badge_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/route_chest_artifact_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.
