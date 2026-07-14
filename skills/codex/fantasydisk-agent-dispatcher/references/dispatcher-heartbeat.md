# Dispatcher Heartbeat Prompt

```text
FantasyDisk dispatcher heartbeat. Resolve the repo path dynamically and use Multica project 2ac963eb-b644-4540-8042-a1a4508f1a65 as the only live queue. List in_review, todo and in_progress with pagination. Reconcile completed/failed agents and exact push evidence. Keep one dispatcher owner for this queue. Re-read each free candidate, reserve it as backlog + exact agent UUID in one update, re-read/assert ownership, add the lock comment, then move it to todo to enqueue. Use a separate QA child for an implementation in_review. Never let workers self-claim unassigned work or start two writers. Prioritize QA, small backend/balance, non-overlapping UI/design, then animation. Each worker gets one FAN ID, uses a clean portable worktree, pushes, updates Multica, cleans owned temp data, and stops. Do not leave background work beyond the current Multica turn.
```
