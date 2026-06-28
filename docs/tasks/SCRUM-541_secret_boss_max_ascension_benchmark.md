# SCRUM-541 Secret Boss: max Ascension Act 3 follow-up

Status: done 2026-06-28.

Owner: backend-loop-rawls-peer. Locked paths:
`scripts/meta_progression.gd`, `scripts/main.gd`, `scripts/combat_director.gd`,
`scripts/boss.gd`, `scripts/progression_data_enemies.gd`,
`scenes/BossSecretAscension.tscn`, `tests/secret_encounter_test.gd`,
`tests/runtime_smoke_test.gd`, `tests/runtime_smoke_boss_elite_test.gd`,
`docs/design/systems/enemies_bosses.md`,
`docs/design/systems/progression_balance.md`,
`docs/design/current_game_state.md`, `docs/design/content_registry.md`.

## Result

- Replaced the old SCRUM-619 secret gate with a max-selected-Ascension gate:
  `MetaProgression.secret_encounter_unlocked_for_level(run_level)` returns true
  only at `MAX_ASCENSION_LEVEL` (5).
- Route boss entry no longer replaces the Act 3 boss id. The normal Act 3 boss
  is fought first.
- After normal Act 3 boss victory, `CombatDirector` starts the secret follow-up
  only when the run selected max Ascension. Below max Ascension, the run ends
  normally.
- Added separate canonical boss id `secret_ascension_boss`, scene
  `scenes/BossSecretAscension.tscn`, and unique pattern registry entry.
- Added backend placeholder mechanics:
  `SecretBossSectorRing`, delayed rift eruption clusters, phase-2 pressure/adds
  at 50% HP, phase 3 below 25% HP.

## Benchmark

Act 3 max Ascension L5 benchmark uses route scaling stage 18
(`route_stage 10 + Act 3 offset 8`) and L5 `boss_hp_mult = 1.30`.

- Secret boss HP estimate: `47,606.6`.
- L20 optimum class-kit 1-target DPS range:
  - low `205.39` DPS -> `231.8s` TTK;
  - median `264.77` DPS -> `179.8s` TTK;
  - high `391.83` DPS -> `121.5s` TTK.
- L20 random-average class-kit 1-target DPS range:
  - low `85.07` DPS -> `559.6s` TTK;
  - median `93.64` DPS -> `508.4s` TTK;
  - high `137.09` DPS -> `347.3s` TTK.

Interpretation: the fight is intentionally brutal for tuned L20 builds and not
a global class rebalance. Random-average builds are expected to struggle hard.

## Validation

- PASS: `Godot --headless --path . --import`
- PASS: `git diff --check`
- PASS: `Godot --headless --path . --script res://tests/secret_encounter_test.gd`
- PASS: `Godot --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd`
- PASS: `Godot --headless --path . --script res://tools/balance_harness.gd`
- PASS: `Godot --headless --path . --script res://tests/boss_elite_ttk_gate.gd`
- PASS: `Godot --headless --path . --script res://tools/class_damage_table_3variants.gd`

Known unrelated full umbrella status on current `origin/dev`: full
`tests/runtime_smoke_test.gd` still has the pre-existing autosave continue/new
game failure observed before SCRUM-541.

## Follow-up

Final visual identity, sprite, animation rows and polished localized boss name
are Design/Animation scope unless PM explicitly accepts the placeholder.
