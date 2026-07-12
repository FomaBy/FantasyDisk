# SCRUM-976 — Gameplay sandbox runtime layer

Статус: done
Jira: SCRUM-976

Owner: root-next9
Thread/Worker: `/root`
Контур: Codex
Ветка/worktree: `codex/scrum976-gameplay-sandbox` / `FantasyDisk_worktrees/scrum-976-gameplay-sandbox`

## Решение

- Единый `scripts/gameplay_sandbox.gd` задаёт пять canonical keys, диапазоны,
  шаг `0.1`, normalize/reset/snapshot/metadata API.
- `GameSettings` хранит configured values; `Main.begin_new_run_session()` на
  подтверждении оружия создаёт отдельный immutable active-run snapshot.
- Autosave сохраняет active snapshot; старые autosave без поля читаются как
  нейтральные. Сброс Settings не меняет уже активный забег.
- Игрок получает final exact damage/attack-speed слой вне release softcaps;
  summon deploy/ally cadence также покрыты.
- Общий `Enemy` применяет HP/урон один раз ко всем ordinary/summoned/elite/boss
  путям. Attack speed меняет только cooldown countdown, не телеграфы/windup.
- Любой custom snapshot блокирует achievements, Codex и boss/meta/Ascension
  writes и публикует eligibility metadata; run-local экономика остаётся.

## Проверка

- `tests/gameplay_sandbox_scrum976_test.gd`: persistence, corrupt/clamp/snap,
  neutral/easier/harder/custom, immutable snapshot, autosave, player/enemy exact
  factors, summon cadence, cooldown-vs-windup, progression guards.
- Регрессионные и runtime-gates выполняются перед routing в QA.

Результат:

- focused SCRUM-976 — PASS;
- settings/autosave/achievements/meta/damage/contact/boss/elite/mini-elite/
  summon/Ascension — PASS;
- runtime boss+elite и progression+economy suites — PASS;
- global damage и global survivability balance — PASS;
- полный `tests/runtime_smoke_test.gd` на финальном диффе — PASS (известная
  безвредная dummy-renderer диагностика null texture при headless screenshot);
- независимый pre-land review — PASS после исправления neutral summon parity,
  final exact flat-damage, custom victory truth и elite reflect-thorns bypass.

## Jira/Git evidence

Implementation complete; commit/push `origin/dev`, Jira QA routing and cleanup
are performed at the task boundary.

## Independent production QA — PASSED (2026-07-11)

- Fresh QA base: `origin/dev` with implementation `5f580c6fb` and Jira mirror
  routing `788ffc234`; production diff reviewed read-only.
- The focused regression now instantiates the real ordinary, summoned, elite,
  and boss scene paths and verifies exact HP/damage/cadence factors, legacy
  neutral restore, neutral boss/meta/Ascension writes, and custom-run balance
  evidence ineligibility.
- Focused `gameplay_sandbox_scrum976_test.gd`: PASS after rebase.
- Persistence/progression: `game_settings_smoke_test`,
  `run_autosave_persistence_test`, `achievements_smoke_test`,
  `codex_discovery_contract_test`, `codex_unlock_tracking_test`,
  `meta_progression_smoke_test`, `meta_points_per_ascension_test`,
  `artifact_ascension_gate_test`, and `runtime_smoke_progression_economy_test`:
  PASS.
- Combat/summons: `boss_outgoing_damage_multiplier_test`,
  `contact_damage_softcap_test`, `runtime_smoke_boss_elite_test`,
  `boss_summon_cap_test`, `summon_weapon_crowd_floor_test`,
  `summoner_strengthening_test`, `elite_attack_config_safety_test`,
  `mini_elite_roster_spawn_test`, and `boss_directional_telegraph_test`: PASS.
- Balance gates: `balance_harness.gd`, `global_damage_balance_smoke_test.gd`,
  and `global_survivability_balance_smoke_test.gd`: PASS; neutral release
  formulas remain unchanged.
- Final full `runtime_smoke_test.gd`: PASS. The headless dummy renderer emitted
  the known non-fatal null-texture screenshot diagnostic.
- SCRUM-1025 Settings UI was not modified; its integration remains a separate
  downstream ticket over this accepted backend contract.
