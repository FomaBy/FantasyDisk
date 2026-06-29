# SCRUM-553 — Лужи (chemist pool + элитная) рендерятся поверх всего → нужен нижний слой

Jira: SCRUM-553
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

**Тип:** Баг · **Приоритет:** p1 · **Спринт:** 0.1.7 · **Метки:** foma

## Проблема
Лужи химика (`ChemistPoisonPool`) и других summon-пулов рисуются **ПОВЕРХ** монстров,
персонажа, монет и сфер опыта. Должны быть **нижним наземным слоем** — декаль под всеми
боевыми сущностями.

## Корень
`scripts/class_weapon.gd:515` `_spawn_damage_pool()` ставит `pool.z_index = 5` (строка 524):

```gdscript
var pool := Node2D.new()
pool.name = "ChemistPoisonPool"
_register_effect(pool)
pool.add_to_group("chemist_clouds")
...
pool.z_index = 5            # ← БАГ: выше сущностей (z≈0) → поверх всего
```

Эта же функция рисует poison/spark/briar-пулы (текстуры `class_weapon.gd:5-7`), поэтому
один фикс покрывает все summon-пулы.

Тот же баг у элитной лужи яда: `scripts/enemy.gd:961` `_spawn_poison_puddle()` →
`puddle.z_index = 5`.

## Эталон слоёв (почему z=5 = поверх)
| Сущность | z_index |
|---|---|
| Пикапы (`pickup.gd`, `extends Node2D`, без z) | 0 |
| Игрок (риг, `player.gd:1766`) | 0 |
| Монстры (тело) | ~0 |
| Неймплейты/маркеры | 3000+ |
| **Лужа (сейчас)** | **5 ← поверх всех** |

## Фикс
- Опустить лужи **ниже** сущностей. Рекомендация: ввести `const GROUND_POOL_Z := -3` и
  выставить `pool.z_as_relative = false` (абсолютный наземный слой, не зависит от родителя),
  либо просто `pool.z_index = -2..-3`.
- Применить к **обоим** местам: `class_weapon._spawn_damage_pool` и
  `enemy._spawn_poison_puddle`.
- **НЕ** опускать ниже фона/пола арены — лужа видна над землёй, но под всеми сущностями.

## Acceptance
- [ ] В бою лужа визуально **под** персонажем, монстрами, монетами и сферами опыта.
- [ ] Тики урона лужи и combo-облака работают как раньше (нет геймплейного регресса).
- [ ] `runtime_smoke_test.gd` + `attack_vfx_smoke_test.gd` зелёные **через гейт**:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/<smoke>.gd`

## Files
- `scripts/class_weapon.gd` (~515-535, `_spawn_damage_pool`) — основной фикс
- `scripts/enemy.gd` (~954-963, `_spawn_poison_puddle`) — тот же фикс для элитной лужи
