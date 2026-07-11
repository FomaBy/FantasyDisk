# SCRUM-1074 — Atlas focused Metal test lifecycle leak

Статус: done
Версия: 0.2.1
Jira: SCRUM-1074
Контур: Codex
Owner: Back-end QA / Codex
Thread/Worker: `/root`
Branch: `codex/scrum1074-scratch-guard`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1074-scratch-guard`
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

```bash
scratch=$(mktemp -d /tmp/fsd-scrum1074.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
HOME="$scratch" XDG_DATA_HOME="$scratch" \
  GODOT_BIN=/path/to/Godot \
  python3 tools/godot_gate.py --verbose --path . \
  --display-driver macos --rendering-method mobile \
  --rendering-driver metal \
  --script res://tests/atlas_scrum1070_respec_button_test.gd -- \
  --user-data-dir="$scratch"
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

## Historical QA verdict: FAILED

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

## Independent corrective QA verdict: FAILED

Independent QA on fresh `origin/dev` `6819a2a8c` confirms that corrective
commit `693967eee` is test-only and that the lifecycle oracle itself is sound:
the four pure cases pass, the seven-probe path rejects three consecutive
positive count steps, all owned child/Main/SubViewport `WeakRef` barriers
propagate errors to exit `1`, and the public `AudioManager.stop_music()` plus
eight-frame drain matches the SCRUM-1031/QA-protocol contract.

The full focused test is unsafe and cannot be accepted. It has no scratch
`user://` guard before `_check_reset_scopes()` confirms two real resets.
`UI._atlas_respec_confirm()` calls `Meta.save_state()` with the default
`user://fantasydisk_meta.cfg`. The reproduction section claims isolated
`HOME`/`XDG_DATA_HOME`/user-data, but its copyable command supplies none. The
existing `atlas_scrum970_clickability_test.gd` provides the required precedent:
it refuses to run unless a unique scratch root is explicitly supplied and
verified.

Dynamic evidence:

- focused headless: exit `0`, both SCRUM-1070/SCRUM-1074 markers, `16`
  deterministic teardowns and the pure oracle cases PASS;
- isolated macOS/Metal lifecycle series: `5/5` exit `0`, both markers, zero
  `ObjectDB instances were leaked`, resources-still-in-use, Ogg lifecycle,
  `ERROR` or `SCRIPT ERROR` diagnostics;
- every verbose Metal log contains `16` pre-existing RGB8-to-RGBA8 hardware
  conversion warnings from repeated Main fixtures, so the task's literal
  claimed zero-`WARNING` policy is not reproduced on a fresh headless-imported
  cache even though the lifecycle leak is absent;
- the initial documented non-isolated headless invocation changed the real
  default save: `fantasydisk_meta.cfg` mtime became `2026-07-11 21:04:40`, size
  `344` bytes. No backup was visible beside it; QA did not attempt an
  unauthorized external restore. All later runs used isolated HOME/XDG roots.

Required correction: add a fail-closed scratch user-data guard before any
fixture is instantiated, make the reproduction command set and pass the same
unique root, add a negative self-test proving default `user://` exits before
`Main` construction, and clarify the RGB8 warning policy without hiding stderr.
SCRUM-1074 returns to `К выполнению`; linked SCRUM-1070 remains in
`Контроль качества`.

## Scratch user-data corrective implementation

- The focused test now validates an explicit `--user-data-dir=<scratch>` at
  the first line of `_initialize()`, before constructing `Main`, a viewport or
  any other fixture.
- The platform-resolved `OS.get_user_data_dir()` must be a descendant of the
  same scratch root. Missing, `/`, or mismatched roots fail closed with exit
  `1`; the safe path prints the resolved scratch directory.
- The reproduction command now creates one owned temporary root, applies it to
  both `HOME` and `XDG_DATA_HOME`, passes it as a test user argument and removes
  it on every shell exit.
- Lifecycle acceptance continues to reject ObjectDB/resource/Ogg, `ERROR` and
  `SCRIPT ERROR` diagnostics. The exact pre-existing RGB8-to-RGBA8 hardware
  conversion warnings remain visible in verbose Metal output and are recorded
  separately; no stderr suppression or broad warning filter is added.

## Scratch user-data corrective verification

- negative default-user run: exit `1` at the first `_initialize()` guard; no
  `Main` fixture or functional marker was reached; the already changed external
  save was not rewritten by this run as proven by stable
  metadata `mtime=1783793080`, `size=344` before/after;
- isolated focused headless: PASS, verified scratch path plus both
  SCRUM-1070/SCRUM-1074 markers and `16` deterministic teardowns;
- isolated ordinary macOS/Metal: PASS `5/5`, both markers on every run, zero
  ObjectDB/resource-still-in-use/Ogg/`ERROR`/`SCRIPT ERROR` diagnostics; every
  run retained the exact known `16` RGB8 conversion warnings in verbose output;
- Meta40, SCRUM-970 pointer clickability, semantic typography, button family,
  gamepad focus and UI no-overlap gates: PASS;
- runtime UI and full runtime smoke: PASS; duplicate-artifact guard scanned
  `15188` files, with only the existing dummy-renderer null-texture screenshot
  diagnostic;
- `git diff --check`: PASS; product UI/audio/assets/runtime remain unchanged.

Disk cleanup: isolated `/tmp/fsd-scrum1074-*` roots/logs and generated UID
sidecars removed; disposable `.godot` cache and task worktree are removed after
the final push. No remote task branch is created.

## QA-Вердикт

Статус: PASSED

Independent QA reviewed corrective commit `cb9671188` from fresh
`origin/dev` `8bc3b4039`; before evidence, the branch was fast-forwarded to
`38f114126`, whose only intervening change is the disjoint SCRUM-1075 design
package. The correction remains test/docs-only and the SCRUM-1070 product
surface has no drift.

- Static order: `_require_scratch_user_dir()` is the first operation in
  `_initialize()`, before any `SubViewport`, `Main` or reset fixture.
- Negative default-user run: `exit 1`, no functional/lifecycle marker, and the
  external save remained byte-identical immediately before/after:
  `mtime=1783793080`, `size=344`,
  `SHA-256=e72e9018bb5efe3ab8160f74f0822bc7dae9c7da17b314e3a9703af157d8f2a9`.
- Isolated focused headless: PASS with verified scratch path, both markers and
  `16` deterministic owned viewport teardowns.
- Independent isolated macOS/Metal series: PASS `5/5`; every run exited `0`,
  printed both markers and had zero ObjectDB/resource-still-in-use/Ogg,
  `ERROR` or `SCRIPT ERROR` diagnostics. The exact known `16` RGB8-to-RGBA8
  conversion warnings per run stayed visible and were not suppressed.
- Linked product gates PASS: Meta40, isolated SCRUM-970 pointer clickability,
  SCRUM-1061 semantic typography, SCRUM-1051 button family, dark-fantasy theme,
  gamepad focus, UI no-overlap, runtime UI and full runtime smoke. The final
  duplicate-artifact guard scanned `15208` files; only the accepted headless
  dummy-renderer screenshot diagnostic appeared.
- Existing-source provenance, exact `420x72/88/104` geometry, five-state family,
  frame/content margins, labels, focus and both reset scopes remain accepted.

Disk cleanup: removed the disposable `446 MB` `.godot` cache, all owned
`/tmp/fsd-qa1074-*` and `/tmp/fsd-qa1070-*` roots/logs, and generated untracked
UID sidecars; QA worktree/branch removal follows the final push and Jira sync.
