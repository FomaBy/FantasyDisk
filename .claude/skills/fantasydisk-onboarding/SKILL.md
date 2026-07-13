---
name: fantasydisk-onboarding
description: Compact startup protocol for FantasyDisk agents. Use when first opening the repo or when unsure about Multica tracking, ownership, branches, skills, or QA flow.
---

# FantasyDisk Onboarding

Read `AGENTS.md` first. It is intentionally short and points to deeper docs only
when needed.

## Essentials

- Godot 4 project. Work on `dev`; `main` is release/stable.
- **Multica is the task/status/owner source of truth** — workspace `FantasyDisk`,
  project `FantasyDisk`, issues `FAN-*`, driven via the `multica` CLI. Legacy Jira
  (`SCRUM-*`) is a read-only historical archive; never claim or sync work there
  (see `docs/process/jira_to_multica_cutover.md`).
- `docs/tasks/*.md` and `docs/process/task_board.md` are mirrors/evidence.
- One task = one owner = one lane = one locked-path set.
- Do not edit files locked by another active owner.
- In-scope work is pre-approved; do not ask routine approval.

## Before Work

```bash
git branch --show-current
git status --short --branch
multica issue get <FAN-issue-id> --output json
```

You work the Multica issue assigned to you (or an eligible unassigned one). Claim
by moving it to `in_progress` and posting a start comment with owner/lane/locked
paths:

```bash
multica issue status <FAN-issue-id> in_progress
```

Check `multica issue comment list <id> --recent 10` for the latest owner/handoff
context before editing, and mirror status locally if a task `.md` exists.

## Mandatory Skills

- UI/layout/frames: `fantasydisk-ui-director`.
- Raster assets/icons/sprites/VFX: `fantasydisk-asset-generator`.
- Animation/rigs: `fantasydisk-animation-director`.
- Class/weapon balance: `fantasydisk-class-balance-director`.
- Release: `fantasydisk-release-director`.

## Finish

Run focused tests/smokes, update docs/mirrors, push owned files to `origin/dev`,
comment the Multica issue, and move it to `in_review` (QA gate). QA PASSED is
required before an issue becomes `done`.
