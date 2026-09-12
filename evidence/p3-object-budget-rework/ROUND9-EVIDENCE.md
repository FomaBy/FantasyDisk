# FAN-3934 round 9 — evidence completion (15:03:45Z decision)

## 1. Windowed Engineer accessibility result (required by the decision)

Command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3
tools/godot_gate.py --path . --script res://tests/ultimates/presentation/engineer_accessibility_modes_test.gd`
(no `--headless` → real macOS display server). Source: the successor commit (see
metadata); header, environment snapshot, full log and exit status retained in
`round9/engineer-windowed-header.txt`, `round9/engineer-windowed.log`
(**exit_status=0**). Result: `PASS (12 production mode casts, crowded/repeated
feedback, lifecycle restoration, windowed temporal bounds)` — the viewport image
readback executed on the real renderer (`ENGINEER_ACCESSIBILITY_TEMPORAL`,
display_server macOS, gl_compatibility): all three weapons measured 0.0 flash
coverage / 0.0 fullscreen-Hz against declared bounds. Headless assertions and the
readback prohibition are unchanged (headless PASS retained in round-8 evidence).

Regression coverage for the granted alpha-capture behavior now lives in
`tests/p3_feedback_allocation_test.gd` (section J, PASS): adapter-binds-alpha
before the first animation step owns the fade start; unadapted ticks fade from
spawn alpha; pooled reuse captures its own (freshly adapted) alpha rather than
inheriting an expired record's base; two simultaneous ticks hold independent
bases. Expected values use the closed form alpha(t) = base·(1 − t/0.16)².

## 2. Shutdown-warning diagnosis — pre-exists on current dev, not this repair

Round-8 logs (all four runs, including menu-only P1) end with
`32 ObjectDB instances were leaked at exit` and `10 resources still in use`;
round-7 logs do not. Controls on a clean `origin/dev` worktree
(`round9/…` + `/tmp/devctl` runs recorded in this report):

- Clean-dev P3 run: same warnings (`34 ObjectDB…`/`12 resources…` in one run,
  `32/10` in another — run-to-run variance).
- Clean-dev `--verbose` run identifies the owners: leaked instances are
  `AudioStreamOggVorbis` and `OggPacketSequence` objects — dev's audio
  subsystem retains Ogg streams at exit. None of the leaked classes belong to
  FAN-3934 paths (no feedback/timeline/registry objects).
- The warnings therefore pre-exist in the tested composition's dev base and are
  NOT introduced by this repair. Fixing them means editing dev's audio-resource
  ownership (outside every granted path) — no fix attempted; original round-8
  logs retained unmodified.

## 3. FPS-difference explanation corrected

The earlier "dev renderer settings" claim is withdrawn. Measured with an
identical probe on both bases (`round9/vsync_measure.gd`): d192be10b and
current dev report the same `vsync_mode=1`, `Engine.max_fps=0`, macOS display
server, 2560x1440 window, and statistically identical menu wall-FPS
(556.7 vs 542.0). `project.godot` is byte-identical. The differing runtime
condition between the ~115 FPS round-7 readings and the ~650 FPS round-8
readings is not observable from engine state (likely host compositor/display
throttling state at run time); the cause is recorded as **unknown**, the
observation retained, and all original thresholds pass on every reading.

## Successor

Evidence/test-only successor on `fan3934-ci-recovery` (production content
byte-identical to `53afca416d`/`51db8d23` lineage; see metadata pins).
