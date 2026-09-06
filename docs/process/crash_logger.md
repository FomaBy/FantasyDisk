# Local crash incident logging

FantasyDisk registers `scripts/crash_logger.gd` as a Godot autoload. It uses the
Godot 4.7 `Logger` callback and `OS.add_logger()` to preserve structured engine
and GDScript errors locally. It does not upload, transmit, or expose a network
API.

## Files and retention

Every captured error is written as a separate, complete JSON file beneath
`user://logs/incidents/`. The ordinary rotating Godot log remains separate at
`user://logs/godot.log`. Incident filenames contain a UTC timestamp and a local
sequence number.

Writes are serialized on the main thread and committed with a temporary-file
rename, so an interrupted write cannot masquerade as a complete incident.
Callbacks enqueue under a mutex and schedule one coalesced deferred flush; clean
frames do not poll the incident queue.
Retention is bounded to 20 incident files and 1 MiB total, with a 64 KiB limit
per record. The oldest files are removed first. A full in-memory callback queue
retains the newest 64 incidents and reports how many older pending records were
dropped.

Each record includes:

- UTC timestamp, application version, and a SHA-256 build identity;
- structured error fields and all script frames supplied by Godot, up to 64;
- an explicit unavailable status when Godot supplies no script frames;
- the newest 50 combat breadcrumbs, in chronological order, containing only
  class ID, weapon ID, event phase, and process-frame number.

Credential-shaped values, including quoted JSON `Authorization` fields, and
personal home paths are redacted. External source paths are replaced with
`<external>`. Godot `res://` and `user://` paths and ordinary URLs are retained
because they are useful diagnostics and are not OS home paths. Redaction is a
bounded safeguard, not a complete secret scanner: uncommon authorization
schemes or names such as cookie sessions, `client_secret`, `private_key`, and
`auth-token` may require manual sanitization. Do not add player names, save
contents, free-form chat, access tokens, or other personal data to breadcrumbs.

## Combat breadcrumbs

The logger observes the existing `Player.weapon_cast_observed` and
`Player.weapon_animation_event` signals. Cast observation records activation;
the animation `release` phase records finish. Other animation phases are also
recorded to preserve the sequence around the failure. Hero-select snapshot
players are excluded, and gameplay producers are not modified.

## Verification

Run the deterministic unit coverage through the repository gate:

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  python3 tools/godot_gate.py --headless --path . \
  --script res://tests/crash_logger_test.gd
```

Run the isolated expected-error probe directly so its one intentional Godot
error does not weaken the repository's normal fatal-diagnostic scan:

```sh
python3 tools/crash_logger_profile.py probe
```

The probe requires one incident and at least two meaningful GDScript frames. It
rejects any extra engine error and removes its test output synchronously.

For the exported macOS debug candidate, use:

```sh
python3 tools/crash_logger_profile.py export-probe
```

This exports the current tree, runs the debug-only
`--crash-logger-self-test` flag, verifies the same record schema and location,
then removes the export and test logs. Release exports ignore the flag because
the self-test is guarded by `OS.is_debug_build()`; normal gameplay cannot invoke
it.

Before any further P1 main-menu candidate comparison, first run the predeclared
baseline-only resolution check against the immutable baseline:

```sh
python3 tools/crash_logger_profile.py null-profile \
  --baseline-sha <baseline> > null-profile.json
```

The same baseline occupies both positional slots. The check uses exactly twelve
pairs, 6,000 warmup frames, 24,000 measured frames per trial, and a 2 ms
calibration load. All trials and diagnostic host-load observations are retained;
there are no exclusions, retries, early stops, or pauses of unrelated work. It
passes only when calibration is responsive and the entire paired interval lies
inside `-1%` to `+1%`. If it is inconclusive, do not run another candidate
comparison: preserve that result and move the measurement to a dedicated,
otherwise-idle macOS benchmark runtime before trying again.

Only after a passing resolution check, run one candidate comparison on immutable
revisions and bind it to that exact evidence:

```sh
python3 tools/crash_logger_profile.py profile \
  --baseline-sha <baseline> --candidate-sha <candidate> \
  --null-evidence null-profile.json
```

These commands enforce the fixed protocol; their measurement parameters cannot
be overridden. The candidate comparison refuses null evidence produced for a
different baseline, profiler source, or protocol. The profiler resolves the
revisions before execution, serializes
each Godot process through `tools/godot_gate.py`, warms each process for 6,000
frames, and reports one 24,000-frame sample per SHA in each of twelve pairs.
The within-pair order is predeclared as three identical ABBA blocks:
`BC, CB, CB, BC, BC, CB, CB, BC, BC, CB, CB, BC`, where `B` is the baseline
and `C` is the candidate. Each revision therefore runs first in six pairs. On
the required macOS host, an acknowledged phase handshake samples Godot's
process-wide user and system CPU time with `proc_pid_rusage`. The rendered
main-menu scenario remains unchanged, while display and driver sleep are
excluded from the metric. A deterministic 2 ms per-frame CPU load calibrates
every trial; the run is inconclusive unless every trial detects that load. The
median of the twelve paired regressions is evaluated against the 1% budget with
a one-sided 95% bound. The single result includes every CPU and wall-clock
sample in execution order,
baseline/candidate SHAs, the effective protocol and its SHA-256, the profiler
source SHA-256, diagnostic host load averages before and after every run, and
the cleanup result. Host load is observation evidence, not an input to the
verdict. If calibration or noise cannot resolve that budget, treat the result as
inconclusive; do not infer a pass from more paced wall-clock frames or increase
the sample count after seeing the result.

## Reading an incident

Start with `error.text`, then inspect `script_backtrace.traces` from the newest
frame outward and correlate the ordered `breadcrumbs` by frame. The SHA-256 is
an immutable content identity: exported builds hash their `.pck`; editor runs
hash the logger script and identify that fallback source explicitly.

## Attaching one incident to a bug card

Incident sharing is always a deliberate manual action:

1. Open the project's user data folder and locate `logs/incidents/`. Select the
   incident whose timestamp matches the reproduced failure; do not select the
   directory, `godot.log`, or unrelated incidents.
2. Inspect the selected JSON locally before sharing it. Confirm the error,
   backtrace, and breadcrumbs belong to the report and contain no credentials
   or personal data. If further redaction is needed, make a sanitized copy,
   replace only the sensitive values, and confirm that the copy remains valid
   JSON. Do not attach the unredacted original.
3. Record the reproduction steps and the incident's `build_version`,
   `build_sha256`, and `build_sha256_source` in the bug card so the attachment
   can be tied to the exact build.
4. Use the bug-card interface's **Add attachment** control to upload only the
   inspected incident JSON (or its sanitized copy), then verify that this one
   file appears on the card.
5. Remove any temporary sanitized copy after the attachment is confirmed. The
   locally retained incident remains subject to the normal bounded rotation.

The logger never performs this attachment or any other upload automatically.
