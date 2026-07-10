# Characters And Weapons

Обновлено: 2026-07-04

Канонические данные персонажей и оружия доступны через compatibility facade `scripts/progression_data.gd`; после SCRUM-198 исходные домены живут в `scripts/progression_data_characters.gd` и `scripts/progression_data_weapons.gd`. Этот файл описывает игровую идентичность, сцены и текущие backend-режимы.

## Characters

| Character ID | Role |
| --- | --- |
| `berserk` | melee sector/circle fighter, высокий риск рядом с толпой |
| `soldier` | double-action physical fighter: explosive arquebus bullet, slow fuse grenade nuke, bayonet melee cone; каждое действие с шансом 50% происходит дважды |
| `thief` | economy/evasion trickster (SCRUM-897): trait-магнит подбора, монетный рикошет с мгновенным золотом, паралич-кинжал, позиционное дым-облако уклонения |
| `elementalist` | pure-mage зонер (SCRUM-947..950): trait «Проводник стихий» — все magic-tagged бонусы ×1.30; квадрат четырёх стихий, полнокартный X-разлом, самый медленный тяжёлый метеор |
| `sniper` | long-range precision class: lockshot, kill-zone marking, split rounds |
| `priest` | holy sustain caster: sanctify marks, ward pulses, prayer chains |
| `biologist` | bio-reaction scientist: spore blooms, sample analysis, symbiote webs |
| `robot` | heavy tank-control construct: magnetic pulls, compression lines, reactor vents |
| `engineer` | mechanical summoner/support: sentry links, repair drone sustain, pressure mine grid |
| `dark_mage` | caster: цепные снаряды, curse-прожиг, зеркальные AoE-взрывы; убитые взрываются (trait «Тёмный распад») |
| `guitarist` | sound/control: waves, knockback, deployable amp |
| `assassin` | хрупкий crit-скейлер (trait «Хладнокровие»: кап крита 100%, избыток → крит-урон): дуговой boomerang, point-blank flurry с рывком темпа, poison line от героя; выживает уворотом («Теневая завеса») |
| `ranger` | дальний точный контроль: piercing shots, fan beams, trap |
| `doctor` | weapon-only sustain (SCRUM-900): trait «Клятва чумного доктора» — generic реген/вампиризм/kill-heal не действуют; лечится только уроном своего оружия (зелье-AoE, чума со спредом, сектор-пила) |
| `chemist` | catalyst-периодика (+50%): быстрый физический AoE, вечные кислотные заряды из луж, постоянная пара гомункулов танк+кастер |
| `knight` | tank/control melee: spear strip, shield bash, circular flail |
| `druid` | summon/nature control: beast pack, thorn zones, raven totem |

## Weapon Matrix

У каждого класса ровно 3 выбираемых стартовых оружия. Все варианты выбираются через `ProgressionData.WEAPONS_BY_CLASS` и передаются в `Player.configure_character(character_id, weapon_id)`.

SCRUM-856 закрепляет class-trio identity audit как baseline для полной rebalance
волны: `docs/design/reports/full_class_rebalance_identity_audit.md`. Численные
гейты по 51 паре класс+оружие сейчас PASS, но downstream SCRUM-857..860 должны
разводить похожие оружия механикой кита (дистанция/риск, геометрия, задержка,
chain/split/pierce, deploy/summon поведение, sustain/defense окно), а не только
множителями урона.

SCRUM-857 реализует первый mechanic-first pass для projectile/chain/pierce и
delayed-AoE family: grenade не наносит урон до окончания fuse, meteor стал
долгим high-payoff impact с shard-зонами, sniper shatter расходится веером по
траекториям вместо nearest-chain, priest prayer chain выбирает sustain-дугу к
владельцу, а dark pierce/curse получают decay.

| Class | Weapon ID | Name | Scene | Backend Mode | Gameplay Identity |
| --- | --- | --- | --- | --- | --- |
| `berserk` | `sword` | Двуручный меч | `TwoHandedSword.tscn` | `sweep` | Узкий дальний сектор 100 градусов радиуса 350; секторные бонусы расширяют угол, Radius расширяет дальность |
| `berserk` | `axe` | Двуручный топор | `TwoHandedAxe.tscn` | `sweep` | Широкий сектор 180 градусов радиуса 250 по ближайшему монстру |
| `berserk` | `hammer` | Двуручный молот | `TwoHandedHammer.tscn` | `circle` | Круговой slam радиуса 150; Radius увеличивает круг, секторные бонусы не влияют, плотные паки получают target diminishing |
| `soldier` | `soldier_rifle` | Аркебуза строя | `SoldierRifle.tscn` | `arquebus_shot` | Частая одиночная взрывная пуля: видимый снаряд летит далеко и взрывается малым AoE с falloff |
| `soldier` | `soldier_grenade` | Граната с фитилем | `SoldierGrenade.tscn` | `grenade_fuse` | Медленный полёт (кап скорости ~460) + видимый фитиль после посадки; тяжёлый редкий взрыв с falloff, урон только на взрыве |
| `soldier` | `soldier_bayonet` | Штык-стойка | `SoldierBayonet.tscn` | `bayonet_cone` | Ближний сектор 105 градусов без мёртвой зоны у ног: укол+knockback каждому в конусе; редкий авто-выстрел по цели за конусом |
| `thief` | `thief_coin_pouch` | Кошель Рикошета | `ThiefCoinPouch.tscn` | `coin_ricochet` | SCRUM-897: цепь из 6 прыжков (кап прогрессии 8), урон монотонно убывает до 50% ролла к последнему прыжку; золото начисляется мгновенно (без пикапа) с первых 3 целей |
| `thief` | `thief_shadow_cloak` | Отравленный Кинжал | `ThiefShadowCloak.tscn` | `shadow_backstab` | SCRUM-897: фантомный кинжал бьёт за ближайшей целью БЕЗ движения героя; встроенный паралич-яд 0.85с (кап 1.8с, босс/элита ×0.25), удар в спину ×1.35, соседям 0.35 ролла |
| `thief` | `thief_smoke_bomb` | Дымовая Бомба | `ThiefSmokeBomb.tscn` | `smoke_bomb` | SCRUM-897: брошенный снаряд (фитиль 0.5с) → одно AoE-событие урона → НЕдамажащее облако 2.6с; уклонение +0.35 только внутри облака, суммарный кап в дыму 0.90 |
| `elementalist` | `elementalist_orb_ring` | Кольцо Четырёх Стихий | `ElementalistOrbRing.tscn` | `elemental_orbit` | SCRUM-948: квадратная AoE в точке каста — тики бьют тремя каналами (магия+физика+ожог) и отбрасывают врагов от центра |
| `elementalist` | `elementalist_prism_focus` | Призматический Фокус | `ElementalistPrismFocus.tscn` | `prism_rift` | SCRUM-949: полнокартный X-разлом — две диагонали (плечи 4800px ≥ диагонали арены) пронзают всё на пути, центр пересечения бьёт бонус-AoE |
| `elementalist` | `elementalist_meteor_core` | Ядро Метеора | `ElementalistMeteorCore.tscn` | `meteor_shards` | SCRUM-950: самое медленное оружие игрока (fire_interval 4.50) — телеграф+падение (1.30с), тяжёлый magic-взрыв с falloff и догорающая DoT-зона |
| `sniper` | `sniper_deadeye_rifle` | Винтовка Мертвого Глаза | `SniperDeadeyeRifle.tscn` | `sniper_lockshot` | Дальний lockshot: короткий прицел, затем точный beam по locked target и falloff по линии |
| `sniper` | `sniper_spotter_scope` | Прицел Наводчика | `SniperSpotterScope.tscn` | `sniper_kill_zone` | Маркирует kill-zone у ближайшей цели и вызывает несколько точных sky-beam попаданий |
| `sniper` | `sniper_shatter_rounds` | Осколочные Патроны | `SniperShatterRounds.tscn` | `sniper_split_round` | Основной дальний выстрел раскалывается веером по траекториям; осколки pierce до 2 целей |
| `priest` | `priest_reliquary` | Светлый Реликварий | `PriestReliquary.tscn` | `priest_sanctify` | Отмечает ближайшую цель и взрывает священную область с sustain-heal от урона |
| `priest` | `priest_censer` | Кадило Обета | `PriestCenser.tscn` | `priest_ward` | Несколько защитных волн вокруг героя, ближний контроль и малое лечение |
| `priest` | `priest_chime` | Колокол Молитвы | `PriestChime.tscn` | `priest_prayer_chain` | Молитвенная цепь выбирает sustain-дугу между врагами ближе к владельцу и возвращает heal |
| `biologist` | `biologist_spore_lens` | Споровая Линза | `BiologistSporeLens.tscn` | `bio_spore_bloom` | Три расширяющихся споровых кольца на цели с убывающим уроном |
| `biologist` | `biologist_sample_injector` | Инъектор Образцов | `BiologistSampleInjector.tscn` | `bio_sample_dart` | Прямой sample dart и delayed analysis pulses по ближайшим тканям |
| `biologist` | `biologist_symbiote_seed` | Семя Симбионта | `BiologistSymbioteSeed.tscn` | `bio_symbiote_web` | Симбиотическая сеть связывает первичную цель с соседними врагами |
| `robot` | `robot_magnetic_anchor` | Магнитный Якорь | `RobotMagneticAnchor.tscn` | `robot_magnetic_anchor` | Target-centered magnetic anchor pulls nearby enemies inward and detonates |
| `robot` | `robot_hydraulic_press` | Гидравлический Пресс | `RobotHydraulicPress.tscn` | `robot_compression_line` | Two pressure jaws compress a line corridor and push enemies toward its axis |
| `robot` | `robot_reactor_core` | Реакторное Ядро | `RobotReactorCore.tscn` | `robot_reactor_vent` | Four directional reactor vents clear close-range space around the player |
| `engineer` | `engineer_sentry_wrench` | Ключ Часового | `EngineerSentryWrench.tscn` | `engineer_sentry_link` | `turret_dps`: temporary sentries remember targets per cycle, spread beam shots, and add small capped splash |
| `engineer` | `engineer_repair_drone` | Ремонтный Дрон | `EngineerRepairDrone.tscn` | `engineer_repair_drone` | Chain drone links enemies and repairs owner from damage |
| `engineer` | `engineer_pressure_mines` | Минная Сетка | `EngineerPressureMines.tscn` | `engineer_pressure_mines` | Three pressure mines fan out and trigger independently |
| `dark_mage` | `dark_book` | Книга тьмы | `DarkBook.tscn` | `dark_mirror_blast` | Пара взрывов: по цели и в зеркальной точке относительно мага (SCRUM-941) |
| `dark_mage` | `cursed_skull` | Проклятый череп | `CursedSkull.tscn` | `skull_curse_burn` | Curse-only зона: без прямого урона, частые dot-тики по проклятым; тик = dot_damage × mult × (1 + Int × curse_int_scale), magic-множители не участвуют (SCRUM-940) |
| `dark_mage` | `dark_wand` | Темная палочка | `DarkWand.tscn` | `dark_chain_burst` | Цепной снаряд до 3 целей с малым AoE-бурстом на каждом попадании (SCRUM-939) |
| `guitarist` | `electric_guitar` | Электрогитара | `ElectricGuitar.tscn` | `sound_wave` | Направленная звуковая волна |
| `guitarist` | `bass_guitar` | Бас-гитара | `BassGuitar.tscn` | `pulse` | Частый круговой pulse/knockback |
| `guitarist` | `sound_amp` | Звуковой усилитель | `SoundAmp.tscn` | `amp` | `stage_pulse`: deploy amp, autonomous pulses, cleanup, capped deploy count |
| `assassin` | `chakrams` | Чакрамы | `Chakrams.tscn` | `boomerang` | SCRUM-894: коридор к цели + возврат ЛЕВОЙ дугой (`return_arc_offset`); правильная позиция даёт double-pass, гейт 1+1 хит на цель за каст |
| `assassin` | `shadow_daggers` | Теневые кинжалы | `ShadowDaggers.tscn` | `stab_flurry` | SCRUM-894: сектор + point-blank покрытие вокруг героя (`point_blank_radius`); серия по врагам даёт «Рывок темпа» (`flurry_tempo_*`: скорость+уворот, кулдаун) |
| `assassin` | `venom_wire` | Ядовитая струна | `VenomWire.tscn` | `dot_beam` | SCRUM-894: poison-линия ОТ героя + `close_contact_radius` (вплотную не мёртвая зона); крит-снапшот усиливает тики (`dot_crit_snapshot_ratio`) |
| `ranger` | `moon_crossbow` | Лунный арбалет | `MoonCrossbow.tscn` | `beam` | Дальний точный piercing shot |
| `ranger` | `storm_longbow` | Грозовой длинный лук | `StormLongbow.tscn` | `beam` | 3 дальних луча веером |
| `ranger` | `hunter_trap` | Охотничий капкан | `HunterTrap.tscn` | `trap` | Deploy trap: burst + knockback при входе врага |
| `doctor` | `restore_potion` | Зелье восстановления | `RestorePotion.tscn` | `aoe_projectile` | Бросок зелья: магический AoE-взрыв 150r; хил 16% фактического урона через drain-бюджет (SCRUM-900) |
| `doctor` | `plague_syringe` | Чумной шприц | `PlagueSyringe.tscn` | `plague_dart` | Чумной дротик: зараза 24с, ramp тиков 0.45→1.0, спред 22%/тик (радиус 200, кап 10 зараз), хил 12% чумного урона (SCRUM-900) |
| `doctor` | `bone_saw` | Костяная пила | `BoneSaw.tscn` | `saw_sector` | Melee-сектор 135°/215: мультихит с диминишем сверх 4 целей, сильнейший хил кита 34% — только по фронту (SCRUM-900) |
| `chemist` | `blast_powder` | Взрывная пыль | `BlastPowder.tscn` | `aoe_projectile` | SCRUM-943: быстрый ПРЯМОЙ физический close-mid AoE (fire 0.62, r150, range 430), без луж/DoT; trait периодики его не усиливает |
| `chemist` | `acid_flask` | Кислотная колба | `AcidFlask.tscn` | `aoe_projectile` | SCRUM-944: долгая (7с) полупрозрачная лужа; тики пока враг внутри + один ВЕЧНЫЙ кислотный заряд с каждой отдельной лужи (кап 5, артефакт +3), заряды тикают по dot-оси до смерти носителя |
| `chemist` | `homunculus_vial` | Склянка гомункула | `HomunculusVial.tscn` | `summon` | SCRUM-946: постоянная пара — танк (4x max HP Химика, таунт-пульсы, смертен, респавн 4с) + неуязвимый кастер (вне боевого лимита, волны каждые 1.7с вешают вечный DoT-заряд, кап 4; fallback-позиция — плечо Химика) |
| `knight` | `long_spear` | Копье | `LongSpear.tscn` | `strip` | Длинный точечный выпад, легкий frontal block/counter |
| `knight` | `tower_shield` | Башенный щит | `TowerShield.tscn` | `sweep` | Frontal guard/counter, contact-pack control |
| `knight` | `holy_flail` | Освященный кистень | `HolyFlail.tscn` | `circle` | Circular holy control, broad soft counter |
| `druid` | `summon_amulet` | Амулет призыва | `SummonAmulet.tscn` | `summon` | `pack_damage` beast pack scaling from Leadership |
| `druid` | `briar_staff` | Посох терний | `BriarStaff.tscn` | `aoe_projectile` | Thorn zone, AoE DoT, crowd control |
| `druid` | `raven_totem` | Вороний тотем | `RavenTotem.tscn` | `amp` | `support_totem` pulses, Leadership-scaled deploy limit with deploy cap |

## Class Trait: Элементалист «Проводник стихий» (SCRUM-947)

Все magic-tagged источники бонусов магического урона для Элементалиста на 30%
эффективнее (bonus-effectiveness scaling, НЕ флэт-множитель урона): источник
«+15% магического урона» даёт другим классам +14.93% (после глобального softcap
SCRUM-503), а Элементалисту — ровно ×1.30 от этого (+19.41%, UI может округлять
до ~+20%). Точка применения — `ProgressionData.derived_parameters`
(data-driven запись `ProgressionData.CLASS_TRAITS.elementalist.magic_bonus_effectiveness`, реестр traits SCRUM-935).

Детерминированный порядок стакинга (каждый источник усиливается РОВНО один раз,
до перемножения источников; двойного применения при нескольких магических
множителях нет; покрыт `tests/elementalist_kit_test.gd`):

1. забеговый `run_modifiers.magic_damage_multiplier`: softcap SCRUM-503 → ×1.30
   на избыток → `upgrade_damage_exponent`;
2. пассив оружия `passive_mods.magic_damage_multiplier` (класс-прогрессия):
   ×1.30 на бонусную часть;
3. magic-tagged бафы (`prayer_opening_*`): ×1.30 на саму добавку;
4. атрибутный источник: дельта интеллекта НАД базой класса (после growth-скаляра
   `CLASS_LEVEL_STAT_GROWTH_SCALARS`, у Элементалиста 0.92) → ×1.30 только в
   канале `magic_damage`.

НЕ усиливаются: универсальные `damage_multiplier`/`damage_flat` (не magic-tagged),
physical-only и periodic-only (`dot_*`) источники, штрафы (<1.0). Изоляция типов
урона SCRUM-524 не нарушается (интеллект владеет только магией). Плата за trait —
кит отбалансирован от чуть более низкой базы: сохранён growth-скаляр интеллекта
0.92 и умеренные базовые множители при самых медленных интервалах кита.

## Class Trait: Вор «Воровская хватка» (SCRUM-897)

Стартовый радиус подбора Вора сильно увеличен: множитель
`ProgressionData.CLASS_TRAITS.thief.pickup_radius_multiplier` (1.85) применяется
в `ProgressionData.derived_parameters` к СТАРТОВОЙ части формулы
`pickup_radius = (105 + perception×7) × trait + pickup_radius_flat`. Деньги,
опыт и материалы тянутся к Вору с ~298px против ~140-175px у остальных классов
(identity класса, а не бонус одного оружия; `pickup_radius` переведён в
primary-статы Вора). Flat-источники забега (артефакт «Магнитный кошель» +90 и
т.п.) добавляются ПОВЕРХ без trait-усиления — рост ограничен, runaway невозможен.
Покрыт `tests/thief_kit_test.gd`.

## Backend Modes

- `scripts/berserk_weapon.gd`: `frustum`, `strip`, `sweep`, `circle`; melee damage window is synced with swing timing.
- `scripts/class_weapon.gd`: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`, `arquebus_shot`, `grenade_fuse`, `bayonet_cone`, `coin_ricochet`, `shadow_backstab`, `smoke_bomb`, `elemental_orbit`, `prism_rift`, `meteor_shards`, `sniper_lockshot`, `sniper_kill_zone`, `sniper_split_round`, `priest_sanctify`, `priest_ward`, `priest_prayer_chain`, `bio_spore_bloom`, `bio_sample_dart`, `bio_symbiote_web`, `robot_magnetic_anchor`, `robot_compression_line`, `robot_reactor_vent`, `engineer_sentry_link`, `engineer_repair_drone`, `engineer_pressure_mines`.
- `scripts/summoner_weapon.gd`: summon weapon wrapper for Druid and Chemist minion styles.

`stab_flurry` hits several nearest enemies inside a short wave-shaped melee zone. `dot_beam` is a pierce line that applies DoT. `trap` deploys a node that triggers burst damage and knockback when an enemy enters its radius. Soldier-specific modes (SCRUM-936/937/938): `arquebus_shot` fires one visible explosive bullet that detonates in a small radial-falloff AoE at the hit point; `grenade_fuse` lobs a slow capped-speed projectile that lands, burns a visible fuse (`grenade_delay`), and only then detonates a heavy telegraphed blast; `bayonet_cone` is a close melee sector (`cone_degrees`) with a contact-rescue radius at the player's feet plus an occasional configurable auto rifle shot (`bayonet_auto_shot_chance`, additive with the bayonet_trigger artifact) toward the nearest enemy beyond the cone. All three actions can be duplicated once by the Soldier double-action trait (SCRUM-935, `ProgressionData.CLASS_TRAITS`): a 50% per-activation roll spawns one full non-recursive copy of the action after a short readable delay. Thief-specific modes (SCRUM-897): `coin_ricochet` — цепь до `projectile_count` прыжков (жёсткий кап `COIN_CHAIN_HARD_CAP` 8), урон убывает монотонно `tail^(i/(n-1))` до `damage_falloff`-доли (0.5) на последнем задуманном прыжке, золото начисляется мгновенно `gain_money` с первых `steal_hits` целей (без спавна пикапа); `shadow_backstab` — фантомный кинжал материализуется ЗА ближайшей целью БЕЗ движения/телепорта героя (референс Dead Cells Assassin's Dagger), встроенный паралич-яд `poison_paralysis_duration` (кап `POISON_PARALYSIS_CAP` 1.8с, боссы/элиты ×`POISON_PARALYSIS_BOSS_FACTOR` 0.25), удар в спину ×`BACKSTAB_POSITIONAL_MULTIPLIER` 1.35 когда цель отдаёт спину фантому (живая скорость врага, фоллбэк «чейзер смотрит на героя»); `smoke_bomb` — брошенный снаряд летит `grenade_delay`, на детонации ОДНО AoE-событие урона (скейл от урона/AoE/темпа билда), затем НЕдамажащее облако `smoke_duration` с позиционным уклонением (`Player.register_smoke_cloud`, кап в дыму `SMOKE_CLOUD_DODGE_CAP` 0.90). Elementalist-specific modes (SCRUM-948..950; исторические имена режимов сохранены ради стабильных внешних контрактов): `elemental_orbit` — квадратное поле четырёх стихий в точке каста (половина стороны = `aoe_radius × SQUARE_HALF_RATIO`), тики бьют магией (ролл оружия), физикой (`SQUARE_PHYSICAL_SHARE` от канала damage) и ожог-статусом `four_elements_burn` (от dot-осей), каждый тик отталкивает врагов от центра квадрата; `prism_rift` — полнокартный X-разлом через точку фокуса: две диагонали (направление ±45°, плечи `PRISM_FULL_MAP_REACH` = 4800px ≥ диагонали арены 4096×2304) пронзают всех на пути без спада, дедуп гарантирует не более одного луч-хита на врага за каст, малый центр-AoE добавляет `PRISM_CENTER_BONUS_SHARE`; `meteor_shards` — одиночный тяжёлый метеор: `grenade_delay` (1.30с) = полная задержка (телеграф `HazardVfx` 42% + видимое падение), удар — тяжёлый магический AoE с falloff, затем догорающая зона `dot_ticks × pool_tick_interval` по dot-оси владельца со спадом по рангу удалённости. Sniper-specific modes: `sniper_lockshot` locks one target after a short telegraph, `sniper_kill_zone` rains several precision beams inside a marked area, and `sniper_split_round` branches from a primary shot into fixed fan trajectories with limited pierce rather than nearest-target chain. Priest-specific modes: `priest_sanctify` delays a holy mark explosion, `priest_ward` pulses protective circles from the player, and `priest_prayer_chain` scores its next target toward the owner-side sustain arc. Biologist-specific modes: `bio_spore_bloom` grows expanding target-centered spore rings, `bio_sample_dart` follows a direct sample hit with delayed analysis pulses, and `bio_symbiote_web` links the primary target to nearby enemies with a damage-sharing web. Robot-specific modes: `robot_magnetic_anchor` pulls enemies toward a marked target before impact, `robot_compression_line` compresses enemies toward a line axis, and `robot_reactor_vent` emits four short directional vents around the player. Knight weapons share a block/counter hook but split it by geometry: spear is narrow reach with light frontal retaliation, tower shield is the strongest frontal guard/counter against contact packs, and holy flail keeps broad circular control with softer counter output. Assassin-specific behaviour (SCRUM-894, замена shadow_momentum из SCRUM-860): trait «Хладнокровие» (`ProgressionData.CLASS_TRAITS.assassin`) поднимает кап шанса крита до 100% только Ассасину (глобальный `CRIT_CHANCE_CAP` 55% у остальных), выключает diminishing крит-вложений и переливает избыток raw-шанса сверх капа в крит-урон (`crit_overflow_to_crit_damage` 0.5; итог зажат `CRIT_DAMAGE_CAP`). `boomerang` возвращается квадратичной ЛЕВОЙ дугой (`return_arc_offset`): выброс — прямой коридор, возврат — полилиния дуги с дедупом per-cast/per-target (максимум 1 outbound + 1 return хит); позиция у разворота/у героя даёт честный double-pass, зеркальная правая сторона возврат не ловит. `stab_flurry` Теневых кинжалов при `point_blank_radius` дополнительно кроет врагов вплотную вокруг героя (мёртвой зоны в упор нет; общий лимит целей), а серия, задевшая врага, даёт «Рывок темпа» (`flurry_tempo_*`: короткий бафф скорости и уворота с внутренним кулдауном — перманентного аптайма нет, стакинга нет, attack_speed не трогает). `dot_beam` Ядовитой струны при `close_contact_radius` стартует от самого героя и первыми бьёт целей в упор (общий пирс-лимит), а крит прямого удара снапшотом усиливает DoT-тики (`dot_crit_snapshot_ratio`). Классовая защита — «Теневая завеса»: самоцентричная аура уворота (`Player.current_dodge_chance`), бонус `veil_dodge_bonus × buff_power` (кап `veil_dodge_cap`) действует только пока враг внутри derived `aura_radius`; суммарный уворот всегда ≤ `SURVIVABILITY_DODGE_CAP` — бессмертия нет. Контракты: `tests/assassin_kit_test.gd`, `tests/kill_scaling_identity_test.gd`. Engineer-specific modes: `engineer_sentry_link` deploys temporary sentry beam nodes that remember targets within a firing cycle, spread shots before retargeting, and add small capped splash; `engineer_repair_drone` chains damage into small self-repair; `engineer_pressure_mines` fans out independent mines that persist for their `pool_duration` and tick each `pool_tick_interval` while enemies stand inside. Deploy visuals use data-driven source textures when configured: `sound_amp` uses `deploy_sound_amp_field.png`, while `raven_totem` uses `deploy_raven_totem_field.png`; other deploy/trap visuals fall back to each weapon's `WeaponVisual` texture.
## Visual Asset Status

Design visual set is complete for the first 9 classes and 27 weapons as of 2026-06-11. SCRUM-168 adds Soldier as a Back-end class with canonical Soldier character/weapon PNG paths connected; rig/motion remains Animator handoff. SCRUM-169 adds Thief as Back-end gameplay with canonical Thief character/weapon PNG paths connected; rig/motion is `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_sniper_rig_motion_task.md`. SCRUM-165 adds Priest gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_priest_rig_motion_task.md`. SCRUM-162 adds Biologist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_biologist_rig_motion_task.md`. SCRUM-166 adds Robot gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_robot_rig_motion_task.md`. SCRUM-164 adds Engineer gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_engineer_rig_motion_task.md`. Weapon art v2 pass 2026-06-12 reduced oversized socket visuals, fixed scene texture fallbacks, and replaced the Knight visual stack: `assets/sprites/characters/knight.png` is now an unarmed base sprite, while `long_spear.png`, `tower_shield.png`, and `holy_flail.png` are separate polished noble knight weapons. New class full-art PNGs are art-approved at `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). The first 27 weapon PNGs in the matrix above exist at their canonical `assets/sprites/weapons/*.png` paths (`256x256`, transparent), including the 12 formerly fallback weapons:
`shadow_daggers`, `venom_wire`, `storm_longbow`, `hunter_trap`, `plague_syringe`, `bone_saw`, `acid_flask`, `homunculus_vial`, `tower_shield`, `holy_flail`, `briar_staff`, `raven_totem`.

Socket/display status: the original 27 weapon scenes point to matching canonical PNG and use reduced `WeaponVisual.scale` for clearer body/face readability. Soldier scenes point to canonical `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`. Preview sheets: `docs/design/previews/weapon_v2_assets_contact.png` for raw PNG QA and `docs/design/previews/weapon_v2_socket_contact.png` for class/weapon visual placement. `venom_wire` is intentionally thin and best paired with a separate line/VFX during attacks; `hunter_trap` and several deploy/summon weapons can also serve as world sprite bases.

Source-specific summon/deploy visuals (SCRUM-157): `scripts/summoner_weapon.gd` reads `ally_visual_id` / `ally_visual_ids` and passes the selected ID into `AllyMinion.set_visual_id()`. `summon_amulet` randomly uses `ally_druid_beast` or `ally_druid_pack_spirit`; `homunculus_vial` uses the SCRUM-945 PixelLab pair art (`homunculus_tank_*`/`homunculus_caster_*`, 4-directional static frames chosen by movement axis in `AllyMinion`/`SummonerWeapon`); `leadership_echo` is reserved for future echo-style summons. `scripts/class_weapon.gd` reads optional `deploy_texture_path`: `sound_amp` deploys `deploy_sound_amp_field.png`, while `raven_totem` deploys `deploy_raven_totem_field.png`.

Summon role runtime (SCRUM-254/SCRUM-854/SCRUM-859): summon/deploy configs may define `summon_role`, `deploy_role` and role coefficients. `SummonerWeapon` builds an `AllyMinion.set_combat_profile()` payload from owner `derived_parameters` and Leadership: damage, move speed, attack interval, lifetime, max HP, control knockback, support healing and small splash. Current mobile summon roles are `pack_damage` (Druid beasts), `tank_control` (Chemist homunculus), `support_totem`, `engineer_sentry` and `support_drone`; deploy identity roles are `stage_pulse` (Guitarist amp), `support_totem` (Druid raven totem), `turret_dps` (Engineer sentry), `repair_chain` (Engineer drone), and `mine_grid` (Engineer mines). Mobile summon weapons tag minions by owner+weapon, prefill about half of the current cap at battle start, and then replenish normally. ClassWeapon deploy count uses `max_summons_cap` where configured, so Leadership still improves the loop but cannot create AFK runaway device carpets. `ProgressionData.weapon_archetype()` treats `summon_role` weapons as summon archetype, and the balance harness models pure summon DPS through minion output rather than an invisible direct hit.

## Chemist Class Trait — «Катализатор» (SCRUM-942)

Signature trait Химика (канон: `docs/design/class_traits_registry.md`, данные:
`ProgressionData.CLASS_TRAITS`): ВЕСЬ периодический урон Химика усилен на +50%
(`periodic_damage_multiplier: 1.5`). Прямые попадания — включая прямой AoE-взрыв
Взрывной пыли — trait НЕ усиливает.

Что считается периодическим (source tagging, data-driven — будущие оружия
опт-инятся этими же тегами):

- hit-контексты с `damage_type="dot"`: тики луж (`ClassWeapon._damage_enemies_in_pool`),
  DoT-тики оружия (`_apply_weapon_dot_tick`) — множитель применяется в
  `Player.meta_damage_multiplier`;
- статусы с `dot_damage`, применённые через `StatusEffects.apply_status_from(источник, ...)`:
  кислотные заряды луж, волны гомункула-кастера, `toxic_debuff` — множитель
  источника запекается в `dot_damage` на моменте применения;
- универсальные DoT-тики игрока (`Player._trigger_universal_dot`).

Бюджет-формулы зеркалят trait в `_budget_dot_dps`/`_budget_pool_dps`/
`_budget_pool_charge_dps`/`_budget_summon_wave_dps`, поэтому авто-тюнинг
(`budget_tuning_for`) сам пересчитывает кит Химика под классовый коридор —
формульный гейт и live-замеры видят одну и ту же периодику. Утечка другим
классам исключена данными: у классов без trait'а множитель 1.0
(`tests/chemist_kit_test.gd`).

Балансовые капы периодики Химика (задокументированные): кислотные заряды — не
более 5 вечных зарядов на цель с разных луж (артефакт «Кислотный катализатор»
+3, до 8); повторное стояние в одной луже второй заряд НЕ даёт (per-pool
идентичность статуса `acid_charge_p<pool_id>`); волны кастера — стак до 4 вечных
зарядов `homunculus_caster_dot` на цель.

## Targeting Rule

Все атакующие оружия игрока целятся в ближайшего живого врага, а не в направление движения. Без врагов сохраняется последнее направление атаки.

## Cleanup Rules

- При смене персонажа/оружия/забега/смерти/возврате в меню временные weapon effects очищаются.
- Deployables/traps/totems/summons должны быть в `player_weapon_effects` и не оставаться на карте после cleanup.
- Class-specific leftovers не должны оставаться на карте.
