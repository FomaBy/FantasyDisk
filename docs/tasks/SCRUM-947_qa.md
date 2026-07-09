# SCRUM-947 — independent QA: Elementalist magic-bonus trait

Статус: done (remediation `2a8aac19` ready for independent recheck)
Дата: 2026-07-10
QA owner: Codex `/root`
Combined implementation: SCRUM-947, SCRUM-948, SCRUM-949, SCRUM-950
Implementation commits: `f6266a76`, `3b9a0a6c`, `4cf721fa`, `d62eb642`

## QA-Вердикт

Current status: PENDING INDEPENDENT RECHECK

Remediation `2a8aac19` is pushed to `origin/dev`. It preserves below-base
Intelligence penalties and adds the missing focused regression while all
Elementalist, isolation, balance and runtime gates pass. The original FAILED
verdict and evidence below remain the historical QA record; a worker other than
the remediation author must issue the new final verdict.

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
