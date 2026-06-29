# SCRUM-541 Secret Boss: max Ascension Act 3 follow-up

Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

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
- PASS: `Godot --headless --path . --script res://tests/runtime_smoke_test.gd`

## QA Verdict: RED (2026-06-28, qa_508_codex190526)

Current `origin/dev` was checked in clean QA worktree
`C:\Users\FomaE\FantasyDisk_agents\qa_508_codex190526` with Godot 4.7 headless.

Passed:
- `tests/secret_encounter_test.gd` - PASS: max selected Ascension gate,
  separate boss id, one-time reward.
- `tests/boss_elite_ttk_gate.gd` - PASS: boss TTK stays at least 1.35x elite
  at stages 0/2/4/6/8/10.
- `tools/balance_harness.gd` - PASS.
- `tools/class_damage_table_3variants.gd` - PASS.

Failed blocker:
- `tests/runtime_smoke_boss_elite_test.gd` - FAIL, exit 1.
- Key assertion: `Expected elite iron_bastion to expose its unique encounter
  pattern meta.`
- Same gate repeatedly logs runtime errors in `combat_director.gd:758` and
  `ui_screens.gd:8554/8534/8563` (`float`/`int` constructor calls and `max_hp`
  Dictionary access).

Because `runtime_smoke_boss_elite_test.gd` is an explicit SCRUM-541 acceptance
gate, QA cannot accept the task. Jira bug filed and linked: SCRUM-656.
SCRUM-541 was returned to `К выполнению`.

## Backend Recheck: PASS (2026-06-28, backend_517_20260628193938)

Clean Windows worktree from fresh `origin/dev`, branch
`codex/backend_517_20260628193938`. The QA RED blocker did not reproduce after
explicit Godot import; no gameplay/code changes were required.

Validation:
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
  (known unrelated duplicate UID warnings for copied skeleton reference art).
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd`
  (`Runtime boss/elite smoke suite passed.`)
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/secret_encounter_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/boss_elite_ttk_gate.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/balance_harness.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/class_damage_table_3variants.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`

Result: SCRUM-541 is ready for QA recheck. The previous
`runtime_smoke_boss_elite_test.gd` failure is treated as a stale/cold-import
runner issue unless QA can reproduce it again on a freshly imported worktree.

## Backend Follow-up Fix: PASS (2026-06-28, backend_scrum541_codex_20260628195911)

Claimed SCRUM-541 again from Jira to harden the QA RED runtime-error lines while
preserving the accepted secret boss behavior. No balance numbers changed.

Changes:
- `combat_director.gd`: nullable `pickup_radius` reads now fall back to `0.0`
  instead of calling `float(null)` in test stubs/cold runner states.
- `ui_screens.gd`: HUD resource reads now tolerate missing snapshot/player
  values and avoid `float(null)`, `int(null)`, and non-Dictionary snapshot access.

Validation:
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/secret_encounter_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/boss_elite_ttk_gate.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/balance_harness.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/class_damage_table_3variants.gd`
- PASS: `git diff --check -- scripts/combat_director.gd scripts/ui_screens.gd`
- FAIL unrelated: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`
  at `runtime_smoke_test.gd:908`, `Expected level-up to play a placeholder toast
  animation.`

Result: ready for QA recheck of SCRUM-541/SCRUM-656 blocker path.

## Follow-up

Final visual identity, sprite, animation rows and polished localized boss name
are Design/Animation scope unless PM explicitly accepts the placeholder.

## QA Verdict: PASS (2026-06-28, qa_541_codex_20260628_200927)

Fresh Windows QA worktree from `origin/dev`:
`C:\Users\FomaE\FantasyDisk_agents\qa_541_codex_20260628_200927`
at commit `9b3db158`.

Verified after explicit Godot 4.7 import:
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --import`
  (known unrelated duplicate UID warnings for copied skeleton reference art).
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/secret_encounter_test.gd`
  (`Secret encounter test passed`).
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd`
  (`Runtime boss/elite smoke suite passed`).
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/boss_elite_ttk_gate.gd`
  (boss TTK remains >= 1.35x elite at stages 0/2/4/6/8/10).

The previous SCRUM-656 RED blocker did not reproduce: no `iron_bastion`
pattern-meta failure and no `combat_director.gd` / `ui_screens.gd` runtime
errors in the focused boss/elite gate.

Residual unrelated blocker documented, not counted against SCRUM-541:
- FAIL: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`
  at `tests/runtime_smoke_test.gd:930`,
  `Expected level-up to play a placeholder toast animation.`
- This matches the known SCRUM-654/SCRUM-658 level-up toast umbrella-smoke issue
  and does not touch the secret boss gate.

QA result: PASS for SCRUM-541 secret boss gate.
