# Full Class Rebalance: Summon, Deploy, Turret, And Zone Ownership Pass
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Main Codex class-balance worker
Thread/Worker: current Codex thread after Faraday shutdown
Locked paths: `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/progression_data_weapons.gd`, `tests/summoner_strengthening_test.gd`, summon/deploy docs
Jira: SCRUM-859
Исполнитель: Codex
Branch: `codex/scrum859-summon-deploy-turret`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum859-summon-deploy-turret`

## Контекст
Пользователь отдельно отметил, что summons сейчас играются отвратительно, и хочет персонажа с турельками, вокруг которых он бегает. В проекте уже есть Druid pets, Chemist homunculus, Engineer sentry/repair drone/mines, Guitarist amp и active `SCRUM-854` по persistent zones/summons. Этот pass должен идти после или поверх результата `SCRUM-854`, не параллельно в тех же файлах.

## Требования
- [x] Не начинать runtime edits, пока `SCRUM-854` не завершен/не released или dispatcher явно не развел locked paths.
- [x] Engineer sentry gameplay сделать основным turret loop: несколько temporary sentries, autonomous target choice, player kites around them, Leadership scales count/cadence without AFK runaway.
- [x] Druid pets, Chemist homunculus, Engineer sentry, Engineer repair drone, Guitarist amp and Druid totem must each have different summon/deploy role: pack, tank/control, turret DPS, repair chain, stage pulse, support/control.
- [x] Summons should start combat near half-quota where appropriate, then refill toward Leadership-scaled cap at readable cadence.
- [x] Minion/deploy hits need small AoE or target distribution so they are not dead slots in crowd fights, but must keep caps/falloff.
- [x] Persistent zones/mines/totems should own lifetime independently; new attack should not delete all previous effects unless a documented cap is exceeded.
- [x] Update summon/deploy tests and docs.

## Acceptance Criteria
- [x] Engineer can be played as "place turrets and move around them" without replacing every class summon fantasy.
- [x] Druid/Engineer/Chemist/Guitarist deploy mechanics are visibly and mechanically distinct.
- [x] Summon/deploy floor tests and class balance reports pass or list documented residual risk.
- [x] `summon_weapon_crowd_floor_test.gd`, `global_damage_balance_smoke_test.gd`, relevant live combat/summon tests, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [x] Jira result explicitly references how this task integrated or waited for `SCRUM-854`.

## Ход Работ
2026-07-04: claimed in Jira as `В работе` by Faraday /
`019f2a46-535b-7370-8c36-44f0966ad81f` after SCRUM-858 landed on `origin/dev`
(`5039ba0e`/`f300900b`, docs follow-up `39cbb181`). Scope guard: do not touch
SCRUM-860 kill-scaling/sustain; keep edits to summon/deploy/turret ownership,
focused tests, and relevant docs.

2026-07-04: Faraday was stopped before source/test edits after no progress
heartbeat; main Codex continued in this worktree. Implemented `max_summons_cap`
for ClassWeapon deploy count, capped Guitarist amp and Druid raven totem at 3,
capped Engineer sentry at 5, added explicit `deploy_role` markers, and turned
Engineer sentry into a turret loop with per-cycle target memory plus small capped
splash. `SCRUM-854` integration is preserved: mobile summon prefill/scoped caps
remain unchanged, pressure mines keep independent lifetime, and this pass only
adds deploy caps/roles and sentry target distribution on top of the landed
SCRUM-854 runtime contract.

2026-07-04 result: ready for QA after local green gates. Evidence:
`tests/summoner_strengthening_test.gd` passed; `tests/summon_weapon_crowd_floor_test.gd`
passed (`druid/summon_amulet` lvl20 621.7, `chemist/homunculus_vial` lvl20 611.6,
`engineer/engineer_sentry_wrench` lvl20 648.5); `tests/weapon_integrity_test.gd`
passed (17 classes, 51 weapons); `tests/weapon_scene_integrity_test.gd` passed
(51 weapon scenes, 35/35 attack modes); `tests/runtime_smoke_weapon_mechanics_test.gd`
passed; `tests/global_damage_balance_smoke_test.gd` passed (combined +/-25%,
solo +/-20%, CCT +/-30%, worst CCT +22% doctor/restore_potion/20);
`tools/balance_harness.gd` passed and wrote local build reports; final
`tests/runtime_smoke_test.gd` passed cleanly. While validating, Player universal
DoT callback was also moved from a delayed enemy object bind to `instance_id`
resolution to remove green-smoke ERROR noise from freed enemies.

## История / Previous Blocker
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

## QA-Вердикт 2026-07-04
Статус: PASSED
Commit tested: `b179527fefdae8ba698d08d0eccdb9bf545fd0f1` (`8fb46083` and `54d15d7c` ancestors).

Independent class-balance QA confirmed:
- Engineer sentry has `turret_dps`, target memory/distribution, and capped splash
  `82px / x0.24 / cap 2`.
- Deploy caps apply after Leadership scaling: `sound_amp=3`, `raven_totem=3`,
  Engineer sentry `5`.
- Deploy role markers exist for `stage_pulse`, `support_totem`, `turret_dps`,
  `repair_chain`, and `mine_grid`.
- SCRUM-854 contracts for pressure-mine independent lifetime and scoped mobile
  summon caps remain intact.

Godot-gate checks all exited 0:
- `tests/summoner_strengthening_test.gd` — PASS.
- `tests/summon_weapon_crowd_floor_test.gd` — PASS.
- `tests/weapon_integrity_test.gd` — PASS.
- `tests/weapon_scene_integrity_test.gd` — PASS.
- `tests/runtime_smoke_weapon_mechanics_test.gd` — PASS.
- `tests/global_damage_balance_smoke_test.gd` — PASS.
- `tools/balance_harness.gd` — PASS.
- `tests/global_survivability_balance_smoke_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.

Reports: `balance_report` max combined deviation `0.1%`; global damage worst
CCT `+22% doctor/restore_potion/20` is outside SCRUM-859 scope and within gate;
SCRUM-859 rows are around `+20%` at 20-target CCT and within the `+30%` gate;
global survivability PASS with no immortal profile.

Disk cleanup: QA removed `/private/tmp/fantasydisk-scrum859-qa-lG1cGr` including
`.godot`, `build`, `qa_logs`, `.uid/import` sidecars and ran `git worktree prune`.
