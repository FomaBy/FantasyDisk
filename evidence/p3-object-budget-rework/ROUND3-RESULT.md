# FAN-3934 round 3 — lazy executor residency implemented; P3 borderline (1/2 runs pass)

Candidate commit `85405739ab6deaa10049d09de6b324e356ada991` (base `d192be10b`; includes
round-1 `071abccfc` and round-2 `236d45bfd` fixes). Author: dev_high agent
`11dd50f9-2322-4aa0-a09e-631e1159c1df`. **No candidate is published — one of the two
required P3 runs still exceeds the cap.**

## Evidence corrections (per PM review 2026-09-09T06:22:25Z)

- The round-3 cache probe bug is confirmed and fixed: the earlier version sampled
  `has_cached`/object counts BEFORE clearing the reference. Corrected measurement
  (`round3/script_cache_and_cold_activation.json`): a plain-`load()`ed executor script
  is NOT cached and retains 0 objects after its last reference is dropped; the earlier
  "scripts are permanent residents" claim was wrong. The 800-object residency is
  reference ownership: eager discovery/registry dictionaries hold all 51 executor
  scripts. Lazy residency removes exactly that ownership.
- Raw logs for all round-3 measurements are now committed under
  `evidence/p3-object-budget-rework/round3/` (previously only stdout).
- Cold-activation timing (previously missing): first `executor_for("berserk","axe")`
  through the lazy registry costs 16.4 ms once (script compile + admission), 11 µs
  warm, +21 retained objects, same instance on repeat — measured at the controller's
  pre-charge resolution point, so the cost lands before activation, never mid-cast.

## Implemented (inside the 05:28:40Z + 06:22:25Z grants)

- `weapon_ultimate_package_discovery.gd`: `discover(base, lazy_executors := false)` —
  lazy mode defers only the executor script load/admission; `validate_document` is the
  extracted script-free stage and `validate_pair` delegates to it, so eager and lazy
  share one code path with identical error strings. `admit_executor(key)` runs the full
  same-seam admission on first demand; failures are remembered (stable) with errors
  exposed via `admission_errors_for`. Default mode (tooling/tests) is unchanged eager.
- `weapon_ultimate_registry.gd`: runtime catalog builds with lazy discovery;
  `executor_for()` admits on first use, caches for the active lifetime, and on failed
  admission evicts the pair and restores the base profile — the exact behavioral
  outcome of eager rejection, resolved before charge/activation.
- `tests/p3_executor_residency_test.gd` (+uid): gates lazy/eager pair parity on the
  real catalog, non-residency of unresolved executors, first-use admission identity and
  cache stability, and stable fail-closed admission on a broken fixture with eager
  parity of the core error. PASS. Eager suites re-run green:
  `executor_contract_audit_test`, `berserk_balance_test`, `presentation_contract_test`,
  `fan1541_activation_integration_test`.

## Measurements (unchanged FAN-3877 probe, exclusive gate, 0 competing Godot processes)

| Contour | Result | Peak objects | Per-second mean | FPS avg / 1% | Peak mem |
|---|---|---:|---:|---:|---:|
| P3 run 1 | **FAIL** | 4,332 / 4,000 | 3,904 | 118.7 / 115.8 | 129.3 MiB |
| P3 run 2 | PASS | 3,970 / 4,000 | 3,481 | 118.7 / 113.2 | 128.5 MiB |
| P1 menu | PASS | 2,267 (was 2,718) | — | 118.3 / n/a | 119.5 MiB |
| P2 48 enemies | PASS | 4,371 / 5,000 (was 4,794) | — | 111.8 / n/a | 128.4 MiB |

Attribution signal run on the same SHA: mean 3,715, peak 4,196. Orphans 0, no
monotonic growth, populations held, one accepted ultimate of 18 attempts everywhere.

## The remaining problem: bimodal run-to-run variance

Run 1 held ~300 more objects than run 2 from the first sampled second (start 3,619 vs
3,321) with identical scenarios — the divergence exists before any sampling-window
gameplay. The P3 setup spawns initial enemies randomly (no controlled seed), and
different enemy types load different full-frame SpriteFrames resource sets; the loaded
set persists in the resource cache for the whole run. The lazy-residency gain (~420
mean) is real but the run's peak now sits inside this ±300 composition variance around
the 4,000 cap: certification requires BOTH runs ≤4,000 and currently depends on which
enemies spawn.

Options that could stabilise this are outside my current grant and need a decision:
deterministic/seeded initial-enemy composition for the P3 contour (probe- or
spawn-side), lazy/deferred full-frame frame loading per enemy kind (floor reduction,
resource-ownership change), or the previously queued feedback-density levers.
