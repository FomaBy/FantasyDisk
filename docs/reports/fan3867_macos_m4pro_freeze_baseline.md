## FAN-3867 macOS M4 Pro freeze baseline (read-only diagnostic)

Path note: the card specified `docs/reports/performance/macos-m4pro-freeze-baseline-FAN-3867.md`.
The repository's existing perf-report convention is a flat `docs/reports/*.md`
directory with a `fanNNNN_snake_case.md` filename (see
`docs/reports/fan2914_row_scale_before_after.md`); this report follows that
existing convention mechanically, per the card's own allowance, instead of
introducing a new `performance/` subdirectory.

No gameplay code, scenes, assets, project/import settings, CI, or export
configuration were changed for this report. All measurements are read-only.

**Rework note (this revision):** independent QA (`FAILED` on candidate
`aa3fa4ab925eddb6bba0f1ee8d1561487f1c1d7b`) found two defects, both fixed here
and only here:

1. The `dense_wave` contour's original description/report said `spawn basic
   40`, but `scripts/dev_console.gd:16` clamps a single `spawn` call to
   `SPAWN_COUNT_LIMIT = 24` (`scripts/dev_console.gd:625`), so the original
   candidate actually spawned 24, not 40. Fixed by reproducing with two
   console calls (`spawn basic 24` + `spawn basic 16`, verified against
   `SPAWN_COUNT_LIMIT` in the same file) to honestly reach the intended load,
   and by re-measuring one isolated cold and one warm run for this corrected
   contour (methodology and results below, this revision only).
2. The `vfx_heavy` subsystem-correlation summary undercounted its own raw
   evidence (reported 8 spikes >50ms, `vfx_heavy_detail.csv` actually has 11;
   reported `phys_ms` range `0.9-15.3`, actual `0.691-15.274`). Both numbers
   below are recomputed directly from the unchanged, previously-attached
   `vfx_heavy_detail.csv` and now match it exactly.

`ordinary` and `vfx_heavy` raw measurement CSVs and their headline
p50/p95/p99/max/spike-count numbers were not in question and are unchanged
from the previous revision.

### Environment

- Exact commit: this revision's own commit/tree (see handoff comment), tree
  from a task branch rebased onto fresh `origin/dev`. Original measurement
  base for `ordinary`/`vfx_heavy`/pre-fix `dense_wave`: commit
  `8553691c7390be492e8edf8df59a5cce3a26e5bc`. The corrected `dense_wave`
  replay in this revision ran against the same working tree, unaffected by
  the intervening `dev` history (no product files touched by either).
- Machine: MacBook, Apple M4 Pro (`Mac16,8`), 48 GiB RAM, macOS 26.5.1
  (build 25F80), on AC power, battery 100%, `pmset -g therm` reported no
  thermal or performance warning at any point during any run (original or
  rework).
- Godot: `4.7.stable.official.5b4e0cb0f`, renderer `gl_compatibility`
  (`renderer/rendering_method` in `project.godot`); engine selected
  `OpenGL API 4.1 Metal - Compatibility - Apple M4 Pro` at every run.
- Display/window: `--resolution 1920x1080`, V-Sync enabled (engine default,
  "Requested V-Sync mode: Enabled" in stdout on every run).
- Profiler panels/commands: `Performance.get_monitor()` sampled every real
  frame (`TIME_FPS`, `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, `OBJECT_COUNT`,
  `OBJECT_NODE_COUNT`, `MEMORY_STATIC`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`,
  `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`,
  `PHYSICS_2D_ACTIVE_OBJECTS`, `PHYSICS_2D_COLLISION_PAIRS`) — the same
  monitors the editor Debugger → Monitors panel exposes, read via script
  instead of the GUI debugger so every frame is captured, not just the
  1 Hz debugger snapshot. `tools/godot_gate.py`'s headless import
  (`Godot --headless --path . --import --quit`) was run once first, as
  project-cache setup, not as a measured sample (a shipped export never pays
  the source-checkout import cost; conflating it with gameplay freezes would
  misattribute cause).

### Method

`docs/qa/perf-checklist.md` already states headless does not substitute for
real render on this project. All measured runs used a real on-screen Godot
process (no `--headless`), driven end-to-end by a disposable, uncommitted
`SceneTree` script (`--script <path>` outside `res://`, task-owned evidence,
not part of the repo) that:

1. Instances `res://scenes/Main.tscn` for real (same load path a player hits).
2. Uses the repo's own dev console (`scripts/dev_console.gd`,
   `dev_console.execute_command(...)`) to reach a bounded, reproducible
   in-game state: `godmode` (survive the whole window), `fight battle` or
   `fight boss`, then scenario-specific `spawn <type> <count>` and `ult`.
3. Samples `Performance.get_monitor()` every real frame into a CSV.

Any engineer can reproduce the same states by hand from the main menu: open
the console (`` ` ``), run the same commands. The commands used per contour
are listed below; only the per-frame CSV logging was scripted.

Isolation: each scenario got its own isolated `$HOME` (Godot's `user://` on
macOS resolves under `$HOME/Library/Application Support/Godot/...`), so its
shader cache starts empty ("cold") on the first run and is reused ("warm") by
the next same-scenario run in the same process family — mirroring
`tools/godot_gate.py`'s "isolate HOME/XDG/AppData... for every Godot process"
convention. The `res://.godot/` asset-import cache is shared/project-local and
was warmed once for all scenarios by the setup import pass above. The
corrected `dense_wave` cold/warm pair in this revision used a freshly created,
previously-unused isolated `$HOME` (cold = first-ever launch under that
`$HOME`, empty shader cache; warm = second launch under the same `$HOME`,
reused shader cache) — separate from, and not reused between, the `ordinary`
and `vfx_heavy` contours' own isolated `$HOME` directories.

**Enemy-count verification:** because a `spawn` console call is silently
clamped, this revision verifies the actually-spawned enemy count directly
from the running scene (`get_tree().get_nodes_in_group("enemies").size()`)
immediately after issuing the spawn commands, instead of trusting the
command's own echo. For the corrected `dense_wave` contour this read 54
enemies right after `spawn basic 24` + `spawn basic 16` + `spawn shooter 8`
(48 commanded + a few from the normal wave director in the intervening
frames before the count was taken) — confirming the two-call spawn honestly
reaches the intended ~48-enemy load, unlike the single clamped call.

### Scenario matrix

| ID | Scenario | Reproduction (dev console, after `fight <kind>`) |
| --- | --- | --- |
| ordinary | Обычный бой | `fight battle` (default wave director, no forced spawns) |
| dense_wave | Плотная волна | `fight battle`; `spawn basic 24`; `spawn basic 16` (two calls — `SPAWN_COUNT_LIMIT=24` in `scripts/dev_console.gd:16` clamps a single call); `spawn shooter 8`; verified ~48 enemies present (see Method) |
| vfx_heavy | VFX-heavy бой | `fight boss`; `spawn mage 6`; `spawn shaman 6`; `ult` every ~4s (charges + casts the player ultimate for sustained VFX load) |

Each of the 3 contours ran: 1 cold repeat (fresh isolated `$HOME`) + 2 warm
repeats (`ordinary`, `vfx_heavy`; same `$HOME`, reused shader cache) or 1 warm
repeat (`dense_wave`, corrected contour, this revision) = 8 runs total across
both revisions. Each run: 12 s discarded warm-up window (post-`fight`,
scenario setup settling) + 45 s measured steady-state capture window, real
frame-by-frame sampling (not a fixed-timestep tick — `frame_delta_ms` is
wall-clock time between successive real frames). Raw CSVs (8 measurement
files + 3 detail files, ~3.6 MB total) are attached to the Multica card as
disposable evidence, not committed to the repo; the two obsolete pre-fix
`dense_wave_cold/warm1/warm2.csv` files from the rejected candidate remain
attached to the earlier comment for audit trail but are superseded by
`dense_wave_fix_cold.csv` / `dense_wave_fix_warm.csv` below.

### Frame-time distribution (measured window only, warm-up excluded)

All times in ms, all rows use the same 45 s / real-frame sampling.

| Run | n frames | p50 | p95 | p99 | max | spikes >50ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ordinary / cold | 4902 | 10.88 | 14.12 | 14.66 | 581.2 | 9 |
| ordinary / warm1 | 5012 | 10.04 | 14.12 | 14.74 | 610.4 | 9 |
| ordinary / warm2 | 5076 | 10.97 | 14.30 | 15.29 | 992.4 | 5 |
| dense_wave / cold (fixed, 48 enemies) | 5136 | 9.54 | 14.28 | 15.88 | 598.1 | 6 |
| dense_wave / warm (fixed, same `$HOME`) | 4924 | 9.75 | 14.41 | 17.72 | 561.2 | 8 |
| vfx_heavy / cold | 5262 | 10.14 | 14.57 | 15.08 | 180.7 | 11 |
| vfx_heavy / warm1 | 5251 | 9.65 | 14.65 | 15.10 | 178.6 | 11 |
| vfx_heavy / warm2 | 5280 | 9.92 | 14.68 | 14.99 | 189.1 | 8 |

p50/p95/p99 are flat and healthy (~10-18 ms, consistent with the ~120 Hz
ProMotion-capped display this M4 Pro reports) across cold and warm and across
all three contours — the steady baseline is not the problem. The problem is
tail spikes: every single one of the 8 windows, cold **and** warm, produced
multiple frames over 50 ms, confirming this is a **repeating** in-session
freeze, not only a one-time cache/shader warm-up artifact (criterion 4).

Representative spike timestamps (full list in the attached CSVs):

- `ordinary/cold`: t=13.9s (523.0ms), t=19.1s (530.6ms), t=27.4s (581.2ms)
- `dense_wave/cold (fixed)`: t=2.4s (598.1ms), t=39.3s (583.2ms)
- `dense_wave/warm (fixed)`: t=0.5s (508.2ms), t=19.1s (561.2ms), t=32.8s (535.7ms)
- `vfx_heavy/cold`: t=2.0s (180.7ms), t=9.2s (82.0ms), t=17.5s (82.9ms)

`ordinary` and `dense_wave` produce fewer but much larger spikes (up to
~600 ms); `vfx_heavy` produces more frequent but smaller spikes (80-190 ms).
These are two distinct spike populations, not one.

### Warm-up vs repeating spikes (criterion 4)

The discarded 12 s warm-up window (right after `fight <kind>`, before the
measured window starts) also contains 2-5 spikes >50ms per run, in **both**
cold and warm `$HOME` states (checked on `ordinary` and `vfx_heavy`, where
both cold and warm repeats exist: e.g. `vfx_heavy/warm1` warm-up: 5 spikes,
same order as its own cold run). Because warm `$HOME` already has a
populated shader cache, this rules out "one-time global shader compile" as
the sole explanation for the warm-up spikes — they correlate with combat
*encounter start* (scene/state setup, first enemies spawning, first VFX
instances for that run), not purely with the process's first-ever shader use.
Encounter-start spikes are therefore reported separately and excluded from
the steady-state table above; they are a second, smaller finding, not
conflated with the measured-window repeating spikes.

### Subsystem correlation (criterion 3, 1 warm run per contour, richer monitors)

A second pass, same scenarios and states (warm `$HOME`), additionally logged
`TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, draw calls, objects-in-frame,
primitives, and 2D physics activity per frame. This table was independently
recomputed from the raw `*_detail.csv` attachments as part of this revision
(all three counts now match the CSVs exactly, byte-for-byte reproducible).

| Contour | Spikes >50ms | proc_ms during spikes | phys_ms during spikes | baseline (non-spike) proc/phys |
| --- | ---: | --- | --- | --- |
| ordinary | 6 | 13.5-14.5 ms | 1.1-1.4 ms | same range |
| dense_wave | 7 | 13.2-15.3 ms | 1.2-1.7 ms | same range |
| vfx_heavy | 11 | 14.3-19.1 ms | 0.7-15.3 ms | same range |

`TIME_PROCESS` (game-logic `_process`/`_physics_process` script cost) and
`TIME_PHYSICS_PROCESS` (2D physics step cost) stay in their normal baseline
range **during** every logged spike, even while `frame_delta_ms` is
80-500+ ms. Draw calls, object/primitive counts, and active 2D physics bodies
also stay close to their local baseline at spike frames (e.g. `dense_wave`
baseline draw_calls median 275 vs 234-376 at spikes — within normal wave-growth
drift, not a step change). This is a direct measurement, not inference: **the
stall is not spent inside script logic or the 2D physics step**, and it is
not obviously proportional to render call/object count either.

Note: the `ordinary` and `dense_wave` rows in this correlation table come
from the original (pre-rework) detail captures — those two contours' detail
data were not disputed by QA and are reproduced unchanged. Only `vfx_heavy`'s
summary numbers were wrong; its underlying `vfx_heavy_detail.csv` was never
wrong and is reused as-is.

### Result: causes not proven — INCONCLUSIVE at the subsystem level

Per criterion 5, this scope cannot claim a proven root cause and does not.

**Excluded by direct measurement:**
- GDScript hot-path / gameplay logic cost (`TIME_PROCESS` flat through spikes).
- 2D physics step cost (`TIME_PHYSICS_PROCESS` flat through spikes, phys2d
  active-body count flat).
- Pure one-time global shader/cache warm-up (spikes repeat in every 45 s
  measured window, cold and warm, well after any first-use warm-up).

**Not excluded / candidate causes for a follow-up probe** (the frame time
unaccounted for by `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` is spent somewhere
between the scripted process step and the swapped frame — consistent with,
but not proven to be, one or more of):
- Main-thread stalls waiting on the render server / GPU (`gl_compatibility`
  driver behavior on Apple Silicon via ANGLE/Metal translation), not visible
  to the `Performance` monitors used here.
- Synchronous resource I/O on first appearance of a given enemy/VFX
  instance within a run (texture/audio decode, matching this project's own
  `fantasydisk-code-quality-director` guidance to inspect "cold first-spawn
  resource loads... combat-feedback/VFX churn").
- OS/driver-level scheduling or GC-adjacent pauses not captured by the
  engine-internal monitors used here.

**Next bounded probe** (explicitly out of this card's scope, for a follow-up
card): capture one `vfx_heavy` and one `dense_wave` window with macOS
Instruments (Time Profiler + Metal System Trace) attached to the same Godot
process, to see where the main thread is blocked during a >50ms frame that
`TIME_PROCESS`/`TIME_PHYSICS_PROCESS` cannot explain. That native trace file
is the sufficient regression oracle for actually isolating the cause; this
card cannot substitute for it without exceeding its read-only diagnostic
scope.

### Regression oracle (criterion 5)

Until a specific cause lands with a fix, the reproducible baseline itself is
the oracle any future fix must move:

- Reproduction: the 3-contour scenario matrix and dev-console command
  sequences in the table above, 45 s measured window after a 12 s discarded
  warm-up, `--resolution 1920x1080`, real (non-headless) render,
  `gl_compatibility`.
- Current baseline (this report): 5-11 frames >50ms per 45 s window in every
  contour and every cold/warm state; worst observed frame 992.4 ms
  (`ordinary/warm2`).
- A fix for a proven cause must be checked against this same matrix and must
  reduce the >50ms spike count and/or max frame time for the contour(s) its
  fix targets, without moving p50/p95/p99 (which are already healthy) in the
  wrong direction.

### Scope confirmation

Only this report file was changed. No files under `scripts/`, `scenes/`,
`assets/`, `project.godot`, `export_presets.cfg`, CI config, or
`docs/qa/perf-checklist.md` were changed. `git status` is clean apart from
this file.
