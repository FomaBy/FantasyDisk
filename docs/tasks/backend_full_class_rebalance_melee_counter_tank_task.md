# Full Class Rebalance: Melee, Counter, Tank, And Risk-Reward Pass
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: backend/codex-scrum858-melee-risk
Thread/Worker: 019f29dd-7939-71f1-a89e-41acb59793a4
Locked paths: `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/player.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`, survivability/balance tests, relevant docs
Jira: SCRUM-858
Исполнитель: Codex

## Контекст
Пользователь хочет, чтобы melee и tank classes игрались не как обычные AoE-кнопки. Нужны разные risk windows: тяжелые cleave/slam, быстрые flurry/saw, shield counter, короткая защита/микро-окно, возможно attack-driven reposition без превращения всех в одинаковый dash.

## Требования
- [x] Перед стартом проверить overlap с `SCRUM-854` и другими active tasks на `class_weapon/player/progression_data`.
- [x] Knight должен получить реально ощутимую counter fantasy: основной damage budget частично смещен в on-hit/block retaliation, например incoming damage 5 -> retaliation около 25 при caps/TTD gates; монстры иногда умирают от ответки.
- [x] Tower shield/long spear/holy flail должны различаться: shield = guard/counter/front control, spear = reach/pierce/line punish, flail = circular holy control.
- [x] Berserk melee kit сохранить как heavy body pressure, но проверить, что sword/axe/hammer не стали тремя одинаковыми AoE.
- [x] Doctor bone saw / Assassin stab flurry / Robot close-control развести по cadence: saw = маленький быстрый sustain damage, assassin = crit burst windows, robot = compression/knockback/armor pressure.
- [x] Defensive windows не должны давать permanent immunity, uncapped healing or runaway control.
- [x] Обновить survivability and damage gates.

## Acceptance Criteria
- [x] Knight can clear part of a contact pack through shield counter retaliation while staying within survivability caps.
- [x] Melee weapons differ by at least two of: geometry, cadence, setup/payoff, defensive contribution, scaling hook.
- [x] No class relies on generic permanent bullet/projectile behavior for its melee identity.
- [x] `global_survivability_balance_smoke_test.gd`, relevant survivability harness, `global_damage_balance_smoke_test.gd`, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [x] Docs updated with before/after identity and balance notes.

## Результат
- Реализован incoming-based Knight counter в `Player.take_damage()` / `_try_knight_counter()`: `counter_incoming_multiplier`, `counter_radius`, `counter_arc_degrees`, `counter_target_cap`, diminish, knockback/stagger и cooldown reset при `configure_character()`.
- `tower_shield`, `long_spear`, `holy_flail` разведены по tank identity: shield = сильная фронтальная guard/counter ответка по contact pack, spear = reach/pierce + light narrow counter, flail = broad circular holy-control counter.
- Focused test покрывает 5 incoming damage -> около 25 shield retaliation по 24 HP contact pack, cooldown gate, frontal arc и radius exclusions.
- Обновлены docs: `docs/design/systems/characters_weapons.md`, `docs/design/systems/combat.md`, `docs/design/systems/progression_balance.md`, `docs/design/current_game_state.md`.
- Тесты: `melee_unique_mechanics_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `survivability_scenario_test.gd`, `global_survivability_balance_smoke_test.gd`, `global_damage_balance_smoke_test.gd`, `runtime_smoke_test.gd`, `tools/survivability_harness.gd`.
- Disk cleanup: removed `.godot` import cache and temporary Godot `.uid` sidecars created by smoke tests.

## QA-Вердикт 2026-07-04
Статус: PASSED
Commit tested: `39cbb181aaf1f50da941a0fa2b9b5f32c783f699` (`c37a7b95`/`f300900b` ancestors).

Проверки через `tools/godot_gate.py`:
- `tests/melee_unique_mechanics_test.gd` — PASS.
- `tests/runtime_smoke_weapon_mechanics_test.gd` — PASS.
- `tests/survivability_scenario_test.gd` — PASS.
- `tests/global_survivability_balance_smoke_test.gd` — PASS.
- `tests/global_damage_balance_smoke_test.gd` — PASS.
- `tools/survivability_harness.gd` — PASS.
- `tools/balance_harness.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS; known non-blocking `_apply_dot_tick` CallbackTweener stderr only.

Disk cleanup: QA removed `/private/tmp/fd858qa-021619` and `/private/tmp/fd858qa-021619-logs`; dispatcher removed SCRUM-858 landing temp clone/logs.
