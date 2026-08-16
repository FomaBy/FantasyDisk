---
name: fantasydisk-agent-dispatcher
description: Execute or supervise the current Qwen-only mechanical dispatch contract for FantasyDisk Multica issues. Use for readiness handoff, capacity-safe assignment, exact-SHA QA launch, deterministic parent release, or dispatcher reconciliation; PM supplies judgment and Qwen alone performs allocation.
---

# FantasyDisk Agent Dispatcher

Multica project `FantasyDisk` is the live queue. Jira Archive and local task
Markdown are references only.

This skill does not grant general allocation authority:

- PM defines scope, acceptance criteria, CUE/Fibonacci, complexity,
  dependencies, routing, and QA/rework readiness.
- Qwen Operations Dispatcher alone performs mechanical assignment and
  deterministic lifecycle transitions from a complete gate.
- Developers implement one assigned issue.
- QA verifies one assigned exact-SHA child independently.

Use the bound `multica-workspace-governance` skill as the canonical workspace
contract. Load only the needed reference:

- dispatcher cycle: `references/dispatcher-heartbeat.md`
- implementation handoff: `references/backend-loop.md`
- UI/design handoff: `references/design-loop.md`
- animation/content handoff: `references/animator-loop.md`
- QA execution: `references/qa-loop.md`

Never use static worker UUIDs, incident dates, temporary quota statements, or
closed issue exceptions as durable routing policy. Resolve current agents,
registry state, capacity, dependencies, locks, and candidate SHA from Multica
immediately before action.

Fail closed on an inconsistent gate, unresolved dependency, busy/excluded
target, overlap, duplicate dispatcher, stale SHA, reviewer conflict, or command
failure. Launch only an unassigned `backlog` target. Use one launch mechanism
and verify one resulting run. Do not invent product judgment to make a dispatch
happen.
