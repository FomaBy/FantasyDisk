# Characters And Weapons

Обновлено: 2026-06-13

Канонические данные персонажей и оружия доступны через compatibility facade `scripts/progression_data.gd`; после SCRUM-198 исходные домены живут в `scripts/progression_data_characters.gd` и `scripts/progression_data_weapons.gd`. Этот файл описывает игровую идентичность, сцены и текущие backend-режимы.

## Characters

| Character ID | Role |
| --- | --- |
| `berserk` | melee AoE/frustum fighter, высокий риск рядом с толпой |
| `soldier` | tactical physical fighter: suppression burst, delayed grenade, bayonet brace |
| `thief` | agile trickster: coin ricochet, shadow backstab, smoke dodge window |
| `elementalist` | elemental AoE caster: orbit ticks, prism rifts, meteor shards |
| `sniper` | long-range precision class: lockshot, kill-zone marking, split rounds |
| `priest` | holy sustain caster: sanctify marks, ward pulses, prayer chains |
| `biologist` | bio-reaction scientist: spore blooms, sample analysis, symbiote webs |
| `robot` | heavy tank-control construct: magnetic pulls, compression lines, reactor vents |
| `engineer` | mechanical summoner/support: sentry links, repair drone sustain, pressure mine grid |
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
| `berserk` | `hammer` | Двуручный молот | `TwoHandedHammer.tscn` | `circle` | Малый стартовый круг с close-ring cap 115px; late-game AoE stays local instead of screen-wide |
| `soldier` | `soldier_rifle` | Аркебуза строя | `SoldierRifle.tscn` | `suppression_burst` | Три коротких выстрела по линии: primary full damage, соседние цели reduced suppression damage |
| `soldier` | `soldier_grenade` | Граната с фитилем | `SoldierGrenade.tscn` | `grenade_cook` | Телеграф ground-zone, задержка фитиля, взрыв с falloff |
| `soldier` | `soldier_bayonet` | Штык-стойка | `SoldierBayonet.tscn` | `bayonet_brace` | Короткая defensive corridor-стойка: один укол на врага и knockback |
| `thief` | `thief_coin_pouch` | Кошель Рикошета | `ThiefCoinPouch.tscn` | `coin_ricochet` | Цепной рикошет по ближайшим целям с убывающим уроном и кражей золота |
| `thief` | `thief_shadow_cloak` | Плащ Захода | `ThiefShadowCloak.tscn` | `shadow_backstab` | Мгновенный заход за спину ближайшей цели, усиленный удар и небольшой splash |
| `thief` | `thief_smoke_bomb` | Дымовая Бомба | `ThiefSmokeBomb.tscn` | `smoke_bomb` | Delayed AoE дыма плюс временное уклонение |
| `elementalist` | `elementalist_orb_ring` | Кольцо Трех Стихий | `ElementalistOrbRing.tscn` | `elemental_orbit` | Стихийные сферы вращаются вокруг героя и наносят AoE-тиковый урон |
| `elementalist` | `elementalist_prism_focus` | Призматический Фокус | `ElementalistPrismFocus.tscn` | `prism_rift` | Два пересекающихся луча-разлома по ближайшей цели после короткого телеграфа |
| `elementalist` | `elementalist_meteor_core` | Ядро Метеора | `ElementalistMeteorCore.tscn` | `meteor_shards` | Отложенный метеорный удар и вторичные осколочные взрывы |
| `sniper` | `sniper_deadeye_rifle` | Винтовка Мертвого Глаза | `SniperDeadeyeRifle.tscn` | `sniper_lockshot` | Дальний lockshot: короткий прицел, затем точный beam по locked target и falloff по линии |
| `sniper` | `sniper_spotter_scope` | Прицел Наводчика | `SniperSpotterScope.tscn` | `sniper_kill_zone` | Маркирует kill-zone у ближайшей цели и вызывает несколько точных sky-beam попаданий |
| `sniper` | `sniper_shatter_rounds` | Осколочные Патроны | `SniperShatterRounds.tscn` | `sniper_split_round` | Основной дальний выстрел раскалывается по соседним целям с убывающим уроном |
| `priest` | `priest_reliquary` | Светлый Реликварий | `PriestReliquary.tscn` | `priest_sanctify` | Отмечает ближайшую цель и взрывает священную область с sustain-heal от урона |
| `priest` | `priest_censer` | Кадило Обета | `PriestCenser.tscn` | `priest_ward` | Несколько защитных волн вокруг героя, ближний контроль и малое лечение |
| `priest` | `priest_chime` | Колокол Молитвы | `PriestChime.tscn` | `priest_prayer_chain` | Молитвенная цепь перескакивает между врагами и возвращает sustain |
| `biologist` | `biologist_spore_lens` | Споровая Линза | `BiologistSporeLens.tscn` | `bio_spore_bloom` | Три расширяющихся споровых кольца на цели с убывающим уроном |
| `biologist` | `biologist_sample_injector` | Инъектор Образцов | `BiologistSampleInjector.tscn` | `bio_sample_dart` | Прямой sample dart и delayed analysis pulses по ближайшим тканям |
| `biologist` | `biologist_symbiote_seed` | Семя Симбионта | `BiologistSymbioteSeed.tscn` | `bio_symbiote_web` | Симбиотическая сеть связывает первичную цель с соседними врагами |
| `robot` | `robot_magnetic_anchor` | Магнитный Якорь | `RobotMagneticAnchor.tscn` | `robot_magnetic_anchor` | Target-centered magnetic anchor pulls nearby enemies inward and detonates |
| `robot` | `robot_hydraulic_press` | Гидравлический Пресс | `RobotHydraulicPress.tscn` | `robot_compression_line` | Two pressure jaws compress a line corridor and push enemies toward its axis |
| `robot` | `robot_reactor_core` | Реакторное Ядро | `RobotReactorCore.tscn` | `robot_reactor_vent` | Four directional reactor vents clear close-range space around the player |
| `engineer` | `engineer_sentry_wrench` | Ключ Часового | `EngineerSentryWrench.tscn` | `engineer_sentry_link` | Temporary sentry selects targets and fires focused beams |
| `engineer` | `engineer_repair_drone` | Ремонтный Дрон | `EngineerRepairDrone.tscn` | `engineer_repair_drone` | Chain drone links enemies and repairs owner from damage |
| `engineer` | `engineer_pressure_mines` | Минная Сетка | `EngineerPressureMines.tscn` | `engineer_pressure_mines` | Three pressure mines fan out and trigger independently |
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
| `chemist` | `homunculus_vial` | Склянка гомункула | `HomunculusVial.tscn` | `summon` | `tank_control` homunculus scaling from magic damage |
| `knight` | `long_spear` | Копье | `LongSpear.tscn` | `strip` | Длинный точечный выпад, defense passive |
| `knight` | `tower_shield` | Башенный щит | `TowerShield.tscn` | `sweep` | Shield bash / frontal control, tank identity |
| `knight` | `holy_flail` | Освященный кистень | `HolyFlail.tscn` | `circle` | Medium circular heavy swing |
| `druid` | `summon_amulet` | Амулет призыва | `SummonAmulet.tscn` | `summon` | `pack_damage` beast pack scaling from Leadership |
| `druid` | `briar_staff` | Посох терний | `BriarStaff.tscn` | `aoe_projectile` | Thorn zone, AoE DoT, crowd control |
| `druid` | `raven_totem` | Вороний тотем | `RavenTotem.tscn` | `amp` | `support_totem` pulses, Leadership-scaled deploy limit |

## Backend Modes

- `scripts/berserk_weapon.gd`: `frustum`, `strip`, `sweep`, `circle`; melee damage window is synced with swing timing.
- `scripts/class_weapon.gd`: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`, `suppression_burst`, `grenade_cook`, `bayonet_brace`, `coin_ricochet`, `shadow_backstab`, `smoke_bomb`, `elemental_orbit`, `prism_rift`, `meteor_shards`, `sniper_lockshot`, `sniper_kill_zone`, `sniper_split_round`, `priest_sanctify`, `priest_ward`, `priest_prayer_chain`, `bio_spore_bloom`, `bio_sample_dart`, `bio_symbiote_web`, `robot_magnetic_anchor`, `robot_compression_line`, `robot_reactor_vent`, `engineer_sentry_link`, `engineer_repair_drone`, `engineer_pressure_mines`.
- `scripts/summoner_weapon.gd`: summon weapon wrapper for Druid and Chemist minion styles.

`stab_flurry` hits several nearest enemies inside a short wave-shaped melee zone. `dot_beam` is a pierce line that applies DoT. `trap` deploys a node that triggers burst damage and knockback when an enemy enters its radius. Soldier-specific modes: `suppression_burst` schedules short repeated line shots, `grenade_cook` telegraphs then detonates a delayed AoE with falloff, and `bayonet_brace` checks a forward corridor for one hit per enemy during the brace window. Thief-specific modes: `coin_ricochet` chains between nearby enemies and can steal money, `shadow_backstab` repositions behind a target before striking, and `smoke_bomb` creates a delayed AoE plus temporary dodge. Elementalist-specific modes: `elemental_orbit` runs short orbiting AoE ticks around the player, `prism_rift` lays two crossing beams on a target, and `meteor_shards` delays an impact then spawns shard bursts. Sniper-specific modes: `sniper_lockshot` locks one target after a short telegraph, `sniper_kill_zone` rains several precision beams inside a marked area, and `sniper_split_round` branches from a primary shot into nearby enemies. Priest-specific modes: `priest_sanctify` delays a holy mark explosion, `priest_ward` pulses protective circles from the player, and `priest_prayer_chain` bounces a sustain tether between enemies. Biologist-specific modes: `bio_spore_bloom` grows expanding target-centered spore rings, `bio_sample_dart` follows a direct sample hit with delayed analysis pulses, and `bio_symbiote_web` links the primary target to nearby enemies with a damage-sharing web. Robot-specific modes: `robot_magnetic_anchor` pulls enemies toward a marked target before impact, `robot_compression_line` compresses enemies toward a line axis, and `robot_reactor_vent` emits four short directional vents around the player. Engineer-specific modes: `engineer_sentry_link` deploys a temporary sentry beam node, `engineer_repair_drone` chains damage into small self-repair, and `engineer_pressure_mines` fans out independent mines. Deploy visuals use data-driven source textures when configured: `sound_amp` uses `deploy_sound_amp_field.png`, while `raven_totem` uses `deploy_raven_totem_field.png`; other deploy/trap visuals fall back to each weapon's `WeaponVisual` texture.

## Visual Asset Status

Design visual set is complete for the first 9 classes and 27 weapons as of 2026-06-11. SCRUM-168 adds Soldier as a Back-end class with canonical Soldier character/weapon PNG paths connected; rig/motion remains Animator handoff. SCRUM-169 adds Thief as Back-end gameplay with canonical Thief character/weapon PNG paths connected; rig/motion is `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_sniper_rig_motion_task.md`. SCRUM-165 adds Priest gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_priest_rig_motion_task.md`. SCRUM-162 adds Biologist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_biologist_rig_motion_task.md`. SCRUM-166 adds Robot gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_robot_rig_motion_task.md`. SCRUM-164 adds Engineer gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_engineer_rig_motion_task.md`. Weapon art v2 pass 2026-06-12 reduced oversized socket visuals, fixed scene texture fallbacks, and replaced the Knight visual stack: `assets/sprites/characters/knight.png` is now an unarmed base sprite, while `long_spear.png`, `tower_shield.png`, and `holy_flail.png` are separate polished noble knight weapons. New class full-art PNGs are art-approved at `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). The first 27 weapon PNGs in the matrix above exist at their canonical `assets/sprites/weapons/*.png` paths (`256x256`, transparent), including the 12 formerly fallback weapons:
`shadow_daggers`, `venom_wire`, `storm_longbow`, `hunter_trap`, `plague_syringe`, `bone_saw`, `acid_flask`, `homunculus_vial`, `tower_shield`, `holy_flail`, `briar_staff`, `raven_totem`.

Socket/display status: the original 27 weapon scenes point to matching canonical PNG and use reduced `WeaponVisual.scale` for clearer body/face readability. Soldier scenes point to canonical `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`. Preview sheets: `docs/design/previews/weapon_v2_assets_contact.png` for raw PNG QA and `docs/design/previews/weapon_v2_socket_contact.png` for class/weapon visual placement. `venom_wire` is intentionally thin and best paired with a separate line/VFX during attacks; `hunter_trap` and several deploy/summon weapons can also serve as world sprite bases.

Source-specific summon/deploy visuals (SCRUM-157): `scripts/summoner_weapon.gd` reads `ally_visual_id` / `ally_visual_ids` and passes the selected ID into `AllyMinion.set_visual_id()`. `summon_amulet` randomly uses `ally_druid_beast` or `ally_druid_pack_spirit`; `homunculus_vial` uses `ally_homunculus`; `leadership_echo` is reserved for future echo-style summons. `scripts/class_weapon.gd` reads optional `deploy_texture_path`: `sound_amp` deploys `deploy_sound_amp_field.png`, while `raven_totem` deploys `deploy_raven_totem_field.png`.

Summon role runtime (SCRUM-254): summon/deploy configs may define `summon_role` and role coefficients. `SummonerWeapon` builds an `AllyMinion.set_combat_profile()` payload from owner `derived_parameters` and Leadership: damage, move speed, attack interval, lifetime, max HP, control knockback and support healing. Current roles are `pack_damage` (Druid beasts), `tank_control` (Chemist homunculus), `support_totem` (Druid raven totem), `engineer_sentry` and `support_drone`. `ProgressionData.weapon_archetype()` treats `summon_role` weapons as summon archetype, and the balance harness models pure summon DPS through minion output rather than an invisible direct hit.

## Targeting Rule

Все атакующие оружия игрока целятся в ближайшего живого врага, а не в направление движения. Без врагов сохраняется последнее направление атаки.

## Cleanup Rules

- При смене персонажа/оружия/забега/смерти/возврате в меню временные weapon effects очищаются.
- Deployables/traps/totems/summons должны быть в `player_weapon_effects` и не оставаться на карте после cleanup.
- Class-specific leftovers не должны оставаться на карте.
