---
name: fantasydisk-onboarding
description: Master onboarding for any new AI agent OR human joining FantasyDisk. Invoke when first connecting to the FantasyDisk repository, starting work on the project, or unsure how work is created, owned, branched, and synced. Teaches the JIRA-ONLY rule, branch model, mandatory skills, and the pre-work checklist.
---

# FantasyDisk Onboarding

Read this before touching anything. It is the fast startup protocol — it does not replace `AGENTS.md`, Jira, task files, or the process docs, it points you at them in the right order.

## What is FantasyDisk

- A **Godot 4 top-down roguelike**. Repo root is the Godot project.
- **All development is done by AI agents.** The user does not hand-write code and expects autonomous execution: understand the task, check owners, do your part, test, document, sync Jira + GitHub.
- GitHub: **https://github.com/FomaBy/FantasyDisk** (private).

## Branches & Versions

- `main` = **release line only**. No ordinary development, no direct pushes (protected by convention/agreement, not just config).
- `dev` = **active working branch** (the default — work here).
- Tags `vX.Y.Z` = released versions.
- Never switch branches or run destructive git commands without explicit permission. No force push. Never rewrite another owner's WIP. Don't commit `.godot/`, caches, or secrets.

## THE MAIN RULE: JIRA-ONLY

**Jira (project `SCRUM`) is the single source of truth** for tasks, status, owner, and sprint state. Since 2026-06-27:

- Every task is **created in Jira and taken from Jira**.
- `docs/tasks/*.md` and `docs/process/task_board.md` are **mirrors / cache / dashboard — NOT the source**. They follow Jira, never lead it.
- New task → Jira issue first, local `.md`/board mirror second.
- Took a task → Jira `in_progress` + comment, then mirror.
- Finished → Jira status/comment, then mirror `done`/`review`.
- QA PASSED → move Jira to «Готово».
- Blocked → Jira comment/status with the precise reason.
- If sources disagree, **do not guess** — Jira issue/comments/assignee/labels win; reconcile the mirror, or record a blocked/handoff note.
- Never store a Jira token in the repo (Keychain/env/secrets only).

## Mandatory Project Skills

If a task falls inside a skill's domain, the skill is **mandatory** — no manual fallback pipelines.

| Domain | Skill |
| --- | --- |
| UI screens / HUD / menus / frames / responsive layout | `fantasydisk-ui-director` |
| Raster assets: sprites, icons, frames, buttons, VFX PNG | `fantasydisk-asset-generator` |
| Character / enemy / boss animation, SpriteFrames, rigs | `fantasydisk-animation-director` |
| Class / weapon balance | `fantasydisk-class-balance-director` |
| Release build / changelog / publish | `fantasydisk-release-director` |
| Create a Jira ticket | `jira-create-ticket` |
| Move/transition child issues in bulk | `jira-move-children` |
| Turn release notes into change requests | `change-request-from-release-notes` |
| Customer-facing release notes from branches | `customer-release-notes-from-branches` |

Hard rules baked into the skills: UI gets an OpenAI mockup/spec with safe content zones before Godot work; assets use transparent background + D&D/Dark-Fantasy-Dragon style, source in `docs/design/references/`, runtime under `assets/`; animated entities need `move/walk` 5+ frames and `attack_primary` 5+ frames; balance compares three-weapon kits across solo / AoE / survivability.

## Onboarding in One Line

```bash
bash scripts/onboard.sh
```

## Checklist Before You Work

Never start until you have confirmed:

1. **Branch = `dev`** (`git branch --show-current`).
2. **Pull / sync** — `git fetch origin --prune`, check you are not behind `origin/dev`, working tree state is known.
3. **Jira issue** — find it; check status, comments, **assignee/owner**, labels, sprint. The issue must be **explicitly assigned to you**. If it looks role-appropriate but has no owner/dispatch, **wait for PM/dispatcher — do not self-select.**
4. **Locked paths** — read `Контур`, `Owner`, `Thread/Worker`, `Locked paths` on the issue + mirror; make sure your files/assets/screens don't overlap another active owner.
5. **Dirty worktree** — check for uncommitted changes that overlap your task or another owner's lane.

Then: set Jira `in_progress` + comment, sync the mirror, and only then change code/assets/docs. When done: test, update docs + mirrors, set Jira `done`/`review`, sync, commit/push (or open a PR). Leave a clean tree or a synced blocker. A task is fully closed **only after `## QA-Вердикт: PASSED`**.

## One Task = One Owner = One Lane

The core concurrency rule: **one task = one owner = one execution lane = one set of locked paths.** Multiple AIs (Codex, Claude, DeepSeek, Gemini, any other) may run in parallel **only** on different tasks with non-overlapping files. Don't route one task to two agents; don't edit files locked by another lane; don't run a review/fix in parallel with the implementation it reviews.

## Read Order (when you need depth)

`AGENTS.md` → `docs/process/ai_agent_memorandum.md` (the full version of this protocol) → `docs/process/task_board.md` → `docs/process/agent_role_boundaries_and_handoffs.md` → `docs/process/pm_workflow.md` → `docs/process/jira_sync.md` → `docs/process/versioning_and_branching.md` → relevant `docs/tasks/*.md` → `docs/design/*.md` for gameplay/balance/UI/content.
