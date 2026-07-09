# SCRUM-947 — independent QA: Elementalist magic-bonus trait

Статус: done
Дата: 2026-07-10
Final QA owner: Codex `/root/audit_repo`
Historical QA owner: Codex `/root`
Combined implementation: SCRUM-947, SCRUM-948, SCRUM-949, SCRUM-950
Implementation commits: `f6266a76`, `3b9a0a6c`, `4cf721fa`, `d62eb642`
Remediation: `2a8aac19` (Jira sync `cee96169`)

## QA-Вердикт

Статус: PASSED

Final independent recheck on 2026-07-10 confirms remediation `2a8aac19` fixes
the blocking Intelligence-penalty defect without a production regression.
Fresh ratios were `1.000000` at zero delta, `1.265778` for `+2` Intelligence
(exact class-growth × `1.30` expectation), and `0.777778` for `-2` Intelligence
(exact unamplified penalty). Run and passive `0.80` magic multipliers remained
`0.800000`, physical/DoT channels stayed isolated, and run+passive stacking
matched its independently multiplied expectation exactly.

The full Elementalist, damage isolation, 51/51 tuning, 17-class budget, global
damage/survivability, 153-measurement comfort band, projectile identity,
animation, runtime, balance harness and survivability harness gates all passed.
Elementalist tuning remains ring `51.84/178.11`, prism `51.84/178.22`, meteor
`51.85/178.23` solo/20-target DPS; the final balance audit reports all 51
class+weapon pairs PASS. Detailed final evidence is in
`docs/tasks/SCRUM-1019_qa.md`.

SCRUM-947 is accepted and may move to `Готово`. The original FAILED verdict and
evidence below remain intact as the historical QA record.

Disk cleanup: disposable `.godot/`, generated `build/`, temporary probe and QA
worktree removed after Jira/GitHub synchronization.

Historical status: FAILED

The positive-bonus path is data-driven and otherwise behaves as specified:
Elementalist magic-tagged run, passive, prayer and above-base Intelligence
bonuses receive exactly `1.30x` bonus effectiveness; universal, physical and
DoT sources remain isolated. The acceptance edge for an attribute penalty is
incorrect, however.

`derived_parameters()` computes the effective attribute as
`base + max(current - base, 0) * 1.30`. When current Intelligence is below the
class base this restores it to the base. An independent probe using the same
Elementalist weapon and no run modifiers produced the same `magic_damage` for
base Intelligence and base minus two Intelligence. The trait therefore erases
an Intelligence debuff, contrary to its documented rule that bonuses are
amplified while penalties pass through unchanged.

Follow-up Bug: `SCRUM-1019` — *Elementalist trait: preserve below-base
Intelligence penalties*. It blocks acceptance of SCRUM-947 and requires a
regression assertion for the negative-delta case. QA made no production change.

## Non-blocking verification

All existing commands ran through `tools/godot_gate.py` and passed, which also
confirms that the failing edge was previously uncovered:

- `tests/elementalist_kit_test.gd`;
- `tests/damage_type_isolation_test.gd`;
- `tests/weapon_tuning_application_test.gd` — 51/51 pairs;
- `tests/class_budget_profiles_integrity_test.gd` — 17 classes;
- `tests/global_damage_balance_smoke_test.gd`;
- `tests/global_survivability_balance_smoke_test.gd`;
- `tests/comfort_band_cross_class_gate.gd` — 153 measurements;
- `tests/projectile_chain_pierce_identity_test.gd`;
- `tests/animation_smoke_test.gd`;
- `tests/runtime_smoke_test.gd`;
- `tools/balance_harness.gd`.

Current Elementalist tuning remains inside the global corridors: ring
`51.84/178.11`, prism `51.84/178.22`, meteor `51.85/178.23` solo/20-target
DPS, with crowd-clear deviations inside the accepted bands. These metrics do
not waive the blocking semantic defect.
