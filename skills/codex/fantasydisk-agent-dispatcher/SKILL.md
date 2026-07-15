---
name: fantasydisk-agent-dispatcher
description: Coordinate continuous FantasyDisk multi-agent delivery from Multica. Use when distributing queued FAN issues, assigning QA/backend/design/animation workers, inspecting or restarting agents, preventing duplicate ownership, or keeping the project conveyor active across macOS and Windows runtimes.
---

# FantasyDisk Agent Dispatcher

Run a central Multica dispatcher. Multica project `FantasyDisk` is authoritative;
legacy Jira is a read-only archive. Never let workers discover and claim the same
unassigned implementation issue independently. The only self-selection exception
is the exclusive QA queue owner defined below.

## Context

Read repo `AGENTS.md`. Resolve the repository with `git rev-parse
--show-toplevel`; never assume a drive letter, shell syntax, or home-directory
path. The dispatcher chooses explicit absolute repo/worktree paths valid on the
current runtime and includes them in each worker prompt.

Canonical IDs:

- project: `2ac963eb-b644-4540-8042-a1a4508f1a65`
- Codex agent: `4eccbced-60b5-4e7a-87fd-d9f3699d3bed`
- Claude agent: `e2e1c89f-587d-4a2d-bbaa-ce9b5dea908d`
- QA Codex Sol: `f992a646-a8ea-4935-ba94-212595803052`

## Discover

List the whole queue; a known parent ID is optional:

```bash
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status in_review --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status todo --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status in_progress --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status backlog --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status blocked --limit 100 --output json
```

Page with `--offset` if a result reaches the limit. The list result does not
contain the comment/lock history: for every candidate run `multica issue get
<FAN-id> --output json` and `multica issue comment list <FAN-id> --recent 10
--output json`. Reject blocked/dependent/stale-owner candidates. Treat
`in_review` as the exclusive QA lane: observe or wake QA Codex Sol, but do not
create a competing QA child. Then dispatch small backend/balance work, followed
by non-overlapping UI/design and animation work.

Before assigning, inspect capacity with `multica agent list --output json`,
`multica agent tasks <agent-uuid> --output json`, and assignee-filtered `todo` /
`in_progress` issue lists. Do not queue a second issue to a busy agent. QA Codex
Sol must keep runtime concurrency `1` and at most one QA child `in_progress`.

Every actionable issue, including QA/review and follow-up children, must satisfy
repo `docs/process/story_points.md` before execution: description contains
`Story points: <N>` plus a CUE rationale; exactly one canonical issue Label
matches `SP:<N>` where N is one of `1, 2, 3, 5, 8, 13`; numeric metadata
`story_points` matches N; `estimation_model` is `CUE Fibonacci 1,2,3,5,8,13`.
Return missing, duplicate, or inconsistent labels/estimates to PM. Never
dispatch an issue sized above `13 SP`; require decomposition first.

## Assign Without Duplicate Claims

1. Require a `DISPATCH_CONTROL_FAN` for the run. Post a `--content-file` lease
   comment with dispatcher identity and an expiry no more than 15 minutes ahead;
   re-read recent comments and continue only if no other unexpired lease exists.
   Refresh before every assignment. A second dispatcher observes only.
2. Re-read the candidate immediately before assignment:
   `multica issue get <FAN-id> --output json` and recent comments.
3. Require `todo`, no active assignee, no blocker, no overlapping owner/lock,
   and a valid story-points readiness check from `docs/process/story_points.md`.
   Capture the latest comment timestamp/ID. Never feed an implementation parent
   already in `in_review` through this general assignment path; QA Codex Sol owns
   that lane and creates/reuses its own separate QA child.
4. Multica CLI has no compare-and-swap claim. Under the single-dispatcher rule,
   reserve without starting the daemon in one update:
   `multica issue update <FAN-id> --status backlog --assignee-id <agent-uuid>
   --output json`.
5. Re-read the issue and comments. Assert `backlog`, the exact assignee UUID,
   and no new foreign owner/lock comment after the captured cursor. If any check
   differs, roll back before enqueue. Otherwise post the assignment/locks
   comment through `--content-file`, re-read once more, then move it to `todo`.
6. The worker re-reads its issue, verifies its own assignee, then sets
   `in_progress` and posts owner/workdir/branch/locked paths. Unassigned workers
   must never self-claim by changing status alone.

For an already assigned `backlog` issue, never replace its assignee. Release it
to `todo` only after its dependency/hold is explicitly cleared and the exact
assignee has no active task.

If reservation or enqueue fails, keep it parked, unassign, and only then restore
the prior free status so no daemon can start mid-rollback:

```bash
multica issue status <FAN-id> backlog
multica issue assign <FAN-id> --unassign
multica issue status <FAN-id> todo
```

Record the failure. This lease/re-read protocol reduces but cannot eliminate a
server race; true multi-dispatcher safety requires server-side
claim-if-unassigned/expected-status. Never run multiple dispatcher writers.

## Autonomous QA Lane

QA Codex Sol is the sole writer for `in_review` selection. The general
dispatcher may trigger a QA queue sweep when the agent is idle, then observes.
It must not pre-create the QA child, replace the parent assignee, or send the
same parent to another reviewer.

In one queue-sweep run QA selects one eligible parent by priority then age,
audits parent/comments/children/dependencies/active runs/exact pushed SHA and
reviewer independence, and writes a parent claim comment. Live Multica agent
ACL denies self-assignment, so QA creates or reuses an unassigned `backlog` QA
child and records exact child metadata `qa_owner_id=f992a646-a8ea-4935-ba94-212595803052`,
`qa_run_id=<current-task-id>`, `qa_candidate_sha=<exact-sha>`, and
`qa_claim_mode=autonomous_unassigned`, plus a matching owner/run/SHA comment.
Before moving the QA child to `in_progress`, QA also records its CUE/Fibonacci
estimate, exactly one matching `SP:<N>` Label, and matching
`story_points`/`estimation_model` metadata. Every new `BUG:` / `IMPROVEMENT:`
child receives the same estimate block, Label, and metadata before it becomes
dispatchable.
QA then re-reads parent, child, metadata, and comments. The claim is valid only
when all four values match, the current run is live, the SHA is unchanged, and
there is no competing claim/verdict. QA moves that child directly to
`in_progress` and completes it in the same run; it does not use `todo` and spawn
a second daemon task. On any mismatch it cancels its duplicate child and does
not test the stale/contested candidate. Every dispatcher treats this complete
metadata claim as a live owner signal even though `assignee_id` is null. This is
a narrow QA-only exception; unassigned implementation workers still cannot
self-claim.

Load `references/qa-loop.md` whenever waking or reconciling this lane. QA must
perform the complete independent verification, attach visual/runtime evidence
when needed, write the detailed report, create linked `BUG:` / `IMPROVEMENT:`
children for every confirmed follow-up, and clean its disposable worktree/data.

When using an in-process subagent instead of a Multica daemon agent, the central
dispatcher must first set `in_progress` and post a direct-control owner/lock
comment. Do not assign a daemon agent as well.

## Worker Contract

Give a worker exactly one FAN ID per run. It must:

- verify issue status, assignee, comments, and locked paths before edits;
- fetch `origin/dev`, pin its SHA, then create a named task branch/worktree from
  that exact SHA (`git worktree add -b <task-branch> <absolute-path> <sha>`);
- read the relevant UI/asset/animation/balance skill;
- update docs and run the required synchronous quality gates;
- commit and push task-owned files with the FAN key;
- post exact SHA, commands/results, residual risk, and cleanup evidence;
- move implementation to `in_review`; a QA PASS marks both the QA child and its
  implementation parent `done`; QA RED completes the QA child with verdict
  evidence but leaves the parent `in_review` and creates/links every confirmed
  defect or required improvement;
- stop after that issue so the central dispatcher chooses the next assignment.

Never leave background commands or workers running past the owning Multica turn.

## References

Load only the role template needed:

- `references/backend-loop.md`
- `references/qa-loop.md`
- `references/design-loop.md`
- `references/animator-loop.md`
- `references/dispatcher-heartbeat.md`

## Report

Report active agents and FAN IDs, lane coverage, failed starts, green/red gates,
and genuine blockers. Do not call work complete before push, Multica evidence,
and cleanup are all verified.
