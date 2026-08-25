# FantasyDisk independent QA protocol

Updated: 2026-08-01

QA verifies one explicitly assigned child pinned to one pushed candidate SHA.
QA does not self-select a parent, create competing review, repair production
code, or allocate rework.

Multica workspace lifecycle and dispatch transactions live in
`multica-workspace-governance`; the canonical dispatcher record is
`docs/process/dispatcher-authority.md`; this reference defines FantasyDisk
verification.

## Entry gate

Before testing, read the QA child, implementation parent, recent comments,
children, metadata, dependencies, active runs, and repository ancestry. Require:

- exact `candidate_sha == dispatch_candidate_sha`;
- candidate is pushed and reachable from the expected integration history;
- reviewer is not the implementer;
- exactly one live QA claim and no competing verdict;
- child and parent refer to the same scope/candidate;
- Story Points, estimation model, complexity, routing, and acceptance criteria
  are consistent;
- blocked dependencies and locked resources do not invalidate the test.

Fail closed on any mismatch. Publish the exact blocker; do not test a stale or
contested candidate and do not issue PASS.

## Test plan

Build a risk-based matrix before execution:

| Acceptance criterion | Risk | Check/evidence | Result |
| --- | --- | --- | --- |
| observable behavior | regression/failure mode | exact command or manual scenario | pending/pass/fail/blocked |

Read changed code, tests, fixtures, configuration, data, and docs. A developer
report, code review, or green CI status is context—not independent QA evidence.
Reject false-green tests that only reproduce their own expected output or avoid
the affected runtime path.

For a normal small gameplay, scene, or test change, independently run one or two
checks that directly exercise its acceptance path. Do not repeat the developer's
entire matrix. Escalate to a full gate only for release, saves/migrations,
networking, payments/secrets/security, or an already-red CI whose scope cannot
be isolated.

Choose any additional checks only when the assigned acceptance criteria need
them:

- focused functional behavior;
- negative and edge cases;
- integration and regression;
- save/data compatibility;
- manual/windowed interaction;
- platform/export behavior;
- performance/runtime stability;
- visual geometry, readability, and frame content zones.

Use `tools/godot_gate.py` for focused automated Godot execution. Use a
`tools/quality_gate.py` certifying profile only when one of the broad-risk cases
above or an explicit acceptance criterion requires it. Never substitute a
different platform for a platform-specific acceptance criterion.

## Gate evidence contract

`tools/quality_gate.py` fails closed on an empty scope and names the failure in
`static_checks`. Read the names, not the exit code:

- `test-discovery` — appended last to `static_checks` in every run except
  `--list`, including `--skip-static` and `--profile static`. Its `errors` say
  which set was empty: no Godot tests discovered, no Python tests discovered,
  or no Godot test selected for the requested scope.
- `python-unit` — `unittest discover` rooted at `tests/`.
- `python-unit:<root-relative dir>` — one check per nested discovery root that
  `tests/` cannot reach as a package (currently `python-unit:tests/tools`). A
  suite that collected but ran nothing fails as `<name> executed 0 tests`.

The gate emits no other names for these failures.

`exit code 0` does not prove tests ran: a non-certifying run (`--filters`,
`--skip-static`, `--skip-godot`, `--skip-umbrella`, a dirty worktree, or a
`--changed-ref` other than the configured `origin/dev` base) is
`partial_pass` and still exits `0`. Confirm execution in
`build/quality_gate_report.json`:

- `executed_python_tests` — Python tests actually run across the `python-unit`
  checks; `0` means there was no Python coverage.
- `selected_godot_tests` — Godot tests the scope selected; the `godot_tests`
  array stays empty when they were not executed.
- `changed_ref` and `changed_base_sha` — the effective diff reference and its
  resolved commit. `certifying: true` requires `changed_ref` to be the
  configured `origin/dev` base.

Treat a run as certifying profile evidence only when the report also has
`certifying: true`. A named focused suite may still be sufficient lean evidence
when the issue does not require a certifying quality profile; record exactly
what ran and never describe a filtered profile as certifying.

## Runtime safety

Bound self-reexecuting or engine-heavy harnesses with the repository gate and a
finite timeout. Monitor early process growth; stop a runaway test before it can
exhaust the host. Record the failure honestly rather than retrying indefinitely.

Use disposable, task-owned user data and worktrees. Do not change releases,
tags, repository rules, secrets, external accounts, or production data during
QA.

## Visual evidence

Only for an explicit UI/visual/manual acceptance criterion, capture the evidence
that materially proves it. Screenshots and video are not default evidence for a
non-visual gameplay fix:

- screenshots/video with viewport, platform, and candidate SHA;
- rect/content-zone dumps;
- logs/traces/profiler captures;
- source/runtime asset manifests.

Content may not cover frame ornament. Background and non-background generator
routing must match repo `AGENTS.md`. Store or attach evidence through the
task-approved path and sanitize secrets/personal data.

## Findings

Classify each finding:

- passed;
- failed;
- blocked;
- not tested;
- inconclusive.

For a confirmed defect, report reproduction, expected/actual behavior,
candidate/environment, severity/impact, evidence, affected scope, and a proposed
acceptance criterion. PM decides decomposition/estimate/routing; QA does not
assign or implement it.

## Verdict

Publish:

```text
QA verdict: PASSED | FAILED | INCONCLUSIVE
Candidate/base SHA:
Environment:
Acceptance → evidence matrix:
Commands and results:
Evidence:
Findings:
Linked defects: <ids | none>
Documentation consistency:
Residual risk:
Recommendation: Go | Go with known risks | No-Go
Disk cleanup:
```

- `PASSED`: every required criterion has sufficient executed evidence; finish
  the QA child and trigger PM once.
- `FAILED`: one or more required criteria fail; finish the child with evidence
  and trigger PM once for bounded rework.
- `INCONCLUSIVE`: evidence cannot establish the result; record the exact unblock
  condition and trigger PM once.

QA does not directly close/reassign the implementation parent or launch the next
stage. PM prepares the deterministic gate and the canonical dispatcher executes
it.
