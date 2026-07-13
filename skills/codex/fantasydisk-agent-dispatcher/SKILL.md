---
name: fantasydisk-agent-dispatcher
description: Coordinate continuous FantasyDisk multi-agent work from Multica. Use when the user asks to keep agents working, distribute board tasks, inspect or restart agents, run QA/backend/design/animator workers, prevent idle time, enforce pull-claim-work-push-update-clean loops, or manage autonomous Codex subagents for FantasyDisk delivery.
---

# FantasyDisk Agent Dispatcher

Use this skill to run FantasyDisk as a Multica-driven agent conveyor: workers take one issue, finish it, push it, update the Multica issue, clean disk, then take the next eligible issue until the board queue is empty or truly blocked.

**Multica is the source of truth** — workspace/project `FantasyDisk`, issues `FAN-*`, driven via the `multica` CLI. Legacy Jira (`SCRUM-*`) is a read-only historical archive; never claim or sync work there (see `docs/process/jira_to_multica_cutover.md`).

## Required Context

Before dispatching project work, read the repo `AGENTS.md` and obey its Multica-tracking, role-boundary, UI, asset, animation, balance, versioning, autonomy, and disk-cleanup rules. For UI, animation, asset, or balance work, tell workers to read the relevant FantasyDisk domain skill before editing.

Assume the normal repo path is `D:\FantasyDisk`. Do not send workers into a dirty main checkout. Workers must create isolated clean git worktrees from fresh `origin/dev`, usually under `D:\FantasyDisk_agents\`.

## Dispatcher Workflow

1. Check current state:
   - `git -C D:\FantasyDisk fetch origin dev`
   - `git -C D:\FantasyDisk status --short --branch`
   - `multica issue children <parent-id> --output json` (or `multica issue get <id>`) to read the live board.
2. Close completed subagents so they do not consume concurrency.
3. Prefer the live Multica board over local task mirrors. Use current statuses and comments/assignees/locked paths to avoid duplicate work.
4. Spawn workers up to the useful concurrency limit:
   - QA first for issues in `in_review`.
   - Backend/balance next for small bugs and logic work.
   - UI/design next for redesign tasks, with no overlapping screens/assets between workers.
   - Animator/content for animation or sprite tasks, or QA fallback when animation queue is empty.
5. Give every worker a loop prompt, not a one-shot prompt: take exactly one issue, finish it, push, update the Multica issue, clean, then take another.
6. Create or maintain a heartbeat automation when the user wants continuous work beyond the current turn. Prefer a heartbeat attached to the current thread every 10 minutes.

## Worker Contract

Every worker prompt must include:

- Work autonomously; do not ask the user for in-scope confirmations.
- Use a clean worktree from fresh `origin/dev`; never use dirty `D:\FantasyDisk` for task edits.
- Pull/rebase from `origin/dev` before every new issue.
- Claim in Multica before editing: `multica issue status <FAN-id> in_progress` plus a start comment with owner, thread/worker id, locked files/assets/screens.
- Respect role boundaries and active locked paths. Do not revert others' changes.
- Commit and push each completed issue to `dev` with the `FAN-*` key in the commit message.
- Update the Multica issue truthfully. Implementation work normally goes to `in_review` (QA gate); QA PASSED moves it to `done`; QA RED gets an evidence comment or bug/handoff.
- Clean owned temp files after every issue: disposable `.godot`, `__pycache__`, logs, generated scratch, temporary worktrees when safe.
- Never commit `.godot`, `source_docs/FantasyDisk_GDD.txt`, `.routine.lock`, unrelated `.import` files, caches, or sidecars.

## Multica Helpers

Use these from a FantasyDisk worktree:

```bash
multica issue get <FAN-id> --output json
multica issue children <parent-id> --output json
multica issue status <FAN-id> in_progress
multica issue comment add <FAN-id> --content-file ./reply.md
multica issue status <FAN-id> in_review
```

If the user explicitly says to ignore stale assignees such as Designer2, workers may take physically free tasks from another lane only after checking live Multica issue comments, assignee, status, and locked paths for active ownership.

## Reference Prompts

Load only the reference needed for the worker type you are spawning:

- `references/dispatcher-heartbeat.md` for recurring heartbeat prompt text.
- `references/qa-loop.md` for QA workers.
- `references/backend-loop.md` for backend or balance workers.
- `references/design-loop.md` for UI/design workers.
- `references/animator-loop.md` for animation/content workers.

## Reporting

When reporting status to the user, keep it operational:

- which agents are running,
- which lanes they cover,
- whether any failed to start,
- what automation exists,
- which blockers require a Multica comment or handoff.

Do not claim a task is done until the worker has pushed, updated the Multica issue, and cleaned its own disk usage.
