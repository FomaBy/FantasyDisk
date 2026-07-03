# Full Class Rebalance: Projectile, Chain, Pierce, And Delayed AoE Pass
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: backend/class-rebalance-backend-Mill
Thread/Worker: class-rebalance-backend-Mill
Locked paths: `scripts/class_weapon.gd`, `scripts/projectile.gd`, `scripts/progression_data_weapons.gd`, `scripts/progression_data_balance.gd`, focused weapon mechanic tests, relevant balance docs
Jira: SCRUM-857
Исполнитель: Codex

## Контекст
После identity audit нужно сделать ranged/caster оружия действительно разными в runtime: граната не должна ощущаться тем же AoE, что метеор; рикошет, split, pierce, chain и delayed burst должны иметь разные правила урона, target selection и payoff.

## Требования
- [x] Перед стартом проверить Jira/dirty overlap с `SCRUM-854`; не начинать, если тот же worker еще активно держит `scripts/class_weapon.gd` или `scripts/progression_data_weapons.gd`.
- [x] Для Soldier grenade закрепить delayed explosive: projectile/throw/cook не наносит урон в полете и на приземлении; damage только после fuse/telegraph, с falloff.
- [x] Для Elementalist meteor закрепить long-cast, huge payoff: заметная задержка, крупная область, высокий burst, вторичные shards; tradeoff - медленный цикл/overkill risk.
- [x] Для Thief coin и Sniper shatter развести ricochet vs split/pierce: ricochet цепляется по ближайшим целям с falloff, split/shatter расходится по траекториям/соседям без ощущения той же цепи.
- [x] Для Priest/Elementalist/Dark Mage chain/pierce mechanics развести: prayer/chain sustain, elemental chain/rift control, dark pierce beam/curse decay должны иметь разные target rules.
- [x] Проверить, что projectile/chain/pierce изменения не делают AoE и solo однотипно сильными без tradeoff.
- [x] Обновить docs и focused tests/harness expectations.

## Acceptance Criteria
- [x] Soldier grenade, Elementalist meteor, Thief ricochet, Sniper split/pierce, Priest chain and Dark Mage pierce/curse имеют отличающиеся runtime rules.
- [x] Ни одна правка не превращает разные классы в одинаковый "летит AoE и взрывается".
- [x] Balance reports показывают class-kit totals в коридорах class-balance-director или отклонения документированы для следующего pass.
- [x] Пройдены focused weapon tests, `global_damage_balance_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] Docs updated: mechanics/current state/progression balance as relevant.

## Результат
SCRUM-857 implemented by `class-rebalance-backend-Mill` on 2026-07-04.

- `scripts/class_weapon.gd`: added `pierce_damage_falloff`, dark beam decay,
  cursed splash falloff, fuse-safe delayed callbacks without Node lambda
  capture, sniper fan split/pierce corridor, and priest sustain-arc target
  selection.
- `scripts/progression_data_weapons.gd`: tuned Soldier grenade fuse/payoff,
  Elementalist meteor long-cast/shards, Sniper shatter pierce, Dark Mage curse
  splash decay and dark wand pierce decay.
- Added `tests/projectile_chain_pierce_identity_test.gd` focused runtime
  contract for grenade timing, meteor long-cast payoff, coin ricochet vs sniper
  fan split, priest sustain arc and dark pierce/curse decay.
- Docs updated:
  `docs/design/systems/characters_weapons.md`,
  `docs/design/systems/progression_balance.md`,
  `docs/design/current_game_state.md`,
  `docs/design/mechanics_extract.md`,
  `docs/design/reports/full_class_rebalance_identity_audit.md`.

Checks (all PASS via `tools/godot_gate.py`):
- `res://tests/projectile_chain_pierce_identity_test.gd`
- `res://tools/balance_harness.gd`
- `res://tests/weapon_identity_diversity_test.gd`
- `res://tests/global_damage_balance_smoke_test.gd`
- `res://tests/weapon_integrity_test.gd`
- `res://tests/weapon_scene_integrity_test.gd`
- `res://tests/runtime_smoke_weapon_mechanics_test.gd`
- `res://tests/global_survivability_balance_smoke_test.gd`
- `res://tests/runtime_smoke_test.gd`

Balance note: global damage remains green; worst CCT stays
`doctor/restore_potion/20` at +22%, within the +/-30% gate. Runtime smoke still
prints the pre-existing `_apply_dot_tick` CallbackTweener warnings from
`player.gd`, but exits PASS.

Disk cleanup: pending final commit cleanup; remove generated `.godot/`,
untracked `.uid`, ignored `.import` sidecars and transient failure reports before
marking Jira QA-ready.
