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

Credential-shaped values and personal home paths are redacted. External source
paths are replaced with `<external>`. Do not add player names, save contents,
free-form chat, access tokens, or other personal data to breadcrumbs.

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

For the P1 main-menu frame-time comparison on immutable revisions, use:

```sh
python3 tools/crash_logger_profile.py profile \
  --baseline-sha <baseline> --candidate-sha <candidate>
```

The profiler runs identical rendered main-menu workloads after warmup, reports
five raw post-warmup samples for each SHA, and evaluates the median against the
1% budget. A result inside the measured noise band is reported as inconclusive,
not as a pass; increase `--frames-per-sample` and rerun.

## Reading an incident

Start with `error.text`, then inspect `script_backtrace.traces` from the newest
frame outward and correlate the ordered `breadcrumbs` by frame. The SHA-256 is
an immutable content identity: exported builds hash their `.pck`; editor runs
hash the logger script and identify that fallback source explicitly.
