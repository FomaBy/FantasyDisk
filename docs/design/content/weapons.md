<!-- content-registry-section -->

# FantasyDisk Content Registry — Оружие И Ультимейты

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Оружие

| ID | Игровое имя | Класс | Роль | Источник | Статус |
| --- | --- | --- | --- | --- | --- |
| `sword` | Двуручный меч | Берсерк | Узкий сектор 100 градусов радиуса 350 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `axe` | Двуручный топор | Берсерк | Широкий сектор 180 градусов радиуса 250 | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `hammer` | Двуручный молот | Берсерк | Круговой AoE 150px с Radius scaling и diminishing по плотной толпе | `ProgressionData.BERSERK_WEAPONS` | Реализовано |
| `soldier_rifle` | Аркебуза строя | Солдат | Suppression burst: 3 коротких выстрела по линии; основная цель полный урон, соседи reduced damage | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierRifle.tscn` | Реализовано |
| `soldier_grenade` | Граната с фитилем | Солдат | Delayed ground explosion: телеграф, короткий фитиль, falloff урона к краю | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierGrenade.tscn` | Реализовано |
| `soldier_bayonet` | Штык-стойка | Солдат | Defensive brace corridor: каждый враг в стойке получает один укол и knockback | `ProgressionData.SOLDIER_WEAPONS`, `scenes/SoldierBayonet.tscn` | Реализовано |
| `thief_coin_pouch` | Кошель Рикошета | Вор | Coin ricochet (SCRUM-897): цепь 6 прыжков (кап 8), спад до 50% к последнему, мгновенное золото с первых 3 целей | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefCoinPouch.tscn`, `assets/sprites/weapons/thief_coin_pouch.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_shadow_cloak` | Отравленный Кинжал | Вор | Shadow backstab (SCRUM-897): фантомный кинжал без движения героя, паралич-яд и удар в спину ×1.35 | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefShadowCloak.tscn`, `assets/sprites/weapons/thief_shadow_cloak.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `thief_smoke_bomb` | Дымовая Бомба | Вор | Smoke bomb (SCRUM-897): бросок → AoE-взрыв → недамажащее облако с позиционным dodge (кап 0.90 в дыму) | `ProgressionData.THIEF_WEAPONS`, `scenes/ThiefSmokeBomb.tscn`, `assets/sprites/weapons/thief_smoke_bomb.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_orb_ring` | Кольцо Четырёх Стихий | Элементалист | SCRUM-948 square field: квадратная AoE в точке каста, тики трёх каналов (магия+физика+ожог) с отбросом от центра | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistOrbRing.tscn`, `assets/sprites/weapons/elementalist_orb_ring.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_prism_focus` | Призматический Фокус | Элементалист | SCRUM-949 full-map X: диагональный разлом во всю арену через точку фокуса + центр-AoE | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistPrismFocus.tscn`, `assets/sprites/weapons/elementalist_prism_focus.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `elementalist_meteor_core` | Ядро Метеора | Элементалист | SCRUM-950 heavy meteor: самое медленное оружие игрока — телеграф+падение, тяжёлый удар, догорающая DoT-зона | `ProgressionData.ELEMENTALIST_WEAPONS`, `scenes/ElementalistMeteorCore.tscn`, `assets/sprites/weapons/elementalist_meteor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `sniper_deadeye_rifle` | Винтовка Мертвого Глаза | Снайпер | Sniper lockshot: короткий прицел/телеграф, затем точный дальний луч по locked target и line falloff | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperDeadeyeRifle.tscn`, `assets/sprites/weapons/sniper_deadeye_rifle.png`, `assets/sprites/effects/vfx_weapon_sniper_deadeye_rifle_endpoint_impact.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 endpoint VFX готов к SCRUM-931 |
| `sniper_spotter_scope` | Прицел Наводчика | Снайпер | Sniper kill-zone: маркирует область у цели и вызывает несколько точных sky-beam попаданий по врагам внутри | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperSpotterScope.tscn`, `assets/sprites/weapons/sniper_spotter_scope.png`, `assets/sprites/effects/vfx_weapon_sniper_spotter_scope_{telegraph,impact}.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 telegraph/impact готовы к SCRUM-932 |
| `sniper_shatter_rounds` | Осколочные Патроны | Снайпер | Sniper split round: основной дальний выстрел раскалывается веером; отдельный SCRUM-934 projectile component рассчитан на многократный spawn без визуального шума | `ProgressionData.SNIPER_WEAPONS`, `scenes/SniperShatterRounds.tscn`, `assets/sprites/weapons/sniper_shatter_rounds.png`, `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds_projectile.png`, `scripts/cutout_rig_2d.gd` | Реализовано; SCRUM-934 projectile VFX готов к SCRUM-933 |
| `priest_reliquary` | Светлый Реликварий | Священник | Sanctify: отмечает цель священным знаком, затем взрыв по области лечит часть нанесенного урона | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestReliquary.tscn`, `assets/sprites/weapons/priest_reliquary.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_censer` | Кадило Обета | Священник | Ward pulses: несколько защитных волн вокруг героя наносят урон и дают малое лечение | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestCenser.tscn`, `assets/sprites/weapons/priest_censer.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `priest_chime` | Колокол Молитвы | Священник | Prayer chain: молитвенная нить перескакивает между врагами и возвращает sustain | `ProgressionData.PRIEST_WEAPONS`, `scenes/PriestChime.tscn`, `assets/sprites/weapons/priest_chime.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_spore_lens` | Споровая Линза | Биолог | Spore bloom: три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSporeLens.tscn`, `assets/sprites/weapons/biologist_spore_lens.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_sample_injector` | Инъектор Образцов | Биолог | Sample dart: берет образец у цели, затем два анализа бьют ее и ближайшие ткани | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSampleInjector.tscn`, `assets/sprites/weapons/biologist_sample_injector.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `biologist_symbiote_seed` | Семя Симбионта | Биолог | Symbiote web: первичная цель связывается с соседними врагами и делит биоурон по сети | `ProgressionData.BIOLOGIST_WEAPONS`, `scenes/BiologistSymbioteSeed.tscn`, `assets/sprites/weapons/biologist_symbiote_seed.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_magnetic_anchor` | Магнитный Якорь | Робот | Magnetic anchor: отложенный тяжёлый AoE в точке цели, полный урон с falloff от центра, стягивает рядовых к центру 0.85/каст (импульс cap 1500); элитки/боссы не смещаются, урон полный | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotMagneticAnchor.tscn`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_hydraulic_press` | Гидравлический Пресс | Робот | Compression line: урон по ВСЕЙ ширине коридора suppression_width (300, ×1.30 с «Калибратором»), прижимает рядовых к оси 0.80/каст; элитки/боссы — полный урон, резист смещения ×0.25; SCRUM-917 PixelLab VFX сжимается side-to-centre и синхронизирует active frame с hit delay 0.20с | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotHydraulicPress.tscn`, `scenes/vfx/RobotHydraulicPressCompressionVfx.tscn`, `assets/sprites/weapons/robot_hydraulic_press.png`, `assets/sprites/effects/robot_hydraulic_press_compression/`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `robot_reactor_core` | Реакторное Ядро | Робот | Reactor vent: ровно 4 вентиля 90° от мировой фазы (без самонаведения), паттерн +6°/каст — веер обходит круг за 15 атак; урон вентиля = ролл ×0.42, extra_projectile — dormant/internal injected-only compatibility seam with no live production source; it does not expand the blades | `ProgressionData.ROBOT_WEAPONS`, `scenes/RobotReactorCore.tscn`, `assets/sprites/weapons/robot_reactor_core.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_sentry_wrench` | Ключ Часового | Инженер | Sentry turret (SCRUM-888): разворачивает персистентные стационарные турели (жёсткий лимит 2, старейшая заменяется), турели сами обстреливают ближайших врагов залпом снарядов с capped splash | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerSentryWrench.tscn`, `scenes/SentryTurret.tscn`, `scripts/sentry_turret.gd`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_turret/sentry_turret.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_repair_drone` | Орбитальный Дрон | Инженер | SCRUM-906/FAN-1075: 2 увеличенных контактных дрона по умолчанию, строго напротив друг друга на кольце 121 px; visual scale 0.24, спираль с третьего дрона, кап 6 | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerRepairDrone.tscn`, `assets/sprites/weapons/engineer_repair_drone.png`, `scripts/engineer_orbit_drone.gd`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `engineer_pressure_mines` | Минная Сетка | Инженер | Pressure mine grid: три мины веером срабатывают отдельно при касании врагом | `ProgressionData.ENGINEER_WEAPONS`, `scenes/EngineerPressureMines.tscn`, `assets/sprites/weapons/engineer_pressure_mines.png`, `scripts/cutout_rig_2d.gd` | Реализовано |
| `dark_book` | Книга тьмы | Темный маг | Два AoE-снаряда в две ближайшие цели | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `cursed_skull` | Проклятый череп | Темный маг | Самонаводящееся проклятие, DoT и небольшой splash по цели | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `dark_wand` | Темная палочка | Темный маг | Два pierce-луча веером | `ProgressionData.DARK_MAGE_WEAPONS` | Реализовано |
| `electric_guitar` | Электрогитара | Гитарист | Звуковая волна вперед | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `bass_guitar` | Бас-гитара | Гитарист | Частый слабый контроль-пульс с сильным отталкиванием | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `sound_amp` | Звуковой усилитель | Гитарист | Деплойный усилитель: живет ~7с, лимит 1 + floor(Лидерство/4) | `ProgressionData.GUITARIST_WEAPONS` | Реализовано |
| `chakrams` | Чакрамы | Ассасин | Boomerang-коридор туда и обратно; критовые попадания дают shadow burst у цели без перемещения героя | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `shadow_daggers` | Теневые кинжалы | Ассасин | Быстрые короткие multi-stabs в ближней зоне + crit shadow burst у цели | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `venom_wire` | Ядовитая струна | Ассасин | Тонкая poison-линия с DoT + crit shadow burst у цели | `ProgressionData.ASSASSIN_WEAPONS` | Реализовано |
| `moon_crossbow` | Лунный арбалет | Рейнджер | Stance-charged piercing shot | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `storm_longbow` | Грозовой длинный лук | Рейнджер | SCRUM-911/912: stance-charged конус из 5 пробивающих стрел (34°, 980px, pierce 4) с PixelLab bow-release/through-hit VFX | `ProgressionData.RANGER_WEAPONS`, `assets/sprites/effects/vfx_weapon_storm_longbow.png`, `assets/sprites/effects/storm_longbow/storm_longbow_release_spriteframes.tres`, `scenes/vfx/StormLongbowVolleyVfx.tscn` | Реализовано; PixelLab source/evidence в `docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/` |
| `hunter_trap` | Охотничий капкан | Рейнджер | Deploy trap: burst + knockback; stance charge усиливает | `ProgressionData.RANGER_WEAPONS` | Реализовано |
| `restore_potion` | Зелье восстановления | Доктор | Drain/lifesteal-связь к цели | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `plague_syringe` | Чумной шприц | Доктор | Drain-связь с poison DoT и sustain | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `bone_saw` | Костяная пила | Доктор | Ближний saw arc/flurry, DoT и lifesteal от урона | `ProgressionData.DOCTOR_WEAPONS` | Реализовано |
| `blast_powder` | Взрывная пыль | Химик | AoE explosion + spark cloud; combo с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `acid_flask` | Кислотная колба | Химик | Большая poison/acid pool; combo explosion с другим элементом | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `homunculus_vial` | Склянка гомункула | Химик | Temporary minion scaling from magic damage | `ProgressionData.CHEMIST_WEAPONS` | Реализовано |
| `long_spear` | Копье | Рыцарь | Длинный точечный strip + block/counter passive | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `tower_shield` | Башенный щит | Рыцарь | Shield bash / frontal control + сильный block/counter | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `holy_flail` | Освященный кистень | Рыцарь | 7-step center-out spiral (`0.085с`, `22%→100%` radius) + broad holy-control counter; SCRUM-924 PixelLab chain/flail VFX follows each live step | `ProgressionData.KNIGHT_WEAPONS` | Реализовано |
| `summon_amulet` | Амулет призыва | Друид | Командуемая beast pack, scaling from Leadership | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `briar_staff` | Посох терний | Друид | Thorn zone, AoE DoT, crowd control | `ProgressionData.DRUID_WEAPONS` | Реализовано |
| `raven_totem` | Вороний тотем | Друид | Totem pulses, Leadership-scaled deploy limit | `ProgressionData.DRUID_WEAPONS` | Реализовано |

Weapon art v2 2026-06-12: сцены `WeaponVisual` должны использовать texture path, совпадающий с canonical weapon ID (исключение: Berserk `sword/axe/hammer` используют historical файлы `two_handed_sword/axe/hammer.png`). SCRUM-277 закрыл оставшиеся proxy-ссылки новых классов: Вор, Элементалист, Снайпер, Священник, Биолог и Инженер теперь рендерят свои `assets/sprites/weapons/<weapon_id>.png`, а `PriestChime` больше не показывает `sound_amp.png`. `long_spear`, `tower_shield`, `holy_flail` перерисованы как noble knight equipment. Scene scales уменьшены, чтобы оружие занимало примерно 50-65% высоты персонажа и не перекрывало лицо/корпус. Контрольные листы: `docs/design/previews/weapon_v2_assets_contact.png`, `docs/design/previews/weapon_v2_socket_contact.png`. SCRUM-168 добавил 3 Soldier weapon IDs и подключил canonical textures `soldier_rifle.png`, `soldier_grenade.png`, `soldier_bayonet.png`.

Временные visuals классового оружия регистрируются в runtime-группе `player_weapon_effects` и должны удаляться при смене оружия/персонажа, смерти, завершении забега и очистке world state.

## Ультимейты Классов

Источник данных: `scripts/progression_data.gd::ULTIMATE_CONFIGS`. Все ульты активируются через InputMap action `ultimate` и отображаются в HUD как `ULT`.

| Class ID | Ultimate ID/Title | Status |
| --- | --- | --- |
| `berserk` | Неистовство | Реализовано |
| `dark_mage` | Темная буря | Реализовано |
| `guitarist` | Соло | Реализовано |
| `assassin` | Танец клинков | Реализовано |
| `ranger` | Лунный залп | Реализовано |
| `doctor` | Переливание | Реализовано |
| `chemist` | Цепная реакция | Реализовано |
| `knight` | Бастион | Реализовано |
| `druid` | Зов стаи | Реализовано |
