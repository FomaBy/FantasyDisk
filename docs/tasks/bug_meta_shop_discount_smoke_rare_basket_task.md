# BUG: Meta shop-discount smoke compares rare-upgraded baskets

Статус: new
Версия: 0.2.1
Jira: SCRUM-1027
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
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
   versus `290`.

## Root-Cause Evidence

`atlas_m5` enables `guaranteed_rare_shop`. In `_random_shop_items()`, a basket
without a tier-3 item replaces one sampled item with a separately selected rare
item. The discounted run therefore does not necessarily contain the same
basket as the base run; its total may rise even when `shop_price_mult` is
correctly applied. The current smoke conflates two independent mechanics.

## Expected

The discount oracle compares identical item identities/base costs or isolates
the pure discount node. A separate assertion verifies the guaranteed-rare
capstone. Repeated deterministic seeds stay green while a real multiplier or
rare-guarantee regression still fails.

## Acceptance Criteria

- Verify the exact `shop_price_mult` against the same basket, with rounding and
  minimum-price behavior explicit.
- Verify `atlas_m5` still guarantees at least one tier-3 shop item when the
  original sample lacks one.
- Repeat enough deterministic seeds/baskets to prove the test is stable.
- `meta_skill_tree_smoke_test.gd`, `meta40_atlas_screen_smoke_test.gd`,
  `meta_progression_smoke_test.gd` and full runtime smoke pass.
- Update relevant meta/test documentation; route to independent QA.

Disk cleanup: none created while recording the unassigned bug.

Thread cleanup: not a disposable worker thread.
