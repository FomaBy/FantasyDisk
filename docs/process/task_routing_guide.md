# FantasyDisk routing guide

Routing begins in Multica, not in local task files. PM decides the lane from
CUE, scope, risk, acceptance criteria, dependencies, and capability. Qwen
Operations Dispatcher then selects an eligible live worker inside that approved
lane.

## Canonical lanes

| Story Points | Complexity | Developer lane | QA lane |
| --- | --- | --- | --- |
| `1/2/3` | low | Codex Dev Luna | QA Codex Terra |
| `5` | medium | Codex Dev Terra or routed Claude | QA Codex Terra |
| `8` | medium | Codex Dev Terra or routed Claude | QA Codex Sol |
| `13` | high | Fable or Codex Dev Sol | QA Codex Sol |

Current availability, agent IDs, quota, and fallback eligibility are resolved
from live Multica state. Do not hardcode them here. Upward borrowing is allowed
only by workspace policy when native higher-band work is absent; downward
borrowing is forbidden.

## Readiness gate

Before Qwen can see a candidate, PM leaves it unassigned in `backlog` and makes
these agree after re-read:

- description with Story Points, CUE rationale, complexity rationale, routing,
  and acceptance criteria;
- one `SP:N` label and numeric `story_points=N`;
- `estimation_model=CUE/Fibonacci`;
- one `Complexity:<tier>` label and `complexity_tier`;
- resolved dependencies and no conflicting hold;
- `dispatch_ready=true`, `pipeline_status=ready_for_dispatch`,
  `dispatch_kind`, and `dispatch_lane`;
- matching candidate SHA fields for QA.

Use `docs/process/story_points.md` and `docs/process/pm_workflow.md`.

## Discipline routing

- Gameplay/runtime/data/balance/tests: backend developer plus the relevant
  balance or code-quality skill.
- UI/layout/frames: developer with `fantasydisk-ui-director`; backgrounds and
  non-background art follow the generator split in repo `AGENTS.md`.
- Character/monster motion: animation worker with the PixelLab integration
  skill.
- Releases: release-capable developer with `fantasydisk-release-director`.
- Acceptance: independent QA child pinned to the exact pushed candidate SHA.

Locked paths and reviewer independence outrank convenience. Split overlapping
discipline work into independently acceptable children with explicit handoffs.

## Dispatch boundary

Only Qwen performs assignment and `backlog → todo`, using the canonical
workspace dispatcher skill. PM never substitutes a manual launch; workers never
self-claim; QA never selects its own parent. If capacity, quota, dependency,
overlap, or gate evidence is missing, leave the issue unassigned in `backlog`
with the exact waiting condition.
