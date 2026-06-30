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

## QA-Вердикт
Статус: PASSED

Проверял claude-qa (2026-06-30) на чистом изолированном worktree от origin/dev HEAD, fdengine-семафор slots=1 (анти-OOM на фоне живого флота). Коммит SCRUM-718 `5df51bdb` — ancestor origin/dev подтверждён.

Scope review: коммит **test-only** (только `tests/route_generation_reachability_test.gd` + .uid, 98 строк) — `route_map_screen.gd` / `run_autosave.gd` / node rewards НЕ тронуты → нулевой риск. Новый тест: на 24 свежих маршрутах валидирует структуру (N рядов активностей + boss-ряд), forward-рёбра в диапазоне следующего ряда (нет тупиков/out-of-range) и BFS-достижимость каждого узла от ряда 0 + достижимость босса — ловит регрессию связей с риском софт-лока. Использует публичный API (`main._generate_route`, `main.ROUTE_STEPS_TO_BOSS`).

Гейты (все RC=0):
- `res://tests/route_generation_reachability_test.gd` → passed (24 routes, 10 rows + boss).
- `res://tests/run_autosave_persistence_test.gd` → passed (round-trip/atomic/corrupt/version/clear).
- `res://tests/route_node_preview_test.gd` → PASSED.
- `res://tests/route_node_threat_badge_test.gd` → PASSED (19 badges; battle/chest/elite_battle).
- `res://tests/route_chest_artifact_test.gd` → PASSED.

→ PASSED.
