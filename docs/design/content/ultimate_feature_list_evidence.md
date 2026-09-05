# Ultimate feature list: executable evidence contract (FAN-3904)

`data/ultimates/feature_list.json` maps every canonical weapon ultimate to a
behavior summary and one verification recipe. `tools/ultimate_feature_list_check.py`
proves the mapping is complete, runs the recipes without a shell and writes a
report in which `passing` exists only as the result of a fresh run bound to
the candidate. Evidence enters that report on exactly two paths: the checker
executes the recipe itself, or `tools/quality_gate.py` executes the suite and
hands its own in-memory result to the checker library inside the same process.
No manifest, log or report on disk is ever imported as proof. This document is
the contract for that checker. The content
description of the ultimates themselves stays in the FD06-owned content
document and in `docs/design/ultimates/<class_id>.md`.

## Canonical identities

The feature list is not a roster. Identities are discovered every run from the
existing canonical sources and the list is validated against them:

| Source | Role |
| --- | --- |
| `data/ultimates/schema/v1/classes/<class_id>.json` | identity source: `class_id`, `class_order`, `profiles[].weapon_id` |
| `data/ultimates/classes/<class_id>/<weapon_id>.json` | ready overlays; must name exactly the same pairs |

Exactly 17 classes and 51 weapons are expected. A duplicate, extra, missing or
swapped entry, an `id` that is not `<class_id>/<weapon_key>`, or a catalog/overlay
disagreement exits nonzero before anything runs.

## Committed entry schema

```json
{
  "id": "berserk/sword",
  "class_id": "berserk",
  "weapon_key": "sword",
  "behavior": "Алый Вихрь: ...",
  "state": "active",
  "verification": ["python3", "tools/godot_gate.py", "--headless", "--path", ".", "--script", "res://tests/ultimates/mechanics/berserk_live_test.gd"]
}
```

| Field | Rule |
| --- | --- |
| `id` | exactly `<class_id>/<weapon_key>`, one entry per canonical pair, catalog order |
| `behavior` | non-empty summary of what the ultimate does (canonical title + mechanics text) |
| `state` | committed values are only `not_started`, `active`, `blocked` |
| `verification` | argv array for `active`; `null` for `not_started` and `blocked` |
| `blocked_reason` | required for `blocked`; names the missing or broken suite |

A committed `passing` or `failed` state, or a committed `evidence` object, is a
manual claim and fails validation. The repository never proves a pass.

## Recipe allowlist

Recipes are argv arrays executed with `subprocess` and no shell. The only
admitted shape is:

```
python3 tools/godot_gate.py --headless --path . --script res://tests/<suite>.gd
```

Everything else fails closed with a three-part message (what failed,
consequence, fix):

- another interpreter or binary in `argv[0]`;
- another runner in `argv[1]`, including `tools/quality_gate.py` and the checker
  itself (no recursive gate invocation);
- extra or reordered options (`--import`, `--export`, a different `--path`);
- absolute, home-relative or `..` paths, backslashes, or a suite outside
  `tests/` (symlinks are resolved before the check);
- tokens with whitespace or shell metacharacters (`; | & $ ` " ' * ? ( ) [ ] { } # ! < >`);
- a suite that does not exist, is not a `SceneTree` test, or requires the
  machine-wide exclusive lease (`TIMING_SENSITIVE_GODOT_SCRIPTS`).

At execution the checker adds only runtime scratch arguments
(`-- --user-data-dir=<scratch>`), points `HOME`/`XDG_DATA_HOME`/`APPDATA` at the
same scratch directory, clears `FSD_GODOT_EXCLUSIVE` and sets
`FSD_ULTIMATE_FEATURE_LIST_ACTIVE=1` so a nested checker refuses to start.
Every recipe is bounded by `--timeout` (default `FSD_GODOT_TEST_TIMEOUT` or
900 s) and `--output-limit` (default 4 MB); a timeout kills the whole process
tree and records exit code 124, an overflow kills the process and records the
truncation. Exit codes are preserved in the evidence. The checker performs no
network access and writes only under `build/`; `--report` and `--log-dir`
outside `build/` are refused.

## Fresh evidence

The checker executes each distinct recipe once per run (entries sharing a recipe
share its evidence) and writes `build/ultimate_feature_list/report.json` plus one
log per recipe under `build/ultimate_feature_list/logs/<argv_digest>.log`.

Every executed command is normalized back to recipe form before it may bind:
runtime scratch arguments after `--` are dropped, the interpreter token becomes
`python3`, the runner must resolve to this repository's `tools/godot_gate.py`
and `--path` must resolve to this checkout. A command that does not normalize
to exactly the committed recipe carries no evidence for it, whoever executed
it. The `recipes` section of the report keeps the actual `executed_argv`,
`executed_by`, exit status, duration, log path and log digest of every run.

| Report state | Meaning |
| --- | --- |
| `passing` | fresh run exited 0 with no fatal diagnostic and no truncation |
| `failed` | nonzero exit, timeout, output overflow or a `push_error`/`SCRIPT ERROR` diagnostic |
| `blocked` | committed `blocked` with its `blocked_reason` |
| `not_started` | committed `not_started`; no recipe mapped yet |

A `passing` record carries:

```json
{
  "candidate_sha": "<git rev-parse HEAD, 40 hex>",
  "argv_digest": "sha256 of the normalized recipe argv (JSON, compact)",
  "log_digest": "sha256 of the actual captured log",
  "log_path": "build/ultimate_feature_list/logs/<argv_digest>.log",
  "exit_code": 0,
  "executed_by": "ultimate_feature_list_check | quality_gate_profile"
}
```

`--verify-report <path>` re-derives every binding against the current checkout,
which must be the same clean commit the report was generated on: the report and
every passing record must name `HEAD`, the report's `feature_list_digest` must
equal the committed list, the `argv_digest` must equal the digest of the recipe
currently committed for that entry, the log must exist under `build/`, hash to
`log_digest` and carry no fatal diagnostic, `exit_code` must be 0, and the
entry's recipe execution record must exist, normalize to the committed recipe
and agree with the entry (passed, exit 0, same log path and digest). A dirty
worktree at generation (`worktree_dirty` in the report) or at verification
fails, because a working tree that differs from `HEAD` is not the candidate.
Any other candidate, an edited recipe or feature list, an edited or missing
log, a hand-edited state or execution record, a pass without evidence, or a
report whose `blocked`/`not_started` entries no longer match the list fails
nonzero. Missing or blocked verification is reported truthfully and is not a
failure; a target number of passing entries is never a criterion.

`--verify-report` detects drift after a run. It cannot distinguish a genuine
report from one forged together with its logs by someone who can write to
`build/`, so a report is proof only for whoever produced it in their own run
(or gate run) or reproduces it. Independent QA therefore re-runs the checker on
the exact candidate SHA instead of verifying a report it received.

The checker's own exit status: `0` all checks passed, `1` validation,
verification or recipe failure, `2` usage or environment refusal.

## Quality gate integration

`tools/quality_gate.py --profile changed` owes the checker when the diff
against the integration base touches any of:

- `data/ultimates/**`
- `tests/ultimates/**`
- `tools/ultimate_feature_list_check.py`
- `tests/test_ultimate_feature_list.py`

Deduplication against the invoking profile is structural: the gate adds every
active recipe suite from the committed feature list to its own Godot selection,
runs each suite once through its normal per-suite path (import pre-pass,
timeouts, `push_error` verdict), keeps the actual command, captured output and
exit status of every recipe suite in memory, and then calls the checker library
exactly once in its own process (`bind_profile_run`), after removing generated
import sidecars so the worktree the checker records is the candidate. The
checker launches nothing and reads no file as evidence: it validates the list,
requires every handed-over command to normalize to the recipe it proves, binds
every entry to the log of this run (`executed_by: quality_gate_profile`) and
fails any recipe the gate did not execute as `not executed by the invoking
profile`. The trust boundary is the gate process: there is no manifest,
`--bind-only` or `--profile-results` option, so a file placed under `build/`
by hand can never become evidence, and a report or manifest left over from an
earlier run on the same SHA is never reused. A recipe may never name
`tools/quality_gate.py` or the checker, so no recursive gate invocation exists.

The step is named `ultimate-feature-list`; its verdict is part of the gate
verdict and the gate report records `ultimate_feature_list_selected` and the
step result with the checker report path. If the checker is owed but the run's
selection does not contain every recipe suite (name filters, shards, `--skip-godot`,
a fail-fast stop), the step is recorded as `skipped` with the reason and the run
is non-certifying. `--profile static` and `--static-only` keep their documented
command set and never run the checker.

## Commands

```
python3 tools/ultimate_feature_list_check.py --validate-only
python3 tools/ultimate_feature_list_check.py
python3 tools/ultimate_feature_list_check.py --verify-report build/ultimate_feature_list/report.json
python3 -m unittest tests.test_ultimate_feature_list
```

Independent QA reproduces the report on the exact candidate SHA and re-runs the
negative controls in `tests/test_ultimate_feature_list.py`, which cover
cardinality and key errors, fabricated and stale evidence, disallowed commands
and paths, timeout, failure, output overflow, digest mismatch, recipe
deduplication, in-process gate binding (missing or mismatching executed
command, unexecuted recipes, failed or timed-out suites, ignored on-disk
manifests), stale same-SHA reuse, fabricated execution records and the gate
selection rules.
