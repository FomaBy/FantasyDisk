# FantasyDisk PM workflow

Updated: 2026-07-26

PM owns professional readiness and policy. PM does not assign delivery workers
or launch dev/QA. The canonical dispatcher in
`docs/process/dispatcher-authority.md` alone performs mechanical allocation
from PM-prepared metadata.

Use `docs/process/story_points.md` for the complete CUE/Fibonacci rubric and the
bound `multica-workspace-governance` references for the server transaction.

## 1. Define the result

Read issue description, comments, dependencies, related work, current
repository behavior, and relevant specs. State:

- user or technical outcome;
- in-scope and out-of-scope boundaries;
- verifiable acceptance criteria;
- dependencies and locked resources;
- required documentation/evidence;
- whether independent QA is required and what it must prove.

Research routine technical uncertainty. Ask Sergey only for unresolved
security/privacy/access/secret risk or a genuinely irreversible product
decision with no safe default.

## 2. Estimate and decompose

Judge Complexity, Uncertainty, and Effort holistically. CUE is not an additive formula.
Do not translate Story Points into time or score the factors independently.

Allowed Story Points are `1, 2, 3, 5, 8, 13`. Prefer independently acceptable
`1–5` SP tasks. Challenge `8/13`; work above `13` must be decomposed.

For each delivery task record:

```text
Story points: <N>
Estimation model: CUE / Fibonacci
CUE rationale: <brief>
Complexity tier: low|medium|high
Complexity rationale: <brief>
Routing lane: <developer and QA pool>
Acceptance criteria:
- <observable result>
```

Coordination umbrellas estimate coordination only, set
`work_type=coordination_umbrella`, and list independently estimated children.

## 3. Write and verify the gate

Keep the task unassigned in `backlog`. Make these agree:

- description Story Points and CUE model;
- exactly one `SP:<N>` label;
- numeric `story_points=<N>`;
- `estimation_model=CUE/Fibonacci`;
- description complexity tier/rationale;
- exactly one `Complexity:<tier>` label;
- `complexity_tier=<tier>`;
- routing, dependencies, and acceptance criteria.

Re-read description, labels, metadata, owner, status, comments, dependencies,
and children. Any mismatch leaves the issue unassigned in `backlog` with
`dispatch_ready=false` and an exact unblock condition.

## 4. Select the lane

Canonical native bands:

- `1/2/3`: low developer; QA Terra.
- `5`: medium developer; QA Terra.
- `8`: medium developer; QA Sol.
- `13`: high developer; QA Sol.

Resolve exact current agents, quota, and capacity from live Multica state.
Upward borrowing is allowed only by workspace policy when native higher-band
work is absent; never borrow downward.

## 5. Pre-stage lifecycle

Before implementation handoff, record the expected independent same-card QA
lane and exact-candidate handoff fields. QA starts only after the developer
publishes an immutable candidate and PM admits it under the shared guard.

For a failed or inconclusive verdict, define a bounded defect/rework issue with
reproduction, expected/actual behavior, evidence, candidate SHA, scope,
acceptance criteria, and its own estimation. Do not send ambiguous “fix QA”
work to the canonical dispatcher.

## 6. Hand off to the canonical dispatcher

On a ready unassigned `backlog` target, set:

```text
pipeline_status=ready_for_dispatch
dispatch_ready=true
dispatch_kind=implementation|qa
dispatch_lane=dev_low|dev_medium|dev_high|qa_low|qa_high
dispatch_target_agent_id=<optional explicit policy target>
dispatch_candidate_sha=<required exact SHA for QA>
```

Clear `waiting_on` only after the dependency is proven satisfied. Re-read the
entire gate. The canonical dispatcher then chooses an eligible worker and
performs the only allowed launch sequence.

PM must not substitute:

- direct assignment;
- `backlog → todo|in_progress|in_review`;
- agent/squad mention;
- rerun;
- manual autopilot trigger;
- a second launch mechanism.

## 7. Supervise evidence

On a completion trigger:

1. Wait for the source run to be terminal.
2. Verify exact pushed SHA, ancestry, checks, documentation, cleanup, and live
   capacity/overlap.
3. Prepare the pre-staged QA child or next bounded stage.
4. Hand the consistent gate to the canonical dispatcher.

Supervise the canonical dispatcher for duplicate runs, gate bypass, stale
capacity, quota scope, reviewer conflicts, and lifecycle mismatch. Fix
policy/configuration—not product scope—when it violates the deterministic
contract.

## Communication

Start Multica comments with a concise plain-language summary, then give technical
fields. Keep agent IDs, quota state, leases, reset times, incident history, and
candidate SHA in live records rather than durable Markdown.
