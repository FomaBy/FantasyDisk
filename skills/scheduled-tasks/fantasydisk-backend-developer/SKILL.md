---
name: fantasydisk-backend-developer
description: Run an autonomous FantasyDisk backend worker. Use for scheduled/background backend execution that takes one eligible Multica issue (project FantasyDisk, FAN-*), works on dev, tests, commits, pushes, updates the Multica issue, and stops or repeats by scheduler policy.
---

# FantasyDisk Backend Developer

Use this for a backend worker run inside a FantasyDisk checkout. Follow repo
`AGENTS.md` first.

## Rules

- **Multica is the source of truth** — workspace/project `FantasyDisk`, issues
  `FAN-*`, driven via the `multica` CLI. Local task files and board rows are
  mirrors only. Legacy Jira (`SCRUM-*`) is a read-only archive; never claim or
  sync work there (see `docs/process/jira_to_multica_cutover.md`).
- Work exactly the one backend Multica issue assigned to this agent before editing.
- Work on `dev`; never push to `main`.
- Stay in backend scope: gameplay code, GDScript, balance implementation,
  runtime UI glue, tests, and docs. Create handoffs for art/animation/QA.
- Do not ask routine questions. If blocked, update the Multica issue with the
  precise reason.
- Do not use `git add -A`; stage only owned files.

## Workflow

1. Verify issue, assignee, parent/dependencies, comments, active runs and locked
   paths. Work only in the Multica-provided workdir:

```bash
multica issue get <FAN-issue-id> --output json
multica issue comment list <FAN-issue-id> --recent 10 --output json
```

2. Fetch `origin`, safely integrate current `origin/dev`, and stop with a Multica
   blocker if sync or ownership is unsafe:

```bash
git branch --show-current
git status --short --branch
git fetch origin --prune
git pull --ff-only origin dev
```

3. Re-read and require this agent's exact `assignee_id`; never select an
   unassigned issue. Post start/heartbeat evidence through `--content-file`:
   owner, task/run id, workdir/branch, locked paths and next gate. Then move the
   assigned issue to `in_progress`; never claim a second issue.
4. Stay in backend scope: gameplay/runtime code, balance implementation, tests
   and docs. Create Multica child handoffs for Design, Animator or QA work.
5. Run focused checks and `python3 tools/quality_gate.py --profile changed`.
6. Commit only owned files and push the green result to `origin/dev` under repo
   policy.
7. Comment exact SHA, push state, tests, docs, risks and `Disk cleanup:`. Move
   the issue to `in_review`; `done` requires independent QA PASSED.

## Report

End with: FAN issue id, what changed, tests/smokes, Multica status, commit hash,
and whether another backend issue was available.
