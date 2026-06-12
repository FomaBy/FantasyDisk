# Characters And Weapons

Обновлено: 2026-06-12

Канонические данные персонажей и оружия находятся в `scripts/progression_data.gd`. Этот файл описывает игровую идентичность, сцены и текущие backend-режимы.

## Characters

| Character ID | Role |
| --- | --- |
| `berserk` | melee AoE/frustum fighter, высокий риск рядом с толпой |
| `dark_mage` | caster: AoE, beams, DoT, дистанционный wave clear |
| `guitarist` | sound/control: waves, knockback, deployable amp |
| `assassin` | быстрый crit melee/ranged hybrid: boomerang, flurry, poison line |
| `ranger` | дальний точный контроль: piercing shots, fan beams, trap |
| `doctor` | self-sustain через урон: potion, poison injection, melee saw |
| `chemist` | AoE + DoT zones: explosions, acid pools, homunculus summon |
| `knight` | tank/control melee: spear strip, shield bash, circular flail |
| `druid` | summon/nature control: beast pack, thorn zones, raven totem |

## Weapon Matrix

У каждого класса ровно 3 выбираемых стартовых оружия. Все варианты выбираются через `ProgressionData.WEAPONS_BY_CLASS` и передаются в `Player.configure_character(character_id, weapon_id)`.

| Class | Weapon ID | Name | Scene | Backend Mode | Gameplay Identity |
| --- | --- | --- | --- | --- | --- |
| `berserk` | `sword` | Двуручный меч | `TwoHandedSword.tscn` | `frustum` | Широкий усеченный замах 90 градусов, радиус 600, надежно достает врагов рядом |
| `berserk` | `axe` | Двуручный топор | `TwoHandedAxe.tscn` | `sweep` | Широкая дуга, контроль ближней толпы |
| `berserk` | `hammer` | Двуручный молот | `TwoHandedHammer.tscn` | `circle` | Малый стартовый круг, сильный late-game AoE scaling |
| `dark_mage` | `dark_book` | Книга тьмы | `DarkBook.tscn` | `aoe_projectile` | 2 AoE-снаряда по ближайшим целям |
| `dark_mage` | `cursed_skull` | Проклятый череп | `CursedSkull.tscn` | `homing_curse` | Самонаведение, DoT и splash |
| `dark_mage` | `dark_wand` | Темная палочка | `DarkWand.tscn` | `beam` | 2 pierce-луча веером |
| `guitarist` | `electric_guitar` | Электрогитара | `ElectricGuitar.tscn` | `sound_wave` | Направленная звуковая волна |
| `guitarist` | `bass_guitar` | Бас-гитара | `BassGuitar.tscn` | `pulse` | Частый круговой pulse/knockback |
| `guitarist` | `sound_amp` | Звуковой усилитель | `SoundAmp.tscn` | `amp` | Deploy amp, autonomous pulses, cleanup |
| `assassin` | `chakrams` | Чакрамы | `Chakrams.tscn` | `boomerang` | Коридор урона туда и обратно, crit-friendly |
| `assassin` | `shadow_daggers` | Теневые кинжалы | `ShadowDaggers.tscn` | `stab_flurry` | Быстрые короткие multi-stabs по ближайшим целям |
| `assassin` | `venom_wire` | Ядовитая струна | `VenomWire.tscn` | `dot_beam` | Тонкая poison-линия с DoT |
| `ranger` | `moon_crossbow` | Лунный арбалет | `MoonCrossbow.tscn` | `beam` | Дальний точный piercing shot |
| `ranger` | `storm_longbow` | Грозовой длинный лук | `StormLongbow.tscn` | `beam` | 3 дальних луча веером |
| `ranger` | `hunter_trap` | Охотничий капкан | `HunterTrap.tscn` | `trap` | Deploy trap: burst + knockback при входе врага |
| `doctor` | `restore_potion` | Зелье восстановления | `RestorePotion.tscn` | `aoe_projectile` | AoE throw + self heal |
| `doctor` | `plague_syringe` | Чумной шприц | `PlagueSyringe.tscn` | `homing_curse` | Poison injection + sustain |
| `doctor` | `bone_saw` | Костяная пила | `BoneSaw.tscn` | `stab_flurry` | Ближний риск, bleed-like DoT, small heal |
| `chemist` | `blast_powder` | Взрывная пыль | `BlastPowder.tscn` | `aoe_projectile` | Взрыв + poison cloud |
| `chemist` | `acid_flask` | Кислотная колба | `AcidFlask.tscn` | `aoe_projectile` | Большая acid pool / stacking DoT feeling |
| `chemist` | `homunculus_vial` | Склянка гомункула | `HomunculusVial.tscn` | `summon` | Temporary minion scaling from magic damage |
| `knight` | `long_spear` | Копье | `LongSpear.tscn` | `strip` | Длинный точечный выпад, defense passive |
| `knight` | `tower_shield` | Башенный щит | `TowerShield.tscn` | `sweep` | Shield bash / frontal control, tank identity |
| `knight` | `holy_flail` | Освященный кистень | `HolyFlail.tscn` | `circle` | Medium circular heavy swing |
| `druid` | `summon_amulet` | Амулет призыва | `SummonAmulet.tscn` | `summon` | Beast pack scaling from Leadership |
| `druid` | `briar_staff` | Посох терний | `BriarStaff.tscn` | `aoe_projectile` | Thorn zone, AoE DoT, crowd control |
| `druid` | `raven_totem` | Вороний тотем | `RavenTotem.tscn` | `amp` | Totem pulses, Leadership-scaled deploy limit |

## Backend Modes

- `scripts/berserk_weapon.gd`: `frustum`, `strip`, `sweep`, `circle`; melee damage window is synced with swing timing.
- `scripts/class_weapon.gd`: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`.
- `scripts/summoner_weapon.gd`: summon weapon wrapper for Druid and Chemist minion styles.

`stab_flurry` hits several nearest enemies inside a short wave-shaped melee zone. `dot_beam` is a pierce line that applies DoT. `trap` deploys a node that triggers burst damage and knockback when an enemy enters its radius. Deploy visuals reuse each weapon's `WeaponVisual` texture.

## Visual Asset Status

Design visual set is complete for 9 classes and 27 weapons as of 2026-06-11. Weapon art v2 pass 2026-06-12 reduced oversized socket visuals, fixed scene texture fallbacks, and replaced the Knight visual stack: `assets/sprites/characters/knight.png` is now an unarmed base sprite, while `long_spear.png`, `tower_shield.png`, and `holy_flail.png` are separate polished noble knight weapons. New class full-art PNGs are art-approved at `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). All weapon PNGs in the matrix above exist at their canonical `assets/sprites/weapons/*.png` paths (`256x256`, transparent), including the 12 formerly fallback weapons:
`shadow_daggers`, `venom_wire`, `storm_longbow`, `hunter_trap`, `plague_syringe`, `bone_saw`, `acid_flask`, `homunculus_vial`, `tower_shield`, `holy_flail`, `briar_staff`, `raven_totem`.

Socket/display status: all 27 weapon scenes now point to their matching canonical PNG and use reduced `WeaponVisual.scale` for clearer body/face readability. Preview sheets: `docs/design/previews/weapon_v2_assets_contact.png` for raw PNG QA and `docs/design/previews/weapon_v2_socket_contact.png` for class/weapon visual placement. `venom_wire` is intentionally thin and best paired with a separate line/VFX during attacks; `hunter_trap`, `sound_amp`, `tower_shield`, `raven_totem`, `summon_amulet`, and `homunculus_vial` can also serve as deployable/world sprite bases.

## Targeting Rule

Все атакующие оружия игрока целятся в ближайшего живого врага, а не в направление движения. Без врагов сохраняется последнее направление атаки.

## Cleanup Rules

- При смене персонажа/оружия/забега/смерти/возврате в меню временные weapon effects очищаются.
- Deployables/traps/totems/summons должны быть в `player_weapon_effects` и не оставаться на карте после cleanup.
- Class-specific leftovers не должны оставаться на карте.
