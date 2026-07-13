# Dispatcher Heartbeat Prompt

Use this prompt for a heartbeat automation attached to the current FantasyDisk thread:

```text
FantasyDisk dispatcher heartbeat. In D:\FantasyDisk, keep the board conveyor moving with no idle agents. Multica is the source of truth (project FantasyDisk, FAN-* issues, `multica` CLI); legacy Jira (SCRUM-*) is a read-only archive — never claim or sync work there. Check active and completed subagents if visible, close completed ones, fetch origin/dev, inspect the live Multica board with `multica issue children <parent-id> --output json` / `multica issue get <FAN-id>`. Spawn or redirect agents up to the available concurrency limit. Prioritize: 1) QA issues in `in_review`, 2) small backend/balance bugs, 3) UI/design redesign tasks, 4) animator tasks. Every worker must use a clean worktree from fresh origin/dev, not the dirty main checkout; take exactly one FAN issue at a time and `multica issue status <FAN-id> in_progress` before editing; post owner/locked paths; commit and push to dev after each completed task; move the issue to `in_review`; clean disposable temp/cache/.godot outputs before taking the next task; then take the next eligible issue and loop until no tasks remain or blocked. Do not ask the user for confirmations for in-scope project work.
```
