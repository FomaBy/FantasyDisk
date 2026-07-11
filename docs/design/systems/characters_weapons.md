# Characters And Weapons

Обновлено: 2026-07-04

Канонические данные персонажей и оружия доступны через compatibility facade `scripts/progression_data.gd`; после SCRUM-198 исходные домены живут в `scripts/progression_data_characters.gd` и `scripts/progression_data_weapons.gd`. Этот файл описывает игровую идентичность, сцены и текущие backend-режимы.

## Characters

| Character ID | Role |
| --- | --- |
| `berserk` | melee sector/circle fighter, высокий риск рядом с толпой; trait «Ярость» (SCRUM-1004) — урон непрерывно растёт от недостающего HP, кап +40% |
| `soldier` | double-action physical fighter: explosive arquebus bullet, slow fuse grenade nuke, bayonet melee cone; каждое действие с шансом 50% происходит дважды |
| `thief` | economy/evasion trickster (SCRUM-897): trait-магнит подбора, монетный рикошет с мгновенным золотом, паралич-кинжал, позиционное дым-облако уклонения |
| `elementalist` | pure-mage зонер (SCRUM-947..950): trait «Проводник стихий» — все magic-tagged бонусы ×1.30; квадрат четырёх стихий, полнокартный X-разлом, самый медленный тяжёлый метеор |
| `sniper` | long-range precision class: lockshot, kill-zone marking, split rounds |
| `priest` | holy sustain caster: sanctify marks, ward pulses, prayer chains |
| `biologist` | хрупкий био-реактивный гибрид (SCRUM-896): trait «Разбор образцов» — прямой урон по целям под своим DoT ×1.20 (SCRUM-1005); локальные споровые кольца+замедление, длинный пирсинг-луч с бурстом анализа, дальнее темпоральное семя |
| `robot` | heavy tank-control construct: magnetic pulls, compression lines, reactor vents |
| `engineer` | командир устройств (SCRUM-905..908, trait «Сеть мастерской»: живые устройства дают стеки, усиливающие только устройства; Лидерство поднимает кап): турели с боезапасом 15, орбитальные боевые дроны, персистентные парные мины |
| `dark_mage` | caster: цепные снаряды, curse-прожиг, зеркальные AoE-взрывы; убитые взрываются (trait «Тёмный распад») |
| `guitarist` | magic caster + deployable summoner (SCRUM-899): узкий рифф-strip, большое кайт-кольцо баса, амп-турели; trait «Разогрев» (SCRUM-1006) |
| `assassin` | хрупкий crit-скейлер (trait «Хладнокровие»: кап крита 100%, избыток → крит-урон): дуговой boomerang, point-blank flurry с рывком темпа, poison line от героя; выживает уворотом («Теневая завеса») |
| `ranger` | «сторожевой лук» (SCRUM-909..913): trait — каждый лучный хит отбрасывает ОТ героя; сплит-болт 1→4, дальний пирс-конус, перманентные капканы с параличом и зелёным кровотечением |
| `doctor` | weapon-only sustain (SCRUM-900): trait «Клятва чумного доктора» — generic реген/вампиризм/kill-heal не действуют; лечится только уроном своего оружия (зелье-AoE, чума со спредом, сектор-пила) |
| `chemist` | catalyst-периодика (+50%): быстрый физический AoE, вечные кислотные заряды из луж, постоянная пара гомункулов танк+кастер |
| `knight` | tank-отражатель (SCRUM-920..923): trait «Возмездие» — контактный атакующий отлетает прочь (боссы/главные элиты не смещаются); тройной секвенс-укол копья, конус-баш щита к ближайшей цели с масштабируемым отбросом, расширяющаяся спираль кистеня |
| `druid` | summon/nature control: beast pack, thorn zones, raven totem |

## Structured Hero Select dossier (SCRUM-1064)

Все 17 классов используют один data-driven контракт
`ProgressionData.hero_select_dossier(character_id)`. Он возвращает только
проверяемые данные: optional canonical trait, имя, три weapon ID/player-facing
названия из `WEAPONS_BY_CLASS`, top-3 `BASE_STATS` и полное разбиение
`ATTRIBUTE_REGISTRY` на `primary` / `secondary` / player-facing `weak`.
Свободные `CHARACTER_CONFIGS.description`, `strengths`, `weaknesses` остаются
legacy/другими consumer-данными и не участвуют в выборе героя.

Алгоритм ведущих характеристик един для всего ростера: значения сортируются по
убыванию, при равенстве сохраняется канонический порядок `STAT_NAMES`; берутся
ровно первые три, число показывается рядом. Relevance-группы непересекаются и
вместе покрывают все 24 записи `ATTRIBUTE_REGISTRY`; внутренний ключ `optional`
сохранён для reward weighting, но в Hero Select называется «Слабые атрибуты».

Предметная ревизия сверяла каждую классификацию с `CLASS_TRAITS` и фактическими
механиками трёх оружий. В частности: Доктор не получает generic
regen/vampirism; Ассасин владеет crit-cap; Химик — periodic multiplier; Друид —
buff/aura/summon scale; Робот — mitigation. Generic damage Тёмного мага остаётся
secondary из-за действующей per-hero damage-star прогрессии, хотя прямые
оружейные каналы — magic/DoT. Глобальный reward-инвариант остаётся
`2 primary / 8 secondary / 7 optional` на каждый атрибут; баланс-числа и weapon
mechanics этой задачей не менялись. Контракт:
`tests/hero_select_scrum1064_dossier_test.gd` +
`tests/attribute_relevance_test.gd`.

Аудит выявил связанный dead-progression дефект: личное созвездие Доктора
содержало generic regeneration/vampirism, которые его же Plague Oath отбрасывает
при применении. SCRUM-1064 заменяет эти minor/technique/hidden эффекты живыми
DoT/tempo/health/support/ultimate осями и фиксирует запрет тестом
`tests/skill_tree_per_hero_test.gd`; weapon-конфиги и run-баланс не меняются.

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

SCRUM-1043 выравнивает hammer slam относительно ног full-frame Берсерка без
числового ребаланса оружия. Hammer-only hit/VFX center смещён на `16px` вниз,
а вертикальная ось умножена на `1.12`: прежний верхний reach остаётся около
`150px`, нижний становится около `184px`, горизонталь практически не меняется.
`_circle_attack_center(owner_node)` и `_circle_attack_visual_scale()` служат
единым protected-контрактом для damage membership и Animator VFX bridge. Для
Knight `holy_flail` и любого другого circle-оружия остаются прежние центр и
`Vector2.ONE`; sword/axe, урон, cooldown, Radius growth и diminishing не менялись.

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
| `priest` | `priest_censer` | Кадило Обета | `PriestCenser.tscn` | `priest_ward` | Несколько тяжёлых волн вокруг героя; финал поглощает 18% одного удара за cast и отвечает retaliation без скрытого лечения |
| `priest` | `priest_chime` | Колокол Молитвы | `PriestChime.tscn` | `priest_prayer_chain` | Молитвенная цепь выбирает sustain-дугу между врагами ближе к владельцу и возвращает heal |

| `biologist` | `biologist_spore_lens` | Споровая Линза | `BiologistSporeLens.tscn` | `bio_spore_bloom` | ЛОКАЛЬНЫЙ AoE у персонажа (range 235): три расширяющихся кольца с falloff; задетые замедлены 5→20% по прогрессии и заражены bio_infection (SCRUM-896) |
| `biologist` | `biologist_sample_injector` | Инъектор Образцов | `BiologistSampleInjector.tscn` | `bio_sample_dart` | Длинный пирсинг-луч (640): полный маг.ролл + физ.доля всем на линии, малый бурст анализа на конце (96); ближайший получает пробу-инфекцию (SCRUM-896) |
| `biologist` | `biologist_symbiote_seed` | Семя Симбионта | `BiologistSymbioteSeed.tscn` | `bio_symbiote_web` | Дальнее темпоральное семя (700): прорастание 0.55с, стартовый маг.хит 0.85 с falloff (зона 150), главный пейофф — биоинфекция 6×1.6 тиков (SCRUM-896) |
| `robot` | `robot_magnetic_anchor` | Магнитный Якорь | `RobotMagneticAnchor.tscn` | `robot_magnetic_anchor` | Heavy delayed AoE anchor at the target point: full roll with falloff from the anchor centre, pulls rank enemies 0.85 of the way to centre per cast (impulse capped 1500); elites/bosses take full damage but are not displaced — point-grouping niche |
| `robot` | `robot_hydraulic_press` | Гидравлический Пресс | `RobotHydraulicPress.tscn` | `robot_compression_line` | Wide compression corridor: damage across the FULL suppression_width (300, ×1.30 with Press Calibrator), compresses rank enemies 0.80 of their offset toward the axis per cast; elites/bosses full damage, displacement resisted ×0.25 — line-alignment niche |
| `robot` | `robot_reactor_core` | Реакторное Ядро | `RobotReactorCore.tscn` | `robot_reactor_vent` | Exactly 4 reactor vents at 90° from a world phase (no homing) that rotate +6° clockwise per cast — the fan sweeps the full circle over 15 casts; per-vent damage = roll × 0.42 |
| `engineer` | `engineer_sentry_wrench` | Часовая турель | `EngineerSentryWrench.tscn` | `engineer_sentry_link` | `turret_dps` (SCRUM-905): турели с боезапасом 15 выстрелов — расстреляла магазин → свернулась; таймера жизни/замены старейшей нет; предел парка 2+floor(sa/4), рельс 6; залп по разным ближайшим целям + capped splash |
| `engineer` | `engineer_repair_drone` | Орбитальный Дрон | `EngineerRepairDrone.tscn` | `engineer_orbit_drone` | SCRUM-906: боевые дроны кружат вокруг инженера по спирали (радиус слота +14%), физический контактный урон с per-enemy CD 0.85с; число дронов 1+floor(max(sa−12,0)/4), рельс 6; attack_speed крутит RPM; ремонт удалён |
| `engineer` | `engineer_pressure_mines` | Минная Сетка | `EngineerPressureMines.tscn` | `engineer_pressure_mines` | SCRUM-907: 2 персистентные мины за деплой в случайном кольце 110..260; таймера жизни нет; враг подрывает сразу, свой игрок — после 3с; кап живых 6 (skip, не retire) |

SCRUM-925/926 gives Priest one mandatory per-combat prayer before any battle
start hook or objective spawn: `prayer_wrath` (+20% all Priest damage),
`prayer_mending` (+2 HP/s) or `prayer_aegis` (−20% incoming damage). The pool
is data-driven by `ProgressionData.class_battle_prayers("priest")`, and
`Player.select_battle_prayer()` enforces exactly one immutable selection for
the current player instance. `Player.on_battle_start()` never makes a hidden
default selection; non-Priest pools remain empty.
| `dark_mage` | `dark_book` | Книга тьмы | `DarkBook.tscn` | `dark_mirror_blast` | Пара взрывов: по цели и в зеркальной точке относительно мага (SCRUM-941) |
| `dark_mage` | `cursed_skull` | Проклятый череп | `CursedSkull.tscn` | `skull_curse_burn` | Curse-only зона: без прямого урона, частые dot-тики по проклятым; тик = dot_damage × mult × (1 + Int × curse_int_scale), magic-множители не участвуют (SCRUM-940) |
| `dark_mage` | `dark_wand` | Темная палочка | `DarkWand.tscn` | `dark_chain_burst` | Цепной снаряд до 3 целей с малым AoE-бурстом на каждом попадании (SCRUM-939) |
| `guitarist` | `electric_guitar` | Электрогитара | `ElectricGuitar.tscn` | `riff_strip` | Узкая передняя полоса постоянной ширины `wave_width` (118): частые низко-средние магические хиты, без pierce-капа (SCRUM-899) |
| `guitarist` | `bass_guitar` | Бас-гитара | `BassGuitar.tscn` | `pulse` | Большое кольцо (радиус 330 с 1 уровня): частые слабые магические тики + сильный knockback под кайт; ранняя слабость — урон, не радиус (SCRUM-899) |
| `guitarist` | `sound_amp` | Звуковой усилитель | `SoundAmp.tscn` | `amp` | `stage_pulse`: деплой амп-турелей, автономные магические пульсы, cleanup, лимит; скейлинг: Лидерство = число (1+floor(L/4), кап 3) и uptime (+min(L×0.12, 3)с), summon_amount = темп пульса (канон-хейст), attack_speed = каденция установки; урон пульса — чистая magic_damage ось (SCRUM-899) |
| `assassin` | `chakrams` | Чакрамы | `Chakrams.tscn` | `boomerang` | SCRUM-894: коридор к цели + возврат ЛЕВОЙ дугой (`return_arc_offset`); правильная позиция даёт double-pass, гейт 1+1 хит на цель за каст |
| `assassin` | `shadow_daggers` | Теневые кинжалы | `ShadowDaggers.tscn` | `stab_flurry` | SCRUM-894: сектор + point-blank покрытие вокруг героя (`point_blank_radius`); серия по врагам даёт «Рывок темпа» (`flurry_tempo_*`: скорость+уворот, кулдаун) |
| `assassin` | `venom_wire` | Ядовитая струна | `VenomWire.tscn` | `dot_beam` | SCRUM-894: poison-линия ОТ героя + `close_contact_radius` (вплотную не мёртвая зона); крит-снапшот усиливает тики (`dot_crit_snapshot_ratio`) |
| `ranger` | `moon_crossbow` | Лунный арбалет | `MoonCrossbow.tscn` | `moon_split_shot` | SCRUM-910: физический болт в цель + расщепление в 4 РАЗНЫХ соседей (радиус `aoe_radius` 260) с ТЕМ ЖЕ уроном, без рекурсии; каждый хит отбрасывает от героя |
| `ranger` | `storm_longbow` | Грозовой длинный лук | `StormLongbow.tscn` | `storm_pierce_cone` | SCRUM-911/1037: конус 5 пробивающих стрел (34°, дальность 980), пирс 4/стрела без спада, дедуп на залп; каждый хит отбрасывает от героя; один Animator release VFX играет на залп без замены live beam-коридоров |
| `ranger` | `hunter_trap` | Охотничий капкан | `HunterTrap.tscn` | `trap` | SCRUM-913: ПЕРМАНЕНТНЫЙ капкан (кап 6 живых, не таймер), игроку безопасен; триггер = физ. AoE + паралич 2.2с (movement_locked, боссы ×0.25) + зелёное кровотечение 5с по dot-оси |
| `doctor` | `restore_potion` | Зелье восстановления | `RestorePotion.tscn` | `aoe_projectile` | Бросок зелья: магический AoE-взрыв 150r; хил 16% фактического урона через drain-бюджет (SCRUM-900) |
| `doctor` | `plague_syringe` | Чумной шприц | `PlagueSyringe.tscn` | `plague_dart` | Чумной дротик: зараза 24с, ramp тиков 0.45→1.0, спред 22%/тик (радиус 200, кап 10 зараз), хил 12% чумного урона (SCRUM-900) |
| `doctor` | `bone_saw` | Костяная пила | `BoneSaw.tscn` | `saw_sector` | Melee-сектор 135°/215: мультихит с диминишем сверх 4 целей, сильнейший хил кита 34% — только по фронту (SCRUM-900) |
| `chemist` | `blast_powder` | Взрывная пыль | `BlastPowder.tscn` | `aoe_projectile` | SCRUM-943: быстрый ПРЯМОЙ физический close-mid AoE (fire 0.62, r150, range 430), без луж/DoT; trait периодики его не усиливает |
| `chemist` | `acid_flask` | Кислотная колба | `AcidFlask.tscn` | `aoe_projectile` | SCRUM-944: долгая (7с) полупрозрачная лужа; тики пока враг внутри + один ВЕЧНЫЙ кислотный заряд с каждой отдельной лужи (кап 5, артефакт +3), заряды тикают по dot-оси до смерти носителя |
| `chemist` | `homunculus_vial` | Склянка гомункула | `HomunculusVial.tscn` | `summon` | SCRUM-946: постоянная пара — танк (4x max HP Химика, таунт-пульсы, смертен, респавн 4с) + неуязвимый кастер (вне боевого лимита, волны каждые 1.7с вешают вечный DoT-заряд, кап 4; fallback-позиция — плечо Химика) |
| `knight` | `long_spear` | Копье | `LongSpear.tscn` | `strip` | SCRUM-921: тройной секвенс-укол лево→центр→право (±16°, окно 0.11с, полоса 110×540); одна цель ≤ 1 укола за цикл (анти-triple-dip, budget solo=1.0); лёгкий frontal block/counter |
| `knight` | `tower_shield` | Башенный щит | `TowerShield.tscn` | `sweep` | SCRUM-922: конус 95° в направлении БЛИЖАЙШЕГО монстра, все цели конуса отлетают прочь; импульс (260 + knockback_power×3.0)×1.15 растёт от вложений в отброс; боссы/главные элиты ×0.25, мини-элиты полноценно; сильнейший block/counter |
| `knight` | `holy_flail` | Освященный кистень | `HolyFlail.tscn` | `circle` | SCRUM-923: расширяющаяся спираль — фронт-дуга 150° делает полный оборот за 7 шагов×0.085с, радиус растёт 22%→100% (r235); урон от центра наружу, максимум 1 хит/цель/каст; круговая мягкая ответка |
| `druid` | `summon_amulet` | Амулет призыва | `SummonAmulet.tscn` | `summon` | `pack_damage` beast pack scaling from Leadership |
| `druid` | `briar_staff` | Посох терний | `BriarStaff.tscn` | `aoe_projectile` | Thorn zone, AoE DoT, crowd control |
| `druid` | `raven_totem` | Вороний тотем | `RavenTotem.tscn` | `amp` | `support_totem` pulses, Leadership-scaled deploy limit with deploy cap |

SCRUM-895 Animator pass отделяет читаемость оружия от backend-механики.
`TwoHandedAxe` теперь добавляет isolated PixelLab 8-frame cleave: реальный
двуручный топор проходит всю фактическую `180° / 250px` дугу поверх спокойной
sector-подсветки; cooldown/damage/range/follow-up не менялись. `TwoHandedHammer`
на live impact показывает PixelLab overhead-weapon frame 5, ground crack и
shock ring фактического `150px` радиуса. Sword scene/script/геометрия не
затронуты. Lower-side Hammer membership вынесен в backend handoff SCRUM-1043;
visual bridge уже принимает его `_circle_attack_center` /
`_circle_attack_visual_scale` contract и до land использует текущие defaults.
Source/runtime/report: `docs/design/references/scrum895_berserk_axe_hammer_vfx/`.

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

## Class Kit: Биолог — гибридные оси и trait «Разбор образцов» (SCRUM-896/1005)

Биолог — хрупкий био-реактивный AoE-класс с несколькими равноправными осями
сборки. Аудит вклада параметров по оружиям (изоляция типов SCRUM-524 не
нарушается — каждый канал скейлится только своим атрибутом):

| Ось | Спор. Линза | Инъектор | Семя | Скейл |
| --- | --- | --- | --- | --- |
| `magic_damage` (Интеллект) | кольца (полный ролл × falloff^i) | луч (полный ролл каждому) + бурст анализа ×0.55 | стартовый хит ×0.85 с falloff | основной прямой канал всех трёх |
| `damage` (Сила) | — | +`INJECTOR_PHYSICAL_SHARE` (0.50 канала damage) КАЖДОМУ на луче, тип "physical" | — | физическая ось сборки (паттерн SQUARE_PHYSICAL_SHARE) |
| `dot_damage` (Знание) | тик инфекции ×1.0 | тик пробы ×0.6 | тик инфекции ×1.6 — главный пейофф | размер тика bio_infection |
| `dot_speed` (Знание/Энергия/Ловкость) | каденция ×2.0 | каденция ×1.2 | каденция ×1.0 | скорость тиков инфекции (устоявшийся DPS = тик × каденция) |
| `aoe_radius` | кольца 210 (сохранён «нравящийся») | бурст 96 (<< Линзы) | зона 150 (между Линзой и бурстом) | покрытие/инфекция толпы |
| `attack_range` | 235 — ЛОКАЛЬНЫЙ (через экран не стреляет) | 640 — длинный пирсинг-инструмент | 700 — самое дальнобойное | позиционирование/риск |

Механика инфекции: status `bio_infection` (refresh, 1 стак, `source_id`
владельца, тики `player_owned`); устоявшийся DPS = тик × каденция — перекаст НЕ
мультиплицирует тики (bio-ветка `_budget_dot_dps` зеркалит это в бюджете, ось
НЕ зависит от скорости атаки). Замедление Линзы: 5%→20% по нормированной
прогрессии (эффективный `magic_damage` к lvl1-базе класса, кап на ×3), refresh
без стака, поверх — артефакт «Споровый конденсатор»; движковый кламп скорости
≥0.25 исключает стоп-лок.

Trait «Разбор образцов» (SCRUM-1005, реестр `CLASS_TRAITS.biologist`): пока на
цели живёт периодический эффект САМОГО Биолога, его прямые хиты по этой цели
×1.20 (`infected_direct_hit_multiplier`, generic-гейт в
`ClassWeapon._damage_enemy`). Тики DoT НЕ усиливаются (не дублирует
«Катализатор» Химика), чужой/истёкший статус бонуса не даёт
(`StatusEffects.has_dot_from_source`), ульта — не оружейный прямой урон и в
trait не входит (аналогично исключению ульты из «Двойного действия»). В
budget-модели trait учтён фактором ×(1+0.20×0.75) на прямой компонент оружий с
`dot_ticks>0` — тюнер компенсирует кит автоматически. Покрыт
`tests/biologist_kit_test.gd`.

## Backend Modes

- `scripts/berserk_weapon.gd`: `frustum`, `strip`, `sweep`, `circle`; melee damage window is synced with swing timing.
- `scripts/class_weapon.gd`: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `riff_strip`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`, `arquebus_shot`, `grenade_fuse`, `bayonet_cone`, `coin_ricochet`, `shadow_backstab`, `smoke_bomb`, `elemental_orbit`, `prism_rift`, `meteor_shards`, `sniper_lockshot`, `sniper_kill_zone`, `sniper_split_round`, `priest_sanctify`, `priest_ward`, `priest_prayer_chain`, `bio_spore_bloom`, `bio_sample_dart`, `bio_symbiote_web`, `robot_magnetic_anchor`, `robot_compression_line`, `robot_reactor_vent`, `engineer_sentry_link`, `engineer_orbit_drone`, `engineer_pressure_mines`, `moon_split_shot`, `storm_pierce_cone`.
- `scripts/summoner_weapon.gd`: summon weapon wrapper for Druid and Chemist minion styles.

`stab_flurry` hits several nearest enemies inside a short wave-shaped melee zone. `dot_beam` is a pierce line that applies DoT. `trap` deploys a node that snaps shut on the first enemy entering its radius (SCRUM-913: перманентный до срабатывания, игрок не запускает; физический AoE + паралич + кровотечение — см. Ranger-блок ниже). Soldier-specific modes (SCRUM-936/937/938): `arquebus_shot` fires one visible explosive bullet that detonates in a small radial-falloff AoE at the hit point; `grenade_fuse` lobs a slow capped-speed projectile that lands, burns a visible fuse (`grenade_delay`), and only then detonates a heavy telegraphed blast; `bayonet_cone` is a close melee sector (`cone_degrees`) with a contact-rescue radius at the player's feet plus an occasional configurable auto rifle shot (`bayonet_auto_shot_chance`, additive with the bayonet_trigger artifact) toward the nearest enemy beyond the cone. All three actions can be duplicated once by the Soldier double-action trait (SCRUM-935, `ProgressionData.CLASS_TRAITS`): a 50% per-activation roll spawns one full non-recursive copy of the action after a short readable delay. Thief-specific modes (SCRUM-897): `coin_ricochet` — цепь до `projectile_count` прыжков (жёсткий кап `COIN_CHAIN_HARD_CAP` 8), урон убывает монотонно `tail^(i/(n-1))` до `damage_falloff`-доли (0.5) на последнем задуманном прыжке, золото начисляется мгновенно `gain_money` с первых `steal_hits` целей (без спавна пикапа); `shadow_backstab` — фантомный кинжал материализуется ЗА ближайшей целью БЕЗ движения/телепорта героя (референс Dead Cells Assassin's Dagger), встроенный паралич-яд `poison_paralysis_duration` (кап `POISON_PARALYSIS_CAP` 1.8с, боссы/элиты ×`POISON_PARALYSIS_BOSS_FACTOR` 0.25), удар в спину ×`BACKSTAB_POSITIONAL_MULTIPLIER` 1.35 когда цель отдаёт спину фантому (живая скорость врага, фоллбэк «чейзер смотрит на героя»); `smoke_bomb` — брошенный снаряд летит `grenade_delay`, на детонации ОДНО AoE-событие урона (скейл от урона/AoE/темпа билда), затем НЕдамажащее облако `smoke_duration` с позиционным уклонением (`Player.register_smoke_cloud`, кап в дыму `SMOKE_CLOUD_DODGE_CAP` 0.90). Elementalist-specific modes (SCRUM-948..950; исторические имена режимов сохранены ради стабильных внешних контрактов): `elemental_orbit` — квадратное поле четырёх стихий в точке каста (половина стороны = `aoe_radius × SQUARE_HALF_RATIO`), тики бьют магией (ролл оружия), физикой (`SQUARE_PHYSICAL_SHARE` от канала damage) и ожог-статусом `four_elements_burn` (от dot-осей), каждый тик отталкивает врагов от центра квадрата; `prism_rift` — полнокартный X-разлом через точку фокуса: две диагонали (направление ±45°, плечи `PRISM_FULL_MAP_REACH` = 4800px ≥ диагонали арены 4096×2304) пронзают всех на пути без спада, дедуп гарантирует не более одного луч-хита на врага за каст, малый центр-AoE добавляет `PRISM_CENTER_BONUS_SHARE`; `meteor_shards` — одиночный тяжёлый метеор: `grenade_delay` (1.30с) = полная задержка (телеграф `HazardVfx` 42% + видимое падение), удар — тяжёлый магический AoE с falloff, затем догорающая зона `dot_ticks × pool_tick_interval` по dot-оси владельца со спадом по рангу удалённости. Sniper-specific modes: `sniper_lockshot` locks one target after a short telegraph, `sniper_kill_zone` rains several precision beams inside a marked area, and `sniper_split_round` branches from a primary shot into fixed fan trajectories with limited pierce rather than nearest-target chain. Priest-specific modes: `priest_sanctify` delays a holy mark explosion, `priest_ward` pulses protective circles from the player, and `priest_prayer_chain` scores its next target toward the owner-side sustain arc. Biologist-specific modes: `bio_spore_bloom` grows expanding target-centered spore rings, `bio_sample_dart` follows a direct sample hit with delayed analysis pulses, and `bio_symbiote_web` links the primary target to nearby enemies with a damage-sharing web. Robot-specific modes (SCRUM-915/916/918, редизайн кита): `robot_magnetic_anchor` — редкий тяжёлый AoE-пулл (самый медленный инструмент кита, `fire_interval` 2.05) с задержкой удара `grenade_delay`; центр = точка якоря (цель/направление), НЕ позиция игрока; полный ролл с falloff от центра, рядовых стягивает к центру на `ANCHOR_PULL_CONVERGENCE` 0.85 пути за каст (без овершута, cap 0.95, импульс зажат `ANCHOR_PULL_IMPULSE_CAP` 1500), элитки/боссы НЕ смещаются, но урон получают полностью — ниша «группировка точка-за-точкой». `robot_compression_line` — широкий коридор компрессии: урон по ВСЕЙ ширине `suppression_width` (300; ×1.30 с артефактом «Калибратор пресса»), рядовых прижимает к осевой линии на `PRESS_COMPRESSION_CONVERGENCE` 0.80 бокового отступа за каст (ось не пересекается — за два каста толпа «в ряд»), элитки/боссы — резист смещения `PRESS_ELITE_BOSS_COMPRESSION_FACTOR` ×0.25 при полном уроне, Робот при касте не двигается — ниша «выравнивание в линию». `robot_reactor_vent` — вращающийся 4-направленный веер: ровно `REACTOR_VENT_COUNT` 4 вентиля с шагом 90° от МИРОВОЙ фазы `_reactor_vent_phase` (старт 0°=восток, самонаведения нет — параметр `direction` игнорируется), паттерн доворачивается на `REACTOR_ROTATION_STEP_DEG` +6° по часовой после КАЖДОЙ атаки (полный цикл 90°/6°=15 атак; скорость атаки ускоряет только частоту шагов), пер-вентильный урон = ролл × `REACTOR_VENT_DAMAGE_RATIO` 0.42 (за каст по кругу ≈1.68× ролла, НЕ деление на 4), `extra_projectile` расширяет лопасти (+14%/снаряд, `REACTOR_EXTRA_PROJECTILE_WIDTH_BONUS`), но направлений остаётся ровно 4 — ниша «вращающаяся зона 360°». Отложенные удары якоря и пресса резолвятся именованными методами через `Callable(self, ...).bind()` по instance id (SCRUM-1034, канон SCRUM-551): VFX и владелец перепроверяются по id, teardown-safe, без freed-lambda-captures. Классовый trait «Бронекорпус» (`CLASS_TRAITS.robot`, `incoming_damage_multiplier: 0.8`) режет 20% ЛЮБОГО входящего урона последним множителем — после dodge/block/absorb/defense, с полом 0.5 (худший кап митигации ≈94% < гейта 98%). Кит целиком физический (`damage_parameter: "damage"`). Покрыто `tests/robot_kit_test.gd`. Knight weapons share a block/counter hook but split it by geometry: spear is narrow reach with light frontal retaliation, tower shield is the strongest frontal guard/counter against contact packs, and holy flail keeps broad circular control with softer counter output. Assassin-specific behaviour (SCRUM-894, замена shadow_momentum из SCRUM-860): trait «Хладнокровие» (`ProgressionData.CLASS_TRAITS.assassin`) поднимает кап шанса крита до 100% только Ассасину (глобальный `CRIT_CHANCE_CAP` 55% у остальных), выключает diminishing крит-вложений и переливает избыток raw-шанса сверх капа в крит-урон (`crit_overflow_to_crit_damage` 0.5; итог зажат `CRIT_DAMAGE_CAP`). `boomerang` возвращается квадратичной ЛЕВОЙ дугой (`return_arc_offset`): выброс — прямой коридор, возврат — полилиния дуги с дедупом per-cast/per-target (максимум 1 outbound + 1 return хит); позиция у разворота/у героя даёт честный double-pass, зеркальная правая сторона возврат не ловит. `stab_flurry` Теневых кинжалов при `point_blank_radius` дополнительно кроет врагов вплотную вокруг героя (мёртвой зоны в упор нет; общий лимит целей), а серия, задевшая врага, даёт «Рывок темпа» (`flurry_tempo_*`: короткий бафф скорости и уворота с внутренним кулдауном — перманентного аптайма нет, стакинга нет, attack_speed не трогает). `dot_beam` Ядовитой струны при `close_contact_radius` стартует от самого героя и первыми бьёт целей в упор (общий пирс-лимит), а крит прямого удара снапшотом усиливает DoT-тики (`dot_crit_snapshot_ratio`). Классовая защита — «Теневая завеса»: самоцентричная аура уворота (`Player.current_dodge_chance`), бонус `veil_dodge_bonus × buff_power` (кап `veil_dodge_cap`) действует только пока враг внутри derived `aura_radius`; суммарный уворот всегда ≤ `SURVIVABILITY_DODGE_CAP` — бессмертия нет. Контракты: `tests/assassin_kit_test.gd`, `tests/kill_scaling_identity_test.gd`. Engineer-specific modes (SCRUM-905..908 rework): `engineer_sentry_link` разворачивает турели с боезапасом (`sentry_shot_magazine` 15; каждый снаряд залпа тратит заряд) — турель сворачивается, расстреляв магазин, таймера жизни и замены старейшей нет, предел парка `max_summons + floor(summon_amount/4)` с рельсом `max_summons_cap` (при полном парке деплой пропускается), темп пульса делится на attack_speed; `engineer_orbit_drone` обслуживает постоянный парк орбитальных боевых дронов (спираль вокруг игрока, радиус слота +14%, физический контакт с per-enemy кулдауном `drone_hit_cooldown`, число дронов `1 + floor(max(summon_amount − drone_count_threshold, 0)/drone_count_step)`, attack_speed раскручивает обороты; прежний ремонт/цепь удалены); `engineer_pressure_mines` кладёт по 2 персистентные мины за деплой в случайные точки кольца `mine_place_min..max` (110..260) — мина лежит без таймера жизни до срабатывания: враг подрывает сразу, свой игрок только после `mine_self_arm_delay` (3с), кап живых `mine_active_cap` 6. Все три оружия — устройства: живые устройства кормят стеки trait'а «Сеть мастерской» (турель/дрон 1.0, мина 0.5; кап 3+floor(Лидерство/6); +6% урона устройств за стек), потребитель — `_workshop_network_factor` в `_rolled_damage`. Guitarist-specific rework (SCRUM-899): `riff_strip` — узкий передний коридор ПОСТОЯННОЙ полной ширины `wave_width` на всю `attack_range` (в духе берсерк-форм, но магией): бьёт всех врагов в полосе без pierce-капа (отличие от `beam`), в отличие от расширяющейся `sound_wave` ширина не растёт к концу — позиционирование корпусом обязательно; бюджет-зеркало — ветка `riff_strip` в `ProgressionData._budget_hit_model`, archetype `aura`. Амп-саммонер правила (данные `GUITARIST_WEAPONS.sound_amp`, opt-in ключи, `raven_totem` Друида не подписан): Лидерство = ЧИСЛО активных ампов (1 + floor(L/4), кап `max_summons_cap` 3 + артефактный `amp_cap_bonus`) и UPTIME (`amp_leadership_lifetime_per_point` 0.12с/очко, кап 3с — поверх артефактного `amp_lifetime_bonus`); summon_amount = СИЛА через темп пульса (`amp_summon_haste`: интервал ÷ (1 + min(summon_amount×0.014 + leadership×0.006, 0.30)) — канон summoner-хейста); attack_speed = каденция УСТАНОВКИ (generic `fire_interval` скейл); урон каждого пульса — чистая `magic_damage` ось владельца (никакой «лидерской» оси урона). Trait «Разогрев» (SCRUM-1006, `CLASS_TRAITS.guitarist`): +2 п.п. магического урона за секунду без полученного урона, кап +20% (0→кап ровно за 10с); квалифицированный удар (прошедший гейты предотвращения `Player.take_damage`) сбрасывает в 0, полностью предотвращенные события (godmode/i-frames/невидимость/уворот) НЕ сбрасывают; потребитель — `Player.meta_damage_multiplier` только для hit-контекстов `damage_type=="magic"` (physical/dot оси и другие классы не затронуты; деплой-пульсы ампов идут через владельца — ownership сохранён). Покрыто `tests/guitarist_kit_test.gd`. Ranger-specific rework (SCRUM-909..913, замена старых beam-режимов): `moon_split_shot` — одиночный физический болт в ближайшую/указанную цель, после попадания расщепляется в до `split_count` (4, артефакт «Лунный расщепитель» +2) РАЗНЫХ соседей первичной жертвы в радиусе `aoe_radius` с ТЕМ ЖЕ уроном (без спада, без повторных хитов, вторичные ветки дальше НЕ ветвятся — рекурсии нет по построению); `storm_pierce_cone` — дальнобойный конус `beam_count` (5 + extra_projectile) пробивающих стрел равномерно по полному раствору `cone_degrees` (34°), каждая — коридор `beam_width` (30) на `attack_range` (980) с пирсом до `pierce_count` (4, «Грозовой пробойник» +2) целей БЕЗ спада (`pierce_damage_falloff` 1.0), дедуп урона на весь залп (цель у вершины получает ровно один хит), уже поражённое тело всё равно тратит пирс-бюджет проходящей стрелы (колонна из 6 получает ровно pierce_count хитов); `trap` (hunter_trap) — ПЕРМАНЕНТНЫЙ капкан: живёт до срабатывания либо штатной очистки (без таймера жизни; кап 6 живых + артефакт «Корневой капкан» +2 — старейший тихо снимается), проверка только по группе enemies (игрок не запускает и не снимает), триггер = физический AoE-хлопок (ролл на момент срабатывания × снапшот заряда стойки) + жёсткий паралич `trap_paralyze_seconds` (2.2с; статус `hunter_trap_paralysis` с `movement_locked` — жертва реально стоит, боссы/элиты ×0.25) + зелёное кровотечение `hunter_trap_bleed` по dot-оси (тик = `dot_damage` владельца × Знание, 10 тиков × 0.5с = 5с — течёт при параличе и продолжается после), отброса на триггере НЕТ (паралич держит жертву в капкане). Trait «Сторожевой лук» (SCRUM-909, `CLASS_TRAITS.ranger`, `bow_hit_knockback: 1.0`): каждый прямой хит оружия с конфиг-флагом `bow_knockback_trait` (арбалет и лук; капкан НЕ входит) отбрасывает жертву строго ОТ ИГРОКА (вектор игрок→монстр на момент хита — сплит/пирс/удар в спину толкают прочь от героя, не по полёту снаряда); сила = derived `knockback_power` (конфиг `knockback` 175/150 — «высокий против обычного дальнобоя» при дефолте 80 — + endurance×4 + leadership×3, ×`knockback_multiplier` артефакта «Ударная тетива»), уроном не скейлится, боссы/элиты — общий контроль-резист ×0.25; герой сам никуда не сдвигается. Кит целиком физический (`damage_parameter: "damage"` ← Сила): magic/DoT-апгрейды прямые лучные хиты не скейлят, кровотечение капкана — единственная dot-ось кита. Синергия «Метки охотника» сохранена: паралич (`speed_multiplier 0.0`) и гуляющий импульс отброса оба квалифицируют цель как «меченую» (+25% урона). Покрыто `tests/ranger_kit_test.gd`. Deploy visuals use data-driven source textures when configured: `sound_amp` uses `deploy_sound_amp_field.png`, while `raven_totem` uses `deploy_raven_totem_field.png`; other deploy/trap visuals fall back to each weapon's `WeaponVisual` texture.
## Visual Asset Status
Design visual set is complete for the first 9 classes and 27 weapons as of 2026-06-11. SCRUM-168 adds Soldier as a Back-end class with canonical Soldier character/weapon PNG paths connected; rig/motion remains Animator handoff. SCRUM-169 adds Thief as Back-end gameplay with canonical Thief character/weapon PNG paths connected; rig/motion is `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_sniper_rig_motion_task.md`. SCRUM-165 adds Priest gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_priest_rig_motion_task.md`. SCRUM-162 adds Biologist gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_biologist_rig_motion_task.md`. SCRUM-166 adds Robot gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_robot_rig_motion_task.md`. SCRUM-164 adds Engineer gameplay with canonical PNGs ready and rig/motion in `docs/tasks/animation_engineer_rig_motion_task.md`. Weapon art v2 pass 2026-06-12 reduced oversized socket visuals, fixed scene texture fallbacks, and replaced the Knight visual stack: `assets/sprites/characters/knight.png` is now an unarmed base sprite, while `long_spear.png`, `tower_shield.png`, and `holy_flail.png` are separate polished noble knight weapons. New class full-art PNGs are art-approved at `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). The first 27 weapon PNGs in the matrix above exist at their canonical `assets/sprites/weapons/*.png` paths (`256x256`, transparent), including the 12 formerly fallback weapons:
`shadow_daggers`, `venom_wire`, `storm_longbow`, `hunter_trap`, `plague_syringe`, `bone_saw`, `acid_flask`, `homunculus_vial`, `tower_shield`, `holy_flail`, `briar_staff`, `raven_totem`.

Socket/display status: the original 27 weapon scenes point to matching canonical PNG and use reduced `WeaponVisual.scale` for clearer body/face readability. Soldier scenes point to canonical `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`. Preview sheets: `docs/design/previews/weapon_v2_assets_contact.png` for raw PNG QA and `docs/design/previews/weapon_v2_socket_contact.png` for class/weapon visual placement. `venom_wire` is intentionally thin and best paired with a separate line/VFX during attacks; `hunter_trap` and several deploy/summon weapons can also serve as world sprite bases.

Source-specific summon/deploy visuals (SCRUM-157): `scripts/summoner_weapon.gd` reads `ally_visual_id` / `ally_visual_ids` and passes the selected ID into `AllyMinion.set_visual_id()`. `summon_amulet` randomly uses `ally_druid_beast` or `ally_druid_pack_spirit`; `homunculus_vial` uses the SCRUM-945 PixelLab pair art (`homunculus_tank_*`/`homunculus_caster_*`, 4-directional static frames chosen by movement axis in `AllyMinion`/`SummonerWeapon`); `leadership_echo` is reserved for future echo-style summons. `scripts/class_weapon.gd` reads optional `deploy_texture_path`: `sound_amp` deploys `deploy_sound_amp_field.png`, while `raven_totem` deploys `deploy_raven_totem_field.png`.

Summon role runtime (SCRUM-254/SCRUM-854/SCRUM-859): summon/deploy configs may define `summon_role`, `deploy_role` and role coefficients. `SummonerWeapon` builds an `AllyMinion.set_combat_profile()` payload from owner `derived_parameters` and Leadership: damage, move speed, attack interval, lifetime, max HP, control knockback, support healing and small splash. Current mobile summon roles are `pack_damage` (Druid beasts), `tank_control` (Chemist homunculus), `support_totem`, `engineer_sentry` and `orbit_drone`; deploy identity roles are `stage_pulse` (Guitarist amp), `support_totem` (Druid raven totem), `turret_dps` (Engineer sentry), `orbit_drone` (Engineer drone), and `mine_grid` (Engineer mines). Mobile summon weapons tag minions by owner+weapon, prefill about half of the current cap at battle start, and then replenish normally. ClassWeapon deploy count uses `max_summons_cap` where configured, so Leadership still improves the loop but cannot create AFK runaway device carpets. `ProgressionData.weapon_archetype()` treats `summon_role` weapons as summon archetype, and the balance harness models pure summon DPS through minion output rather than an invisible direct hit.

## Berserk Class Trait — «Ярость» (SCRUM-1004)

Signature trait Берсерка (канон: `docs/design/class_traits_registry.md`, данные:
`ProgressionData.CLASS_TRAITS.berserk`, `rage_damage_bonus_cap: 0.40`): исходящий
урон растёт НЕПРЕРЫВНО от недостающего здоровья — риск/награда identity «живёт в
гуще боя».

Формула (единая точка — `ProgressionData.class_rage_damage_bonus`):

```
missing_ratio = clamp(1 − health / max_health, 0, 1)
бонус         = 0.40 × missing_ratio          # линейно, без ступенек
множитель     = 1 + бонус                     # ×1.0 полное HP, ×1.2 половина,
                                              # ровно ×1.4 (кап) на пустом
```

Клампы невалидного HP: отрицательное health → ровно кап (+40%), health выше
max_health или max_health ≤ 0 → без бонуса (×1.0); NaN/бесконечный урон
невозможен. Кап жёсткий — выше +40% бонус не растёт и не стакается.

Слой применения — Berserk-only, ПОСЛЕ обычных модификаторов урона/типа:
`Player.rage_damage_multiplier` читается в `BerserkWeapon._rolled_damage`
(после ролла крита), т.е. покрывает все ТРИ оружия кита (меч/топор/молот) в
одной точке; вторичные melee-эффекты (close bonus, execute, followup-дуга)
наследуют уже усиленный `dealt` и повторно НЕ множат — рекурсивного стака нет.
Вторая ось кита — эхо-волна ульты «Неистовство»
(`Player._trigger_berserk_ultimate_echo`) — усилена тем же множителем один раз.
Артефактные low-HP эффекты (SCRUM-500: «Кровавый Рубеж», «Второе Дыхание»,
«Рубеж Стража») — ОТДЕЛЬНЫЙ стакующийся слой от порога 30% и не меняются;
generic-урон вне кита (универсальные DoT-артефакты и т.п.) trait не трогает.
Другим классам не течёт: у классов без `rage_damage_bonus_cap` множитель
ровно 1.0 (data-driven).

Бюджет-зеркало: `class_rage_expected_damage_factor` = 1 + 0.40 ×
`RAGE_BUDGET_EXPECTED_MISSING_HP` — матожидание недостающего HP принято 30%
(огромный запас крови + сустейн держат Берсерка в средне-высоком HP большую
часть забега) ⇒ фактор ×1.12 на канальные выходы
кита в `estimate_weapon_budget_for_stats` (до ульты, паттерн `action_echo`).
`budget_tuning_for` компенсирует кит: на полном HP Берсерк ≈ −11% ниже
коридора, на почти пустом — до ≈ +25% выше (осознанный risk/reward коридор).
Контракты: `tests/berserk_rage_trait_test.gd` (формула, кап, непрерывность,
все три оружия, ульта-эхо, изоляция, бюджет-фактор) +
`tests/berserk_dps_runaway_gate.gd` (live анти-runaway пик).

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

## Knight Class Trait — «Возмездие» + кит редизайна (SCRUM-920..923)

Signature trait Рыцаря (канон: `docs/design/class_traits_registry.md`, данные:
`ProgressionData.CLASS_TRAITS.knight`): враг, нанёсший Рыцарю КОНТАКТНЫЙ удар,
отбрасывается прочь (`retaliation_knockback: 760` — при декее 2400 px/s² это
≈120px смещения, за пределы типового contact_range 40-90px: серия контактных
тычков рвётся, windup врага сбрасывается). Потребитель —
`Player._try_retaliation_knockback`; атакующий приходит 3-м аргументом
`take_damage` ТОЛЬКО из `enemy._update_contact_damage` (снаряды/зоны/элитные
страйки атакующего не передают — дальнобой трейтом не отбрасывается).
Правила смещения (единая таксономия `CombatTargetQuery.is_epic_displacement_immune`):

- обычные монстры и МИНИ-элиты волн (`epic_scale_profile == "mini_elite"`) —
  полный отброс;
- боссы и ГЛАВНЫЕ элиты карты (группы `bosses`/`elite_enemies`, профили
  `boss`/`elite`) — не смещаются трейтом вовсе;
- внутренний кулдаун `retaliation_cooldown: 0.4с` — предохранитель от
  физ/пафинг-раскачки паков (частота событий урона и так зажата i-frames 0.32с);
- полностью предотвращённые удары (godmode/i-frames/невидимость/ульта/уворот)
  отброса не дают; другим классам trait не течёт (data-driven ключи).

Отдельный слой от block/counter пассива оружий (`_try_knight_counter`): counter —
урон+стаггер по дуге с оружейным кулдауном, trait — гарантированный отброс
именно атакующего.

Кит (все три оружия — `BerserkWeapon`, data-driven конфиг-ключи):

- `long_spear` «Тройной укол» (SCRUM-921): цикл = три быстрых последовательных
  укола лево→центр→право (`thrust_count: 3`, `thrust_fan_degrees: 16`,
  `thrust_step_time: 0.11с`), полоса шире старой (90→110×540). Одна цель ловит
  максимум ОДИН укол за цикл (дедуп `_hit_targets` на весь цикл —
  документированное анти-triple-dip решение). Бюджет-зеркало: solo_hits=1.0,
  five_hits растёт от углового размаха веера (`_budget_hit_model`, ветка strip).
  Артефакт «Веер уколов» (`spear_triple_thrust`) добавляет два крайних укола
  ±32° на 55% урона.
- `tower_shield` «Конус-баш» (SCRUM-922): конус 95° целится в направление
  БЛИЖАЙШЕГО монстра (штатный `_target_direction`), все цели конуса получают
  урон и отброс прочь от Рыцаря. Формула импульса:
  `(260 + knockback_power × stagger_knockback_stat_ratio(3.0)) × melee_stagger_knockback_multiplier(1.15)`,
  где `knockback_power` = derived (база 60 + endurance×4 + leadership×3) ×
  `knockback_multiplier` × meta — вложения в отброс видимо усиливают смещение
  (база Рыцаря ≈705 импульса ≈ 104px; глубокие вложения — 250px+). Боссы/главные
  элиты капятся `epic_stagger_knockback_factor: 0.25` (урон — полный, капится
  только смещение), мини-элиты отлетают полноценно. Контроль-оружие: урон ниже
  офф-опций (dmg_mult 0.72 против 3.0 у копья).
- `holy_flail` «Расширяющаяся спираль» (SCRUM-923): каст = `spiral_steps: 7`
  шагов по `spiral_step_time: 0.085с`; фронт-дуга `spiral_arm_degrees: 150°`
  делает ПОЛНЫЙ оборот (360°×(k+1)/steps от направления атаки), радиус фронта
  растёт от `spiral_start_radius_ratio: 0.22`×R до полного R (235) — урон
  ложится от центра наружу, враги на разных радиусах страдают в разные моменты
  каста. Максимум ОДИН хит по цели за каст (дедуп — анти-runaway правило);
  последний шаг замыкает оборот на стартовом угле с полным радиусом (соло-цель
  гарантированно накрыта). Бюджет-зеркало: спиральное покрытие диска 0.85 в
  ветке circle `_budget_hit_model`. Параметры для VFX (SCRUM-924): см.
  коммент в Jira SCRUM-923.

SCRUM-924 синхронизирует визуальный ритм с этой механикой без изменения её
формул. `HolyFlail.tscn` использует узкий Animator-bridge
`scripts/holy_flail_weapon.gd`: каждый из семи live-шагов передаёт фактические
угол и радиус в `HolyFlailSpiralVfx`. Полупрозрачная цепь растёт по спирали от
центра, PixelLab-ghost кистеня проходит 8-кадровый source pack и на седьмом шаге
замыкает оборот при `235px`. Source/object/group/animation IDs, `256x256` RGBA
frames, pivot `(128,128)`, `>=16px` gutters и contact sheet находятся в
`docs/design/references/scrum924_holy_flail_spiral_vfx/`; shared
`berserk_weapon.gd`, damage windows и анти-double-hit дедуп не менялись.

Покрытие: `tests/knight_kit_test.gd` (trait: направление/сила/таксономия/кулдаун/
утечка/предотвращённые удары + сквозной контактный путь; копьё: геометрия веера,
дедуп, порядок окон по кадрам, артефакт; щит: выбор ближайшей цели, членство
конуса, скейл отброса, кап эпиков; кистень: прогрессия радиуса, полный оборот,
max-hit, cleanup).

## SCRUM-1067 weapon-final identity contract

Следующая схема созвездий не добавляет четвёртое оружие и не меняет canonical
trios. Каждая запись `ProgressionData.WEAPONS_BY_CLASS` получает ровно одну
ветвь из шести cost-1 узлов и один уникальный final. Manifest явно хранит все
306 узлов с пятью разными boon effect profiles на ветвь. Полные 51 hook/caps и
negative-control записаны в
`docs/design/data/scrum1067_weapon_finals_manifest.json`.

Финал обязан усиливать существующую нишу — target pattern, cadence, control,
sustain, summon/deploy ownership, zone или projectile behavior — и не может
быть generic multiplier-only. Переиспользование subsystem разрешено только при
уникальном `mechanic_id`, weapon-specific параметрах и отдельном positive
fixture. Два других оружия класса являются обязательными negative-controls.

Runtime SCRUM-1068 предоставляет API
`skill_modifiers_for_weapon(state,class_id,weapon_id)`: class-wide aggregation
schema 5 недостаточна для `damage_flat ≥10` и mechanic finals без утечки на всё
трио.

## Targeting Rule

Все атакующие оружия игрока целятся в ближайшего живого врага, а не в направление движения. Без врагов сохраняется последнее направление атаки.

## Cleanup Rules

- При смене персонажа/оружия/забега/смерти/возврате в меню временные weapon effects очищаются.
- Deployables/traps/totems/summons должны быть в `player_weapon_effects` и не оставаться на карте после cleanup.
- Class-specific leftovers не должны оставаться на карте.
