---
name: fantasydisk-agent-dispatcher
description: Coordinate continuous FantasyDisk multi-agent delivery from Multica. Use when distributing queued FAN issues, assigning QA/backend/design/animation workers, inspecting or restarting agents, preventing duplicate ownership, or keeping the project conveyor active across macOS and Windows runtimes.
---

# FantasyDisk Agent Dispatcher

Run a central Multica dispatcher. Multica project `FantasyDisk` is authoritative;
legacy Jira is a read-only archive. Never let workers discover and claim the same
unassigned issue independently.

## Context

Read repo `AGENTS.md`. Resolve the repository with `git rev-parse
--show-toplevel`; never assume a drive letter or home-directory path. Create
isolated worktrees under `${FANTASYDISK_WORKTREE_ROOT:-<repo-parent>/FantasyDisk_agents}`
from fresh `origin/dev`.

Canonical IDs:

- project: `2ac963eb-b644-4540-8042-a1a4508f1a65`
- Codex agent: `4eccbced-60b5-4e7a-87fd-d9f3699d3bed`
- Claude agent: `e2e1c89f-587d-4a2d-bbaa-ce9b5dea908d`

## Discover

List the whole queue; a known parent ID is optional:

```bash
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status in_review --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status todo --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 --status in_progress --limit 100 --output json
```

Page with `--offset` if a result reaches the limit. Filter JSON by role/lane,
priority, blockers, assignee, parent, comments, and locked paths. Prefer QA for
`in_review`, then small backend/balance work, then non-overlapping UI/design and
animation work.

## Assign Without Duplicate Claims

1. Keep exactly one active dispatcher for a queue. Record its owner and
   heartbeat in the parent/control FAN issue. A second dispatcher observes only.
2. Re-read the candidate immediately before assignment:
   `multica issue get <FAN-id> --output json` and recent comments.
3. Require `todo`, no active assignee, no blocker, and no overlapping owner/lock.
   For implementation already in `in_review`, create or reuse a separate QA child
   issue in `todo`; do not replace the implementation owner.
4. Multica CLI has no compare-and-swap claim. Under the single-dispatcher rule,
   reserve without starting the daemon in one update:
   `multica issue update <FAN-id> --status backlog --assignee-id <agent-uuid>
   --output json`.
5. Re-read the issue and assert both `backlog` and the exact assignee UUID. If
   either differs, do not edit or dispatch. Post the assignment/locks comment,
   then move it to `todo` to enqueue the assigned agent.
6. The worker re-reads its issue, verifies its own assignee, then sets
   `in_progress` and posts owner/workdir/branch/locked paths. Unassigned workers
   must never self-claim by changing status alone.

If reservation or enqueue fails, restore the truthful prior status, unassign the
issue, and record the failure. Cross-dispatcher atomic claiming remains a server
capability gap; never compensate by running multiple writers.

When using an in-process subagent instead of a Multica daemon agent, the central
dispatcher must first set `in_progress` and post a direct-control owner/lock
comment. Do not assign a daemon agent as well.

## Worker Contract

Give a worker exactly one FAN ID per run. It must:

- verify issue status, assignee, comments, and locked paths before edits;
- use a clean worktree from fresh `origin/dev`;
- read the relevant UI/asset/animation/balance skill;
- update docs and run the required synchronous quality gates;
- commit and push task-owned files with the FAN key;
- post exact SHA, commands/results, residual risk, and cleanup evidence;
- move implementation to `in_review`; move QA-passed work to `done`;
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
