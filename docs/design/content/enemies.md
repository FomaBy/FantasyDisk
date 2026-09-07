<!-- content-registry-section -->

# FantasyDisk Content Registry — Монстры, Элитки И Боссы

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Стандартные Монстры

<!-- canonical-ids: actor -->

Эти имена являются каноническими для задач. Если в коде сцена пока называется generic-именем, в задачах все равно нужно ссылаться на игровое имя из таблицы.

| ID | Игровое имя | Текущая сцена | Архетип | Ассет | Поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_cutter` | Рубака Разлома | `scenes/Enemy.tscn` | Ближний бой | `assets/sprites/enemies/enemy_melee.png`; full-frame pilot `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres` from `assets/sprites/enemies/full_frame/rift_cutter_full_frame_sheet.png` | Идет к игроку, бьет с windup; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `ash_marksman` | Пепельный Стрелок | `scenes/EnemyShooter.tscn` | Дальний бой | `assets/sprites/enemies/enemy_ranged.png`; full-frame `assets/sprites/enemies/full_frame/ash_marksman_spriteframes.tres` from `assets/sprites/enemies/full_frame/ash_marksman_full_frame_sheet.png` | Держит дистанцию и стреляет; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `spark_runner` | Искровой Беглец | `scenes/EnemyRunner.tscn` | Быстрый враг | `assets/sprites/enemies/enemy_suicide_runner.png`; full-frame `assets/sprites/enemies/full_frame/spark_runner_spriteframes.tres` from `assets/sprites/enemies/full_frame/spark_runner_full_frame_sheet.png` | Быстро догоняет игрока, может спавниться пачками; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `stone_bruiser` | Каменный Громила | `scenes/EnemyBruiser.tscn` | Жирный медленный | `assets/sprites/enemies/enemy_bruiser_slow.png`; full-frame `assets/sprites/enemies/full_frame/stone_bruiser_spriteframes.tres` from `assets/sprites/enemies/full_frame/stone_bruiser_full_frame_sheet.png` | Высокий HP, низкая скорость; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `bone_caller` | Костяной Зовущий | `scenes/EnemySummoner.tscn` | Суммонер | `assets/sprites/enemies/enemy_summoner.png`; full-frame `assets/sprites/enemies/full_frame/bone_caller_spriteframes.tres` from `assets/sprites/enemies/full_frame/bone_caller_full_frame_sheet.png` | Призывает маленьких мобов; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `void_mage` | Маг Пустоты | `scenes/EnemyMage.tscn` | Магический ranged | `assets/sprites/enemies/enemy_void_mage.png`; full-frame `assets/sprites/enemies/full_frame/void_mage_spriteframes.tres` from `assets/sprites/enemies/full_frame/void_mage_full_frame_sheet.png` | Давление магическими атаками; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `venom_spitter` | Ядовитый Плеватель | `scenes/EnemySpitter.tscn` | Ranged / hazard | `assets/sprites/enemies/enemy_venom_spitter.png`; full-frame `assets/sprites/enemies/full_frame/venom_spitter_spriteframes.tres` from `assets/sprites/enemies/full_frame/venom_spitter_full_frame_sheet.png` | Дальний плевок, давление зоной; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `rift_shieldbearer` | Щитоносец Разлома | `scenes/EnemyShield.tscn` | Защитный враг | `assets/sprites/enemies/enemy_rift_shieldbearer.png`; full-frame `assets/sprites/enemies/full_frame/rift_shieldbearer_spriteframes.tres` from `assets/sprites/enemies/full_frame/rift_shieldbearer_full_frame_sheet.png` | Более живучий вариант передней линии; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `small_biter` | Малый Кусатель | `scenes/EnemyBiter.tscn` | Маленький быстрый | `assets/sprites/enemies/enemy_small_biter.png`; full-frame `assets/sprites/enemies/full_frame/small_biter_spriteframes.tres` from `assets/sprites/enemies/full_frame/small_biter_full_frame_sheet.png` | Давит числом и скоростью; визуально использует registry `move` 6f loop и `attack_primary`/`attack`/`hit`/`death` 6f one-shots | Реализовано |
| `bone_shaman` | Костяной Шаман | `scenes/EnemyBoneShaman.tscn` | Продвинутый суммонер | `assets/sprites/enemies/enemy_bone_shaman.png`; full-frame `assets/sprites/enemies/full_frame/bone_shaman_spriteframes.tres`, PixelLab source `assets/sprites/enemies/pixellab/bone_shaman/` (FAN-2618) | Призыв и поддержка толпы; визуально использует FAN-2519 explicit-eight-direction contract (`idle`/`move`/`attack`/`hit`/`death` × 8 directions, no flip_h, registry `explicit_eight_directions: true`) | Реализовано |
| `winged_spark` | Крылатая Искра | `scenes/EnemyFlyingRunner.tscn` | Летающий враг | `assets/sprites/enemies/enemy_winged_spark.png`; full-frame `assets/sprites/enemies/full_frame/winged_spark_spriteframes.tres` (FAN-2619: explicit 8-направленный PixelLab-пак, `assets/sprites/enemies/pixellab/winged_spark/`) | Hover-движение; pit layer отключен вместе с ямами; визуально использует registry explicit-eight-direction `idle_<dir>`/`move_<dir>`/`attack_<dir>`/`hit_<dir>`/`death_<dir>` строки, без flip_h; `idle_<dir>` несёт hover-flap loop (у летающего актора нет отдельного состояния "hover" в резолвере) | Реализовано |

## Элитные Монстры

<!-- canonical-ids: actor -->

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Уникальное поведение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `iron_bastion` | Железный Оплот | `scenes/EliteArmored.tscn` | Танкующая элитка | `assets/sprites/elites/iron_bastion.png`; full-frame `assets/sprites/elites/full_frame/iron_bastion_spriteframes.tres` (FAN-3093: explicit 8-направленный PixelLab-пак, `assets/sprites/elites/pixellab/iron_bastion/`) | Пассив: периодический щит. Уникальная атака `slam_wave`: замах 0.6с с telegraph-кругом, затем кольцевая ударная волна (радиус 260, урон + отбрасывание), кулдаун 6с. Визуально использует registry explicit-eight-direction `idle_<dir>`/`move_<dir>`/`attack_<dir>`/`hit_<dir>`/`death_<dir>`/`skill_shield_block_<dir>`/`skill_slam_wave_<dir>` строки, без flip_h; `skill_shield_block_<dir>` кадры существуют для консистентности пака, но пассивный щит сейчас проигрывает общее `cast` состояние (подключение — отдельная задача) | Реализовано |
| `night_stalker` | Ночной Сталкер | `scenes/EliteStalker.tscn` | Агрессивная элитка | `assets/sprites/elites/night_stalker.png`; full-frame `assets/sprites/elites/full_frame/night_stalker_spriteframes.tres` | Пассив: рывки к игроку. Уникальная атака `shadow_strike`: уходит в тень на 0.5с с telegraph-меткой за спиной игрока, телепортируется туда и бьет (радиус 92), кулдаун 7с. Визуально: `move` loop, `attack`/`attack_primary`, `death`, `skill_shadow_strike`, `skill_phase_dash` + `attack_*` aliases | Реализовано |
| `plague_prophet` | Чумной Пророк | `scenes/ElitePoisoned.tscn` | Зональная элитка | `assets/sprites/elites/plague_prophet.png`; full-frame `assets/sprites/elites/full_frame/plague_prophet_spriteframes.tres` | Пассив: ядовитые зоны. Уникальная атака `poison_volley`: 3 lob-снаряда по дуге в telegraph-метки, в точках падения лужи на 3с (тик 0.6с), кулдаун 8с. Визуально: `move` loop, `attack`/`attack_primary`, `death`, `skill_poison_volley`, `skill_plague_aura` + `attack_*` aliases | Реализовано |
| `shard_marshal` | Маршал Осколков | `scenes/EliteCommander.tscn` | Командир толпы | `assets/sprites/elites/shard_marshal.png`; full-frame `assets/sprites/elites/full_frame/shard_marshal_spriteframes.tres`; PixelLab source `assets/sprites/elites/pixellab/shard_marshal/` (`06de6f32-fca4-43f2-a657-b011a85d7632`, FAN-2623) | Пассив: одноразовая аура усиления ближайших врагов. Уникальная атака `shard_fan`: веер из 5 кристальных снарядов в сторону игрока после замаха 0.5с, кулдаун 6с. Визуально: `idle` 1f loop, `move` 8f loop, `attack`/`hit`/`death` и обе `skill_*` строки по 8 ракурсам, 7/5/7/7/7f one-shot, `attack_*` aliases; `explicit_eight_directions: true`, без `flip_h`. `mini_swarm_sniper` намеренно использует fallback на этот базовый ID | Реализовано |

Обновление SCRUM-135 от 2026-06-12: все 4 активные элитки используют native `512x512` source PNG и перенарезанные `assets/sprites/elites/cutout/` части под `scripts/sliced_rig_manifest.gd` `size = Vector2(512, 512)`. Поза/силуэт сохранены 1:1 относительно прежних 256px-спрайтов, чтобы epic scale оставался геометрически тем же, но без билинейного мыла на QHD/Retina.

Все уникальные атаки элиток: параметры лежат в `ProgressionData.ELITE_ATTACK_CONFIGS` (data-driven), reusable mechanics — в `ProgressionData.ENEMY_MECHANIC_CATALOG`, unique signatures — в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`; урон атаки ограничен 25% max HP игрока. VFX: `elite_telegraph_circle.png`, `elite_shockwave_ring.png`, `elite_shadow_trail.png`, `elite_poison_lob.png`, `elite_crystal_shard.png` в `assets/sprites/effects/`.

## Умения Монстров (Канонические Имена Кодекса)

Зарегистрированы задачей «Кодекс» 2026-06-11. Это ссылочные имена: задачи и обсуждения
ссылаются на них. Источник данных кодекса: `scripts/codex_data.gd::MONSTERS`.

SCRUM-621 unlock tracking stores canonical Codex entry IDs, not ability IDs:
standard, elite and mini-elite monsters go to `discovered_monsters`, boss IDs go
to `discovered_bosses`, and artifact IDs from `ProgressionData.ARTIFACTS` go to
`discovered_artifacts` in `MetaProgression`.

| ID умения | Игровое имя | Носитель | Что делает |
| --- | --- | --- | --- |
| `ragged_lunge` | Рваный Выпад | Рубака Разлома | Контактный удар с замахом (windup) |
| `ash_shot` | Пепельный Выстрел | Пепельный Стрелок | Одиночный снаряд по герою |
| `spark_rush` | Искровой Натиск | Искровой Беглец | Быстрое сближение с героем |
| `stone_press` | Каменный Напор | Каменный Громила | Тяжелый контактный удар, высокий HP |
| `bone_call` | Зов Костей | Костяной Зовущий | Призыв малых кусателей |
| `void_bolt` | Сгусток Пустоты | Маг Пустоты | Магический снаряд |
| `venom_spit` | Ядовитый Плевок | Ядовитый Плеватель | Дальнобойный плевок |
| `rift_wall` | Стена Разлома | Щитоносец Разлома | Повышенная живучесть передней линии |
| `swarm_bite` | Укус Стаи | Малый Кусатель | Частые слабые укусы, сила в числе |
| `bone_rite` | Костяной Ритуал | Костяной Шаман | Ритуальный призыв свиты |
| `spark_dive` | Пикирование Искры | Крылатая Искра | Hover-полет и заход поверх толпы |
| `iron_shield` | Железный Щит | Железный Оплот | Пассив: периодический щит (снижение урона) |
| `quaking_slam` | Сотрясающий Удар | Железный Оплот | Slam-волна: замах, кольцо 260, урон + отбрасывание |
| `predator_dash` | Хищный Рывок | Ночной Сталкер | Пассив: рывок к игроку |
| `shadow_strike` | Теневой Удар | Ночной Сталкер | Уход в тень, телепорт за спину, удар |
| `rot_omen` | Гнилое Знамение | Чумной Пророк | Пассив: отложенный ядовитый взрыв зоны |
| `venom_volley` | Ядовитый Залп | Чумной Пророк | 3 lob-снаряда, ядовитые лужи |
| `shard_aura` | Аура Осколков | Маршал Осколков | Пассив: разовое усиление обычных монстров |
| `shard_fan` | Веер Осколков | Маршал Осколков | Веер из 5 кристальных снарядов |
| `rift_volley` | Залп Разлома | Страж Разлома | Веерный залп снарядов |
| `rift_zone` | Зона Разлома | Страж Разлома | Отложенный взрыв размеченной зоны |
| `riftling_call` | Призыв Осколышей | Страж Разлома | Призыв свиты тройками |
| `warden_shield` | Щит Стража | Страж Разлома | Периодический щит |
| `flicker_step` | Мерцающий Уход | Страж Разлома | Шанс полного уворота от удара |
| `devourer_dash` | Рывок Пожирателя | Пожиратель Диска | Бросок через арену |
| `disk_slam` | Удар Диска | Пожиратель Диска | Круговая зона удара |
| `radial_burst` | Радиальный Взрыв | Пожиратель Диска | Кольцо снарядов во все стороны |
| `devourer_frenzy` | Ярость Пожирателя | Пожиратель Диска | Энрейдж на низком HP |

## Мини-Элитки (Свита Возвышения L7, SCRUM-155)

Data-driven ростер `scripts/progression_data_enemies.gd::MINI_ELITE_KINDS` содержит 10 видов: `mini_scavenger_reaper` Жнец-Падальщик, `mini_plague_bellringer` Чумной Звонарь, `mini_bone_warden` Костяной Страж, `mini_spark_wight` Искровик, `mini_rot_hound` Гнилая Гончая, `mini_shadow_devourer` Теневой Пожиратель, `mini_siege_rammer` Осадный Таран, `mini_swarm_sniper` Роевой Снайпер, `mini_plague_berserker` Чумной Берсерк и `mini_void_phantom` Фантом Бездны. Каждый вид сохраняет базовую elite-сцену, профиль hp/speed/damage, RGB-тинт различимости и поведение ближайшего elite-паттерна. Свита L7 выбирает вид случайно (`combat_director._maybe_spawn_mini_elite`); kind-мета `mini_elite_kind` на узле. FAN-3627: девять новых/переведённых mini-elite паков имеют собственные завершённые PixelLab character exports с 8 направлениями, RGBA source-фреймами, прозрачным 512×512 runtime, общим footline/pivot, SHA-256 provenance manifest и actor-local `SpriteFrames`; `mini_rot_hound` оставлен без изменений. Для `mini_scavenger_reaper` и `mini_void_phantom` повторно сгенерированы только проблемные 6f directional source/runtime кадров (`move_north`/`move_west`); остальные кадры сохранены. Runtime lookup предпочитает registered `mini_elite_kind` и не использует fallback для девяти target actors. Контрактная проверка находится в `tests/fan3627_mini_elite_directional_test.py`; gameplay, collision, damage, timing и balance не менялись.

## Боссы

| ID | Игровое имя | Текущая сцена | Роль | Ассет | Паттерны | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| `rift_warden` | Страж Разлома | `scenes/BossWarden.tscn` | Финальный босс контроля | `assets/sprites/bosses/boss_rift_warden.png`; full-frame `assets/sprites/bosses/full_frame/rift_warden_spriteframes.tres`; SCRUM-865 PixelLab object `ab1c7701-3ee7-4c7c-8842-22a7def87f08` | Залпы, зоны разлома, призыв, щит, увороты. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_gravity_well`, `skill_rift_zone` + `attack_*` aliases | Реализовано |
| `disk_devourer` | Пожиратель Диска | `scenes/BossDiskDevourer.tscn` | Финальный босс давления | `assets/sprites/bosses/boss_disk_devourer.png`; full-frame `assets/sprites/bosses/full_frame/disk_devourer_spriteframes.tres`; FAN-2635 PixelLab character `b4c5d6bf-a14b-4114-b862-91c7340c4d3a` (8-direction, `explicit_eight_directions: true`) | Рывки, disk slam AoE, radial burst, enrage. Визуально: `idle`/`move`/`attack`/`hit`/`death`/`skill_vampiric_bite`/`skill_rift_zone` × 8 октантов, без flip | Реализовано |
| `bone_archon` | Костяной Архонт | `scenes/BossBoneArchon.tscn` | Финальный босс-некромант | `assets/sprites/bosses/boss_bone_archon.png`; full-frame `assets/sprites/bosses/full_frame/bone_archon_spriteframes.tres`; SCRUM-865 PixelLab object `0335a72f-9905-4a18-ba1e-e91d2a9de9bc` | Волны скелетов (summon), веер черепов (volley), костяная стена (волна зон с проходом). Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_skull_volley`, `skill_bone_prison` + `attack_*` aliases | Реализовано |
| `brood_mother` | Матерь Роя | `scenes/BossBroodMother.tscn` | Финальный босс-рой | `assets/sprites/bosses/boss_brood_mother.png`; full-frame `assets/sprites/bosses/full_frame/brood_mother_spriteframes.tres`; SCRUM-865 PixelLab object `0f0db439-9b79-4b25-8951-988319c5e821` | Частый выводок мелких, паутинные зоны замедления (apply_web_slow), рывок в фазе 3. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_brood_spawn`, `skill_web_zone` + `attack_*` aliases | Реализовано |
| `ashen_colossus` | Пепельный Колосс | `scenes/BossAshenColossus.tscn` | Финальный босс-гигант | `assets/sprites/bosses/boss_ashen_colossus.png`; full-frame `assets/sprites/bosses/full_frame/ashen_colossus_spriteframes.tres`; SCRUM-865 PixelLab object `eb2bfa56-9406-4855-96e6-dc05c9272494` | Slam-волны + тлеющие зоны после ударов, редкий radial burst, энрейдж <25% HP (быстрее, шире волны). Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_molten_slam`, `skill_armor_pulse` + `attack_*` aliases | Реализовано |
| `bloodthorn_lion` | Кровавый Шипастый Лев | `scenes/BossBloodthornLion.tscn` | Новый боссовый хищник (SCRUM-794, design SCRUM-779) | Live static `assets/sprites/bosses/boss_bloodthorn_lion.png`; full-frame `assets/sprites/bosses/full_frame/bloodthorn_lion_spriteframes.tres`; SCRUM-865 PixelLab object `1b923d8c-e83e-48a1-970e-4681f63ead0a` | Прыжки-рывки (dash-pounce), radial burst шипов, колючие `BossRiftZone` bleed-зоны, уникальная `BloodthornSpikeRing` (кольцо с проходом), enrage <35% HP. Визуально: `move`, `attack`/`attack_primary`, `death`, `skill_spike_ring`, `skill_rift_zone` + `attack_*` aliases | Runtime и full-frame реализованы; **вне случайной route-ротации** до QA-gated follow-up |
| `secret_ascension_boss` | Secret Ascension Boss | `scenes/BossSecretAscension.tscn` | Post-final-Act-2 max-Ascension capstone boss | Design source/runtime candidate `assets/sprites/bosses/secret_ascension_boss.png`; source pack `docs/design/references/bosses/secret_ascension_boss/`; telegraphs `assets/sprites/effects/secret_ascension_boss_*_telegraph.png` | `SecretBossSectorRing`, delayed `BossRiftZone` eruptions, phase-2 adds/pressure at 50% HP, phase 3 below 25% HP | SCRUM-539 Design source pack done; animation/runtime integration handoff pending |
| `skeletal_dragon` | Костяной Дракон | TBD | Planned flying skeletal dragon boss | Concept reference `docs/design/references/bosses/pixellab_roster_redraw_2026_06/openai_concepts/skeletal_dragon_concept_openai.png`; PixelLab candidate `assets/sprites/bosses/pixellab_candidates/skeletal_dragon/skeletal_dragon_pixellab_alpha.png` | Planned: flying skeletal pressure, bone/necromancy hazards, wing-safe telegraphs. Mechanics/scene not implemented. | SCRUM-779 Design-source candidate; backend/animation handoff pending |

SCRUM-352/SCRUM-394 Design source для full-frame rows хранится как
`assets/sprites/{enemies,elites,bosses}/full_frame/<entity_id>_full_frame_sheet.png`
(`1704x1144`, RGBA, transparent, 6 columns x 4 rows, `256x256` cells, `24px`
discard-only gutters, `24px` outer padding). Row contract, safe-slicing metadata
and pivot notes are recorded in
`docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`.
SCRUM-378 подключил визуальную маршрутизацию этих boss `skill_*` rows из
`scripts/boss.gd`: callbacks способностей запрашивают соответствующий full-frame
state, но урон, телеграфы, cooldowns, targeting и spawn timing остаются
Back-end mechanics data без изменений.
SCRUM-380/SCRUM-394 Design source для явных full-frame `death` rows хранится в
`assets/sprites/bosses/full_frame/<boss_id>/<boss_id>_death_*.png` и
`<boss_id>_death_row.png`; source references are `1704x304` RGBA with `256x256`
cells, `24px` discard-only gutters and `24px` outer padding; общий манифест:
`docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`.
Для `bone_archon`, `brood_mother` и `ashen_colossus` строки готовы как Design
source pack и подключены Animator-owned SpriteFrames integration SCRUM-370.

Обновление SCRUM-135 от 2026-06-12: оба boss source PNG заменены на native `512x512` и перенарезаны в `assets/sprites/bosses/cutout/`; `rift_warden` сохраняет отдельный `vortex` part, `disk_devourer` остается single-torso rig по текущему CONFIG. Epic boss scale не менялся.

SCRUM-779 (2026-07-01) добавил PixelLab-first Design-source pass для boss
roster refresh и двух новых candidates. OpenAI image generation использовался
только для concept references `skeletal_dragon` и `bloodthorn_lion`; production
sprite candidates созданы через PixelLab MCP и сохранены под
`assets/sprites/bosses/pixellab_candidates/`, с manifest/QA notes в
`docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`.
SCRUM-793 (2026-07-02) promoted only the accepted current-boss candidates
`disk_devourer` and `brood_mother`. SCRUM-865 (2026-07-04) supersedes that
partial runtime state for live bosses: all six live bosses now use PixelLab MCP
8-direction source objects plus imported west-facing runtime full-frame rows in
the existing Godot state contract. `skeletal_dragon` remains source-only/planned,
and `bloodthorn_lion` still stays out of random route rotation until a separate
QA-gated route-pool task. QA evidence:
`build/qa/scrum793_boss_pixellab_promotion/` and
`docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.

## SCRUM-541 Secret Boss Registry Addendum

| ID | Game name | Current scene | Role | Asset | Patterns | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `secret_ascension_boss` | Secret Ascension Boss | `scenes/BossSecretAscension.tscn` | Post-final-Act-2 max-Ascension capstone boss | SCRUM-539 Design source pack: `assets/sprites/bosses/secret_ascension_boss.png`, `assets/sprites/effects/secret_ascension_boss_*_telegraph.png` | `SecretBossSectorRing`, delayed `BossRiftZone` eruptions, phase-2 adds/pressure at 50% HP, phase 3 below 25% HP | Backend implemented; final animation/runtime wiring pending |
