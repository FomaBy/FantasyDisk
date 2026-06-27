---
name: jira-move-children
description: Move all Jira child issues from one parent issue to another, especially moving tasks/stories/bugs from one Epic to another Epic. Use when the user asks to transfer, reparent, move, or migrate child tickets between Jira issues, epics, parents, initiatives, or other parent-capable Jira items, and wants a safe dry-run, permission check, confirmation gate, and execution via Jira Cloud REST API.
---

# Jira Move Children

## Overview

Use this skill to safely reparent Jira child issues from a source issue to a target issue. The common case is moving all tasks from one Epic to another Epic.

Always prepare and show a dry-run first. Do not perform the move until the user explicitly confirms.

## Workflow

1. Identify the Jira base URL, account email, and API token.
   - Prefer credentials already present in the workspace or user-provided environment variables.
   - Never print API tokens or full Basic auth values.
   - If credentials are unavailable, explain what is missing and ask the user to provide Jira Cloud email and API token.

2. Prepare the script command.
   - Use `scripts/move_jira_children.py`.
   - Run dry-run mode first with `--from SOURCE_KEY --to TARGET_KEY`.
   - Add `--base-url`, `--email`, or `--token` only when they are not discoverable from environment or local credential files.

3. Verify access before execution.
   - Confirm the source issue is readable.
   - Confirm the target issue is readable and is a valid parent candidate.
   - Query all direct child issues with `parent = SOURCE_KEY`.
   - Check update permission by validating a parent update on one child with Jira's `validateOnly=true`; this must not change data.
   - If any check fails, stop and report the short reason plus what permission or credential is needed.

4. Present the dry-run result to the user.
   - Include source key, target key, total children, and the child issue keys.
   - State that execution will update each child issue's `parent` field to the target key.
   - Ask for explicit confirmation before running the script with `--execute`.

5. Execute only after confirmation.
   - Run the same script with `--execute`.
   - Report update status for each issue.
   - Run a final verification query to ensure the source has no remaining direct children and moved issues now have the target parent.

## Script

Use:

```bash
python3 /Users/sergeyfomin/.codex/skills/jira-move-children/scripts/move_jira_children.py --from OPENTUNNEL-12696 --to OPENTUNNEL-12751
```

After confirmation:

```bash
python3 /Users/sergeyfomin/.codex/skills/jira-move-children/scripts/move_jira_children.py --from OPENTUNNEL-12696 --to OPENTUNNEL-12751 --execute
```

The script auto-detects a local `APIToken.rtf` in the current directory when present. It also supports:

- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`
- `--credential-file PATH`

## Output Expectations

For dry-runs, summarize the intended change and ask for confirmation in plain language. For failures, keep the reason short and actionable, for example:

- Missing credentials: provide Jira email and API token, or set `JIRA_EMAIL` and `JIRA_API_TOKEN`.
- Cannot read source/target: grant Browse Projects permission or verify the issue key.
- Cannot update child parent: grant Edit Issues permission for the child issue project and permission to link/use the target parent.

For executed moves, include the moved issue keys and verification result.
