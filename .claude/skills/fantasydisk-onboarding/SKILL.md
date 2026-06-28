---
name: fantasydisk-onboarding
description: Compact startup protocol for FantasyDisk agents. Use when first opening the repo or when unsure about Jira, ownership, branches, skills, or QA flow.
---

# FantasyDisk Onboarding

Read `AGENTS.md` first. It is intentionally short and points to deeper docs only
when needed.

## Essentials

- Godot 4 project. Work on `dev`; `main` is release/stable.
- Jira `SCRUM` is the task/status/owner source of truth.
- `docs/tasks/*.md` and `docs/process/task_board.md` are mirrors/evidence.
- One task = one owner = one lane = one locked-path set.
- Do not edit files locked by another active owner.
- In-scope work is pre-approved; do not ask routine approval.

## Before Work

```bash
git branch --show-current
git status --short --branch
python tools/jira_next_task.py --role <role> --lane <codex|claude|otherai> --json
```

Claim before edits:

```bash
python tools/jira_next_task.py --role <role> --lane <lane> --claim --worker <id> --json
```

Then update Jira with owner/thread/locked paths, and mirror locally if present.

## Mandatory Skills

- UI/layout/frames: `fantasydisk-ui-director`.
- Raster assets/icons/sprites/VFX: `fantasydisk-asset-generator`.
- Animation/rigs: `fantasydisk-animation-director`.
- Class/weapon balance: `fantasydisk-class-balance-director`.
- Release: `fantasydisk-release-director`.

## Finish

Run focused tests/smokes, update docs/mirrors, comment Jira, move to QA/review
or done as workflow allows. QA PASSED is required for final `Готово`.
