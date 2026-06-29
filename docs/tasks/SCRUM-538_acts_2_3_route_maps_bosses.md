# SCRUM-538: Progression: добавить акты 2 и 3 с отдельными картами и боссами

Jira: SCRUM-538
Статус: done
Роль: backend
Контур: Codex
Owner: Back-end / codex-background-backend-agent
Thread/Worker: codex-background-backend-agent
Locked paths: scripts/main.gd, scripts/route_map_screen.gd, scripts/combat_director.gd, scripts/ui_screens.gd, scripts/run_autosave.gd, tests/runtime_smoke_test.gd, tests/run_autosave_persistence_test.gd, docs/design/systems/route_map.md, docs/design/systems/progression_balance.md, docs/design/systems/combat.md, docs/design/current_game_state.md

## Задача

Добавить прогрессию забега из трех актов: Act 1 route -> Act 1 boss -> Act 2 route -> Act 2 boss -> Act 3 route -> Act 3 boss -> victory.

Игрок должен сохранять билд между актами: класс, оружие, HP, XP/level, золото, артефакты, модификаторы и мета-прогрессия. Для каждого акта генерируется отдельная route map, а UI должен явно показывать Act X/3.

## Acceptance

- Обычный забег может пройти через три route map и три boss fight до победы.
- `current_act` сохраняется в autosave и восстанавливается для карты/боя там, где autosave уже поддерживает checkpoint.
- Act 2/3 получают контролируемый difficulty/reward scaling без пересборки классового баланса.
- Старые one-act smoke tests обновлены под новый flow, не отключены.
- Документация обновлена: route map, progression/balance, combat, current game state.

## Work Log

- 2026-06-27 23:xx EEST — Claimed in Jira by `codex-background-backend-agent`. SCRUM-503/SCRUM-545 skipped because dirty balance files belong to Claude-owned SCRUM-546; SCRUM-538 has disjoint locked paths.
- 2026-06-27 23:xx EEST — Implemented `current_act` 1..3, act-local `route_stage`, `route_scaling_stage()` for economy/combat scaling, Act 1/2 boss transition to next route map, Act 3 final victory, autosave `current_act`, route UI Act X/3 label, and smoke coverage for Act 1 boss -> Act 2 checkpoint.
- 2026-06-27 23:xx EEST — Done. Verification passed:
  `tests/run_autosave_persistence_test.gd`,
  `tests/runtime_smoke_progression_economy_test.gd`,
  `tests/runtime_smoke_test.gd`,
  `tools/route_economy_xp_model.gd`.

## Result

- Run flow is now Act 1 route -> Act 1 boss -> Act 2 route -> Act 2 boss -> Act 3 route -> Act 3 boss -> victory.
- Player build state is preserved between acts; `current_act` is persisted in autosave and restored with route checkpoints.
- Act 2/3 use `route_scaling_stage()` for controlled combat/economy/reward pressure while keeping each route map act-local.
- Route, combat, progression balance and current state docs were updated.


## QA-Вердикт
Статус: PASSED

claude-qa 2026-06-28: верифицировано на origin/dev (коммит-под-задачу — ancestor HEAD), профильные гейты/смоук зелёные. Переведено в «Готово». Блок добавлен, чтобы jira_board_sync (done+PASSED→Готово) не реверти задачу обратно в «Контроль качества».
