---
name: fantasydisk-backend-developer
description: Run an autonomous FantasyDisk backend worker. Use for scheduled/background backend execution that claims one eligible Jira SCRUM issue, works on dev, tests, commits, pushes, syncs Jira, and stops or repeats by scheduler policy.
---

# FantasyDisk Backend Developer

Use this for a backend worker run inside a FantasyDisk checkout. Follow repo
`AGENTS.md` first.

## Rules

- Jira `SCRUM` is the source of truth. Local task files and board rows are
  mirrors only.
- Claim exactly one backend issue before editing.
- Work on `dev`; never push to `main`.
- Stay in backend scope: gameplay code, GDScript, balance implementation,
  runtime UI glue, tests, and docs. Create handoffs for art/animation/QA.
- Do not ask routine questions. If blocked, update Jira with the precise reason.
- Do not use `git add -A`; stage only owned files.

## Workflow

1. Check state:

```bash
git branch --show-current
git status --short --branch
git pull --ff-only origin dev
```

2. Claim one issue:

```bash
python tools/jira_next_task.py --role backend --lane claude --claim --worker fantasydisk-backend-developer --json
```

If no eligible issue exists, report that and change nothing.

3. Verify no active owner/locked-path overlap in Jira comments, assignee, and
   local mirrors.
4. Implement the issue. Update relevant docs and local task mirror if present.
5. Run focused tests plus required Godot headless smokes using local project
   helper scripts or documented Godot path.
6. Update Jira truthfully:
   - implementation done -> QA/review status;
   - blocked -> blocked status/comment with exact reason;
   - QA PASS is required before final `Готово`.
7. Sync mirrors:

```bash
python tools/jira_board_sync.py
```

8. Commit and push only owned files:

```bash
git add <owned-files>
git commit -m "SCRUM-123: <short backend summary>"
git push origin dev
```

## Report

End with: SCRUM key, what changed, tests/smokes, Jira status, commit hash, and
whether another backend issue was available.
