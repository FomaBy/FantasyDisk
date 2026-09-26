# FAN-3934 — frame-residency causal report (06:12 stage)

Evidence-only stage; sole write set `frame-residency-causal/**`; production,
tests, probe, workflow and thresholds untouched. Both instrumented samples ran
the full original P3 scenario via `tools/godot_gate.py` (exclusive admission),
and every result below is preserved — neither census sample breached 4,000, and
no reruns were made to seek a breach.

## Competing hypotheses (stated before execution)

- H1 (composition): the failing sample's higher floor came from one additional
  DISTINCT enemy kind live at setup (a fourth frame set), costing ~369–449.
- H2 (retention): a holder retains frame sets after consumers die, so the floor
  accumulates across the run regardless of kind count.
- H3 (repair regression): the naming repair allocated persistently.

## Controlled lifecycle evidence (lifecycle.json — discriminates H1 vs H2/H3)

| step | objects | marginal |
|---|---:|---:|
| baseline | 1,512 | — |
| first consumer kind A | 1,970 | **+458** (frames + node subtree) |
| second same-kind consumer | 1,978 | **+8** (node only — SHARED frames, instance IDs equal) |
| additional kind B | 2,358 | **+380** |
| release one A (A2 live) | 2,350 | **−8** |
| release LAST A (B live) | 1,970 | **−380** (A's frames freed with last consumer) |
| release last B | 1,590 | **−380** |

**H2 rejected:** release follows the last consumer exactly; no post-consumer
retention. **H3 rejected** (previously by 8-insertion naming-only diff; here by
sharing/release symmetry). **H1 supported:** each distinct live kind costs its
own 369–449-object frame set; same-kind consumers share (equal instance IDs).
Residual +78 after full release = registry/parsed-config caches, not frames.

## Census samples (census-*.json, original scenario, per-second kind census)

Both samples: boss (Rift Warden) + 6→8 Small Biter summons + exactly ONE random
initial kind (sample 1: Rift Cutter, floor 3,520; sample 2: Rift
Shieldbearer, floor 3,421); 3 unique frame paths throughout; FullFrameBody
consumers tracked live/dying (polled tree-wide, incl. post-group-removal);
feedback pool idle slots grow to 9–13 (retained pooled nodes, ~1 object each —
small, bounded, by design). Peaks 3,800 / 3,708. Observer overhead: monitors
are read before each tree walk; retained rows/strings/arrays are Variant
containers (not Objects), so measured object overhead ≈ 0; the census cannot
observe the HISTORICAL failing sample — **its kind census is explicitly
missing**, and these two samples did not breach (stated as required).

## Reconciliation of the historical 4,018 sample

Source facts: it held 9 initial enemies (all others 8) and floor 3,652 vs
3,253/3,419/3,436. Measurement: kind-count → floor is proven causally above
(+380/+458 per distinct kind). Hypothesis (not proof): 9 initial enemies ⇒ two
distinct random initial kinds ⇒ four frame sets ⇒ floor ≈ 3,253+399 ≈ 3,652.
The failing sample's own kind census is unavailable, so this remains an
evidenced hypothesis with the exact missing observation named.

## Actionable conclusion (item 4)

**No avoidable holder is established.** Frame sets are owned by live consumers,
shared within a kind, and freed with the last consumer — the marginal cost is a
live rendering requirement, so no release/cache repair exists (consistent with
the PM's prohibition on speculative cache clearing). The breach mechanism is
setup-RNG enemy-kind-count variance. Exact options, each requiring its own scope
grant: (a) deterministic/representative initial composition for the P3 contour —
encounter/spawn code (`scripts/encounters/**`, not granted) or the QA-owned
probe; (b) further mean reduction (previously measured feedback levers);
(c) accept the variance risk — a board decision. Remaining evidence that would
settle the historical sample conclusively: a kind census of an actual breaching
instrumented sample (permitted diagnostic, not run here; two non-breaching
samples preserved as-is).
