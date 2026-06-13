# Back-end Task: Live Route Economy And XP Model

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-188
Эпик: epic_full_project_quality_pass

## Scope

Validate current drop/economy/XP curve against actual route combat outputs.

## Requirements

- Simulate representative routes with battle, elite, shop/rest/upgrade and boss nodes.
- Measure expected gold, buying power, XP, level-up count and shop affordability.
- Decide whether XP tempo should move from current model +7.1% toward +10-15%.

## Verification

- Report under `build/`.
- Runtime smoke remains green.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Result Summary (2026-06-13)

Done.

- Added `tools/route_economy_xp_model.gd`, a deterministic route-level model for balanced, combat-heavy and shop/rest routes.
- Generated `build/route_economy_xp_model.md`.
- Measured expected XP, level-up count, expected gold, average shop affordability, attribute-buy affordability and reroll affordability.
- Result: representative routes produce 8-9 level-ups before/including boss rewards and healthy/high buying power.
- Decision: keep current XP tempo. The fixture uplift remains +7.1%, but route-level elite/boss rewards already make practical level-up counts high enough; moving XP toward +10-15% now would likely overfeed combat-heavy paths without live telemetry justification.
- Updated `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`, `CHANGELOG.md`, `docs/process/task_board.md` and `docs/process/jira_sync_map.json`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tools/route_economy_xp_model.gd` — passed, report written.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-188)

Проверено фактически:
- `tools/route_economy_xp_model.gd` (11.9KB) запускается headless, пишет
  `build/route_economy_xp_model.md`. ✓
- Отчёт на РЕАЛЬНЫХ константах (`drop_class_rewards()`, `stage_scaled_cost()`,
  `shop_items()`, live XP-curve — не выдуманные числа). 3 репрезентативных маршрута:
  Balanced (10 узлов, 497 XP, 8 lvl, 684 gold, buying power high), Combat-Heavy (11,
  708 XP, 9 lvl, 956 gold, healthy), Shop/Rest (10, 492 XP, 8 lvl, high). Метрики:
  Expected XP/Levels/Gold/Avg Shop Cost/Affordable Offers/Attr Buys/Rerolls/Buying Power. ✓
- Вывод обоснован: 8-9 level-up за маршрут (с учётом elite/boss наград) — практический
  темп уже достаточный; решение оставить XP-темп +7.1% (не двигать к +10-15% без live
  телеметрии, чтобы не перекормить combat-heavy пути). Разумный аналитический вывод. ✓
- runtime smoke зелёный (tool file-изолирован, не часть smoke).
Багов нет.
