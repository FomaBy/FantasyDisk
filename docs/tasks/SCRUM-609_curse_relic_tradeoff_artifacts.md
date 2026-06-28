# SCRUM-609: Реликвии-проклятия (trade-off артефакты)

Jira: SCRUM-609
Статус: review
Контур: Codex
Owner: Back-end / backend-codex-artifacts-606-609-integrate
Branch: `dev`
Locked paths: `scripts/progression_data_content.gd`, `tests/artifacts_606_609_test.gd`, `assets/sprites/ui/icons/artifacts/artifact_{sacrifice_seal,hungry_amulet,berserk_totem,focus_lens,stone_hide}.png`, `docs/design/*artifact*`, `docs/design/systems/progression_balance.md`

## Scope

Add five passive tier-2/cost55 relic artifacts with real upside and real
downside, using only currently supported runtime mod keys.

## Result

- `sacrifice_seal`: `crit_chance_flat = 0.30`, `max_health_multiplier = 0.78`.
- `hungry_amulet`: `money_gain_multiplier = 1.85`, `healing_multiplier = 0.65`.
- `berserk_totem`: `damage_multiplier = 1.60`, `move_speed_multiplier = 0.80`.
- `focus_lens`: `range_multiplier = 1.70`, `aoe_radius_multiplier = 0.75`.
- `stone_hide`: `defense_flat = 0.40`, `attack_speed_multiplier = 0.75`.
- Each relic is passive, has exactly one plus-side axis and one minus-side axis,
  and is auto-included in `reward_pool`/`shop_items` through
  `ProgressionData.ARTIFACTS`.
- Runtime icons and QA evidence are reused from icon unblock commit `59f9a2ee`.

## Acceptance Evidence

- `tests/artifacts_606_609_test.gd` checks data shape, pool/shop inclusion,
  icon PNG/import readiness, supported mod keys, and exact plus/minus values.
- `tests/content_rewards_integrity_test.gd`, `tests/no_duplicate_artifact_files_test.gd`,
  `tests/runtime_smoke_triggered_artifacts_test.gd`, and `tests/runtime_smoke_test.gd`
  are part of the integration QA gate.

## Integration Result

- Integrated onto fresh `origin/dev` from `codex/scrum-606-609-artifacts` /
  `codex/artifact-icon-unblock-worker` without taking unrelated branch changes.
- Ready for QA after commit/push to `dev`; final commit and test output are recorded
  in Jira comments.
