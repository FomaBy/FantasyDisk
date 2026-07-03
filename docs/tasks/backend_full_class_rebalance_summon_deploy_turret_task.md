# Full Class Rebalance: Summon, Deploy, Turret, And Zone Ownership Pass
Статус: blocked
Версия: 0.2.1
Контур: Codex
Owner: released; blocked by active SCRUM-858 overlap
Thread/Worker: class-rebalance-backend-Mill release note
Locked paths: `scripts/summoner_weapon.gd`, `scripts/ally_minion.gd`, `scripts/class_weapon.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`, summon/deploy tests, relevant docs
Jira: SCRUM-859
Исполнитель: Codex

## Контекст
Пользователь отдельно отметил, что summons сейчас играются отвратительно, и хочет персонажа с турельками, вокруг которых он бегает. В проекте уже есть Druid pets, Chemist homunculus, Engineer sentry/repair drone/mines, Guitarist amp и active `SCRUM-854` по persistent zones/summons. Этот pass должен идти после или поверх результата `SCRUM-854`, не параллельно в тех же файлах.

## Требования
- [x] Не начинать runtime edits, пока `SCRUM-854` не завершен/не released или dispatcher явно не развел locked paths.
- [ ] Engineer sentry gameplay сделать основным turret loop: несколько temporary sentries, autonomous target choice, player kites around them, Leadership scales count/cadence without AFK runaway.
- [ ] Druid pets, Chemist homunculus, Engineer sentry, Engineer repair drone, Guitarist amp and Druid totem must each have different summon/deploy role: pack, tank/control, turret DPS, repair chain, stage pulse, support/control.
- [ ] Summons should start combat near half-quota where appropriate, then refill toward Leadership-scaled cap at readable cadence.
- [ ] Minion/deploy hits need small AoE or target distribution so they are not dead slots in crowd fights, but must keep caps/falloff.
- [ ] Persistent zones/mines/totems should own lifetime independently; new attack should not delete all previous effects unless a documented cap is exceeded.
- [ ] Update summon/deploy tests and docs.

## Acceptance Criteria
- [ ] Engineer can be played as "place turrets and move around them" without replacing every class summon fantasy.
- [ ] Druid/Engineer/Chemist/Guitarist deploy mechanics are visibly and mechanically distinct.
- [ ] Summon/deploy floor tests and class balance reports pass or list documented residual risk.
- [ ] `summon_weapon_crowd_floor_test.gd`, `global_damage_balance_smoke_test.gd`, relevant live combat/summon tests, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [ ] Jira result explicitly references how this task integrated or waited for `SCRUM-854`.

## Результат
Blocked/released 2026-07-04 by `class-rebalance-backend-Mill` before runtime edits.
`SCRUM-854` is `Готово` and landed, but `SCRUM-858` is actively `В работе` and
locks/edits overlapping backend balance paths: `scripts/class_weapon.gd`,
`scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`,
shared balance tests, and relevant docs. SCRUM-859 full acceptance requires those
paths for Engineer sentry, Guitarist amp, Druid raven totem, and deploy cap/config
work, so a partial summon-only edit would be unsafe and incomplete.

Jira was commented with the blocker and moved back to `К выполнению`. Resume this
task only after SCRUM-858 is pushed/QA or dispatcher explicitly narrows SCRUM-859
to non-overlapping `scripts/summoner_weapon.gd` + `scripts/ally_minion.gd` scope.

Tests: not run for SCRUM-859 because no runtime/source changes were made.
Disk cleanup: none created for SCRUM-859.
