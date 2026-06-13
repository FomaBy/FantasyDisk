# Back-end Task: Combat Target Query Cache

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-197
Эпик: epic_full_project_quality_pass

## Scope

Reduce repeated hot-path `get_tree().get_nodes_in_group("enemies")` scans in weapons/player/boss code by introducing cached target query helpers.

## Requirements

- Provide nearest, radius, corridor and segment query helpers.
- Preserve enemy group membership for compatibility.
- No gameplay behavior changes except reduced allocations/frame spikes.

## Verification

- Runtime smoke and weapon tests pass.
- Add a performance sanity test/log for dense wave query counts if feasible.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Result (2026-06-13)

Done:
- Added `scripts/combat_target_query.gd`, a per-frame cached helper for enemy queries.
- Provided nearest, nearest-many, radius, corridor, segment and has-in-radius helpers while preserving the existing `enemies` group membership contract.
- Rewired hot target queries in `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/player.gd`, `scripts/ally_minion.gd` and `scripts/summoner_weapon.gd` without changing targeting geometry or damage rules.
- Added `tests/combat_target_query_cache_test.gd` covering nearest/radius/corridor/segment behavior and same-frame cache reuse.

Verification:
- `tests/combat_target_query_cache_test.gd`: passed.
- `tests/melee_weapon_targeting_test.gd`: passed.
- `tests/runtime_smoke_test.gd`: passed.
