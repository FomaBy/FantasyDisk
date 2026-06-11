# Characters And Weapons

Обновлено: 2026-06-11

Канонические данные персонажей/оружия находятся в `scripts/progression_data.gd`. Этот файл описывает игровые роли и текущую идентичность.

## Characters

| Character | Role |
| --- | --- |
| Берсерк | melee AoE/cone/strip fighter, высокий риск рядом с толпой |
| Темный маг | caster: AoE, beams, DoT, дистанционный wave clear |
| Гитарист | sound/control: waves, knockback, deployable amp |

## Berserk Weapons

| Weapon | Shape | Current Role |
| --- | --- | --- |
| Двуручный меч | `strip` 120x500 | быстрый точный удар по линии, высокий урон |
| Двуручный топор | `sweep` 140°, radius 320 | широкая ближняя дуга, ниже урон, лучше по толпе |
| Двуручный молот | `circle`, radius 100 | слабый старт, damage x0.55, сильный рост от upgrade exponents |

Молот использует усиленное масштабирование от run-upgrade multipliers (`upgrade_aoe_exponent`, `upgrade_damage_exponent`), но его passive отдельно не разгоняется экспонентами.

## Dark Mage Weapons

| Weapon | Mode | Current Role |
| --- | --- | --- |
| Книга тьмы | `aoe_projectile` | два снаряда в ближайшие цели, AoE-взрывы |
| Проклятый череп | `dot_projectile` | DoT, полезен по плотным и живучим целям |
| Темный жезл | `beam` | два pierce-луча веером, line clear |

## Guitarist Weapons

| Weapon | Mode | Current Role |
| --- | --- | --- |
| Электрогитара | `sound_wave` | быстрое направленное звуковое оружие |
| Бас-гитара | `pulse` | частый слабый пульс-контроль с knockback |
| Звуковой усилитель | `amp` | деплойный объект на земле, живет ~7с и пульсирует сам |

`sound_amp` имеет лимит: `1 + floor(Leadership / 4)`. При превышении удаляется старейший усилитель. Cleanup groups: `deployed_sound_amps`, `player_weapon_effects`.

## Targeting Rule

Все атакующие оружия игрока целятся в ближайшего живого врага, а не в направление движения. Без врагов сохраняется последнее направление атаки.

## Cleanup Rules

- При смене персонажа/оружия/забега/смерти/возврате в меню временные weapon effects очищаются.
- Class-specific leftovers не должны оставаться на карте.
