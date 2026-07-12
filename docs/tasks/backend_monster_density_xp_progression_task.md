# Back-end: Monster density and XP progression pacing

Статус: done
Приоритет: P1
Роль: Back-end
Контур: Codex
Owner: backend/codex-monster-xp-progression-orchestrator
Thread/Worker: current Codex control thread + subagents
Jira: SCRUM-853
Версия: 0.2.1
Создано: 2026-07-04
Locked paths: `scripts/progression_data_balance.gd`, `scripts/progression_data_enemies.gd`, `scripts/combat_director.gd`, `scripts/player.gd`, balance/progression harnesses or focused tests, `docs/design/systems/progression_balance.md`, `docs/design/systems/combat.md`, `docs/design/current_game_state.md`, `docs/tasks/backend_monster_density_xp_progression_task.md`, `docs/process/task_board.md`

## Контекст

Пользовательский фидбек: герой скалируется намного быстрее монстров. Уже в первой
зоне можно получить около 15 уровня, а к концу третьего акта герой становится
слишком сильным относительно плотности, количества и живучести врагов.

Нужно усилить pressure curve с самого первого уровня и дальше по времени матча:
больше монстров, выше плотность, заметнее рост HP/опасности, иногда более сильные
мобы/mini-elites. Одновременно нужно растянуть XP-кривую героя. Предпочтение:
не резать сам дроп без необходимости, а увеличить требуемый XP на уровни.

## Целевые Ориентиры

- После 5-6 боев к концу первого акта средний уровень должен быть около 10-15.
- К концу второго акта уровень должен быть около 20, максимум примерно 23-25.
- К концу третьего акта после примерно 20 боев целиться в 30-35, ориентир около
  32 и допустимо ниже, потому что силу дополнительно дают артефакты.

## Acceptance Criteria

- Baseline: посчитать текущий средний kill count, XP gain и level pacing за 20
  боев минимум для `berserk` + `hammer` и еще одного отличающегося героя/оружия.
- Spawn pressure: обычные бои становятся плотнее уже с первой стадии, затем
  дополнительно растут от `route_scaling_stage`, номера волны и elapsed time
  внутри боя без спавна прямо в лицо игроку.
- Enemy scaling: HP/contact threat обычных врагов и шанс/состав сильных мобов
  заметнее растут к Act 2/3; early game остается честным и читаемым.
- XP pacing: требуемый XP на уровни растянут так, чтобы 20 боев в симуляции или
  harness попадали в целевой коридор финального уровня 30-35 или ниже при
  артефактной силе; Act 1/2 ориентиры проверены или явно задокументированы.
- Economy/drop safety: если XP или money drop меняются, причина описана; базовый
  путь — оставить дроп понятным и увеличить XP requirement.
- Regression: focused progression/combat tests, balance reports и
  `tests/runtime_smoke_test.gd` проходят через `tools/godot_gate.py`.
- Docs: обновлены relevant design/system docs с новыми правилами enemy pressure
  и XP pacing.

## Subagent Plan

- Baseline analyst: найти текущие формулы XP/spawn/enemy scaling, посчитать
  baseline kill/XP/level pacing и предложить числовые target multipliers.
- Implementation worker: в отдельном scope подготовить bounded patch по spawn,
  enemy scaling и XP curve, не трогая UI/art/animation.
- Orchestrator: review/integrate, прогнать smokes, обновить Jira/docs/board,
  commit/push.

## Start Note

2026-07-04 Codex claim: Jira `SCRUM-853` создан в active sprint `Спринт 0.2.1`
и взят через claim-first worker `codex-monster-xp-progression-orchestrator`.
Branch/worktree: `dev` at `/Users/sergeyfomin/Documents/AI Agent`. Next
verification: baseline kill/XP pacing and focused implementation via subagents.

## Result

Implemented in backend/balance scope:

- Added SCRUM-853 pressure multipliers in `scripts/combat_director.gd`:
  ordinary spawn density grows from stage 0, then increases by
  `route_scaling_stage`, wave index and elapsed combat time; enemy HP and
  contact/damage pressure also grow on those axes.
- Increased baseline normal wave pressure in `scripts/main.gd`: base spawn count
  `4 -> 5`, normal wave limit `8 -> 10`, active cap `20 -> 22` with max cap
  `36 -> 48`, and normal spawn pauses `0.8-1.4s -> 0.7-1.2s`.
- Added Act 2/3 advanced-mob weighting for shooter/summoner/heavy archetypes and
  a non-Ascension mini-elite pressure chance (`0.015..0.12`) for normal waves.
- Stretched hero XP requirements in `scripts/progression_data_balance.gd` to
  `ceil(req * 1.09 + 0.8)` while leaving per-monster XP drops unchanged.
- Fixed boss completion reward ordering so boss XP/money/artifact rewards are
  granted before `_clear_world()` and enter the run snapshot.
- Added focused pacing guard `tests/monster_xp_pressure_pacing_test.gd`.

Deterministic projection:

- Berserk/hammer: kill scalar `0.94`, estimated kills `726.5`, XP Act 1 `287.3`
  -> level `14`, Act 2 `1028.2` -> level `24`, 20-fight run `2470.8` -> level
  `32` (old curve projected level `42`).
- Dark Mage/dark_book: kill scalar `1.00`, estimated kills `773.9`, XP Act 1
  `301.4` -> level `15`, Act 2 `1080.5` -> level `24`, 20-fight run `2598.7`
  -> level `32` (old curve projected level `43`).

Validation:

- `python3 tools/godot_gate.py --headless --path . --script res://tests/monster_xp_pressure_pacing_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/route_economy_xp_model.gd` — passed, updated `build/route_economy_xp_model.md`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_progression_economy_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_damage_spread_gate.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd` — passed.

Docs updated: progression/combat/enemy/current-state/mechanics docs now record
SCRUM-853 pressure and XP pacing.

Disk cleanup: none created.
