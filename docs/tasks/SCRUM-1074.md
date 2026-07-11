# SCRUM-1074 — Atlas focused Metal test lifecycle leak

Статус: done
Версия: 0.2.1
Jira: SCRUM-1074
Контур: Codex
Owner: Back-end QA / Codex
Thread/Worker: `/root/audit_new_sprint_tail/review_scrum1067_spec/scrum1070_independent_review`
Branch: `codex/scrum1074-atlas-metal-lifecycle`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1074-atlas-metal-lifecycle`
Parent: SCRUM-220
Source QA: SCRUM-1070
Related precedent: SCRUM-1031

## Scope

- test-only lifecycle fix in `tests/atlas_scrum1070_respec_button_test.gd`;
- child-first owned `SubViewport`/`Main` teardown with frame barriers and
  `WeakRef` verification;
- pre-quit public `AudioManager.stop_music()` barrier for windowed fixtures;
- this mirror and QA evidence.

Production `scripts/ui_screens.gd`, Atlas geometry/semantics, runtime audio and
button assets are excluded.

## Reproduction

On fresh `origin/dev` `0b17c754a`, run the SCRUM-1070 focused test with an
isolated `HOME`/`XDG_DATA_HOME`/test `--user-data-dir` under macOS Metal:

```text
tools/godot_gate.py --verbose --display-driver macos \
  --rendering-method mobile --rendering-driver metal \
  --script res://tests/atlas_scrum1070_respec_button_test.gd
```

The functional success marker is printed, then process exit reports four
leaked ObjectDB instances and two resources: the Ogg packet/stream/playback
chain for `music_menu_tavern_warm.ogg`.

## Expected

The windowed focused gate must exit `0` without `WARNING`, `ERROR`,
`SCRIPT ERROR`, `ObjectDB instances were leaked` or
`resources still in use at exit`, matching the QA protocol and SCRUM-1031.

## Acceptance

- five consecutive isolated Metal runs are functionally PASS and lifecycle
  clean;
- headless focused geometry/live-resize/reset assertions remain unchanged;
- semantic, Meta40, clickability, button family/theme, gamepad, no-overlap,
  runtime UI and full runtime gates remain PASS;
- no production UI/audio/schema/balance edits;
- SCRUM-1070 receives a clean independent QA rerun and may then move to Done.

## QA evidence

- reproduced `2/2` on Apple M4 Pro, Godot 4.7, Metal 4.0 Forward Mobile;
- verbose types: `OggPacketSequence`, `AudioStreamOggVorbis`,
  `AudioStreamPlaybackOggVorbis`, `OggPacketSequencePlayback`;
- linked Jira issues: SCRUM-1070 and SCRUM-1031.

## Implementation result

- Reuses the already accepted test-only `tools/qa_capture_teardown.gd` API; the
  shared helper itself needs no change.
- Every owned fixture now stops SubViewport rendering, destroys `Main`/children
  first, verifies child and viewport release through `WeakRef`, and only then
  continues to the next case.
- Every teardown fails on orphan nodes; after the functional matrix warms its
  different viewport/theme caches, a dedicated pair of identical Atlas fixtures
  must return to the same ObjectDB/resource ceiling on the second release.
- Before final quit, the windowed path calls public `AudioManager.stop_music()`,
  waits for the existing eight-frame audio-thread barrier and asserts that both
  menu music players are stopped with `stream == null`.
- Process-level Metal acceptance still rejects any exit log containing
  `ObjectDB instances were leaked`, `resources still in use`, Ogg lifecycle,
  `WARNING`, `ERROR` or `SCRIPT ERROR`; diagnostics are not suppressed.

## Verification result

- final headless focused matrix: PASS, both SCRUM-1070 functional and
  SCRUM-1074 lifecycle markers, `11` deterministic viewport teardowns;
- final post-change macOS Metal series: PASS `5/5` on Apple M4 Pro / Godot 4.7,
  unique isolated HOME/XDG/user-data for every run, exit `0`, both markers, zero
  `WARNING`, `ERROR`, `SCRIPT ERROR`, ObjectDB, resource-still-in-use or Ogg
  lifecycle diagnostics;
- after fast-forward integration onto `origin/dev` `001548305`, focused
  headless PASS, isolated macOS Metal PASS `2/2` with the same zero-diagnostic
  policy, and runtime smoke PASS;
- `tests/ui_no_overlap_matrix_test.gd`: PASS;
- `tests/runtime_smoke_test.gd`: PASS including duplicate-artifact guard over
  `15187` files after integration; the existing headless dummy-renderer
  null-texture screenshot
  diagnostic remains unchanged and outside this test-lifecycle scope;
- `git diff --check`: PASS;
- independent root read-only code review: PASS; child-first WeakRef barriers,
  public audio drain and warmed repeated-fixture ceiling are correctly scoped,
  and no cross-task or production runtime files changed.

Disk cleanup: isolated SCRUM-1074 HOME/XDG/user-data roots, generated Godot
cache, unrelated generated `.gd.uid` sidecars and disposable worktree are
removed after the final push; no remote task branch is created.
