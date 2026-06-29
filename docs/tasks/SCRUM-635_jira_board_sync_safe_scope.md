# SCRUM-635: Safe Scoped Jira Board Sync Helper

Статус: done
Контур: Codex
Owner: process/backend jira-sync-fix-worker
Thread: jira-sync-fix-worker
Locked paths: tools/jira_board_sync.py, docs/process/jira_sync.md, docs/tasks/SCRUM-635_jira_board_sync_safe_scope.md, tests/test_jira_board_sync.py
Jira: SCRUM-635

## Context

`python tools/jira_board_sync.py --no-create` was unsafe for autonomous workers:
it scanned every `docs/tasks/*.md`, could move unrelated old mirrored Jira issues,
and aborted the whole run when one mapped issue was inaccessible, such as an HTTP
404 on SCRUM-327.

## Acceptance Criteria

- `--no-create` without explicit scope must not move broad unrelated statuses.
- Workers can safely sync their own issue with `--issue SCRUM-<key>` or
  `--task docs/tasks/<file>.md`.
- Inaccessible Jira issues are logged and skipped, not fatal for the whole sync.
- Behavior is covered by mocked unit tests or deterministic dry-run evidence.

## Result

Implemented:

- `--no-create` without `--task`/`--issue` is guarded: it logs
  `SAFE_GUARD`, skips broad moves, skips description rewrites, and does not add
  new local map links.
- Workers can scope sync with `--issue SCRUM-123` or `--task <path>`.
- Jira 404/inaccessible errors log `SKIP_INACCESSIBLE` and skip that item
  instead of aborting the whole helper.
- CLI entrypoint and imported `main()` both use the safe implementation.

Verification:

- `python -m unittest tests.test_jira_board_sync` PASS.
- `python tools\jira_board_sync.py --dry-run --issue SCRUM-635` scanned 1 task,
  proposed only SCRUM-635, and performed no live Jira writes.

Safe usage:

```bash
python tools\jira_board_sync.py --no-create --issue SCRUM-635
python tools\jira_board_sync.py --no-create --task docs/tasks/SCRUM-635_jira_board_sync_safe_scope.md
```
