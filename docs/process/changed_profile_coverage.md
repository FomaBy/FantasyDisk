# Changed-profile save, lifecycle and encounter coverage

`tools/quality/selection.py` adds dedicated contracts to the shared changed-profile
suites when these production paths change. Exact-path rules are additive; the
existing core, runtime smoke and typography selection still applies.

| Changed path | Additional coverage |
| --- | --- |
| `scripts/run_autosave.gd` | Autosave persistence, two-act progression/resume, encounter feature-state autosave |
| `scripts/meta_progression.gd`, `scripts/constellation_schema6_data.gd`, `scripts/meta_progression_tree_data.gd` | Meta-progression persistence, schema-6 migration, meta skill-tree smoke, per-hero skill trees |
| `scripts/main.gd`, `scripts/combat_director.gd` | Autosave group above, boss/elite runtime smoke, ultimate-charge persistence, main pause lifecycle, combat-world pause |
| `scripts/ui/screens/victory_death.gd`, `level_up_screen.gd`, `level_up_cards.gd`, `pause_menu.gd` | UI runtime smoke, boss/elite victory flow, death flow, main pause lifecycle, combat-world pause |
| `scripts/encounters/**`, `data/encounters/**` | Every discovered suite under `tests/encounters/`, including nested directories |

The skill-tree data rule also retains its existing offensive-scaling contract.
Encounter directory rules discover suites rather than listing their names, so
future encounter suites are included automatically. Directory boundaries are
significant: `scripts/encounters_extra/` does not match. Encounter data now has
bounded domain coverage rather than triggering the unknown-data full fallback.
Other unknown domains retain that fallback.

The full, Windows and static profiles, filtering, `--skip-umbrella`, and shard
slicing retain their existing behavior. Filters and skipped checks still make
a run partial evidence under the gate's certification rules.

## Validation

Run the Python selection and runner contracts from a scratch child environment:

```sh
scratch=$(mktemp -d)
mkdir -p "$scratch/home" "$scratch/data" "$scratch/tmp"
env HOME="$scratch/home" XDG_DATA_HOME="$scratch/data" TMPDIR="$scratch/tmp" \
  python3 -m unittest discover -s tests -p 'test_quality_selection.py'
env HOME="$scratch/home" XDG_DATA_HOME="$scratch/data" TMPDIR="$scratch/tmp" \
  python3 -m unittest discover -s tests -p 'test_quality_tools.py'
```

For a real changed-profile list/run, use a disposable checkout with just the
production change in its diff. List selection with
`python3 tools/quality_gate.py --profile changed --changed-ref <base> --list`.
Run the same command without `--list` for normal gate execution.

Before any import or suite that can write `user://`, set scratch child `HOME`
and `XDG_DATA_HOME` (also `APPDATA`/`LOCALAPPDATA` on Windows), select the Godot
binary explicitly, and verify `OS.get_user_data_dir()` resolves under scratch.
Godot 4.7 ignores `--user-data-dir`; that argument alone does not isolate saves.
All automated Godot calls go through `tools/godot_gate.py`.

The FAN-4011 mutation experiment uses a separate disposable repository. Commit
the unmodified `encounter_context.gd` as its base and ignore the other copied
files, then change only that tracked production file. Temporarily insert
`_expect(false, "FAN-4011 deliberate failure")` at the start of
`contract_feature_lifecycle_test._initialize()`. Confirm Git's changed paths
contain only `scripts/encounters/encounter_context.gd`, and run the changed
profile with `--skip-static` in scratch isolation. The selected contract suite
must report the deliberate failure and the gate must exit nonzero. Restore the
test bytes in a `finally` block and verify their hash. Run the restored contract
suite to confirm the fixture is healthy. Never commit the broken assertion or
apply it to the published candidate.

## Runtime measurement

Measured on macOS with `4.7.stable.official.5b4e0cb0f`, based on
`9a19870a15d71bc2b63e622c7895519bd84dafb4` (2026-11-14). Discovery found 566
executable suites, including 16 encounter suites. All 35 unique suites needed
for the selections below passed. The 20 selection tests and 83 existing runner
tests also passed; the added selection regressions failed on the original
policy before implementation.

| Single-file change | Before → after selected suites | Added suite time | After suite time |
| --- | --- | --- | --- |
| `run_autosave.gd` | 7 → 10 | 10.2 s | 159.2 s |
| `meta_progression.gd` or `constellation_schema6_data.gd` | 7 → 11 | 8.0 s | 157.1 s |
| `meta_progression_tree_data.gd` | 8 → 12 | 8.0 s | 157.9 s |
| `main.gd` or `combat_director.gd` | 7 → 14 | 26.0 s | 175.1 s |
| Any of the four in-run screens above | 7 → 11 | 19.3 s | 168.4 s |
| Either encounter script from the issue's reproduction table | 7 → 23 | 20.3 s | 169.3 s |
| Encounter data | 566 → 21 | No new suites | 42.7 s |

These are sums of measured per-suite wall times from one sequential run of
the union, using the same sample for each suite shared by before/after sets.
They include gate/process startup and the scratch-path verification probe;
they exclude static checks and the 219.6 s initial asset import. The machine
was shared with other work; these are local estimates, not CI timing promises.
Multiple changed domains select a deduplicated union, so their increments must
not simply be added. The old full-fallback encounter-data runtime was not
measured; only its selection count and the bounded new set were verified.

The isolated mutation selected 23 suites, ran nine before `--fail-fast` stopped
execution, and exited 1 on `contract_feature_lifecycle_test` with
`FAN-4011 deliberate failure`. Only `scripts/encounters/encounter_context.gd`
appeared in changed-path discovery. The original test's SHA-256 was unchanged
after restoration, and the restored focused run exited 0 (`partial_pass`,
because static checks were skipped and the run was filtered). The mutation
run is deliberately non-certifying acceptance evidence. No game/test mutation
is included in this change. Independent candidate QA is still required.
