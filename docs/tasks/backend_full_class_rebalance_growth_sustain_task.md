# Full Class Rebalance: Kill-Scaling, Sustain, And Attribute Growth Pass
Статус: blocked
Версия: 0.2.1
Контур: Codex
Owner: released; blocked by active/unlanded SCRUM-858 overlap
Thread/Worker: class-rebalance-backend-Mill release note
Locked paths: `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/combat_director.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_content.gd`, `scripts/progression_data_balance.gd`, balance/survivability tests, relevant docs
Jira: SCRUM-860
Исполнитель: Codex

## Контекст
Пользователь предложил оружие/класс, который растет от количества убитых монстров: damage, attack speed, vampiric chance or defensive scaling. Такой рост должен быть buildcraft hook, но не бессмертный runaway. Также нужно отделить Doctor sustain, Priest holy sustain, Knight counter survival and generic artifacts.

## Требования
- [ ] Выбрать 1-2 подходящих class/weapon identities для kill-scaling без ломки уже каноничных fantasy; предпочтительно там, где рост отличает gameplay, а не просто добавляет damage всем.
- [ ] Реализовать capped kill-streak/run-kill mechanic: small per-kill or threshold-based scaling, visible reset rules, hard cap and tests.
- [ ] Развести sustain sources: Doctor heals through own drain weapons, Priest through prayer/ward damage, Knight through mitigation/counter, generic vampirism artifacts stay capped and do not stack into immortality.
- [ ] Проверить interaction with active artifacts (`on_kill`, `on_take_hit`, `kill_heal_percent`, `take_hit_pulse_chance`) and avoid double-count runaway.
- [ ] Обновить docs for formulas, caps, class identities and QA evidence.

## Acceptance Criteria
- [ ] Kill-scaling mechanic is implemented, capped, and assigned to a specific class/weapon identity with clear player-facing behavior.
- [ ] Sustain classes feel distinct and do not share the same generic vampirism loop.
- [ ] No survivability scenario reaches permanent immortality; TTD and heal-per-second caps remain within documented gates.
- [ ] `global_survivability_balance_smoke_test.gd`, `survivability_scenario_test.gd`, `global_damage_balance_smoke_test.gd`, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [ ] Docs updated with before/after sustain/growth notes.

## Результат
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
