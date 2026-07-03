# Full Class Rebalance: Kill-Scaling, Sustain, And Attribute Growth Pass
Статус: new
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
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
Заполняет исполнитель.
