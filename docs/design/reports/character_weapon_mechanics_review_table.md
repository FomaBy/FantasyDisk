# Character/Weapon Mechanics Review Table

Дата: 2026-07-08  
Jira: SCRUM-878  
Scope: documentation/review artifact only. Gameplay, balance numbers, visuals and runtime files were not changed.

## Sources

- `scripts/progression_data_weapons.gd`: current `WEAPONS_BY_CLASS` and weapon configs.
- `scripts/progression_data_characters.gd`: character names, base class identity and weapon identity text.
- `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/summoner_weapon.gd`, `scripts/player.gd`: runtime attack modes, deploy/summon/drain/block hooks and scaling helpers.
- `docs/design/systems/characters_weapons.md`, `docs/design/mechanics_extract.md`, `docs/design/systems/combat.md`: current system documentation.
- `docs/design/reports/full_class_rebalance_identity_audit.md`: prior SCRUM-856 identity audit baseline.

## Class Kit Summary

| Character | ID | Main fantasy | Three weapon roles |
| --- | --- | --- | --- |
| Берсерк | `berserk` | High-risk physical melee with frontal pressure. | `sword` = long narrow commit; `axe` = broad close cleave; `hammer` = short circular slam/stagger. |
| Солдат | `soldier` | Tactical line control, explosives and bracing. | `soldier_rifle` = suppression line burst; `soldier_grenade` = delayed fuse AoE; `soldier_bayonet` = defensive forward brace. |
| Вор | `thief` | Agile trickster with ricochet, backstab and smoke. | `thief_coin_pouch` = chain ricochet/economy; `thief_shadow_cloak` = phantom backstab; `thief_smoke_bomb` = delayed smoke plus dodge window. |
| Элементалист | `elementalist` | Elemental AoE caster with orbit, rift and meteor setup. | `elementalist_orb_ring` = orbit ticks; `elementalist_prism_focus` = crossed rift beams; `elementalist_meteor_core` = long-cast impact plus shards. |
| Снайпер | `sniper` | Long-range precision, marks and trajectories. | `sniper_deadeye_rifle` = lockshot; `sniper_spotter_scope` = kill-zone marking; `sniper_shatter_rounds` = split fan shot. |
| Священник | `priest` | Holy sustain through marks, wards and prayer chains. | `priest_reliquary` = sanctify burst/heal; `priest_censer` = protective ward pulses; `priest_chime` = sustain chain. |
| Биолог | `biologist` | Bio-reactions, spores, samples and symbiotic links. | `biologist_spore_lens` = expanding spore rings; `biologist_sample_injector` = dart plus analysis pulses; `biologist_symbiote_seed` = linked web damage. |
| Робот | `robot` | Heavy tank-control through magnetism, compression and reactor vents. | `robot_magnetic_anchor` = pull-in anchor; `robot_hydraulic_press` = compression corridor; `robot_reactor_core` = four close vents/knockback. |
| Инженер | `engineer` | Device commander with turrets, repair and mines. | `engineer_sentry_wrench` = temporary sentry beams; `engineer_repair_drone` = repair chain; `engineer_pressure_mines` = persistent mine grid. |
| Темный маг | `dark_mage` | Glass AoE caster with curses, projectiles and pierce beams. | `dark_book` = double AoE projectile; `cursed_skull` = homing DoT curse; `dark_wand` = decaying pierce beams. |
| Гитарист | `guitarist` | Sound/control class with rhythm and knockback. | `electric_guitar` = directed sound wave; `bass_guitar` = frequent circular pulse; `sound_amp` = deploy amp pulses. |
| Ассасин | `assassin` | Crit tempo, return corridors, flurry and poison line. | `chakrams` = boomerang path; `shadow_daggers` = close stab flurry plus shadow momentum; `venom_wire` = poison pierce line plus shadow momentum. |
| Рейнджер | `ranger` | Stance-charge long range with traps. | `moon_crossbow` = charged single pierce; `storm_longbow` = charged beam fan; `hunter_trap` = armed trap burst/knockback. |
| Доктор | `doctor` | Self-sustain only through weapon drain and close medical risk. | `restore_potion` = drain link; `plague_syringe` = plague DoT drain; `bone_saw` = close saw flurry with small heal. |
| Химик | `chemist` | Reagent AoE, pools and homunculus body control. | `blast_powder` = explosion plus spark cloud; `acid_flask` = persistent acid pool; `homunculus_vial` = temporary tank-control summon. |
| Рыцарь | `knight` | Tank/control with block, counter and heavy melee. | `long_spear` = long strip poke; `tower_shield` = frontal block/counter bash; `holy_flail` = circular holy control/counter. |
| Друид | `druid` | Leadership summon/nature control. | `summon_amulet` = commanded beast pack; `briar_staff` = thorn DoT zone; `raven_totem` = support/control totem. |

## Weapon Mechanics Table

| Character | Weapon | Attack mode | Main distinctive mechanics | Utility / scaling hook | Review note |
| --- | --- | --- | --- | --- | --- |
| Берсерк | `sword` / Двуручный меч | `sweep` | 100 degree long forward sector, 350px reach, precise melee commit. | Physical melee; passive damage bonus; sector upgrades widen angle, radius upgrades extend reach. | Already the clean "long narrow" Berserk option. |
| Берсерк | `axe` / Двуручный топор | `sweep` | 180 degree shorter cleave around nearest target, close pack pressure. | Physical melee; close bonus and arc follow-up; radius/sector scaling. | Needs to stay broad cleave, not become a second sword. |
| Берсерк | `hammer` / Двуручный молот | `circle` | 150px circular slam around player, target diminishing in dense packs. | Physical melee; close damage bonus, strong stagger knockback, Radius growth. | Main review question: should slam gain a clearer risk/payoff window or control effect? |
| Солдат | `soldier_rifle` / Аркебуза строя | `suppression_burst` | Three fast line shots; primary target takes full damage, corridor enemies take reduced suppression damage. | Physical/perception line weapon; mild knockback; range passive. | Good tactical identity if suppression/control is visible enough. |
| Солдат | `soldier_grenade` / Граната с фитилем | `grenade_cook` | Projectile lands without damage, waits for fuse, then telegraphed radial explosion with edge falloff. | Delayed physical AoE; radius passive; knockback. | Strong delayed-AoE exemplar; other delayed weapons should not copy it too closely. |
| Солдат | `soldier_bayonet` / Штык-стойка | `bayonet_brace` | Short forward brace/corridor; each enemy can be hit once during brace window. | Defensive melee; knockback/stagger; small defense passive. | Candidate for stronger "hold the line" counter identity. |
| Вор | `thief_coin_pouch` / Кошель Рикошета | `coin_ricochet` | Coin chains between nearby targets with damage falloff. | Agility/economy hook; steals small gold from early hits; money passive. | Must differ from priest chain by feeling like bounce/economy, not sustain. |
| Вор | `thief_shadow_cloak` / Плащ Захода | `shadow_backstab` | Phantom strikes behind nearest target and splashes nearby enemies without moving hero. | Crit/dodge fantasy; dodge and crit passives. | Review whether "shadow backstab without teleport" is readable enough in combat. |
| Вор | `thief_smoke_bomb` / Дымовая Бомба | `smoke_bomb` | Smoke lands, delays, bursts in an area, and gives a temporary dodge bonus. | Evasion/control; move-speed passive. | Should lean utility/control so it is not just a small grenade. |
| Элементалист | `elementalist_orb_ring` / Кольцо Трех Стихий | `elemental_orbit` | Three orbiting elemental bodies tick around the hero over a short duration. | Magic AoE; radius passive; close-orbit positioning risk. | Distinct rhythm; keep as moving orbit, not static aura. |
| Элементалист | `elementalist_prism_focus` / Призматический Фокус | `prism_rift` | Cross-shaped rift: two beam lines converge on target after telegraph. | Magic geometry; range passive. | Could use stronger intersection/geometry payoff to avoid "delayed beam" feel. |
| Элементалист | `elementalist_meteor_core` / Ядро Метеора | `meteor_shards` | Long cast from above, heavy central impact plus 5 secondary shard zones. | Magic delayed AoE; damage passive. | Should feel slower/heavier than grenade; shards are the key differentiator. |
| Снайпер | `sniper_deadeye_rifle` / Винтовка Мертвого Глаза | `sniper_lockshot` | Short lock/telegraph, then narrow long precision shot with overpenetration/falloff. | Physical precision; crit passive; very long range. | Keep elite/boss focus; do not solve crowd weakness by flattening it into split shot. |
| Снайпер | `sniper_spotter_scope` / Прицел Наводчика | `sniper_kill_zone` | Marks a target area and calls several precision beams into enemies inside it. | Physical setup zone; range passive. | Needs to feel like marked kill-zone, not generic delayed AoE. |
| Снайпер | `sniper_shatter_rounds` / Осколочные Патроны | `sniper_split_round` | Primary shot then fixed fan of shard trajectories; shards can pierce limited targets. | Physical split/pierce; crit-damage passive. | Good if branches visibly originate from the first shot, unlike ricochet chains. |
| Священник | `priest_reliquary` / Светлый Реликварий | `priest_sanctify` | Marks nearest target, then holy sign detonates around it. | Magic sustain; small heal from damage; regeneration passive. | Sustain payoff should stay tied to sanctified target/mark. |
| Священник | `priest_censer` / Кадило Обета | `priest_ward` | Several protective pulses around the owner. | Magic close defense; heal-on-attack; defense passive. | Strong defensive rhythm; value as ward/control rather than only DPS. |
| Священник | `priest_chime` / Колокол Молитвы | `priest_prayer_chain` | Prayer chain jumps between enemies, scoring next target toward owner-side sustain arc. | Magic chain sustain; heal from damage; aura radius passive. | Must feel holy/sustain-return, not coin ricochet. |
| Биолог | `biologist_spore_lens` / Споровая Линза | `bio_spore_bloom` | Three expanding spore rings grow on target with damage falloff. | Magic/DoT biology; dot damage passive. | Clear identity; avoid turning it into another poison pool. |
| Биолог | `biologist_sample_injector` / Инъектор Образцов | `bio_sample_dart` | Direct sample dart, then delayed analysis pulses hit target and nearby tissue. | Magic sample analysis; crit passive; delayed secondary pulses. | Useful "damaging projectile without landing explosion" reference. |
| Биолог | `biologist_symbiote_seed` / Семя Симбионта | `bio_symbiote_web` | Primary target links to nearby enemies and shares bio damage through a web. | Magic network/sustain hint; aura passive; small heal percentage in config. | Review whether web damage-sharing is visible enough to sell the mechanic. |
| Робот | `robot_magnetic_anchor` / Магнитный Якорь | `robot_magnetic_anchor` | Anchor marks a target, pulls nearby enemies inward, then pulses damage. | Physical tank-control; absorb passive; knockback/pull utility. | Excellent control fantasy; review if pull is strong/readable enough. |
| Робот | `robot_hydraulic_press` / Гидравлический Пресс | `robot_compression_line` | Two jaws compress a line corridor and push enemies toward its axis. | Physical line control; defense passive; close/stagger hooks. | Should read as compression, not ordinary beam. |
| Робот | `robot_reactor_core` / Реакторное Ядро | `robot_reactor_vent` | Four directional vents fire around player to clear close space. | Physical close control; knockback; regeneration passive. | Needs to stay directional vent windows, not generic circular pulse. |
| Инженер | `engineer_sentry_wrench` / Ключ Часового | `engineer_sentry_link` | Deploys short-lived sentries; sentries fire autonomous beams, remember per-cycle targets, and add capped splash. | Device/turret DPS; Leadership/summon scaling; active cap 5; summon bonus passive. | Review placement/retarget/reload feel before touching multipliers. |
| Инженер | `engineer_repair_drone` / Ремонтный Дрон | `engineer_repair_drone` | Chain/tether damage through enemies and returns part as repair. | Support drone; capped repair/sustain; regeneration passive. | Needs to differ from priest chain by being mechanical owner-tether repair. |
| Инженер | `engineer_pressure_mines` / Минная Сетка | `engineer_pressure_mines` | Three independent mines fan out, persist, and tick while enemies stand inside. | Route-control device; mine grid deploy role; radius passive. | Good zone ownership candidate; review arming/trigger spacing. |
| Темный маг | `dark_book` / Книга тьмы | `aoe_projectile` | Two AoE projectiles seek nearest targets and explode. | Magic AoE; radius passive. | Current weakest identity row: may need void collapse/curse interaction to avoid generic AoE projectile. |
| Темный маг | `cursed_skull` / Проклятый череп | `homing_curse` | Homing curse hit, 5 DoT ticks, decayed splash around target. | Magic DoT/curse; damage falloff; damage passive penalty. | Keep curse duration/mark value distinct from simple projectile. |
| Темный маг | `dark_wand` / Темная палочка | `beam` | Two pierce beams in a fan; damage decays after each target. | Magic pierce; range passive. | Needs void/decay flavor so it does not overlap ranger beams. |
| Гитарист | `electric_guitar` / Электрогитара | `sound_wave` | Wide directed wave forward with knockback. | Sound/control; attack-speed passive. | Strong flagship identity. |
| Гитарист | `bass_guitar` / Бас-гитара | `pulse` | Frequent low-damage circular pulse with high knockback. | Sound close control; attack-speed passive. | Should be a rhythm/control metronome rather than a DPS circle. |
| Гитарист | `sound_amp` / Звуковой усилитель | `amp` | Deploy amp stays about 7s and pulses autonomously. | Stage deploy; Leadership-scaled active count capped at 3; pickup passive. | Distinguish from raven totem through stage/knockback/control feel. |
| Ассасин | `chakrams` / Чакрамы | `boomerang` | Corridor damage outward and on return path. | Physical crit-friendly; crit shadow burst; crit passive. | Good geometry; keep return path as identity. |
| Ассасин | `shadow_daggers` / Теневые кинжалы | `stab_flurry` | Fast short multi-stab wave against nearby targets. | Close risk/crit; execute, shadow burst, capped `shadow_momentum` from kills. | Review whether close-risk payoff is enough to justify range. |
| Ассасин | `venom_wire` / Ядовитая струна | `dot_beam` | Thin poison garrote line that pierces and applies DoT. | Physical/DoT line; capped `shadow_momentum` from kills. | Should become poison ramp/execute line, not just another pierce beam. |
| Рейнджер | `moon_crossbow` / Лунный арбалет | `beam` | Charged single piercing shot; standing still increases payoff. | Physical precision; long range; range passive. | Keep as single charged line. |
| Рейнджер | `storm_longbow` / Грозовой длинный лук | `beam` | Charged fan of three long beams with pierce. | Physical fan control; range plus slower tempo passive. | Good if stance-charge is visible. |
| Рейнджер | `hunter_trap` / Охотничий капкан | `trap` | Places trap in front; first enemy triggers burst and knockback. | Deploy trap; charge speeds/boosts setup; pickup passive. | Needs arming/placement identity so it is not a mine clone. |
| Доктор | `restore_potion` / Зелье восстановления | `drain_link` | Drain beam to nearest target; damage heals Doctor. | Magic sustain only; capped drain budget; max HP passive. | Review whether "potion" fantasy still matches current link implementation. |
| Доктор | `plague_syringe` / Чумной шприц | `drain_link` | Thin plague link with DoT ticks and partial healing. | Magic DoT sustain; capped drain; max HP passive. | Should spread/ramp plague differently from restore potion link. |
| Доктор | `bone_saw` / Костяная пила | `stab_flurry` | Short saw/flurry arc with bleed-like DoT and small per-hit heal. | Close physical sustain; small defense passive; capped heal path. | Strong risky sustain role; review close combat feel. |
| Химик | `blast_powder` / Взрывная пыль | `aoe_projectile` | AoE explosion plus spark cloud; cloud ticks for 3s and can combo. | Magic reagent burst; persistent pool with combo cloud flag; radius passive. | Needs to emphasize cloud/combo, not only landing explosion. |
| Химик | `acid_flask` / Кислотная колба | `aoe_projectile` | Weak landing burst, larger persistent acid/poison pool with frequent DoT ticks. | Magic area denial; persistent pool/combo; radius passive. | Good as lingering denial if stacking/cap rules are clear. |
| Химик | `homunculus_vial` / Склянка гомункула | `summon` | Summons temporary homunculus with tank-control profile. | Magic summon; max 2 base; Leadership/summon_amount scale bulk, splash, tempo and lifetime. | Should be body-blocking control tank, not extra generic DPS pet. |
| Рыцарь | `long_spear` / Копье | `strip` | Long narrow 90x540 thrust/strip. | Physical tank poke; defense, block and light counter passive. | Healthy reach/control lane. |
| Рыцарь | `tower_shield` / Башенный щит | `sweep` | Short frontal bash/control cone. | Strongest block reduction, HP/defense passive, frontal counter/knockback/stagger. | Prime candidate for explicit shield counter gameplay. |
| Рыцарь | `holy_flail` / Освященный кистень | `circle` | Medium circular heavy swing with holy-control feel. | Physical tank AoE; broad circular counter and knockback passive. | Needs to differ from hammer with holy/control/counter role. |
| Друид | `summon_amulet` / Амулет призыва | `summon` | Commanded beast pack, prefilled at battle start and replenished over time. | Leadership summon; max 3 base; pack_damage role, splash scales with level progression. | Review command distribution/body-blocking so pets feel directed. |
| Друид | `briar_staff` / Посох терний | `aoe_projectile` | Thorn seed creates persistent briar DoT zone. | Sound/nature damage channel; persistent pool; radius passive. | Should lean thorn slow/root/control rather than acid-pool clone. |
| Друид | `raven_totem` / Вороний тотем | `amp` | Deploy totem pulses autonomously for 6.5s. | Support totem; Leadership-scaled active count capped at 3; small support heal/control hooks. | Distinguish from sound amp through command aura/support behavior. |

## Cross-Kit Review Hotspots

| Hotspot | Weapons to compare during design review | Why it matters |
| --- | --- | --- |
| Delayed AoE family | `soldier_grenade`, `elementalist_meteor_core`, `thief_smoke_bomb`, `sniper_spotter_scope`, `priest_reliquary` | All are "wait, then payoff" unless timing, target rule and reward are deliberately different. |
| Generic AoE projectile family | `dark_book`, `blast_powder`, `acid_flask`, `briar_staff`, old fantasy of `restore_potion` | Several can feel like colored explosions/pools unless each has a unique non-landing mechanic. |
| Chain/split/pierce family | `thief_coin_pouch`, `sniper_shatter_rounds`, `priest_chime`, `engineer_repair_drone`, `dark_wand`, `moon_crossbow`, `storm_longbow`, `chakrams`, `venom_wire` | These all distribute damage along targets or lines; retarget rules and feedback must carry the difference. |
| Deploy/summon ownership | `sound_amp`, `hunter_trap`, `engineer_sentry_wrench`, `engineer_pressure_mines`, `homunculus_vial`, `summon_amulet`, `raven_totem` | Placement, active caps, lifetime, arming, retarget cadence and body-blocking matter more than raw DPS. |
| Sustain mechanics | `restore_potion`, `plague_syringe`, `bone_saw`, `priest_reliquary`, `priest_censer`, `priest_chime`, `engineer_repair_drone` | Heal is capped in runtime, but the product feel depends on why the heal happens. |
| Tank/counter melee | `soldier_bayonet`, `robot_*`, `long_spear`, `tower_shield`, `holy_flail`, `hammer`, `bone_saw`, `shadow_daggers` | High EHP or short range alone is not enough; readable guard, stagger, counter or execute windows should sell the role. |
