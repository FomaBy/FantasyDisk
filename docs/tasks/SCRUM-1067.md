# SCRUM-1067 — Созвездия 3×6: design/balance contract

Статус: done
Версия: 0.2.1
Jira: SCRUM-1067
Контур: Codex
Owner: Back-end/Class Balance Codex
Thread: /root/audit_new_sprint_tail
Locked paths: `docs/design/systems/meta_constellations.md`,
`docs/design/systems/progression_balance.md`,
`docs/design/systems/characters_weapons.md`, `docs/design/systems/combat.md`,
`docs/design/mechanics_extract.md`, SCRUM-1067 reports/data/validator and this
mirror. Runtime/UI/art paths are explicitly excluded.

## Scope

- Exact 17 classes × three canonical weapons.
- One free core + three six-node cost-1 branches + two revealed/purchased
  hidden side nodes = 21 nodes and 20 spend per class.
- 306 explicit branch nodes (five distinct boons + final per weapon), 34
  explicit revealed-then-purchased hidden profiles and 51 distinct
  mechanic-first finals, all strictly scoped to their owning weapon.
- Class-trio balance model, 5/6→6/6 and A5 gates.
- Schema 5→6 economy, migration and non-combat `legacy_mastery` compensation.
- Machine manifest, executable validator and SCRUM-1068 test plan.

## Explicit exclusions

No edits under `scripts/**`, no runtime tests, `ui_screens.gd`,
`current_game_state.md`, `menus_ui.md`, UI assets/mockups, PixelLab or Godot UI
implementation. Those belong to SCRUM-1068 and related Atlas tasks.

## Evidence

- `docs/design/data/scrum1067_weapon_finals_manifest.json`
- `docs/design/reports/scrum1067_constellation_3x6_balance_spec.md`
- `docs/design/reports/scrum1067_constellation_3x6_test_plan.md`
- `tools/validate_scrum1067_constellation_spec.py`
- `tools/test_validate_scrum1067_constellation_spec.py`

## Verification plan

- JSON syntax and executable semantic validator.
- Canonical docs cross-link and stale-contract audit.
- Independent read-only review.
- `git diff --check`, scoped file audit and fresh-origin integration.

## Verification evidence (pre-landing)

- Semantic validator: PASS — 17 classes, 306 branch nodes, 51 finals, 34 hidden,
  exact 21 nodes/20 spend per class; all consumer paths resolve.
- Executable validator mutation gate rejects typed-boon, migration, balance,
  no-op/unreviewed final, non-finite/arithmetic/CCT baseline, reveal/purchase and
  missing-consumer corruption.
- Fresh no-meta Godot gates through semaphore: balance harness PASS 51/51
  (worst CCT `sniper/sniper_deadeye_rifle/20` `+20.6%`), global damage PASS,
  global survivability PASS.
- JSON syntax, Python compile, `git diff --check`: PASS.
- Runtime/UI/art edits: none.

## Result

Design/balance handoff для SCRUM-1068 завершён: утверждены точные 17×3 weapon
trios, free core, 306 explicit branch nodes, 34 hidden profiles, 51 уникальный
mechanic-first final, closed 20-point economy и schema-5→6 migration с
non-combat `legacy_mastery`. Manifest содержит полный per-weapon current
no-meta baseline и честно маркированные target (не measured) after contracts;
report содержит 51-row weapon и 17-row class-trio before/target tables.

Independent read-only review: PASS после исправления P1 по explicit boon/hidden
profiles, полным baseline axes, typed validator floors, exact migration/balance
contracts, approved final/baseline hashes и canonical doc structure.

Disk cleanup: removed `.godot` (446–511 MB import caches across gates), isolated
Godot HOME directories, generated build reports, 23 generated `.gd.uid`
sidecars and Python caches. No disposable task artifact remains in the worktree.
