# FAN-3992 — 0.3.1.2 technical-rebuild release inputs

`v0.3.1.1` failed native Windows verification (FAN-3990) and was never
published; its protected tag stays in place. The rebuild with the FAN-3991
Doctor-ultimate crash fix ships as technical hotfix `0.3.1.2`. Product version
stays 0.3.1.

Base: `origin/dev` = `2b8026387bdb9cb7db3a65ef5c3a877984540b1b`
(tree `9f87bdb54f89014eeb883bce42346962a7de08ce`, PR #371), nothing newer on
`dev` when work started. Host: macOS, Godot 4.7.

## Rework 1 (QA FAILED `96684dbc`, verdict comment `01a0f6d6`)

Independent QA (run `01a0f695`) found the separately run FAN-3991 session gate
red once in 11 runs: `dark_mage_then_doctor_natural_end` logged
`Trying to cast a freed object` at `scripts/classes/dark_mage_weapon.gd:126`.
The Dark Mage wand chain keeps its target nodes in an `Array` bound into tween
callbacks; `_launch_dark_chain_hop` and `_resolve_dark_chain_hit` cast the
stored entry to `Node2D` before `is_instance_valid`. A target freed between
hops aborts the chain in the editor and, per FAN-3985, a release template
dereferences the dangling pointer on that cast. The defect predates FAN-3992
(last change FAN-3840) and was in 0.3.1 and 0.3.1.1.

Fix (code commit `ad35d9f331fb5b1883466f8d48bdd2a89c33d443`, tree
`dc35d904dfe01e254538598e152a942394da148a`): both functions read the raw entry
and cast only after `is_instance_valid`; live targets behave as before.

Audit (`deferred_callback_audit.txt`): every deferred callback in
`scripts/classes/**` (`Callable(self, ...)`, `.bind`, `tween_callback`,
`connect`, `call_deferred`, the soldier executor's `deferred(...)`, and the ten
tween lambdas) was checked. No other instance: the rest re-resolve nodes with
`instance_from_id` (null when freed), iterate a fresh query in the same call,
or bind only ids/values. `_apply_weapon_dot_tick` and `_release_effect` take a
typed `Node` argument; a freed argument is rejected by call validation before
the body runs (the pre-existing `Cannot convert argument 1` log line), and both
bodies check `is_instance_valid`. No enemy is freed with an immediate
`free()` anywhere in `scripts/**`.

Regression test `tests/fan3992_dark_chain_freed_target_test.gd` (+ `.uid`):
a freed target stored ahead of a live one, for the hop path and the hit path
(the live target must still be reached), plus a live-only chain (each hit once,
second hit keeps the `pierce_damage_falloff` ratio). Negative control
(`negative_control_rework1.txt`): on the old `dark_mage_weapon.gd` it fails
with two `Trying to cast a freed object` script errors and both freed-target
cases report 0 hits on the live target.

Player notes: one line added to the single `[0.3.1.2]` entry (CHANGELOG and
in-game notes): «Исправлена редкая ошибка цепи Темной палочки Тёмного мага,
когда цель погибала до прилёта снаряда.» (weapon title as shown in game).

Focused suites (`focused_suites_rework1.txt`, dirty tree, non-certifying):
the new test, `fan3987_four_component_version_test`, the three
`patch_notes_*` suites, `update_manager_test`, `dark_mage_kit_test`,
`dark_mage_ultimate_live_test`, `projectile_chain_pierce_identity_test`,
`fan1893_capability_contract_test` — all PASS. Release guards and the
0.3.1.2 version mapping still pass with the new line.

Gates for the rework candidate (published on the card, not in the candidate):
the complete certifying gate from the clean candidate, the session gate once
for the full set, and `FAN3991_SEQUENCES=dark_mage_then_doctor_natural_end`
at least 10 times, all clean. Stale certification captures are re-taken only
if the gate reports them, after this evidence commit.

## Commits

1. Code commit `a5dbf5c3582a693cec6cc070802f80ddfa12eb56`
   (tree `44d930090d0618ba970414ce7898d2ce4fb30dd2`): version, notes, poster
   copy and the updated four-part version test.
2. Evidence commit `93598683c` (first run, gate interrupted by host sleep) and
   this evidence update.
3. Recapture of the three strict FAN-3942 certification packages (Assassin,
   Doctor, Druid) from the clean evidence commit. The capture tests treat any
   later non-capture path as stale, evidence included, so the captures come
   last and name the evidence commit as their source. The certifying gate
   verdict therefore cannot live inside the candidate it certifies; it is
   published on the FAN-3992 card with the candidate SHA, as in FAN-3987.

## Write set

| Path | Change |
|---|---|
| `project.godot` | `config/version="0.3.1.2"` |
| `export_presets.cfg` | macOS `application/version="1.3.12"` (short version stays `0.3.1`); Windows `file_version` and `product_version` `"0.3.1.2"` |
| `CHANGELOG.md` | unreleased `[0.3.1.1]` entry becomes `## [0.3.1.2] — 2026-09-30`: the existing animation line plus «Игра больше не вылетает в долгой сессии, когда ультимейты Доктора используются после игры за другого героя.»; empty `Unreleased` on top; `[0.3.1]` unchanged |
| `scripts/patch_notes_data.gd` | newest entry `0.3.1.1` → `0.3.1.2` with the same two lines plus the Rework 1 line; no logic change |
| `scripts/classes/dark_mage_weapon.gd` | Rework 1: validity check before casting stored chain entries |
| `tests/fan3992_dark_chain_freed_target_test.gd` (+ `.uid`) | Rework 1 regression test |
| `assets/marketing/fantasydisk_0312_announcement.png` (+ `.import`) | byte-identical copy of the 0.3.1 poster; `.import` generated by Godot, fresh UID `uid://cnge6q2jbx4dy`, import parameters identical to the 0.3.1.1 poster; 0.3.1.1 poster left in place |
| `tests/fan3987_four_component_version_test.gd` | now targets 0.3.1.2 (see below) |
| `docs/design/references/weapon_ultimates/{assassin,doctor,druid}/**`, `docs/design/reference-assets-lfs/ultimate-certification/{assassin,doctor,druid}/**` | recaptured certification packages the gate reported stale (commit 3) |
| `evidence/FAN-3992/**` | this directory |

## Focused test

`tests/fan3987_four_component_version_test.gd` now checks:

- updater: `compare_versions` 0.3.1 < 0.3.1.2, 0.3.1.1 < 0.3.1.2 (and the
  reverses), 0.3.1.0 == 0.3.1, 0.3.1.2 < 0.3.1.3 and < 0.3.2; a 0.3.1.2 manifest
  validates; 0.3.1 and 0.3.1.1 clients are offered it, a 0.3.1.2 client is not;
- badge: no `0.3.1.1` entry is left, exactly one `0.3.1.2` entry,
  `entries_since("0.3.1")` is exactly `[0.3.1.2]`, no badge once 0.3.1.2 was
  seen, and the newest note equals the project version;
- main menu: `MainMenuVersionLabel` reads `v0.3.1.2`.

Three-component comparisons are untouched (no change to
`_version_greater`/`compare_versions`).

Results: `focused_suites.txt` — this test plus `patch_notes_composition_test`,
`patch_notes_data_smoke_test`, `patch_notes_smoke_test`, `update_manager_test`,
all PASS (non-certifying, dirty tree before commit).

Negative control (`negative_control.txt`): with the notes file reverted to the
`0.3.1.1` entry and project version 0.3.1.2, the test fails with «the
unpublished 0.3.1.1 patch-notes entry must be replaced by 0.3.1.2» and
«expected exactly one 0.3.1.2 patch-notes entry, got 0».

## Release inputs

- `release_version_mapping.txt`: `tools/release_version_mapping.py --version
  0.3.1.2 --project project.godot --export-presets export_presets.cfg` →
  `0.3.1  1.3.12  0.3.1.2  0.3.1.2`, exit 0. The same check for 0.3.1.1 now
  fails (exit 2), as expected.
- `release_guards.txt`: visual-claims guard OK for 0.3.1.2, release-scope
  guard OK, changelog fragment region current, both posters SHA-256
  `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7`.

## Quality gate

First run (`gate_interrupted_partial.txt`): started from the clean code commit;
every static step (including Python unit), the Godot import pre-pass and Godot
suites 1–2 of 565 passed, then the run was stopped because the MacBook was on
battery with the lid closed and kept entering system sleep (~16 h to reach
suite 3). That run is not a verdict; it is kept only as history.

Second run, on AC power with the lid open: all 17 `*_certification_capture_test`
suites from the clean evidence commit `93598683c`. Exactly three are stale —
Assassin, Doctor and Druid — each naming the FAN-3992 paths (poster, test,
`scripts/patch_notes_data.gd`, `evidence/FAN-3992/**`) as post-capture changes;
the other 14 pass. Those three are re-captured in commit 3; nothing else.

Final verdict: `python3 tools/quality_gate.py --profile changed --changed-ref
origin/dev`, complete and unfiltered, plus the FAN-3991 single-process session
gate `python3 tools/godot_gate.py --headless --path . --script
res://tests/ultimates/multi_class_session_lifecycle_test.gd`, both from a clean
checkout of the final candidate. Results are published on the card. The
certification/timeline suites need the LFS reference assets hydrated:
`git lfs pull --include="docs/design/reference-assets-lfs/**"`.
