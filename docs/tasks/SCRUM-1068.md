# SCRUM-1068 — Schema-6 weapon constellations runtime

Статус: in_progress
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

Disk cleanup: pending active implementation.
