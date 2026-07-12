# SCRUM-1091 — Atlas exact upgrade descriptions and strong unique finals

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1091
Контур: Codex
Owner: Codex Back-end / balance
Thread/Worker: /root/scrum1091_atlas_backend
Dependency: cleared 2026-07-12 — SCRUM-1090/SCRUM-1092 independent re-QA PASSED;
SCRUM-1088/SCRUM-1089 are `Готово` and released overlapping
`scripts/ui_screens.gd` locks.

## Design handoff

- source spec:
  `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/spec.md`;
- PixelLab source/provenance:
  `docs/design/references/scrum1090_atlas_upgrade_descriptions/`;
- preview, debug overlay and responsive matrix:
  `docs/design/previews/scrum1090_atlas_upgrade_descriptions/`.

## Back-end scope

- runtime Atlas dossier only in `scripts/ui_screens.gd` after existing locks are
  released;
- localized schema-6 effect/final descriptions in a focused data/formatter
  owner path;
- final-strength audit against the existing `gain_over_order_5_min >= 1.20`
  contract without weakening class-trio balance gates;
- focused description/final-strength, schema-6 lifecycle/live matrix,
  no-overlap and runtime tests;
- progression/balance/UI system docs.

## Acceptance

- all 357 class nodes expose non-generic Russian copy with the affected value,
  exact numeric change, owning weapon/scope and path progress;
- all 51 weapon finals expose distinct trigger/mechanic/caps and boss behavior;
- every final remains unique and delivers at least the existing +20% strength
  floor over its preceding order-5 node, or a documented equivalent utility
  result accepted by the balance harness;
- long descriptions scroll inside the dossier; price and Buy remain pinned;
- no content touches the frame ornament at 1280×720, 1920×1080 or 2560×1440;
- Jira starts only after SCRUM-1090 QA and overlapping owner locks are released.

## Dependency release (2026-07-12)

SCRUM-1090 и bug SCRUM-1092 приняты independent re-QA. SCRUM-1088 и
SCRUM-1089 находятся в `Готово`; прежние overlapping locks освобождены. Jira
label `blocked` снят. Задача остаётся unclaimed `К выполнению` и готова для
отдельного Back-end/balance claim-first worker.

## Implementation result (2026-07-12)

- Added `scripts/constellation_description_formatter.gd`: one fail-closed
  formatter/data contract for 17 cores, 255 boons, 34 hidden nodes and 51
  finals. It consumes authoritative schema-6 parameters instead of duplicating
  gameplay values.
- `scripts/meta_progression_tree_data.gd` now exposes `dossier` and exact
  Russian `desc` on all 357 class nodes.
- The 51 order-5 identity boons use exact source-identity-keyed Russian copy;
  any manifest identity drift fails closed instead of reusing stale prose.
- `scripts/ui_screens.gd` implements the accepted SCRUM-1090 hierarchy inside
  `AtlasNodeScroll`; `УНИКАЛЬНЫЙ ФИНАЛ` is native text. Price and Buy remain
  pinned outside scroll, finals never expose the legacy toggle, and the panel
  keeps a 30px ornament reserve.
- The stale schema-5 Atlas smoke oracle was migrated to schema 6 (`21` nodes,
  weapon finals, no toggle). This exposed and fixed the real hidden-star UI
  path: reveal facts plus branch connectivity now unlock an explicit cost-1
  purchase; reveal alone does not activate the effect.
- No gameplay mechanic, cap, manifest value or balance multiplier changed.

## Balance decision

Baseline and after are intentionally identical because SCRUM-1067/1068 already
prove unique mechanics and `gain_over_order_5_min >= 1.20` for every final.
`balance_harness` and global damage gates were green before implementation; a
numeric retune would be unrelated risk.

### Class-trio before → after (unchanged)

| class | weapons | trio solo DPS | trio 5T DPS | trio EHP | after |
| --- | --- | ---: | ---: | ---: | --- |
| berserk | sword / axe / hammer | 144.0 | 450.1 | 360.6 | unchanged |
| soldier | rifle / grenade / bayonet | 144.0 | 450.0 | 312.2 | unchanged |
| thief | coin / dagger / smoke | 155.6 | 486.0 | 207.6 | unchanged |
| elementalist | orb / prism / meteor | 155.5 | 534.6 | 152.4 | unchanged |
| sniper | deadeye / spotter / shatter | 165.6 | 360.0 | 368.4 | unchanged |
| priest | reliquary / censer / chime | 136.5 | 434.7 | 258.0 | unchanged |
| biologist | spore / injector / symbiote | 143.1 | 573.5 | 208.2 | unchanged |
| robot | anchor / press / reactor | 135.6 | 415.7 | 541.1 | unchanged |
| engineer | sentry / drone / mines | 135.5 | 483.9 | 255.0 | unchanged |
| dark_mage | book / skull / wand | 139.1 | 672.7 | 151.2 | unchanged |
| guitarist | guitar / bass / amp | 144.0 | 585.0 | 204.0 | unchanged |
| assassin | chakrams / daggers / wire | 215.4 | 362.0 | 262.8 | unchanged |
| ranger | crossbow / longbow / trap | 215.3 | 362.2 | 204.3 | unchanged |
| doctor | potion / syringe / saw | 122.4 | 382.4 | 277.3 | unchanged |
| chemist | powder / acid / homunculus | 139.1 | 672.8 | 160.6 | unchanged |
| knight | spear / shield / flail | 128.5 | 382.5 | 563.0 | unchanged |
| druid | amulet / briar / totem | 144.1 | 449.9 | 251.7 | unchanged |

The full 51-row per-weapon table is generated by `build/balance_report.md`.
All pairs stay inside solo/crowd gates; worst 20-target CCT is `+20.6%`
(`sniper_deadeye_rifle`) inside `±30%`. Because this task changes presentation
only, every per-weapon row is identical before/after.

## Focused verification

- `tools/validate_scrum1067_constellation_spec.py`: PASS (`17/306/51/34`).
- `tools/validate_scrum1068_runtime_manifest.py`: PASS (`357+25=382`).
- `tests/scrum1091_atlas_descriptions_test.gd`: PASS (`357 dossiers`, `51`
  unique final descriptions/mechanic IDs, `51` distinct localized order-5
  identities, floor `>=1.20`, no raw param tokens). Adversarial fixtures cover
  missing params, wrong scope, invalid core, stale identity, weak/mismatched
  finals, invalid cap values and explicit safe-failure propagation.
- `tests/scrum1091_atlas_dossier_ui_test.gd`: PASS at 1280×720, 1920×1080,
  2560×1440 and same-instance resize; scroll/pinned controls/no-toggle/safe zone.
- Baseline `tools/balance_harness.gd` and
  `tests/global_damage_balance_smoke_test.gd`: PASS.
- `tests/meta40_atlas_screen_smoke_test.gd`: PASS after schema-6 oracle
  migration, including all three simultaneous finals and hidden reveal→purchase.

Remaining risk: localized phrases are deterministic and exact, but final
wording may still receive editorial polish; schema and numbers are protected by
fail-closed tests.
