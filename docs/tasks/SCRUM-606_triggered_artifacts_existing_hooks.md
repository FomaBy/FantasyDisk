# SCRUM-606: Триггерные артефакты +5 на существующих хуках

Jira: SCRUM-606
Статус: done
Контур: Codex
Owner: Back-end / backend-codex-artifacts-606-609-integrate
Branch: `dev`
Locked paths: `scripts/progression_data_content.gd`, `tests/artifacts_606_609_test.gd`, `assets/sprites/ui/icons/artifacts/artifact_{field_kit,vital_siphon,powder_charge,bulwark_echo,duelist_spur}.png`, `docs/design/*artifact*`, `docs/design/systems/progression_balance.md`

## Scope

Add five tier-2/cost55 active artifacts on already-supported runtime hooks:
`on_room_clear`, `on_kill`, `on_take_hit`, and `on_crit`. No new gameplay hook
or permanent damage multiplier is introduced by this task.

## Result

- `field_kit`: `room_clear_heal_percent = 0.05`.
- `vital_siphon`: `kill_heal_percent = 0.01`.
- `powder_charge`: `kill_explosion_chance = 0.10`.
- `bulwark_echo`: `take_hit_pulse_chance = 0.16`.
- `duelist_spur`: `crit_speed_burst = 0.22`.
- All five records are `active:true`, include their `trigger`, carry the
  data-driven active note in `description`, and are auto-included in
  `reward_pool`/`shop_items` through `ProgressionData.ARTIFACTS`.
- Runtime icons and QA evidence are reused from icon unblock commit `59f9a2ee`.

## Acceptance Evidence

- `tests/artifacts_606_609_test.gd` checks data shape, pool/shop inclusion,
  icon PNG/import readiness, and exact consumer flags.
- `tests/content_rewards_integrity_test.gd`, `tests/no_duplicate_artifact_files_test.gd`,
  `tests/runtime_smoke_triggered_artifacts_test.gd`, and `tests/runtime_smoke_test.gd`
  are part of the integration QA gate.

## Integration Result

- Integrated onto fresh `origin/dev` from `codex/scrum-606-609-artifacts` /
  `codex/artifact-icon-unblock-worker` without taking unrelated branch changes.
- Pushed to `origin/dev` in commit `162e1797`.
- Jira target status: `Контроль качества`.
- Final tests passed:
  `tests/artifacts_606_609_test.gd`,
  `tests/content_rewards_integrity_test.gd`,
  `tests/no_duplicate_artifact_files_test.gd`,
  `tests/runtime_smoke_triggered_artifacts_test.gd`,
  `tests/runtime_smoke_test.gd`.
