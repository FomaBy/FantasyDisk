# FantasyDisk Multica workflow

Updated: 2026-08-01

Multica project `FantasyDisk` (`FAN-*`, project ID
`2ac963eb-b644-4540-8042-a1a4508f1a65`) is the authoritative queue. Jira
Archive and repository task Markdown are read-only history or spec/evidence
mirrors. Use the `multica` CLI for issue state.

Workspace-wide transaction details live in the bound
`multica-workspace-governance` skill. This file records FantasyDisk-specific
lifecycle and repository evidence.

## Roles

- PM: scope, acceptance criteria, CUE/Fibonacci, decomposition, dependencies,
  complexity, routing, QA/rework readiness, canonical dispatcher supervision.
- Canonical dispatcher: mechanical selection of an eligible worker, assignment,
  `backlog → todo`, exact-SHA QA launch, and deterministic lifecycle
  transitions under `docs/process/dispatcher-authority.md`. It does not make
  product judgments.
- Developer: one explicitly assigned implementation issue.
- QA: one explicitly assigned same-card review stage pinned to the pushed
  candidate SHA; no production fixes in review scope.
- Integrator: the dedicated same-card integration stage; promotes only the
  exact QA-approved SHA into the explicit target.

One daemon agent owns at most one live issue. No worker self-claims unassigned
work, and no second dispatcher or competing QA may exist.

## Status meanings

| Status | Meaning |
| --- | --- |
| `backlog` | parked and not running; dispatch gate may be incomplete or waiting |
| `todo` | one assigned daemon run is queued or starting |
| `in_progress` | the assigned worker has a live claim |
| `in_review` | PM-admitted immutable candidate undergoing same-card QA or integration |
| `blocked` | a concrete external/dependency condition prevents progress |
| `done` | the issue's own completion/QA contract is satisfied |

Status is evidence, not intent. A card must not remain active without a matching
live run or exact handoff.

## Readiness

PM creates or re-estimates an unassigned `backlog` issue. Before dispatch:

Story Points use `1, 2, 3, 5, 8, 13`. CUE does not sum by formula and is not an additive formula; it is a holistic judgment. Keep exactly one `SP:<N>` label, matching `story_points`, and matching `estimation_model`.

- description includes `Story points: <N>`, CUE rationale, complexity tier and
  rationale, routing lane, scope, and verifiable acceptance criteria;
- exactly one `SP:<N>` label matches numeric `story_points=<N>`;
- `estimation_model=CUE/Fibonacci`;
- exactly one `Complexity:<tier>` label matches `complexity_tier`;
- dependencies, hold state, and locked scope are unambiguous.

PM re-reads the complete card. A mismatch leaves `dispatch_ready=false` with an
exact `waiting_on`; it is not repaired by the canonical dispatcher or a worker.

Ready handoff fields:

```text
pipeline_status=ready_for_dispatch
dispatch_ready=true
dispatch_kind=implementation|qa|devops
dispatch_lane=dev_low|dev_medium|dev_high|qa_low|qa_high|devops_integration
dispatch_target_agent_id=<optional policy exception>
dispatch_candidate_sha=<required for QA>
```

For QA, `candidate_sha` and `dispatch_candidate_sha` must match. PM pre-stages
one independently estimated QA child before implementation handoff is complete.

## Mechanical launch

The canonical dispatcher reads the ready index, current quota registry, runtime/agent capacity,
active issue/run ownership, dependencies, and overlaps. It acts only on an
unassigned ready `backlog` issue and an eligible idle target.

The single launch mechanism is:

1. Add one assignment comment while the target is unassigned `backlog`, without
   agent/squad mention.
2. Assign exactly one eligible agent.
3. Re-read and require the exact intended owner plus unchanged `backlog`.
4. Move `backlog → todo` exactly once.
5. Confirm exactly one queued/running task.

Do not combine comment wake, status wake, mention, rerun, squad, or autopilot
trigger. Do not comment after assignment before the worker claim. Unexpected
command failure stops the cycle without retry loops.

## Developer execution

The assigned worker:

1. Re-reads issue, comments, dependencies, acceptance criteria, assignee,
   routing metadata, active runs, and locked paths.
2. Reads repo `AGENTS.md` and the narrow domain skill/reference.
3. Claims the assigned task, records owner/run/workdir/branch/locks, and changes
   only the task-owned scope.
4. For a normal small change, runs one focused check; adds a second only for a
   distinct failure mode. Broad gates are reserved for the risk cases below.
5. Inspects the full diff, commits and pushes the candidate.
6. Posts a Russian summary followed by exact SHA, relevant commands/results,
   untested checks, and residual risk.
7. Triggers PM once. It does not create/assign QA or take another issue.

The implementation parent remains owned/active until PM prepares and the
canonical dispatcher launches its exact-SHA QA child. After that launch, the
canonical dispatcher may unassign the parent
and move it to `in_review` only when child/parent SHA, reviewer independence, and
live QA state all agree.

## QA execution

QA verifies only its assigned child. For a normal small change it inspects the
final diff and independently runs one or two focused checks. It also verifies:

- exact pushed candidate and ancestry;
- reviewer is not the implementer;
- one live claim, no competing verdict;
- acceptance criteria mapped to executed evidence;
- code/tests/fixtures/docs inspected for false greens;
- focused functional, negative, edge, integration, regression, platform,
  performance, and visual checks selected by risk.

The report contains `QA verdict: PASSED|FAILED|INCONCLUSIVE`, exact SHA,
focused commands/results, findings, residual risk, and one recommendation.

QA finishes its child and triggers PM once. It does not repair production code,
reassign the parent, or allocate rework. PM prepares any bounded
defect/rework/lifecycle gate; the canonical dispatcher executes the mechanical
transition.

Broad `changed/full` profiles, repeat matrices, mutation probes, screenshots,
and extra documentation are not default. Require a full gate only for a release,
saves/migrations, networking, payments/secrets/security, or an already-red CI
whose scope cannot be isolated by focused checks.

## DevOps integration

After terminal exact-SHA QA `PASSED`, PM pins equal candidate/dispatch/QA SHAs
and the canonical dispatcher launches the dedicated DevOps issue. DevOps:

1. Confirms the PR head is still the QA-approved SHA and is mergeable.
2. Requires one green PR CI for that unchanged current head. An existing green
   current-head run is sufficient; QA completion alone does not trigger a rerun.
3. Merges without content edits.
4. Fetches `origin/dev` and verifies the approved SHA is reachable.

### Checking mergeability without leaking a commit onto `dev` (FAN-3034)

A conflict/mergeability probe must never produce a commit that a later `git
push` can land on `dev` — including under a placeholder message such as
"TEST MERGE - will discard". Any commit reachable from `dev`'s history is
permanent per this project's no-rewrite rule (the prohibitions section in
`docs/process/versioning_and_branching.md`); a throwaway label does not make
it safe to push and does not entitle anyone to revert it later.

- Prefer the GitHub API/PR `mergeable`/`mergeable_state` field — it never
  touches local `dev`.
- If a local probe is required, run it without creating a landable commit:
  `git merge --no-commit --no-ff <candidate>`, inspect the result, then
  `git merge --abort` (or run it in a disposable clone/worktree that is never
  the target of `git push`).
- Never `git push` a commit produced by a conflict probe, whatever its
  message says. The commit that reaches `dev` must be created fresh, at push
  time, with a real integration message (`Merge FAN-XXXX: ... into dev`), not
  reused from an earlier throwaway check.

Do not require post-merge CI, merge-tree, tree/blob/patch equivalence, or a
separate merge-ref artifact dossier for ordinary gameplay integration. A clean
operator mirror may be fast-forwarded best-effort; WIP means skip it without a
blocker.

## Blockers and recovery

Record a blocker as:

- user/project impact;
- checks already made;
- exact dependency or external-state condition;
- safe unblock action;
- truthful status and `waiting_on`.

Do not park routine technical uncertainty as a user decision. Do not erase
another worker's changes, force Git history, bypass a failed gate, or infer
quota/capacity from stale prompt text.

## Completion evidence

Every task-ending report includes only what is relevant:

- human-readable Russian summary;
- issue and role;
- exact pushed SHA and upstream state;
- required commands and results;
- evidence or docs only when required or changed;
- failed, blocked, skipped, and untested checks;
- residual risk and next lifecycle state;
- operator mirror result only when it was safely updated; WIP is a non-blocking
  skip.

All run-owned tests, builds, tools, and subagents finish synchronously before
the top-level turn ends.
