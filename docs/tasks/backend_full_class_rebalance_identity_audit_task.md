# Full Class Rebalance: Identity Audit And Trio Matrix
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: backend/class-rebalance-backend-Mill
Thread/Worker: class-rebalance-backend-Mill
Locked paths: `docs/design/reports/full_class_rebalance_identity_audit.md`, `build/full_class_rebalance_*`, focused audit/test helpers only; core runtime files read-only unless this task is explicitly expanded
Jira: SCRUM-856
Исполнитель: Codex
Branch/worktree: `codex/class-rebalance-backend-Mill` / `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/class-rebalance-backend-Mill`

## Контекст
Пользовательская задача 2026-07-04: полностью пересмотреть ребаланс всех классов так, чтобы каждый класс и каждое из трех оружий имели уникальный gameplay. Сейчас часть атак ощущается похожей: зоны, взрывы, цепи, summon/deploy и sustain должны различаться не только цифрами, но и ритмом, геометрией, setup/payoff, риском и defensive utility.

## Требования
- [x] Прочитать `fantasydisk-class-balance-director` и обязательные balance docs.
- [x] Инвентаризировать все 17 классов и 51 оружие из `ProgressionData.WEAPONS_BY_CLASS`.
- [x] Составить before class-trio table: solo, AoE/5t, crowd 5/10/20, defense/sustain/control, total kit score, identity diagnosis.
- [x] Составить per-weapon identity table: range/risk, target geometry, cadence, setup/payoff, solo/crowd role, defensive contribution, scaling hook.
- [x] Отметить клоны/почти-клоны: одинаковые AoE, одинаковые delayed explosions, одинаковые pierce/chain/ricochet, мертвые summon/deploy slots, слишком похожий sustain.
- [x] Развести implementation follow-ups по dependency order и locked paths; SCRUM-854 overlap учтен during audit, а final notes теперь используют landed SCRUM-854 как runtime baseline with Jira QA/lock re-check before shared edits.
- [x] Обновить `docs/design/systems/characters_weapons.md`, `docs/design/systems/progression_balance.md` или `docs/design/mechanics_extract.md`, если аудит уточняет текущий контракт.

## Acceptance Criteria
- [x] В отчете есть таблица всех 17 class kits и всех 51 weapons.
- [x] Для каждого класса указан intended gameplay fantasy и три непохожие роли оружия.
- [x] Для каждого найденного clone/dead-slot указан конкретный recommended mechanic-first fix, а не только numeric buff/nerf.
- [x] Отчет явно покрывает идеи пользователя: delayed grenade/meteor, damaging projectile without landing damage, ricochet/split/pierce, chain lightning/prayer, melee AoE with risk window, turret/deploy gameplay, shield counter damage, kill-scaling/vampiric growth.
- [x] Команды/источники измерений перечислены; если full harness не запускался, указана причина.
- [x] Jira result comment содержит ссылки на отчет и список задач, которые audit разблокировал.

## Результат
Done 2026-07-04: produced `docs/design/reports/full_class_rebalance_identity_audit.md`
with the 17-class trio matrix, 51-weapon identity matrix, clone/dead-slot findings,
implementation order, SCRUM-854 overlap/final-baseline notes and user-idea coverage. Updated
domain docs to point SCRUM-857..860 at the mechanic-first audit baseline:
`docs/design/systems/characters_weapons.md`,
`docs/design/systems/progression_balance.md`,
`docs/design/current_game_state.md`, and `docs/design/mechanics_extract.md`.

Checks:
- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/survivability_harness.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/survivability_scenario_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS before final rebase, and PASS again on the final rebased tree. One cold-cache run after deleting `.godot/` first exposed an unrelated reward-card safe-rect failure (`BattleRewardButton0` vs SCRUM-338 safe rect); warm rerun passed, and SCRUM-856 did not edit UI/runtime paths.

Disk cleanup: removed task-created `.godot/`, untracked test `.uid` files, ignored
Godot `.import` sidecars and transient `build/qa/runtime_smoke_last_failure.md`;
no Python `__pycache__` directories were present.

## QA-Вердикт 2026-07-04
Статус: PASSED

Independent Codex QA on live `origin/dev` passed for SCRUM-856. Jira comments
record the disposable clone verification at `origin/dev` containing commit
`044de7e2 docs(SCRUM-856): audit class rebalance identities` plus later baseline
fixes, with `balance_harness.gd`, global damage/survivability smokes,
`survivability_harness.gd`, `survivability_scenario_test.gd`, and
`tests/runtime_smoke_test.gd` all PASS. QA cleanup removed the disposable clone,
logs, path marker, and patch scratch files; no SCRUM-856 QA temp clone remained.
