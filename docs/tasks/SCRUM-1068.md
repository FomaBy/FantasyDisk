# SCRUM-1068 — Schema-6 weapon constellations runtime

Статус: new
Версия: 0.2.1
Jira: SCRUM-1068
Контур: Codex
Owner: Back-end / Codex
Thread/Worker: `/root`
Branch: `codex/scrum1068-schema6`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1068-schema6`
Parent: SCRUM-219
Design gate: SCRUM-1075
Design source: SCRUM-1067

## Locked scope

- production schema-6 manifest/loader and parity tools;
- `meta_progression_tree_data.gd`, `meta_progression.gd`, `main.gd`,
  `player.gd`, `progression_data.gd`, `combat_director.gd`;
- owning weapon consumers named by the SCRUM-1067 manifest and only the combat
  primitives required by their explicit mechanics;
- schema-6 migration, behavioral, balance and regression tests;
- required progression/combat/weapon/current-state documentation.

`scripts/ui_screens.gd` and Atlas runtime layout tests are excluded until the
PixelLab-first SCRUM-1075 mockup is accepted. SCRUM-1073 is separately owned
and must remain sequential with the later Atlas UI phase.

## Exact contract

- 17 free class cores + 306 explicit branch nodes including 51 finals + 34
  hidden nodes = 357 class nodes; frozen Guild Atlas adds 25 for 382 runtime
  nodes total;
- each class is free core + three owning-weapon paths of six cost-1 nodes + two
  revealed-then-purchased hidden cost-1 side nodes, for 21 nodes / 20 spend;
- all three finals may be purchased and active simultaneously, but every boon,
  hidden and final is isolated to its canonical weapon ID;
- schema-5 migration computes the frozen old reward first, preserves Guild and
  progression/reveal facts, refunds class allocations, stores non-combat
  `legacy_mastery=max(old_earned-20,0)`, removes active keystones and is
  idempotent;
- schema-6 spendable rewards are `[2,2,3,4,4,5]`, challenges reveal hidden
  nodes but grant no spendable or combat bonus;
- unknown/no-op effect or mechanic IDs are hard validation/runtime failures;
  behavioral coverage requires 51 positive final fixtures and two same-class
  foreign-weapon negatives per final at relative epsilon `1e-6`.

## Phases

1. Generated production manifest and exact parity/mutation gate.
2. Schema-5→6 migration, economy, reveal ledger and Guild preservation.
3. Typed owning-weapon profile/API and save/continue propagation.
4. Five ordinary boons and purchased hidden effects for all 51 paths.
5. All 51 mechanic-first finals with caps, attribution and lifecycle cleanup.
6. Balance scenarios and full combat/runtime regression.
7. Atlas UI only after SCRUM-1075 becomes accepted; preserve SCRUM-1070.

Partial commits use `FSD_NO_AUTOLAND=1` and are not pushed until a green
integration boundary. Jira heartbeats and final cleanup record the live phase.

Disk cleanup: all isolated `/tmp/fsd-s1068-*` Godot homes and the registered
implementation worktree were removed after push/QA routing; final mirror-sync
worktree removal is recorded in Jira.

## Backend/runtime result — 2026-07-11

Phases 1–6 are implemented and green in the isolated Codex worktree:

- generated production manifest + typed loader: `17 / 306 / 51 / 34`,
  `357 + frozen Guild 25 = 382`;
- schema-5→6 migration preserves Guild/progression/reveal facts, refunds class
  allocations, records non-combat legacy mastery and rejects disconnected or
  over-budget native-schema corruption;
- challenge weapon diversity accepts only the exact three canonical IDs of the
  owning class;
- Player reconstructs profiles from canonical node IDs and applies ordinary,
  hidden and final effects only to the exact owning weapon;
- all 51 finals have an explicit required event and consumer registration;
  the 11 non-ClassWeapon/special consumers implement their own capped state and
  lifecycle, including bounded repair tether/shield and summon-death bridges;
- independent post-review rejected the first resolver-only proof; the correction
  pass now routes ordinary finals through live hit/dodge/absorb/death/expiry
  consumers, setup marks, delayed waves, target/chain caps and Player-owned
  timed shields with derived-stat refresh;
- balance harness covers `no_meta`, `5/6`, `6/6`, all three finals, `20/20` and
  A5; roster max/min is `1.018636` and hard rails pass.

Verification:

- manifest parity + 12 mutation corruptions, including deletion of a bound
  rifle runtime route: PASS;
- migration/economy/Guild preservation/corrupt-save normalization: PASS;
- typed profiles and live Berserk/HolyFlail/Summoner consumers: PASS;
- 51 positive final fixtures + 102 same-class foreign negatives: PASS;
- 11 special-final behavior/cap/lifecycle fixtures: PASS;
- black-box live runtime mitigation, suppression, setup/consume, delayed
  grenade/prism/meteor and overlapping-shatter fixtures: PASS; the same gate
  covers Bayonet line geometry, one-hit Censer ward, Reactor knockback, one
  Dark Book collapse per cast and Acid reset/rearm;
- skull/reliquary death-expiry and plague/wire/saw stack-reset lifecycle
  fixtures: PASS twice independently;
- schema-6 per-hero and Meta/Guild regression suites: PASS;
- all 51 weapon scenes / 39 live attack modes: PASS;
- full `tests/runtime_smoke_test.gd`: PASS (15,206-file duplicate guard; existing
  headless dummy-renderer null-texture diagnostic remains non-fatal).

Independent post-fix review: PASSED after two rejection/correction cycles. The
final pass independently confirmed the delayed Bayonet brace token/deadline,
the shared Dark Book three-hit per-cast ledger and one-collapse cap, then reran
the live runtime and full smoke gates without compile/runtime regressions.

Phase 7 Atlas visual/runtime layout remains excluded: SCRUM-1075 has a valid
PixelLab-ready plan but the external PixelLab account has `$0` balance and only
3 generations, below the required 20–40. No fallback art and no edit to
`scripts/ui_screens.gd` was made. SCRUM-1073 remains sequential behind that UI
phase.

Disk cleanup: transient Godot HOME/user-data directories and the registered
implementation worktree removed after the mandatory push and Jira QA transition.

## QA-Вердикт (2026-07-12)

Статус: FAILED

Проверено на чистом `origin/dev@ab189f75f` (`dc4882cb7` — runtime
изменения): balance harness; Schema-6 manifest loader, migration,
typed profiles, 51×3 event matrix, special/live/lifecycle/consumer suites;
Meta/Guild/per-hero regression; 51 weapon scenes; full runtime smoke. Эти
проверки зелёные, включая delayed Bayonet deadline, shared
per-cast three-hit Dark Book cap, source-scoped one-hit Censer ward, per-volley
Shatter cap и Acid reset/rearm.

Блокер: canonical `tools/validate_scrum1068_runtime_manifest.py`
завершается с exit `1`: `bayonet_brace_countershot: consumer never invokes
required event brace_hit`. В `FINAL_ROUTE_METHODS` mechanic привязан к
`_fire_bayonet_cone`, но реальный delayed event находится в
`_resolve_bayonet_brace_countershot`. Из-за этого mutation suite также
красный на canonical baseline и не может доказать отклонение 12
мутаций.

Баг: Jira `SCRUM-1078`. SCRUM-1068 возвращён в `К выполнению` до
исправления mechanic-bound route proof и повторного QA.
