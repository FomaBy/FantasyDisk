# SCRUM-1074 — Atlas focused Metal test lifecycle leak

Статус: done
Версия: 0.2.1
Jira: SCRUM-1074
Контур: Codex
Owner: Back-end QA / Codex
Thread/Worker: `/root/audit_new_sprint_tail/review_scrum1067_spec/scrum1070_independent_review`
Branch: `codex/scrum1074-atlas-oracle2`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1074-atlas-oracle2`
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

## Initial implementation result (superseded oracle)

- Reuses the already accepted test-only `tools/qa_capture_teardown.gd` API; the
  shared helper itself needs no change.
- Every owned fixture now stops SubViewport rendering, destroys `Main`/children
  first, verifies child and viewport release through `WeakRef`, and only then
  continues to the next case.
- Every teardown fails on orphan nodes. The initial two-fixture global-count
  equality oracle was later superseded after independent QA proved it flaky.
- Before final quit, the windowed path calls public `AudioManager.stop_music()`,
  waits for the existing eight-frame audio-thread barrier and asserts that both
  menu music players are stopped with `stream == null`.
- Process-level Metal acceptance still rejects any exit log containing
  `ObjectDB instances were leaked`, `resources still in use`, Ogg lifecycle,
  `WARNING`, `ERROR` or `SCRIPT ERROR`; diagnostics are not suppressed.

## Initial verification result (before independent QA)

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

## QA-Вердикт: FAILED

Independent QA on fresh `origin/dev` `d7548ba8d` found no static defect in the
test-only diff or SCRUM-1031 teardown architecture. Focused headless passed with
both functional markers and all `11` owned viewport teardowns.

The mandatory isolated macOS/Metal series passed only `4/5`. One run exited `1`
because the new whole-process sampling oracle observed
`Performance.OBJECT_COUNT 1905 -> 1906` between its two warmed fixtures. That
run still had zero external ObjectDB-leak, resources-still-in-use, Ogg type,
`WARNING` or unrelated script-error diagnostics, and the owned `WeakRef`
barriers were clean. Four other ordinary isolated runs exited `0` with both
markers and the same zero-diagnostic policy.

Corrective handoff: keep owned `WeakRef` release and process-exit leak
diagnostics authoritative. The global count probe must detect monotonic
per-cycle growth after warm-up instead of requiring the first and second sample
of the entire process to be exactly equal. Jira is returned to `К выполнению`;
SCRUM-1070 remains in `Контроль качества` until this gate reaches `5/5`.

## Corrective implementation

- Replaces the flaky equality of two process-wide samples with seven identical
  post-warmup fixtures. The first transition remains a warm-up; one isolated
  lazy allocation and separated lazy allocations with intervening plateaus are
  tolerated, while three consecutive later positive steps fail as sustained
  per-cycle accumulation.
- A pure four-case oracle contract covers single lazy allocation, separated
  lazy allocations, three consecutive retained-owner increments and a resource
  decrease that interrupts growth.
- Child/Main/SubViewport `WeakRef` barriers, orphan-node checks, public audio
  drain and strict process-exit ObjectDB/resource/Ogg diagnostics remain
  authoritative and unchanged.
- Scope remains test-only; production UI, audio, assets and shared teardown
  helper are unchanged.

## Corrective verification

- focused headless: PASS with both SCRUM-1070/SCRUM-1074 markers, all four
  synthetic oracle cases and `16` deterministic owned viewport teardowns;
- isolated ordinary macOS/Metal series: PASS `10/10`, unique HOME/XDG/user-data
  roots, exit `0`, both markers and zero `WARNING`, `ERROR`, `SCRIPT ERROR`,
  ObjectDB, resources-still-in-use or Ogg lifecycle diagnostics;
- after fast-forward integration onto `origin/dev` `ea4cf76cd`: focused
  headless PASS, isolated macOS/Metal PASS `5/5` with the same strict
  zero-diagnostic policy, and full runtime smoke PASS;
- `tests/ui_no_overlap_matrix_test.gd`: PASS;
- `tests/semantic_typography_scrum1061_test.gd`: PASS after the integrated
  SCRUM-1069 inventory refresh;
- `tests/runtime_smoke_test.gd`: PASS including duplicate-artifact guard over
  `15187` files post-integration; only the known headless dummy-renderer
  screenshot null-texture diagnostic remains unchanged;
- root corrective review P2 (aggregate vs consecutive positive steps): fixed by
  the plateau-reset streak oracle and covered by its pure self-test contract;
- root final read-only review: PASS after the P2 correction;
- `git diff --check`: PASS.

Regression evidence on the integrated tip: semantic inventory, Meta40, pointer
clickability, button family/theme, gamepad focus, no-overlap, runtime UI and
full runtime passed. The previously stale semantic line metadata was refreshed
by SCRUM-1069 before the final corrective gates.

Disk cleanup: disposable combined QA worktree/cache and isolated
`/tmp/fsd-qa-1074-1070-*` roots are removed after evidence push.

Corrective disk cleanup: isolated SCRUM-1074 HOME/XDG/user-data roots,
generated Godot cache, unrelated generated `.gd.uid` sidecars and disposable
worktree are removed after the final push; no remote task branch is created.
