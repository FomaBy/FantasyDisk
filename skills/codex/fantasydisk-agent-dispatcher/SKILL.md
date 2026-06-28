---
name: fantasydisk-agent-dispatcher
description: Coordinate continuous FantasyDisk multi-agent work from Jira. Use when the user asks to keep agents working, distribute sprint tasks, inspect or restart agents, run QA/backend/design/animator workers, prevent idle time, enforce pull-claim-work-push-sync-clean loops, or manage autonomous Codex subagents for FantasyDisk sprint delivery.
---

# FantasyDisk Agent Dispatcher

Use this skill to run FantasyDisk as a Jira-driven agent conveyor: workers claim one issue, finish it, push it, sync Jira, clean disk, then claim the next eligible issue until the sprint queue is empty or truly blocked.

## Required Context

Before dispatching project work, read the repo `AGENTS.md` and obey its Jira, role-boundary, UI, asset, animation, balance, versioning, autonomy, and disk-cleanup rules. For UI, animation, asset, or balance work, tell workers to read the relevant FantasyDisk domain skill before editing.

Assume the normal repo path is `D:\FantasyDisk`. Do not send workers into a dirty main checkout. Workers must create isolated clean git worktrees from fresh `origin/dev`, usually under `D:\FantasyDisk_agents\`.

## Dispatcher Workflow

1. Check current state:
   - `git -C D:\FantasyDisk fetch origin dev`
   - `git -C D:\FantasyDisk status --short --branch`
   - Set `$env:PYTHONIOENCODING='utf-8'` before Jira helper commands on Windows.
2. Close completed subagents so they do not consume concurrency.
3. Prefer live Jira over local task mirrors. Use current sprint statuses and comments/assignees/locked paths to avoid duplicate work.
4. Spawn workers up to the useful concurrency limit:
   - QA first for `Контроль качества`.
   - Backend/balance next for small bugs and logic work.
   - UI/design next for redesign tasks, with no overlapping screens/assets between workers.
   - Animator/content for animation or sprite tasks, or QA fallback when animation queue is empty.
5. Give every worker a loop prompt, not a one-shot prompt: claim exactly one issue, finish it, push, sync, clean, then claim another.
6. Create or maintain a heartbeat automation when the user wants continuous work beyond the current turn. Prefer a heartbeat attached to the current thread every 10 minutes.

## Worker Contract

Every worker prompt must include:

- Work autonomously; do not ask the user for in-scope confirmations.
- Use a clean worktree from fresh `origin/dev`; never use dirty `D:\FantasyDisk` for task edits.
- Pull/rebase from `origin/dev` before every new issue.
- Claim in Jira before editing: status/comment with owner, thread/worker id, locked files/assets/screens.
- Respect role boundaries and active locked paths. Do not revert others' changes.
- Commit and push each completed issue to `dev` with the `SCRUM-*` key in the commit message.
- Update Jira truthfully. Implementation work normally goes to `Контроль качества`; QA PASS goes to `Готово`; QA RED gets an evidence comment or bug/handoff.
- Run scoped sync only: `python tools\jira_board_sync.py --no-create --issue SCRUM-KEY`.
- Clean owned temp files after every issue: disposable `.godot`, `__pycache__`, logs, generated scratch, temporary worktrees when safe.
- Never commit `.godot`, `source_docs/FantasyDisk_GDD.txt`, `.routine.lock`, unrelated `.import` files, caches, or sidecars.

## Jira Helpers

Use these from a FantasyDisk worktree with `PYTHONIOENCODING=utf-8`:

```powershell
python tools\jira_qa_next.py --json
python tools\jira_next_task.py --role backend --lane codex --allow-unlabeled-lane --claim --worker <worker-id> --json
python tools\jira_next_task.py --role design --lane codex --allow-unlabeled-lane --claim --worker <worker-id> --json
python tools\jira_next_task.py --role animator --lane codex --allow-unlabeled-lane --claim --worker <worker-id> --json
python tools\jira_board_sync.py --no-create --issue SCRUM-KEY
```

If the user explicitly says to ignore stale assignees such as Designer2, workers may take physically free tasks from another lane only after checking live Jira comments, assignee, status, and locked paths for active ownership.

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
- which blockers require a Jira comment or handoff.

Do not claim a task is done until the worker has pushed, synced Jira, and cleaned its own disk usage.
