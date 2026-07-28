# FantasyDisk role boundaries and handoffs

Updated: 2026-07-26

One issue has one live owner and one non-overlapping locked scope. Roles may
collaborate through independently acceptable child issues, not by editing the
same files or assets concurrently.

## Authority map

| Role | Owns | Must not do |
| --- | --- | --- |
| PM | outcome, CUE/Fibonacci, AC, dependencies, complexity, routing, QA/rework readiness | assign delivery agents, launch lifecycle, implement product scope, perform independent QA |
| Qwen dispatcher | deterministic assignment and lifecycle from PM-ready metadata | estimate, change AC/scope/routing, implement, test, interpret product ambiguity |
| Developer | one assigned implementation scope, tests/docs, pushed candidate evidence | self-claim, dispatch, select QA, review its own work independently |
| QA | one assigned exact-SHA child and independent verdict | self-select parent, repair production code, allocate rework, accept stale SHA |
| Design/UI | visual system, mockup/art package, screen/layout evidence in assigned scope | backend/gameplay changes outside the handoff |
| Animation | motion/source frames, runtime animation integration, animation evidence | unrelated UI/backend ownership |

Capability labels do not override the assigned issue, active locks, reviewer
independence, quota, or capacity.

## Ownership check

Before mutation, read:

- issue status and assignee;
- acceptance criteria, dependencies, metadata, and comments;
- active run/task for the proposed owner;
- locked files, assets, scenes, screens, and resources;
- repository/worktree dirty state;
- exact candidate SHA for review.

If evidence conflicts, do not take or resend the task. Record the exact blocker
or return it to PM readiness; never resolve a race by adding a second owner.

## Discipline boundaries

### Backend/gameplay

Own GDScript/runtime logic, data configuration, balance implementation, tests,
and code-facing docs. Request separate UI art, animation, release, or QA children
when those outcomes can be accepted independently.

### UI/design

Own mockups, content zones, responsive geometry, visual asset source packages,
and visual evidence. Use `fantasydisk-ui-director`. Backgrounds use the built-in
image generator; non-background UI art uses PixelLab. Backend integration may
be a separate child when it changes gameplay/runtime contracts.

### Animation

Own PixelLab animation/source packs, normalization, SpriteFrames, directional
state integration, and animation evidence. Do not replace art direction or
gameplay behavior without an explicit issue scope.

### QA

Own acceptance evidence and verdict for the assigned exact candidate. QA may
create evidence/probes that do not modify production code. Confirmed defects are
reported to PM for bounded estimation and Qwen dispatch.

## Handoff content

A cross-role child or handoff includes:

```text
Parent issue:
Expected result:
In scope:
Out of scope:
Owned/locked paths or assets:
Inputs and exact candidate/source SHA:
Acceptance criteria:
Required evidence/checks:
Dependencies:
Recommended role/lane:
```

The receiving issue has its own CUE/Fibonacci and complexity gate. A local
`docs/tasks/*.md` handoff may preserve a rich spec, but Multica remains the live
owner/status source.

## Completion handoff

Developer evidence:

- Russian summary;
- exact pushed SHA and ancestry;
- changed systems/files;
- commands/results and untested checks;
- docs/evidence;
- residual risk;
- operator mirror state when applicable;
- disk cleanup;
- one PM completion trigger.

QA evidence follows `docs/process/qa_protocol.md`. PM then prepares the next
consistent gate; Qwen performs the mechanical transition. No role selects its
own successor.

## Subagents

The main agent may delegate independent, bounded, non-overlapping investigation,
tests, docs, or implementation surfaces. It must define ownership and
verification, collect all results synchronously, inspect the combined diff, and
remain accountable for the final evidence. Subagents never widen authority or
create competing Multica ownership.
