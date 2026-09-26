# FAN-3934 — protected-CI freed-object failure in CombatFeedbackTimeline: diagnosis and repair

Failed CI: run `34729583982`, job `103649782121` (PR #357), 16 static checks + 545
Godot suites; suite 504 `tests/take_damage_contract_routing_test.gd` raised
freed-object `.visible` errors at `combat_feedback_timeline.gd:131/:142` followed
by combat-feedback routing assertion failures. Reproduced locally on unchanged
candidate `7d6053bc…` (`ci-suite-fail-before-fix.log`: same two freed-access sites).

## Root cause (two defects, one mechanism)

The routing test's `_free_feedback_nodes()` immediately `free()`s every node in the
`combat_feedback_labels`/`combat_feedback_flashes` groups between fixtures — a
legitimate external lifetime owner. The pooled timeline kept those freed nodes in
its `_numbers`/`_ticks` arrays:

1. `_acquire_number`/`_acquire_tick` read `.visible` on freed pool members and
   handed the freed node back (the CI errors); the subsequent spawn then produced
   no valid `CombatDamageNumber`, so the fixture's `find_child` and color
   assertions failed (the routing failures).
2. Found while fixing: `spawn_number` reset `label.modulate` to white AFTER
   `label_setup` had set the damage-type/crit color — the pooled path had been
   clobbering the setup color since introduction; the same fixture check exposes it.

## Repair (granted paths only)

`scripts/combat_feedback_timeline.gd`: acquisition compacts each pool to live
members and returns only valid reusable items; release paths guard invalid nodes;
`spawn_number` now resets only `modulate.a` so the setup-owned RGB survives.

## Before/after regression evidence

`tests/p3_feedback_allocation_test.gd` section K: external immediate frees of live
pooled group members, then subsequent spawns (valid items required), setup-color
parity on the replacement, overlap with a live item, full completion and
orphan-free cleanup.

- BEFORE (candidate `7d6053bc` timeline + new regression): exit 3 — three
  freed-object errors and `FAIL: lifetime case: post-free spawn returned no valid
  number` (`pfa-before.log`).
- AFTER (repair): exit 0, `P3_FEEDBACK_ALLOCATION_TEST PASS` (`pfa-after.log`).
- `take_damage_contract_routing_test`: FAIL exit 3 on the candidate
  (`ci-suite-fail-before-fix.log`) → PASS exit 0 on the repair (`tdcr-after.log`).

## Fresh runtime matrix (runtime change invalidates prior lifetime/performance
evidence; observed driver, exclusive gate, strict foreign-overlap NONE, all exits 0)

| Run | Peak / limit | FPS avg / 1% | Mem |
|---|---:|---:|---:|
| P3 run 1 | 3,845 / 4,000 | 735.9 / 581.0 | 162.7 MiB |
| P3 run 2 | 3,829 / 4,000 | 730.6 / 550.3 | 162.5 MiB |
| P1 | 2,246 | 735.7 / 430.8 | 148.0 MiB ≤ 400 |
| P2 (48 held) | 4,032 / 5,000 | 516.3 / 360.7 | 150.0 MiB |

Every in-JSON check true; boss alive throughout; one accepted ultimate of 18
attempts; orphans 0→0; non-monotonic; P2 exactly 48 enemies.
