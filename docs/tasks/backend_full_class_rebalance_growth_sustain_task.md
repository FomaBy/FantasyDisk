# Full Class Rebalance: Kill-Scaling, Sustain, And Attribute Growth Pass
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Main Codex class-balance worker
Thread/Worker: current Codex thread
Locked paths: `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/combat_director.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_content.gd`, `scripts/progression_data_balance.gd`, balance/survivability tests, relevant docs
Jira: SCRUM-860
Исполнитель: Codex
Branch: `codex/scrum860-growth-sustain`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum860-growth-sustain`

## Контекст
Пользователь предложил оружие/класс, который растет от количества убитых монстров: damage, attack speed, vampiric chance or defensive scaling. Такой рост должен быть buildcraft hook, но не бессмертный runaway. Также нужно отделить Doctor sustain, Priest holy sustain, Knight counter survival and generic artifacts.

## Требования
- [x] Выбрать 1-2 подходящих class/weapon identities для kill-scaling без ломки уже каноничных fantasy; предпочтительно там, где рост отличает gameplay, а не просто добавляет damage всем.
- [x] Реализовать capped kill-streak/run-kill mechanic: small per-kill or threshold-based scaling, visible reset rules, hard cap and tests.
- [x] Развести sustain sources: Doctor heals through own drain weapons, Priest through prayer/ward damage, Knight through mitigation/counter, generic vampirism artifacts stay capped and do not stack into immortality.
- [x] Проверить interaction with active artifacts (`on_kill`, `on_take_hit`, `kill_heal_percent`, `take_hit_pulse_chance`) and avoid double-count runaway.
- [x] Обновить docs for formulas, caps, class identities and QA evidence.

## Acceptance Criteria
- [x] Kill-scaling mechanic is implemented, capped, and assigned to a specific class/weapon identity with clear player-facing behavior.
- [x] Sustain classes feel distinct and do not share the same generic vampirism loop.
- [x] No survivability scenario reaches permanent immortality; TTD and heal-per-second caps remain within documented gates.
- [x] `global_survivability_balance_smoke_test.gd`, `survivability_scenario_test.gd`, `global_damage_balance_smoke_test.gd`, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [x] Docs updated with before/after sustain/growth notes.

## Результат
2026-07-04 final: implemented Assassin-only capped kill-growth as `shadow_momentum`
on `shadow_daggers` and `venom_wire`. Normal non-boss/non-elite kills add or
refresh up to 6 stacks for 6 seconds; the stacks grant capped tempo only
(+12% attack speed, +9% crit damage) through `kill_momentum_*` run modifiers.
The mechanic never heals, never counts boss/elite kills, and clears on expiry
or weapon swap. Sustain remains split by class lane: Doctor weapon drain only,
Priest prayer/ward sustain, Knight block/counter mitigation/retaliation, and
generic vampirism artifacts stay capped.

Docs updated: `docs/design/current_game_state.md`,
`docs/design/mechanics_extract.md`,
`docs/design/systems/characters_weapons.md`, and
`docs/design/systems/progression_balance.md`.

Tests:
- PASS `git diff --check`.
- PASS `tests/kill_scaling_identity_test.gd`.
- PASS `tests/doctor_drain_softcap_test.gd`.
- PASS `tests/priest_sustain_softcap_test.gd`.
- PASS `tests/melee_unique_mechanics_test.gd`.
- PASS `tests/runtime_smoke_weapon_mechanics_test.gd`.
- PASS `tests/weapon_integrity_test.gd`.
- PASS `tests/weapon_scene_integrity_test.gd`.
- PASS `tests/global_survivability_balance_smoke_test.gd`.
- PASS `tests/survivability_scenario_test.gd`.
- PASS `tests/global_damage_balance_smoke_test.gd`.
- PASS `tests/runtime_smoke_test.gd`.
- PASS `tools/balance_harness.gd` (`build/` reports generated but ignored).

Disk cleanup: generated Godot `.uid` sidecars removed before commit; task temp
logs and disposable worktree are removed after push/Jira final comment.

2026-07-04: resumed by main Codex after SCRUM-858 landed/QA-synced and SCRUM-859
was pushed to `origin/dev` + moved to `Контроль качества`. Stale Jira `blocked`
label was removed, Jira moved to `В работе`, and current scope is limited to
kill-scaling/sustain identity, tests, docs, and mirror updates. Hegel read-only
exploration recommendation: assign capped non-healing kill-growth to Assassin
first (secondary Thief if needed), reuse `CombatDirector._on_enemy_died()` ->
`Player.on_enemy_killed(enemy)`, exclude boss kills, cap around 6 stacks / 6-8s /
+10-12% effective output, and avoid Doctor/Priest/Knight sustain overlap.

Blocked/released 2026-07-04 by `class-rebalance-backend-Mill` before runtime edits.
SCRUM-860 requires `scripts/class_weapon.gd`, `scripts/player.gd`,
`scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`,
survivability/balance tests, and shared docs. SCRUM-858 is still not landed on
`origin/dev` and its worktree has dirty WIP in overlapping files, including
`scripts/player.gd`, `scripts/progression_data_weapons.gd`, `tests/runtime_smoke_test.gd`,
`tests/melee_unique_mechanics_test.gd`, `docs/process/jira_sync_map.json`, and
shared balance docs.

Jira was commented, label `blocked` was added so auto-pull skips it, and the issue
was returned to `К выполнению`. Resume only after SCRUM-858 is pushed/QA-clean or
dispatcher explicitly narrows SCRUM-860 to a non-overlapping scope.

Tests: not run for SCRUM-860 because no runtime/source changes were made.
Disk cleanup: none created for SCRUM-860.
