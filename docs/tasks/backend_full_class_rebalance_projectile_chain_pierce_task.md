# Full Class Rebalance: Projectile, Chain, Pierce, And Delayed AoE Pass
Статус: new
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/class_weapon.gd`, `scripts/projectile.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`, focused weapon mechanic tests, relevant balance docs
Jira: SCRUM-857
Исполнитель: Codex

## Контекст
После identity audit нужно сделать ranged/caster оружия действительно разными в runtime: граната не должна ощущаться тем же AoE, что метеор; рикошет, split, pierce, chain и delayed burst должны иметь разные правила урона, target selection и payoff.

## Требования
- [ ] Перед стартом проверить Jira/dirty overlap с `SCRUM-854`; не начинать, если тот же worker еще активно держит `scripts/class_weapon.gd` или `scripts/progression_data_weapons.gd`.
- [ ] Для Soldier grenade закрепить delayed explosive: projectile/throw/cook не наносит урон в полете и на приземлении; damage только после fuse/telegraph, с falloff.
- [ ] Для Elementalist meteor закрепить long-cast, huge payoff: заметная задержка, крупная область, высокий burst, вторичные shards; tradeoff - медленный цикл/overkill risk.
- [ ] Для Thief coin и Sniper shatter развести ricochet vs split/pierce: ricochet цепляется по ближайшим целям с falloff, split/shatter расходится по траекториям/соседям без ощущения той же цепи.
- [ ] Для Priest/Elementalist/Dark Mage chain/pierce mechanics развести: prayer/chain sustain, elemental chain/rift control, dark pierce beam/curse decay должны иметь разные target rules.
- [ ] Проверить, что projectile/chain/pierce изменения не делают AoE и solo однотипно сильными без tradeoff.
- [ ] Обновить docs и focused tests/harness expectations.

## Acceptance Criteria
- [ ] Soldier grenade, Elementalist meteor, Thief ricochet, Sniper split/pierce, Priest chain and Dark Mage pierce/curse имеют отличающиеся runtime rules.
- [ ] Ни одна правка не превращает разные классы в одинаковый "летит AoE и взрывается".
- [ ] Balance reports показывают class-kit totals в коридорах class-balance-director или отклонения документированы для следующего pass.
- [ ] Пройдены focused weapon tests, `global_damage_balance_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Docs updated: mechanics/current state/progression balance as relevant.

## Результат
Заполняет исполнитель.
