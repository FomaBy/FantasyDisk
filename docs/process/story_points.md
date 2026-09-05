# Story Points — FantasyDisk

User directive (Sergey Fomin), 2026-07-15. This is mandatory for every new or materially changed actionable FantasyDisk feature, bug, improvement, QA/review, design, animation, balance, release, documentation, process, and handoff issue.

## Model

FantasyDisk uses the relative **CUE** model: **Complexity** is the solution's interacting systems and dependencies; **Uncertainty** is novelty, external dependency, risk, and requirement ambiguity; **Effort** is implementation, assets, documentation, testing, manual verification, and cleanup through Definition of Done.

Story points are neither hours nor a delivery-date promise. Compare the whole task with understood work and choose the next larger size when it falls between values until scope is clarified or decomposed. CUE does not sum by formula: discuss the factors holistically and choose the nearest appropriate size. The Fibonacci scale is **`1, 2, 3, 5, 8, 13`**.

This is the one canonical CUE/Fibonacci contract. A summary, attachment, skill, or template may restate it only without changing its meaning and must link here. Do not publish a second per-factor numeric rubric, a mechanical C/U/E sum, a threshold table, or any other conversion from CUE to SP.

| SP | Relative size and guide |
| --- | --- |
| `1` | Fully understood local change with almost no uncertainty and one simple focused check. |
| `2` | Small known-pattern task with a few related edits, limited verification and documentation. |
| `3` | Bounded task across several files/layers or with one meaningful uncertainty; coordinated tests and documentation are needed. |
| `5` | Material work in one subsystem or a small integration set, with nontrivial edge cases and QA. |
| `8` | Large cross-system/cross-role work with substantial uncertainty, risk, or a platform/visual matrix. |
| `13` | Very large but still one user outcome; review decomposition before dispatch. |

An executable issue above `13 SP` is prohibited: split it into independently testable issues with their own estimates, acceptance criteria, and locked paths. Prefer smaller independently acceptable work whenever a clean boundary exists.

## Required Multica record

The issue description records:

```md
## Complexity estimate

Story points: 5
Label: `SP:5`
Model: CUE / Fibonacci `1, 2, 3, 5, 8, 13`
Rationale: <1–3 sentences covering complexity, uncertainty, and total effort>
```

After a `FAN-*` issue exists, it has exactly one canonical workspace label:

| Story points | Label | Colour |
| --- | --- | --- |
| `1` | `SP:1` | green `#22c55e` |
| `2` | `SP:2` | lime `#84cc16` |
| `3` | `SP:3` | yellow `#eab308` |
| `5` | `SP:5` | orange `#f97316` |
| `8` | `SP:8` | red `#ef4444` |
| `13` | `SP:13` | purple `#a855f7` |

The label is the mandatory reporting dimension. Numeric metadata is a technical mirror for aggregation and validation. Alternative labels such as `story-points-5`, `SP 5`, or `size:5` are prohibited. The description, one `SP:<N>` label, `story_points`, and `estimation_model` must agree.

```bash
multica label list --output json
multica issue label add FAN-123 <uuid-label-SP:5> --output json
multica issue metadata set FAN-123 --key story_points --value 5 --type number
multica issue metadata set FAN-123 --key estimation_model --value "CUE Fibonacci 1,2,3,5,8,13" --type string
multica issue label list FAN-123 --output json
multica issue metadata list FAN-123 --output json
```

## Readiness, reporting, and transition

- PM/the requirements author estimates before assignment, dispatch, or `in_progress`; dispatcher and worker recheck the label, metadata, description, and rationale.
- An unestimated, contradictory, or over-13 issue is not dispatchable. The same rule applies to QA, bug, improvement, and handoff work.
- If scope or acceptance materially changes, re-estimate before work continues: replace the label, update description/metadata, confirm exactly one label, and record old/new value and reason in Multica. Do not retrospectively tune SP merely because implementation progressed.
- Reports group work by the canonical `SP:<N>` label. Historical Jira Archive is read-only and excluded at reporting time, never edited.
- Use SP to assess flow stability, QA first-pass rate, WIP age, and plan/actual delivery. Never rank people, agents, or roles by completed SP or use SP as a personal KPI.
- Existing closed history is not bulk re-estimated. Safe retrospective cleanup uses `tools/story_points_remediation.py` (`inventory`, dry-run plan, apply, audit), preserves rollback snapshots, and never mutates Jira Archive.

## Prohibited uses

Do not convert `1 SP` into fixed hours/days, alter an estimate for a particular worker's experience, lower it to meet a desired date, or mechanically sum unrelated work as a promised date.

## Model sources

- [Atlassian: Fibonacci Story Points](https://www.atlassian.com/agile/project-management/fibonacci-story-points)
- [Scrum.org: Practical Fibonacci](https://www.scrum.org/resources/blog/practical-fibonacci-beginners-guide-relative-sizing)
- [Atlassian: Story points and estimation](https://www.atlassian.com/agile/project-management/estimation)
