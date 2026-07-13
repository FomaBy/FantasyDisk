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
- Work exactly one backend Multica issue before editing.
- Work on `dev`; never push to `main`.
- Stay in backend scope: gameplay code, GDScript, balance implementation,
  runtime UI glue, tests, and docs. Create handoffs for art/animation/QA.
- Do not ask routine questions. If blocked, update the Multica issue with the
  precise reason.
- Do not use `git add -A`; stage only owned files.

## Workflow

1. Check state:

```bash
git branch --show-current
git status --short --branch
git pull --ff-only origin dev
```

2. Take one backend issue (the issue assigned to this worker, or an eligible
   unassigned backend `FAN-*` issue). Claim it and record ownership:

```bash
multica issue get <FAN-issue-id> --output json
multica issue status <FAN-issue-id> in_progress
```

If no eligible issue exists, report that and change nothing.

3. Verify no active owner/locked-path overlap in the Multica issue comments,
   assignee, and local mirrors before editing.
4. Implement the issue. Update relevant docs and local task mirror if present.
5. Run focused tests plus required Godot headless smokes using local project
   helper scripts or documented Godot path.
6. Commit and push only owned files:

```bash
git add <owned-files>
git commit -m "FAN-123: <short backend summary>"
git push origin dev
```

7. Update the Multica issue truthfully:
   - implementation done -> `in_review` (QA gate);
   - blocked -> `blocked` with an exact-reason comment;
   - QA PASSED is required before an issue becomes `done`.

## Report

End with: FAN issue id, what changed, tests/smokes, Multica status, commit hash,
and whether another backend issue was available.
