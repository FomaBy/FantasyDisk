# Dispatcher Heartbeat Prompt

Use this prompt for a heartbeat automation attached to the current FantasyDisk thread:

```text
FantasyDisk dispatcher heartbeat. In D:\FantasyDisk, keep the sprint conveyor moving with no idle agents. Check active and completed subagents if visible, close completed ones, fetch origin/dev, inspect Jira current sprint using PYTHONIOENCODING=utf-8 and tools\jira_qa_next.py / tools\jira_next_task.py. Spawn or redirect agents up to the available concurrency limit. Prioritize: 1) Jira QA in Контроль качества, 2) small backend/balance bugs, 3) UI/design redesign tasks, 4) animator tasks. Every worker must use a clean worktree from fresh origin/dev, not the dirty main checkout; claim exactly one Jira issue at a time before editing; post owner/locked paths; commit and push to dev after each completed task; update Jira; run scoped sync only with tools\jira_board_sync.py --no-create --issue SCRUM-KEY; clean disposable temp/cache/.godot outputs before taking the next task; then claim the next eligible issue and loop until no tasks remain or blocked. Do not ask the user for confirmations for in-scope project work.
```
