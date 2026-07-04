# QA Review: Full Class Rebalance And Class Identity
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Main Codex QA worker
Thread/Worker: current Codex thread + read-only subagent auditors
Locked paths: QA evidence under `build/qa/full_class_rebalance/`, screenshots/reports only
Jira: SCRUM-861
Исполнитель: Codex
Branch: `codex/scrum861-qa-review`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum861-qa-review`

## Контекст
QA gate для полной волны class rebalance 2026-07-04. Эта задача остается blocked, пока backend tasks по identity audit, projectile/chain/pierce, melee/counter/tank, summon/deploy/turret and kill-scaling/sustain не переведены в `Контроль качества` или не имеют truthful blocked/handoff status.

## Что Проверить
- [x] Все 17 классов и 51 оружие покрыты финальным before/after class-trio report.
- [x] У каждого класса три оружия играются по-разному; нет одинаковых AoE/цепей/взрывов/саммонов, отличающихся только цветом или числом.
- [x] Soldier grenade, Elementalist meteor, Thief ricochet, Sniper split/pierce, Priest chain, Dark Mage pierce/curse and delayed AoE mechanics are distinguishable in runtime reports or focused tests.
- [x] Knight counter fantasy реально работает: входящий урон провоцирует meaningful retaliation, но не дает бессмертия.
- [x] Engineer turret/deploy gameplay works; Druid/Chemist/Guitarist summon/deploy identities remain distinct.
- [x] Kill-scaling/sustain mechanics capped; Doctor/Priest/Knight/generic vampirism do not collapse into one sustain loop.
- [x] Docs and Jira evidence match the implemented code.
- [x] Required smokes from backend evidence are green, including `runtime_smoke_test.gd`.

## QA-Вердикт
Статус: PASSED

2026-07-04 final: full class rebalance QA gate passed on dev commit
`f1cac0d8 feat(SCRUM-860): add assassin kill momentum`.

Final before/after report:
`build/qa/full_class_rebalance/final_class_trio_qa_report.md`.

Coverage:
- SCRUM-856 baseline audit covers all 17 class trios and 51 weapons.
- SCRUM-857 focused projectile/chain/pierce checks pass.
- SCRUM-858 focused melee/counter/tank checks pass.
- SCRUM-859 summon/deploy/turret checks pass.
- SCRUM-860 kill-growth/sustain checks pass.
- `tests/weapon_identity_diversity_test.gd` confirms 51 unique weapon identity
  signatures and no duplicate signatures.
- `tests/weapon_integrity_test.gd` confirms 17 classes / 51 weapons.
- `tests/weapon_scene_integrity_test.gd` confirms all 51 scenes and 35/35 attack
  modes.
- `tests/global_damage_balance_smoke_test.gd` confirms 51 pairs inside combined,
  solo, and CCT gates; worst CCT remains `doctor/restore_potion/20` at +22%,
  inside the +/-30% gate.
- `tests/global_survivability_balance_smoke_test.gd` and
  `tests/survivability_scenario_test.gd` confirm finite TTD, no immortality, and
  formula anchors.
- `tests/runtime_smoke_test.gd` passes.

Subagent cross-check:
- Erdos (`019f2a7e-8737-7ac2-9e1c-aeeb75358f6b`): no hard gameplay blocker;
  17 classes / 51 weapons are distinct enough for QA, with manual playfeel as
  residual follow-up risk.
- Darwin (`019f2a7e-9ffe-79f1-80d9-ea960cc25323`): found missing final report,
  stale sync-map before final sync, and stale SummonerWeapon wording. Fixed by
  this report, final Jira sync, and `current_game_state.md` update.

Disk cleanup: remove generated `.godot/`, generated `.uid` sidecars, temp logs
under `/private/tmp/fantasydisk-scrum861-logs`, and disposable QA worktree after
commit/push/Jira final comment.
