# Refactor Wave: Combat Director Spawn, Arena, Rewards And Cleanup

Jira: SCRUM-708
Статус: done
Приоритет: P1
Роль: Back-end / combat quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-combat, area-spawn
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This is part of the Claude refactor wave for checking and improving the whole game by isolated sections. This task owns the combat lifecycle module, not player weapons or enemy internals.

## Scope / Locked Paths

- `scripts/combat_director.gd`
- `tests/runtime_smoke_combat_test.gd`
- Optional new `tests/combat_director_*`
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor CombatDirector around arena setup, spawn pacing, route scaling, combat timers, pickup/reward emission, world cleanup groups, hit-stop/shake ownership and combat end transitions. Preserve current balance values unless a concrete bug is found and covered.

## Acceptance Criteria

- Arena/spawn/reward cleanup contracts are reviewed and improved where safe.
- No broad balance retune is included without harness evidence.
- World cleanup removes temporary combat nodes without deleting persistent UI/run state.
- Focused combat tests cover any changed lifecycle behavior.
- Docs update only if runtime contract changes.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_combat_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_progression_economy_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## Результат (Claude backend, 2026-06-30)

Ветка/коммит: `dev` @ `c9d91534` (origin/dev, ancestor подтверждён).

Изменения (locked paths, баланс-значения не тронуты):
- `scripts/combat_director.gd`
  - `_spawn_enemy_wave`: `_active_enemy_cap()` теперь считается один раз на волну
    и переиспользуется в горячем цикле спавна пачек (значение инвариантно в
    пределах волны — зависит только от route_scaling_stage/spawn_wave_index/типа
    боя, которые тут не меняются). Поведение идентично, убраны лишние пересчёты.
  - `_end_combat`: убран дублирующий составной guard
    `is_instance_valid(current_player)` (раньше проверялся дважды в victory- и
    death-ветках). Обе ветки делают `_store_player_snapshot`; контракт SCRUM-500
    (room_clear_heal до снапшота) и SCRUM-502 (снапшот до _clear_world) сохранён.
- `tests/runtime_smoke_combat_test.gd`
  - Фокус-тест инварианта спавн-капа: после серии из 4 волн число узлов в группе
    `enemies` не превышает `_active_enemy_cap()` (включая small-pack спавны).
    Прямой вызов `main.combat._spawn_enemy_wave()` (main-обёртки нет, хот-файл
    main.gd не трогаем).

Проверки (semaphore, GODOT_BIN=fdengine, slots=1) — все RC=0:
- `tests/runtime_smoke_combat_test.gd` → "Runtime combat smoke suite passed."
- `tests/runtime_smoke_progression_economy_test.gd` → EV-инвариант + suite passed.
- `tests/runtime_smoke_test.gd` → "Runtime smoke test passed."

World cleanup (`game._clear_world`) — вне locked paths (живёт в main.gd), контракт
не менялся; удаление временных боевых узлов покрыто существующим death-flow.

Disk cleanup: рабочий worktree `/private/tmp/fsd_wt_scrum708` удалён после пуша;
временных артефактов не оставлено.
