# FAN-3934 — diagnosis of the preserved 4,018-object P3 sample (05:42 decision)

Evidence-only stage; sole write set `evidence/p3-object-budget-rework/hit-tick-name-diagnosis/**`.
No product, test, workflow or threshold byte changed.

## 1. Hypothesis stated BEFORE analysis (per acceptance item 2)

H1: the failing sample's object floor is higher from the first sampled second by an
amount matching one additional distinct enemy-kind full-frame set (measured range
369–449 objects/kind, round-5 `frames_residency.json`), with an unchanged
per-second fluctuation shape — i.e. a workload-composition difference, not an
allocation regression of the naming repair.
H0: the failing sample's floor matches the passing samples' (a repair-introduced
persistent allocation delta).

## 2. Reconciliation of all four submitted P3 samples (unchanged raw files)

| sample | start | min(floor) | mean | peak | first-second enemies | verdict |
|---|---:|---:|---:|---:|---:|---|
| run1 | 3,420 | 3,419 | 3,679 | 3,876 | 8 | PASS |
| run2 | **3,699** | **3,652** | 3,835 | **4,018** | **9** | FAIL (preserved) |
| rerun1 | 3,443 | 3,436 | 3,632 | 3,839 | 8 | PASS |
| rerun2 | 3,278 | 3,253 | 3,440 | 3,610 | 8 | PASS |

All four record identical `candidate_sha 1b934fc557a7`, boss=1 every second,
1 accepted ultimate of 18, orphans 0→0, non-monotonic.

**Finding:** the failing sample is an outlier at the FIRST sampled second, before
any sampled gameplay: +253 to +420 floor versus the other three, and it holds
**nine** initial enemies versus eight. The floor delta sits inside the measured
per-kind frame-set range (369–449). Fluctuation amplitude above floor is
~200–380 in all four samples (similar shape). This is measured evidence
consistent with H1; H0 (a repair allocation delta) is excluded below.

## 3. Repair allocation neutrality (proof, not assertion)

`git diff fff8ba7a..1b934fc5 -- scripts/` is 8 insertions in
`combat_feedback_timeline.gd`, all naming: two `tick.name` assignments and
comments. No node, resource, tween or pool entry is created, retained or freed
differently; the failing and passing samples ran the SAME source `1b934fc557a7`.

## 4. Corrected causal statement

The prior handoff's "known random enemy composition variance" is re-labeled an
**evidenced hypothesis, not proof**: the floor-outlier + extra initial enemy +
per-kind range are consistent measurements, but the raw probe does not record
enemy KINDS, so kind-level composition is **explicitly missing** as an
observation. No seed control exists in the probe (no controlled seed available;
seeds are permitted only in task-owned diagnostics per the 07:35Z·Sep-9 rule).

**Cap position:** random composition does not waive the 4,000 cap. The measured
facts: the same source produces floors 3,253–3,652 depending on setup-time spawn
RNG; the failing composition peaked 4,018. This is a real workload-dependent
budget breach risk on this candidate, not a measurement artifact; whether it is
acceptable is a scope decision, not this stage's.

## 5. Combat smoke / affected-check mapping (source-bound logs)

Previously source-bound (hit-tick-name/, measured source `1b934fc557a7`):
`take_damage_contract_routing` (exit 0), `combat/smoke_contact_feedback` (0),
`runtime_smoke_combat` (0), `p3_feedback_allocation` (0).
Run unchanged this stage for gap closure (this directory, same source):
`combat/smoke_bootstrap` (0), `combat/smoke_death_flow` (0),
`combat/smoke_hud_layout` (0), `combat/smoke_projectile` (0),
`combat/smoke_wave_cap` (0). Remaining identified gap: `combat/smoke_scenarios.gd`
is the shared assertion helper (not a standalone suite; no `tests/combat/` suite
is unexecuted). Broader runtime/presentation/accessibility sets (engineer,
ultimates) were last source-bound to earlier sources and remain QA's widened set
to re-run on any successor.

## 6. Scope decision requested

If the board requires the P3 cap to hold under the observed worst-case setup
composition, the measured levers (unchanged from earlier rounds, none authorized
now): deterministic/representative fixed composition for the contour (probe-side,
QA-owned), deferred per-kind frame residency (production, resource-ownership
change), or further mean reduction. A code change is NOT requested by this
diagnosis; the naming repair itself is allocation-neutral and its four-sample
matrix stands as submitted for fresh QA.
