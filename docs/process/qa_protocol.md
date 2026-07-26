# FantasyDisk independent QA protocol

Updated: 2026-07-26

QA verifies one explicitly assigned child pinned to one pushed candidate SHA.
QA does not self-select a parent, create competing review, repair production
code, or allocate rework.

Multica workspace lifecycle and dispatch transactions live in
`multica-workspace-governance`; this reference defines FantasyDisk verification.

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

Choose checks in proportion to risk:

- focused functional behavior;
- negative and edge cases;
- integration and regression;
- save/data compatibility;
- manual/windowed interaction;
- platform/export behavior;
- performance/runtime stability;
- visual geometry, readability, and frame content zones.

Use `tools/godot_gate.py` for automated Godot execution and the appropriate
`tools/quality_gate.py` profile for certifying coverage. Never substitute a
different platform for a platform-specific acceptance criterion.

## Runtime safety

Bound self-reexecuting or engine-heavy harnesses with the repository gate and a
finite timeout. Monitor early process growth; stop a runaway test before it can
exhaust the host. Record the failure honestly rather than retrying indefinitely.

Use disposable, task-owned user data and worktrees. Do not change releases,
tags, repository rules, secrets, external accounts, or production data during
QA.

## Visual evidence

For UI/visual/runtime acceptance, capture the evidence that materially proves
the criterion:

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
stage. PM prepares the deterministic gate and Qwen executes it.
