# Codex Multi-Agent Operating Playbook

Updated: 2026-06-28

This document is a portable handoff for another Codex instance. Give it this file
together with `AGENTS.md` when you want it to coordinate FantasyDisk work the
same way: Jira-first, claim-first, multi-agent, no duplicate owners, clean
verification, and explicit Git/Jira closure.

## One-Line Rule

Use Jira as the source of truth, assign exactly one owner per task, isolate
parallel agents by role and locked paths, require claim comments before work,
and never let a task count as done until Jira, local mirrors, tests, docs, and
Git all reflect reality.

## Startup Checklist

Before dispatching agents or taking work:

1. Read `AGENTS.md`.
2. Read these process docs:
   - `docs/process/ai_agent_memorandum.md`
   - `docs/process/jira_sync.md`
   - `docs/process/agent_role_boundaries_and_handoffs.md`
   - `docs/process/pm_workflow.md`
   - `docs/process/qa_protocol.md`
   - `docs/process/versioning_and_branching.md`
3. Confirm branch and dirty state:
   ```bash
   git branch --show-current
   git status --short --branch
   ```
4. Confirm live Jira state, not only local mirrors.
5. Treat `docs/tasks/*.md` and `docs/process/task_board.md` as mirrors/specs, not
   the authoritative queue.
6. Do not ask the user for routine approvals. Make a reasonable in-scope
   decision, implement, test, document, sync Jira, commit, and push.

## Live Jira Probes

Use helpers first:

```bash
python tools/jira_next_task.py --role backend --lane codex --json
python tools/jira_next_task.py --role design --lane codex --required-label design-main --json
python tools/jira_next_task.py --role design --lane codex --required-label designer2 --json
python tools/jira_next_task.py --role animator --lane codex --json
python tools/jira_next_task.py --role qa --lane codex --json
```

For QA in `Kontrol kachestva` / review status:

```bash
set PYTHONIOENCODING=utf-8
python tools/jira_qa_next.py --json
```

On Windows, `jira_board_sync.py` may fail if it imports `fcntl`. If that happens,
record the failure as an environment blocker and keep Jira comments/statuses
accurate through the available Jira REST/helper flow.

## Dispatch Rules

Dispatch only if all are true:

- The Jira issue is in the active sprint or is explicitly assigned for the
  current run.
- It is not `Done`, not `blocked`, not `hold`, and not review-gated unless the
  agent is QA.
- Labels match the role/lane, or the dispatcher explicitly assigns the issue.
- There is no active owner, recent claim/comment, or overlapping locked path.
- The task has a clear owner and write scope.

Skip or leave untouched:

- `blocked`, `hold`, or `[HOLD]` issues.
- Issues already `In Progress` unless you are resuming the same owner/thread.
- Generic design issues without `design-main` or `designer2` when the design pool
  is split.
- UI redesign tasks with overlapping screens, frame kits, or `scripts/ui_screens.gd`
  unless they are explicitly assigned and isolated.
- Any issue whose locked paths overlap dirty local WIP from another worker.

## Agent Types To Spawn

Use workers, not explorers, when the user asks to "give tasks to agents" or
"make agents work".

Typical lanes:

- Back-end: gameplay, GDScript, balance, runtime UI integration, tests, docs.
- Design main: full-screen mockups, major visual direction, large source packs.
- Designer 2: isolated asset packs, QA visual fixes, icons, small source sheets.
- Animator: SpriteFrames, rigs, animation manifests, motion states.
- QA: acceptance review only; QA does not fix code/art in the same task.

## Prompt Template: Implementation Worker

```text
You are an autonomous <ROLE> agent for FantasyDisk.

Work on exactly <SCRUM-KEY>: <SUMMARY>.

Repository: <PATH>. If the checkout is dirty or overlaps another worker, create
a separate clean clone/worktree before editing.

First read AGENTS.md and required process docs. Then inspect live Jira
<SCRUM-KEY>: status, labels, comments, assignee, owner, and locked paths.
Add a Jira claim comment:
Claimed by <worker-id> (dispatcher explicit) - role=<role>, lane=<lane>, locked paths=<paths>.
Transition to In Progress if available.

Scope:
- Do only <ROLE> work.
- Do not touch unrelated systems.
- Do not touch another role's work; create a handoff if needed.
- Do not ask the user for routine approvals.
- Do not use destructive Git.
- Do not use git add -A; stage explicit files only.

Required output:
- Implement the task.
- Run focused tests and required smoke tests.
- Update docs/tasks mirror and relevant docs/design docs.
- Update Jira with result/status.
- Move to QA/review status, not final Done unless the workflow explicitly says so.
- Commit and push explicit files.

Final report:
Jira key, status, changed files, tests and results, docs updated, Jira sync,
commit/push state, blockers or handoffs.
```

## Prompt Template: QA Worker

```text
You are an autonomous QA agent for FantasyDisk.

QA exactly <SCRUM-KEY>: <SUMMARY>.

Repository: <PATH>. If the checkout is dirty or ambiguous, create a separate
clean clone/worktree and verify from clean HEAD/dev.

First read AGENTS.md, jira_sync.md, qa_protocol.md, and the task mirror if it
exists. Inspect live Jira <SCRUM-KEY> and add:
QA claimed by <worker-id>.

QA rules:
- Do not fix code/art/animation in this task.
- Verify acceptance criteria and regression risk.
- Run the focused tests named by the ticket; run broader smoke only when the
  result is meaningful.
- If PASS: write QA verdict to mirror, comment Jira, transition to Done/Gotovo
  if allowed by workflow.
- If FAIL: comment Jira with exact repro, expected/actual, evidence, and create
  or request a role-specific bug/handoff issue.
- Commit and push QA verdict docs if changed.

Final report:
Verdict, evidence, commands, changed files, Jira status, blockers.
```

## Clean Clone / Worktree Practice

Parallel agents should not share one dirty checkout for implementation or QA.
If several workers run at once, prefer separate directories:

```bash
git clone <repo-url> <worker-dir>
cd <worker-dir>
git checkout dev
git pull --ff-only origin dev
```

Use a clean clone especially for QA, because unrelated dirty files can turn a
good test into useless evidence.

## Collision Rules

Hard conflict signals:

- Same Jira issue.
- Same screen, frame kit, character set, source pack, or asset directory.
- Same hot files, especially:
  - `scripts/ui_screens.gd`
  - `scripts/progression_data*.gd`
  - `scripts/player.gd`
  - shared runtime smoke tests
  - active UI frame/source directories
- Existing Jira claim/comment by another worker.
- Local task mirror says `in_progress`, has an owner, or has a recent dispatch.

If there is a conflict, do not start parallel work. Leave a Jira/comment note or
mark blocked only if the task is genuinely blocked.

## Skills

Mandatory skills by task type:

- UI screens, HUD, menus, frames: `fantasydisk-ui-director`
- Raster assets, sprites, icons, frames, VFX PNG: `fantasydisk-asset-generator`
- Posters/infographics/UI images with text zones: `content-zone-image-compositor`
- Character/enemy/boss animation: `fantasydisk-animation-director`
- Class/weapon balance: `fantasydisk-class-balance-director`
- Release: `fantasydisk-release-director`

Read the selected skill's `SKILL.md` completely before acting.

## QA Dispatch Pattern

When there is no implementation work eligible for `codex`, check QA. If multiple
issues are in `Kontrol kachestva`, spawn one QA worker per independent issue,
with explicit issue keys. Do not let every QA worker pull the same first issue.

Good QA worker split:

```text
qa-worker-a -> SCRUM-602
qa-worker-b -> SCRUM-598
qa-worker-c -> SCRUM-605
qa-worker-d -> SCRUM-623
```

Each QA worker must claim in Jira before testing.

## Implementation Dispatch Pattern

When helpers return `task:null`, inspect the live active sprint for eligible
issues. Some issues may lack a role label but be dispatcher-assignable. Assign
only if the scope is clear and non-overlapping.

Safe examples:

- Small combat feedback task that does not touch UI redesign.
- Isolated Codex/backend tracking feature with its own data/tests.
- Focused balance gate with one data file and one test.

Unsafe examples:

- Generic UI redesign task while many UI screens are already in progress.
- Blocked balance chain whose prerequisite has not passed QA.
- Design task without design-main/designer2 label.

## Status Flow

Implementation:

```text
To Do -> In Progress -> Kontrol kachestva / review -> QA -> Done
```

QA:

```text
Kontrol kachestva -> PASSED -> Done
Kontrol kachestva -> FAILED -> bug/handoff + return/reopen as appropriate
```

Never close a task only because code exists locally. Done requires Jira, mirrors,
tests, docs, and Git to agree.

## Git Rules

Before edits:

```bash
git status --short --branch
git fetch origin --prune
```

When committing:

```bash
git add <explicit-file-1> <explicit-file-2>
git status --short
git commit -m "<type>: <short summary>"
git push origin dev
```

Do not:

- `git add -A`
- `git reset --hard`
- force push
- stage `.godot/`, secrets, caches, or unrelated dirty files
- revert user/other-agent work unless explicitly instructed

If `dev` moved, rebase or pull carefully without swallowing unrelated dirty WIP.

## Final Coordinator Report

After dispatching, report:

- Which agents were started.
- Agent ids/nicknames if available.
- Jira keys and role.
- What was skipped and why.
- Any environment blocker.

Example:

```text
Started:
- QA SCRUM-602 -> <agent id>
- QA SCRUM-598 -> <agent id>
- Back-end SCRUM-613 -> <agent id>

Skipped:
- SCRUM-496: hold
- SCRUM-532: already In Progress
- SCRUM-583: generic design UI task without design-main/designer2 split
```

## Bootstrap Prompt For Another Codex

Give another Codex this prompt:

```text
You are coordinating FantasyDisk agents.

Read AGENTS.md and docs/process/codex_multi_agent_operating_playbook.md first.
Then use live Jira as the source of truth, not local task_board alone.

Goal:
- Audit active sprint.
- Spawn/dispatch autonomous Codex agents only for eligible, non-overlapping work.
- Prefer QA workers for issues already in Kontrol kachestva.
- For implementation, claim Jira first, isolate dirty checkouts, run tests,
  update docs, sync Jira, commit and push.
- Do not ask the user routine approvals.
- Do not duplicate owners or touch blocked/hold/foreign-lane tasks.

Return a short report with agent ids, Jira keys, skipped tasks and reasons.
```
