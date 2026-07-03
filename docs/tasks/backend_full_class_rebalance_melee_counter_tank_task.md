# Full Class Rebalance: Melee, Counter, Tank, And Risk-Reward Pass
Статус: new
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/player.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`, survivability/balance tests, relevant docs
Jira: SCRUM-858
Исполнитель: Codex

## Контекст
Пользователь хочет, чтобы melee и tank classes игрались не как обычные AoE-кнопки. Нужны разные risk windows: тяжелые cleave/slam, быстрые flurry/saw, shield counter, короткая защита/микро-окно, возможно attack-driven reposition без превращения всех в одинаковый dash.

## Требования
- [ ] Перед стартом проверить overlap с `SCRUM-854` и другими active tasks на `class_weapon/player/progression_data`.
- [ ] Knight должен получить реально ощутимую counter fantasy: основной damage budget частично смещен в on-hit/block retaliation, например incoming damage 5 -> retaliation около 25 при caps/TTD gates; монстры иногда умирают от ответки.
- [ ] Tower shield/long spear/holy flail должны различаться: shield = guard/counter/front control, spear = reach/pierce/line punish, flail = circular holy control.
- [ ] Berserk melee kit сохранить как heavy body pressure, но проверить, что sword/axe/hammer не стали тремя одинаковыми AoE.
- [ ] Doctor bone saw / Assassin stab flurry / Robot close-control развести по cadence: saw = маленький быстрый sustain damage, assassin = crit burst windows, robot = compression/knockback/armor pressure.
- [ ] Defensive windows не должны давать permanent immunity, uncapped healing or runaway control.
- [ ] Обновить survivability and damage gates.

## Acceptance Criteria
- [ ] Knight can clear part of a contact pack through shield counter retaliation while staying within survivability caps.
- [ ] Melee weapons differ by at least two of: geometry, cadence, setup/payoff, defensive contribution, scaling hook.
- [ ] No class relies on generic permanent bullet/projectile behavior for its melee identity.
- [ ] `global_survivability_balance_smoke_test.gd`, relevant survivability harness, `global_damage_balance_smoke_test.gd`, and `runtime_smoke_test.gd` pass via `tools/godot_gate.py`.
- [ ] Docs updated with before/after identity and balance notes.

## Результат
Заполняет исполнитель.
