# BUG: Meta shop-discount smoke leaves artifact-family RNG unseeded

Статус: review
Версия: 0.2.1
Jira: SCRUM-1027
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1027`
Приоритет: medium
Роль: Back-end
Найдено при проверке: SCRUM-1024 / SCRUM-1026

## Scope And Locks

- `tests/meta_skill_tree_smoke_test.gd::_test_shop_discount`;
- the smallest deterministic test helper/evidence needed to compare identical
  item identities/base costs;
- this mirror and focused test documentation.

Production shop/meta behavior remains read-only unless diagnosis proves a
separate runtime defect. Claim the Jira issue before editing. Do not overlap an
active Atlas/meta owner.

## Reproduction

1. Run `tests/meta_skill_tree_smoke_test.gd` repeatedly on fresh `origin/dev`
   with an isolated `user://`.
2. `_test_shop_discount()` seeds RNG `4242`, samples four items without nodes,
   then enables `atlas_m4` + `atlas_m5` and samples again with the same seed.
3. Observe failures such as discounted total `385` versus base `333`, or `492`
   versus `290`, even though the weighted item-selection RNG was reset.

## Root-Cause Evidence

`atlas_m4` and `atlas_m5` both provide only `shop_price_mult = -0.02`; neither
enables `guaranteed_rare_shop` (that separate capstone is `atlas_k0` and already
has `_test_guaranteed_rare_shop_capstone()`). The test resets only `game.rng`,
which controls `_weighted_sample()`. `ProgressionData.shop_items()` first
materializes rarity-scaling artifact families through
`roll_artifact_family_tier()`, whose default path uses the global RNG. Base and
discount runs can therefore receive the same weighted positions but different
materialized tiers/costs. Aggregate totals are not comparable until both RNG
sources are reset and item identity/tier equality is proven.

## Expected

The discount oracle resets both `game.rng` and the global RNG for each base /
discount pair, proves identical item IDs/kinds/tiers, then checks the exact
rounded `shop_price_mult` result per item. The existing independent
guaranteed-rare capstone assertion remains green. Repeated deterministic seeds
stay stable while a real multiplier or basket-identity regression still fails.

## Acceptance Criteria

- Reset both RNG sources and verify exact `id`/`kind`/`tier` equality for each
  paired basket.
- Verify the exact `shop_price_mult` per item, with rounding and minimum-price
  behavior explicit.
- Keep the existing separate `atlas_k0` guaranteed-tier-3 assertion green.
- Repeat enough deterministic seeds/baskets to prove the test is stable.
- `meta_skill_tree_smoke_test.gd`, `meta40_atlas_screen_smoke_test.gd`,
  `meta_progression_smoke_test.gd` and full runtime smoke pass.
- Update relevant meta/test documentation; route to independent QA.

## Implementation Result

- Replaced the aggregate-total oracle with four paired deterministic baskets.
- Reset both item-selection and artifact-family RNG sources for every base /
  discount pair.
- Asserted the exact `atlas_m4 + atlas_m5` multiplier (`0.96`), basket identity,
  tier identity, per-item rounding and the minimum price guard.
- Restored the process-global RNG to ordinary runtime mode after the successful
  paired oracle, avoiding deterministic state leakage into later smoke cases.
- Left production shop/meta behavior unchanged; the existing independent
  `atlas_k0` guaranteed-rare gate remains the authority for that capstone.

## Verification

- `meta_skill_tree_smoke_test.gd`: PASS on four isolated successful runs after
  the final RNG cleanup (root + independent reviewer).
- One additional repetition stopped before this oracle on the independently
  tracked SCRUM-1028 Bastion harness flake; the direct rerun passed and the
  reproduction was attached to SCRUM-1028 rather than duplicated.
- `meta40_atlas_screen_smoke_test.gd`: PASS.
- `meta_progression_smoke_test.gd`: PASS.
- `runtime_smoke_test.gd`: PASS (the known null dummy-renderer screenshot
  diagnostic remained non-fatal and the suite exited `0`).
- Independent pre-land code review: PASS; no actionable findings remain.

Landed: `f33e98ec4` on `origin/dev`; routed to independent QA.

Disk cleanup: removed task `.godot` cache (~451 MB) and all isolated `/tmp`
user-data directories; clean task worktree removal follows the routing commit.

Thread cleanup: not a disposable worker thread.
