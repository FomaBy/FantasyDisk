# FAN-3991 — 0.3.1.1 crash with memory corruption when Doctor ultimates follow another class

Developer evidence (Claude Dev Fable, macOS development host, Apple M4 Pro,
Godot `4.7.stable.official.5b4e0cb0f`, official 4.7 export templates). Base
`dev` = `01ee13687da712342964bcafebdb79c8a38b7d1e` (tree
`039b17c52480bb27c28d723248a8b85d4418bb58`, the `v0.3.1.1` source). Code
commit `4386342d10ba47cb6d92c81e8e4ba5ce7a770279` (tree
`79e7328320f732cd5423e95bf6623ca3f5716530`). The exact candidate SHA/tree is
recorded on the Multica card; the commits after the code commit carry only
this directory and the re-shot Assassin/Doctor/Druid certification packages,
nothing the export reads.

## What was wrong (FAN-3990 native Windows review, reproduced here)

The 0.3.1.1 Setup crashed in 7 of 7 long sessions that played combats for
another class and then Doctor ultimates (5 × `0xc0000005` in combat, 2 ×
`0xc0000374` heap corruption at exit), always after the same engine chain:
`remove_child(): Parent node is busy adding/removing children` →
`~Node: Condition "data.parent" is true` → hundreds of
`is_greater_than: !data.tree` / `canvas_item_set_draw_index: canvas_item is
null`.

### Root cause (macOS reproduction with GDScript backtrace)

`scenes/vfx/ultimates/doctor/doctor_ultimate_timeline_scene.gd` parents its
victim-impact service (`UltimateVictimImpactPlayer`) *beside* the scene, under
the effect parent — the shipped `Player._vfx_parent()` is `Main`
(`current_scene`) — and released it with a synchronous `free()` from
`finish()` (`_clear_impacts`). When a fight ends while the cast is live,
`finish()` runs inside an exit-tree propagation:

```
[0] _clear_impacts   scenes/vfx/ultimates/doctor/doctor_ultimate_timeline_scene.gd:876   _impacts.free()
[1] finish           scenes/vfx/ultimates/doctor/doctor_ultimate_timeline_scene.gd:203
[2] finish           scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd:117
[3] ultimate_host_finish_presentation  scripts/ultimates/controller/ultimate_player_host.gd:280
[4] _shutdown        scripts/ultimates/controller/ultimate_controller.gd:161
[5] cancel           scripts/ultimates/controller/ultimate_controller.gd:134
[6] _exit_tree       scripts/ultimates/controller/ultimate_player_host.gd:125
[7] _retire_owned_player_node  scripts/main.gd:1715      parent.remove_child(player_node)
[8] _clear_world     scripts/main.gd:1619
[9] _end_combat      scripts/combat_director.gd:414
```

`Main.remove_child(player)` holds `Main` blocked (`data.blocked > 0`) while
the player's subtree leaves the tree; the host's `_exit_tree` cancels the
controller, the runtime finishes the Doctor scene, and the scene calls
`free()` on a node whose parent is the blocked `Main`. `Node::remove_child`
refuses (the first error), `~Node` destroys the object with `data.parent`
still set (the second), and `Main` keeps a dangling child pointer: every
later child-order change on `Main` (enemies and projectiles are added and
removed every frame) runs `canvas_item_set_draw_index` on freed memory, group
sorting walks the dead node (`is_greater_than`), and the heap is corrupted —
an access violation during the fight or a heap-corruption exit when `Main`
finally deletes its children. The reviewer's hint (`main.gd:1715`) is the
*trigger context* — the removal that blocks `Main` — not the refused call;
`main.gd` is unchanged.

Why only Doctor, and only after another class: the Doctor package is the
only class that parents its impact service outside its own scene and frees
it synchronously (Chemist, Robot and Soldier keep theirs as scene children;
Assassin/Druid/Doctor cast-pose sprites under the player's `VisualRoot` are
freed from the host's exit, before `VisualRoot` itself propagates, so their
parent is never busy). The service only exists after a beat that actually
hit enemies. The FAN-3990 driver fires 20 frames after `combat_active`,
without waiting for the FAN-3977 full-frame roster: in the first fights of a
process the packs are still loading and no enemy is in the arena when the
ultimate fires (`D_ult_doc_druid`: Doctor first, `nodes` 144/163/311,
`resident_packs` 9→18→23, no errors), while after other classes the packs
are resident, the crowd is present at the cast (`nodes` 671/517,
`resident_packs` 23) and the sibling exists at `_end_combat`. On macOS,
where the probe waits for the roster, Doctor first crashes too
(`repro/repro_doctor_only_during_cast.log`, exit 250).

### Fix (`doctor_ultimate_timeline_scene.gd`, `_clear_impacts`)

A scene may `free()` synchronously only its own children. A node it placed
outside itself is stopped, hidden and `queue_free()`d, so the scene tree
removes it at the end of the frame — the only point at which its parent is
guaranteed not to be busy. Own-child release (headless fixtures, the
timelines suite's zero-children contract) is unchanged. No error is
silenced, no log level lowered, no scene skipped; game IDs, saves, balance
and presentation data are untouched.
`tests/ultimates/presentation/doctor_ultimate_timelines.gd` now expects the
sibling to be queued for deletion, hidden and stopped after `finish()`.

## Fail-before reproduction (AC1)

`tools/ultimate_session_lifecycle_probe.gd` keeps ONE `scenes/Main.tscn`
alive and plays combat after combat through the shipped path
(`Main._start_combat()` → real Player → the `ultimate` InputMap action
through `Input.parse_input_event` → executor → host-owned presentation →
`_end_combat(true)`), the FAN-3990 `qa-mode=ult` sequence. Endings:
`during_cast` (the fight ends through the game's own `_end_combat(true)` 2.5 s
into the cast — what happens when the ultimate kills the last enemy, the
timer runs out or the player dies mid-cast), `natural` (cast end + 1 s, the
FAN-3990 `qa-natural-end` mode) and `force` (enemies freed first, the
FAN-3990 default).

| Sequence on `dev` 01ee1368 (headless, editor binary) | Result | Log |
|---|---|---|
| dark_mage → doctor, `during_cast` | 2 × busy/`data.parent`, 35 × `canvas_item is null`, 27 × `!data.tree`, 20 × `data.tree !=`; child died by signal 6 | `session-gate/fail_before_01ee1368/fan3991_session_dark_mage_then_doctor.log` |
| chemist → doctor, `during_cast` | 2 × busy/`data.parent`, 28 × `canvas_item`, 6 × `!data.tree`, 17 × `data.tree !=`; signal 6 | `…/fan3991_session_chemist_then_doctor.log` |
| dark_mage → doctor, `natural` | 0 errors, exit 0 (see note) | `…/fan3991_session_dark_mage_then_doctor_natural_end.log` |
| all 17 classes (registry order), `during_cast` | busy/`data.parent` at the first Doctor pair, 11 × `canvas_item`; SIGSEGV (exit 11) after 126 s | `…/fan3991_session_all_17_classes.log` |
| dark_mage → doctor, `force` (FAN-3990 default) | same chain, crash exit 250 | `repro/repro_dark_mage_doctor_during_cast.log`, `repro/…` |

Note on the natural end: at full frame rate the Doctor presentations'
declared `cancel` (2.8–3.9 s) is earlier than the executor chain end
(3.85–5.85 s), so the presentation is already released when
`_ultimate_active` clears and the fight ends with nothing live. The Windows
natural-end sessions ran at 1–14 FPS (one Doctor cast was not even active
after the input frame, `active_after_input:false`), so their "cast end" was
observed on a cast that was still live; the mid-cast ending reproduces that
state deterministically. Both variants are in the gate.

Direct probe run (`repro/repro_dark_mage_doctor_during_cast.log`) carries the
GDScript backtrace above.

## Regression gate (AC3)

`tests/ultimates/multi_class_session_lifecycle_test.gd` (auto-discovered by
`tools/quality_gate.py`, `tests/ultimates/**` is in every profile) runs the
probe in a child Godot process per sequence — `--disable-crash-handler` and
`--log-file` so a crash is an immediate signal and every engine error stays
on disk, a per-sequence timeout — and fails on any of
`Parent node is busy adding/removing children`, `Condition "data.parent" is
true`, `!data.tree`, `p_node->data.tree != data.tree`, `Parameter
"canvas_item" is null`, `previously freed`, `Trying to cast a freed object`,
`SCRIPT ERROR`, a non-zero exit, a timeout, a missing report or a pair that
did not activate. Sequences: dark_mage → doctor (`during_cast`), chemist →
doctor (`during_cast`), dark_mage → doctor (`natural`), all 17 classes in
registry order (`during_cast`, 51 pairs).

| Tree | Result | Log |
|---|---|---|
| `dev` 01ee1368 (probe/test copied in, game code unchanged) | **FAIL**: 3 of 4 sequences die by signal with the error chain; 44 errors | `session-gate/fail_before_01ee1368/gate_stdout.log` |
| code commit 4386342d | **PASS**: 4/4 sequences, 51/51 + 3 × 6/6 pairs, zero lifecycle errors, clean exits (all-17 in 159 s) | `session-gate/pass_after/gate_stdout.log`, child logs beside it |

## Existing gates on the candidate (AC4)

Fresh macOS release export of code commit 4386342d (`export-probe/`,
`tools/ultimate_export_probe.py --captures --skip-import`, PASS in 251 s):

- headless probe inside the exported app: 51/51 pairs, `resolution_source =
  weapon_profile` 51, `legacy_class_fallback` 0, `editor_feature=false`,
  `docs_manifest_present=false` (`export_probe_probe_report.json`);
- mutations: presentation document removed → exit 1, 48/51; executor remap
  removed → exit 1, 50/51 (gate not vacuous);
- player path (`Main._start_combat()` → `Player.activate_ultimate()`), each
  pair in a fresh exported-app process: 51/51 exit 0, crashes `[]`, every
  pair survived ≥ 4.0 s of game time past activation, 17 real game frames
  (`export_probe_player_path.json`, `exported_app_player_path_captures/`);
- 17 presentation captures (`exported_app_captures/`);
- PCK: format 4, 27,034 entries, `pck_sha256`
  `1440369c84677550739eb4b41c7351b465c358f2e5e2cf6509971d54585db2a9`
  (identical to the export of the same content before the commit; as in
  FAN-3985, the hash depends on the import cache — compare file tables).

Editor gates on the same tree:

- `tests/ultimates/player_path_release_safety_test.gd`: 51 pairs, passed
  (`player_path_release_safety_after.log`);
- `tests/ultimates/presentation/doctor_ultimate_timelines.gd`: passed
  (`doctor_ultimate_timelines_after.log`);
- `python3 -m unittest tests.test_export_presets_exclusions
  tests.test_ultimate_presentation_runtime_data`: 15 tests OK;
- `python3 tools/build_ultimate_presentation_runtime_data.py --check`: 17
  documents up to date;
- `python3 tools/quality_static_guard.py --changed-ref origin/dev`: passed;
- the 17 `*_certification_capture_test.gd` and the PR checks are recorded on
  the card for the final candidate SHA (the three strict FAN-3942 packages —
  Assassin, Doctor, Druid — are re-shot after the code and evidence commits
  because any non-evidence change stales their recorded source).

## Object count (AC5)

`tools/ultimate_session_lifecycle_probe.gd --crowd=48 --cast-every=5
--window=60`, windowed, the FAN-3990 P2 roster and pairs: 48 enemies kept
alive, the ultimate recharged and fired through the InputMap action every
5 s for 60 s, `Performance.OBJECT_COUNT` sampled every second
(`object-count/*.json`, per-second samples inside).

| Pair | peak `OBJECT_COUNT` before (01ee1368) | after (candidate) | casts started | FAN-3981 hard limit |
|---|---|---|---|---|
| berserk/sword | 3,987 | 3,979 | 1/12 (rare-charge ledger, by design) | 6,250 |
| dark_mage/cursed_skull | 4,887 | 4,968 | 1/12 (same) | 6,250 |
| druid/briar_staff | 5,138 | 4,992 | 12/12 | 6,250 |
| sniper/sniper_spotter_scope | 5,530 | 5,630 | 12/12 | 6,250 |

Before = the same tree with `doctor_ultimate_timeline_scene.gd` restored to
01ee1368 (these four classes never load the Doctor scene, so the difference
is run-to-run noise: enemies die and respawn on the ultimate). All peaks stay
under the 6,250 hard limit; FomaPC measured 3,741 / 4,652 / 5,242 / 5,609 on
the 0.3.1.1 Setup.

## Files

| Path | What it proves |
|---|---|
| `session-gate/fail_before_01ee1368/` | gate stdout on the unfixed tree + every child session log/report |
| `session-gate/pass_after/` | gate stdout on the candidate + child logs/reports (all 17 classes, 51 pairs) |
| `repro/` | first direct probe runs: natural (no errors), during-cast and force (error chain with backtrace, crash), doctor-only during-cast |
| `object-count/` | before/after crowd windows, per-second samples |
| `export-probe/` | FAN-3985 export gate on the committed tree (layout as `evidence/FAN-3985`) |
| `doctor_ultimate_timelines_after.log`, `player_path_release_safety_after.log` | editor suites on the candidate |

## Reproduce

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/multi_class_session_lifecycle_test.gd
FAN3991_SEQUENCES=dark_mage_then_doctor python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/multi_class_session_lifecycle_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/ultimate_session_lifecycle_probe.gd -- --classes=dark_mage,doctor --end=during_cast --report=/abs/report.json
python3 tools/godot_gate.py --path . --windowed --script res://tools/ultimate_session_lifecycle_probe.gd -- --pairs=berserk/sword,dark_mage/cursed_skull,druid/briar_staff,sniper/sniper_spotter_scope --crowd=48 --cast-every=5 --window=60 --report=/abs/objects.json
python3 tools/ultimate_export_probe.py --captures --evidence-dir evidence/FAN-3991/export-probe
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/player_path_release_safety_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/doctor_ultimate_timelines.gd
python3 -m unittest tests.test_export_presets_exclusions tests.test_ultimate_presentation_runtime_data
```

To see the failure on the unfixed source: check out `01ee1368`, copy
`tools/ultimate_session_lifecycle_probe.gd` and
`tests/ultimates/multi_class_session_lifecycle_test.gd` in, run the first
command (or revert `_clear_impacts` to `_impacts.free()`).
