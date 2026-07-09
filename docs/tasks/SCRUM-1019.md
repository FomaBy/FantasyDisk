# SCRUM-1019 — preserve below-base Elementalist Intelligence penalties

Статус: done
Версия: 0.2.1
Jira: SCRUM-1019
Owner: Codex `/root`
Контур: Codex

## Контекст

Independent QA of SCRUM-947 found that the Elementalist's `1.30x` positive
magic-bonus effectiveness restored any below-base Intelligence value to the
class base. The implementation used `max(delta, 0)` while rebuilding the
effective attribute, so an Intelligence debuff produced no magic-damage loss.

## Решение

- amplify only a strictly positive Intelligence delta above the class base;
- leave zero and negative deltas unchanged;
- add a deterministic focused regression for base-minus-two Intelligence;
- preserve physical and DoT channel isolation;
- do not retune or redesign the three Elementalist weapons.

## Acceptance evidence

The effective Intelligence calculation now starts from the actual scaled value
and rebuilds it only when the delta is strictly positive. Base-minus-two
Intelligence loses exactly `2 / base_intelligence` of the magic channel: the
penalty is neither erased nor multiplied by `1.30`. Positive progression still
uses the class growth scalar and `1.30` trait effectiveness. Focused assertions
also prove that both positive and negative Intelligence deltas leave physical
and DoT output unchanged.

All commands used `tools/godot_gate.py` with Godot 4.7 and passed:

- `tests/elementalist_kit_test.gd`;
- `tests/damage_type_isolation_test.gd`;
- `tests/weapon_tuning_application_test.gd` — 51/51 pairs;
- `tests/class_budget_profiles_integrity_test.gd` — 17 classes;
- `tests/global_damage_balance_smoke_test.gd`;
- `tests/global_survivability_balance_smoke_test.gd`;
- `tests/comfort_band_cross_class_gate.gd` — 153 measurements;
- `tests/projectile_chain_pierce_identity_test.gd`;
- `tests/animation_smoke_test.gd`;
- `tests/runtime_smoke_test.gd`.

Runtime emitted only the known dummy-renderer null-texture screenshot
diagnostic and completed PASS. No Elementalist weapon tuning, geometry,
visuals or animation paths changed. After the implementation is pushed,
SCRUM-1019 and parent SCRUM-947 return to `Контроль качества` for an independent
worker; this implementation report is not the final QA verdict.
