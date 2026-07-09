# Артефакты 0.2.1 — финальная матрица (SCRUM-959)

Контракт для реализации: SCRUM-960 (универсальный пул), SCRUM-961 (классовые), SCRUM-962 (иконки), SCRUM-963 (UI/локализация), SCRUM-964 (QA). Источник данных: `scripts/progression_data_content.gd` (`ARTIFACTS`). Итог: **32 семьи + 37 сохранённых + 85 классовых = 154 артефакта**; удаляется 17 легаси-id.

---

## 1. Обзор и правила

### 1.1 Модель редкости

Редкость = существующее поле `tier`. Отдельного поля `rarity` нет.

| tier | Редкость (канон) | cost (`COST_BY_TIER`) | Вес пула (`TIER_WEIGHTS`) |
| --- | --- | --- | --- |
| 1 | обычный | 30 | 1.0 |
| 2 | редкий | 55 | 0.45 |
| 3 | эпический | 95 | 0.12 |

UI-лейблы `TIER_LABELS` (`ui_screens.gd:12584`, сейчас «Тир 3 — легендарный») переименовываются в SCRUM-963: «Обычный / Редкий / Эпический». Хинт сундука `route_map_screen.gd:785` уже говорит «эпического (тир 3)» — становится каноном.

### 1.2 Единое правило скейла семей

| Тип значения | т1 | т2 | т3 | Ключи |
| --- | --- | --- | --- | --- |
| Базовый стат | +2 | +4 | +7 | `stats` |
| Процентный атрибут (`value_type=percent`) | +10% | +18% | +30% | `*_multiplier` → 1.10/1.18/1.30; долевые `*_flat` → +0.10/+0.18/+0.30 |
| Плоский атрибут (`value_type=flat`) | ≈0.75× | ≈1.25× | ≈2.0× значения level-up карточки (`LEVEL_UP_REWARDS`, `progression_data_content.gd:172`), округлено до красивых чисел | тот же ключ, что у карточки |

Ключ эффекта семьи = **ровно тот же ключ, что у level-up карточки атрибута** (см. таблицы §2). Тип значения — из `ATTRIBUTE_REGISTRY` (`progression_data_characters.gd:710`).

### 1.3 Схема данных (новые поля)

**Семья (универсал с роллом редкости):**

```gdscript
{"id": "warrior_charm", "title": "Оберег воина", "rarity_scaling": true,
 "tier": 1, "cost": 30, "class_affinity": [],
 "tiers": {
    1: {"description": "+2 Сила.", "stats": {"strength": 2.0}},
    2: {"description": "+4 Сила.", "stats": {"strength": 4.0}},
    3: {"description": "+7 Сила.", "stats": {"strength": 7.0}},
 }}
```

- `rarity_scaling: true` — маркер семьи. `tier`/`cost` в корне = базовые (т1) для legacy-читателей (`artifact_definition`, кодекс).
- **Ролл на выдаче (offer-time):** сэмплер, встретив `rarity_scaling`, роллит тир и материализует оффер: `materialize_family_offer(family, tier) -> Dictionary` (новый static в `progression_data.gd`) возвращает плоскую запись `{id, title, tier, cost=COST_BY_TIER[tier], description, stats|mods, rarity_scaling:true}` — дальше пайплайн (карточки, магазин, `apply_reward`) работает без изменений.
- Распределение ролла: reward_pool/shop/события — нормализованные `TIER_WEIGHTS` (≈ 0.64/0.29/0.08); элитка/сундук — `TIER_WEIGHTS × depth_weight` (существующая формула `elite_artifact_choices`, `progression_data.gd:1390-1394`); босс (`boss_completion_*`) — фиксированно тир 3. Вес самой семьи в пуле = 1.0.

**Классовый артефакт:**

```gdscript
{"id": "perfect_edge", "title": "Идеальная грань", "tier": 2, "cost": 55,
 "class_affinity": ["assassin"], "requires_ascension": 5,
 "description": "...", "mods": {"crit_chance_flat": 0.15, "crit_damage_flat": 0.25}}
```

- `requires_ascension: 5` у **всех 85**. Поле опционально: отсутствие = 0 (без гейта) — универсалы/сохранённые не трогаются.
- `affinity_mods` в **данных больше не используется** (гейт теперь на выдаче, эффект — обычные `stats`/`mods`/триггеры). Код-путь `player.gd:1223-1226` остаётся как legacy no-op для старых сейвов.

**`player.artifacts`:** запись расширяется опциональным `tier`: `{"id": ..., "title": ..., "tier": int}` (`player.gd:1230` — дописать `tier` из reward, если есть). Совместимость обязательна: старые `{id, title}` и «только title» (`ui_screens.gd:12561 _player_artifacts`) должны жить — все читатели берут `tier` через `.get("tier", 0)`; 0 = не показывать тир.

### 1.4 Гейтинг классовых (контракт 960/961)

Центральная точка — `is_reward_relevant()` (`progression_data.gd:214`). Новая сигнатура и правило:

```gdscript
static func is_reward_relevant(reward: Dictionary, character_id: String,
        ascension_level := 0, cross_class_ids: Array = []) -> bool:
    # 1) doctor-sustain фильтр — как сейчас;
    # 2) affinity: Array = reward.get("class_affinity", []); если пустой — true;
    # 3) если str(reward.id) in cross_class_ids — true (исключение F);
    # 4) иначе: character_id in affinity  AND  ascension_level >= int(reward.get("requires_ascension", 0)).
```

Уровень возвышения прокидывается **новым опциональным параметром** через сэмплеры (дефолт 0 = заперто — все старые вызовы/тесты безопасны):

```gdscript
static func reward_pool(character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array
static func shop_items(route_stage := 0, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array
static func elite_artifact_choices(route_stage: int, count := 3, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array
static func boss_completion_artifact_rewards(character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array
static func boss_completion_artifact_choices(count := 3, character_id := "", ascension_level := 0, cross_class_ids: Array = []) -> Array
```

Call sites (SCRUM-961, все в `ui_screens.gd`) передают `game.ascension_level_for(game.selected_character_id)` (`main.gd:951`) и `game.player.run_modifiers.get("cross_class_artifact_ids", [])`:

| Поверхность | Строка | Сэмплер |
| --- | --- | --- |
| Элитка / сундук маршрута | `ui_screens.gd:7099` | `elite_artifact_choices` |
| Босс акта | `ui_screens.gd:7200` | `boss_completion_artifact_choices` |
| Событие `random_artifact` | `ui_screens.gd:8959,8979` | `reward_pool` |
| Магазин (+гарантия редкого) | `ui_screens.gd:9032,9052` | `shop_items` |

Гейт по возвышению **метовый** (макс. достигнутый `MetaProgression.ascension_level`, `meta_progression.gd:384`), не выбранный на забег `selected_ascension_level`: награда за прогресс класса не должна пропадать при игре на низкой сложности.

### 1.5 Миграция универсалов (17 id, иконки REUSE)

Донор поглощается семьёй: id и иконка остаются, значения/описания — по правилу §1.2, английские title получают русское имя. Полная карта — в таблицах §2 (колонка «Донор»).

### 1.6 Удаление (17 id)

16 легаси классовых + 1 дубль семьи:

`blood_sigil, jagged_blade, heavy_grip, war_belt, warriors_rage` [berserk] · `void_ink, dark_crystal, ash_page, skull_resonator, ink_candle` [dark_mage] · `echo_pick, copper_string, broken_pick, loud_amp, bass_cable` [guitarist] · `split_core` [dark_mage+guitarist] · **`swift_ink`** (mods `move_speed_multiplier 1.3` — полный дубль семьи `fast_boots`; поглощён ею, id ликвидируется).

Удалить: записи в `progression_data_content.gd:71-111`, 17 PNG+`.import` в `assets/sprites/ui/icons/artifacts/`, референсы `docs/design/references/icons/artifacts/`, строки манифеста `artifact_icons_scrum340_manifest.json`, строки `docs/design/content_registry.md` и `docs/design/artifact_shop_cursor_visual_kit.md`; правка `tests/runtime_smoke_test.gd:6778-6779` (см. §7.5). Осиротевшие id в старых сейвах **безвредны**: `player.artifacts` — дисплейный список (эффекты живут в run_modifiers и не сериализуются между забегами), меты `discovered_artifacts` не матчат `artifact_definition` и просто выпадают из кодекса.

### 1.7 Cross-class исключение

Ровно одно — Thief `stolen_crest` («Украденный герб»), контракт в §5.

---

## 2. Универсальные семьи (32)

### 2.1 Базовые статы (8 семей; stats: +2/+4/+7)

| id | Название (RU) | Стат | Донор | Icon |
| --- | --- | --- | --- | --- |
| `warrior_charm` | Оберег воина | `strength` | warrior_charm (переимен. с Warrior Charm) | REUSE |
| `fox_boots` | Лисьи сапоги | `agility` | fox_boots | REUSE |
| `glass_orb` | Стеклянная сфера | `intelligence` | glass_orb | REUSE |
| `hawk_lens` | Линза охоты | `perception` | hawk_lens | REUSE |
| `ember_core` | Тлеющее ядро | `energy` | ember_core | REUSE |
| `old_codex` | Ветхий кодекс | `knowledge` | old_codex | REUSE |
| `stone_heart` | Каменное сердце | `endurance` | stone_heart | REUSE |
| `banner_seed` | Семя знамени | `leadership` | banner_seed | REUSE |

### 2.2 Производные атрибуты (24 семьи)

Ключ эффекта = ключ level-up карточки атрибута (сверено с `LEVEL_UP_REWARDS` и `_default_run_modifiers`/потребителями). У `vampiric_amount` двойной ключ — как у карточки.

| id | Название (RU) | Атрибут | Ключ эффекта | т1 / т2 / т3 | Донор | Icon |
| --- | --- | --- | --- | --- | --- | --- |
| `splinter_gloves` | Перчатки осколков | damage | `damage_multiplier` | 1.10 / 1.18 / 1.30 | splinter_gloves | REUSE |
| `quickstring` | Быстрая струна | attack_speed | `attack_speed_multiplier` | 1.10 / 1.18 / 1.30 | quickstring | REUSE |
| `sturdy_amulet` | Крепкий амулет | max_health | `max_health_flat` | +15 / +25 / +40 | sturdy_amulet | REUSE |
| `fast_boots` | Легкие сапоги | move_speed | `move_speed_multiplier` | 1.10 / 1.18 / 1.30 | fast_boots (+поглощён swift_ink) | REUSE |
| `battle_fan` | Боевой веер | aoe_radius | `sector_multiplier` | 1.10 / 1.18 / 1.30 | — | NEW: ornate war fan, blades spread wide, steel ribs |
| `magnetic_buckle` | Магнитный талисман | pickup_radius | `pickup_radius_flat` | +35 / +55 / +90 | magnetic_buckle | REUSE |
| `iron_scale` | Железная чешуя | defense | `defense_flat` | +0.10 / +0.18 / +0.30 | — | NEW: single heavy iron scale plate, riveted edge |
| `arcane_prism` | Чародейская призма | magic_focus | `magic_damage_multiplier` | 1.10 / 1.18 / 1.30 | — | NEW: floating crystal prism refracting violet arcane light |
| `ram_horn` | Рог тарана | knockback | `knockback_multiplier` | 1.10 / 1.18 / 1.30 | — | NEW: curled bronze ram horn, battering ring mount |
| `sharp_talisman` | Острый талисман | crit_chance | `crit_chance_flat` | +0.10 / +0.18 / +0.30 | sharp_talisman | REUSE |
| `executioner_edge` | Грань палача | crit_damage | `crit_damage_flat` | +0.10 / +0.18 / +0.30 | — | NEW: broad executioner axe blade fragment, notched edge |
| `ghost_ribbon` | Лента призрака | dodge | `dodge_flat` | +0.10 / +0.18 / +0.30 | — | NEW: translucent spectral silk ribbon, drifting curl |
| `wide_sigil` | Дальняя печать | range | `range_multiplier` | 1.10 / 1.18 / 1.30 | wide_sigil | REUSE |
| `venom_vial` | Флакон отравы | dot_damage | `dot_damage_flat` | +2 / +4 / +6 | — | NEW: cracked vial dripping thick green venom |
| `plague_metronome` | Чумной метроном | dot_speed | `dot_speed_flat` | +0.2 / +0.3 / +0.5 | — | NEW: bone metronome, swinging pendulum, sickly green aura |
| `falcon_feather` | Перо сокола | projectile_speed | `projectile_speed_flat` | +70 / +110 / +180 | — | NEW: sleek falcon feather fletching, wind streaks |
| `wide_halo` | Широкий нимб | aura_radius | `aoe_radius_multiplier` | 1.10 / 1.18 / 1.30 | — | NEW: golden ring halo, expanding concentric glow |
| `war_banner` | Боевое знамя | buff_power | `buff_power_flat` | +0.10 / +0.18 / +0.30 | — | NEW: tattered crimson war banner on broken pole |
| `summoners_bell` | Колокольчик призывателя | summon_amount | `summon_bonus` | +1.5 / +2.5 / +4 | summoners_bell | REUSE |
| `aegis_shard` | Осколок эгиды | absorb | `absorb_flat` | +3 / +5 / +8 | — | NEW: glowing shield shard, faceted protective crystal |
| `troll_blood` | Кровь тролля | regeneration | `regeneration_flat` | +1.0 / +1.6 / +2.6 | — | NEW: thick flask of regenerating troll blood, bubbling |
| `leech_fang` | Клык Пиявки | vampiric_amount | `vampiric_amount_flat` + `vampiric_heal_per_second_cap` | +0.75 / +1.25 / +2.0 (оба ключа) | leech_fang | REUSE |
| `thirsty_ruby` | Жаждущий рубин | vampiric_chance | `vampiric_chance_flat` | +0.10 / +0.18 / +0.30 | — | NEW: deep red ruby with blood drop core |
| `overcharge_rune` | Руна перегрузки | ultimate_power | `ultimate_flat` | +0.10 / +0.18 / +0.30 | — | NEW: crackling runestone, overloaded energy fissures |

Верификация ключей: `damage/magic_damage/attack_speed/move_speed/max_health/sector/aoe_radius/range/knockback_multiplier`, `defense/crit_chance/crit_damage/dodge/pickup_radius/max_health_flat` — дефолты `player.gd:194`; `dot_damage_flat`/`dot_speed_flat` (`progression_data.gd:1189-1190`), `projectile_speed_flat` (:1186), `buff_power_flat` (:1188), `summon_bonus` (`player.gd:2419`), `absorb_flat` (:1182), `regeneration_flat` (:1183), `vampiric_*` (:1268-1269, `player.gd:1405`), `ultimate_flat` (:1274).

---

## 3. Сохранённые универсалы (37, без изменений)

Записи, id, значения и иконки не трогаются (все Icon = REUSE).

**Двойные статы (4, т1):** `red_whetstone` (+3 Сила/+3 Ловкость), `star_compass` (+3 Восприятие/+3 Знание), `living_root` (+3 Выносливость/+3 Энергия), `captains_coin` (+3 Лидерство/+3 Сила). Русские title: Точильный камень, Звёздный компас, Живой корень, Монета капитана; id стабильны.

**Проклятья / трейдоффы (12, т2):** `heavy_totem` (+62% HP / −5% скорости — переезжает в эту группу как трейдофф), `cursed_crown`, `fragile_heart`, `greedy_purse`, `burning_shard`, `golden_route_mark`, `glass_edge`, `sacrifice_seal`, `hungry_amulet`, `berserk_totem`, `focus_lens`, `stone_hide`.

**Эпические (6, т3):** `echo_core`, `blood_pact`, `leech_heart`, `thorn_pact`, `phantom_step`, `rift_key` (ключ секретного боя, `meta_progression.gd:90`).

**Триггерные (12, т2 + soul_harvest т3):** `field_kit`, `vital_siphon`, `powder_charge`, `bulwark_echo`, `duelist_spur`, `guardian_bulwark`, `chain_spark`, `crit_impulse`, `breather_totem`, `counterwave_sigil`, `soul_harvest`, `second_wind`.

**Экономика / спец (3, т1-2):** `silver_coin`, `survival_manual`, `cracked_shield`.

---

## 4. Классовые артефакты (85 = 17 × 5)

Общее для всех строк: `class_affinity=[class_id]`, `requires_ascension: 5`, cost = `COST_BY_TIER[tier]`, без `affinity_mods`. Русские имена — из драфта Jira как есть. Тиры: у каждого класса 3×т2 + 2×т3 (у Химика 1×т1 + 1×т2 + 3×т3) — неформальная сумма силы 12 у всех 17. EXISTS = ключ уже читается кодом (место указано), NEW = новый ключ + скрипт-хук. Триггеры: существующие `on_kill/on_room_clear/on_take_hit/on_crit/on_low_hp`; новые помечены NEW. Icon — все NEW (стиль пака: D&D + Dark Fantasy Dragon, изолированный предмет, без текста/рамок/фона, намёк на класс без текста).

### 4.1 Assassin — Критический танец (chakrams / shadow_daggers / venom_wire)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `perfect_edge` | Идеальная грань | 2 | Шанс и урон крита растут, не ломая 100%-крит идентичность Ассасина. | mods `crit_chance_flat: 0.15` EXISTS, `crit_damage_flat: 0.25` EXISTS | Кап-безопасно by construction: `effective_crit_chance` (diminish 0.45, кап 0.55, `progression_data.gd:539`) и `CRIT_DAMAGE_CAP 2.75`. | flawless obsidian dagger blade, razor edge glint |
| `shadow_twin` | Теневой двойник | 3 | Криты повторяют малый теневой росчерк у цели — двойник добивает область. | active, trigger `on_crit`; mods `crit_shadow_echo_damage: 0.45` NEW — хук `player.gd:691 trigger_assassin_crit_shadow`: существующий burst (сейчас только VFX) при ключе >0 наносит 45% derived damage по `crit_shadow_burst_radius` | Кулдаун бурста уже энерго-зависимый (0.25-0.55с, `player.gd:700`) — анти-runaway встроен. | dark mirrored twin daggers, splitting shadow silhouette |
| `venom_spool` | Ядовитая катушка | 2 | DoT-стаки Ядовитой струны живут дольше; игра от крита/уворота вознаграждается. | mods `venom_dot_extra_ticks: 2.0` NEW — хук `class_weapon.gd` (dot_beam/venom_wire: `dot_ticks` 4→+2); `dodge_flat: 0.05` EXISTS | +50% длительности DoT линии; уворот-бонус мал (кап уворота общий). | spool of dripping green poison wire, coiled |
| `evasion_shroud` | Покров уклонения | 2 | Аура уклонения плотнее и шире; успешный уворот разгоняет рывок Теневых кинжалов. | mods `dodge_flat: 0.08` EXISTS, `dodge_rush_bonus: 0.25` EXISTS (`player.gd:815` — спидбуст после уворота, как phantom_step) | Стакается с phantom_step (0.4) до +65% спидбуста — приемлемо, окно 2с. | flowing hooded shroud, translucent violet evasive wisps |
| `return_arc_rune` | Руна обратной дуги | 3 | Чакрамы возвращаются по широкой дуге, обратный проход бьёт больнее. | mods `boomerang_return_width_mult: 0.35` NEW, `boomerang_return_damage_mult: 0.30` NEW — хук `class_weapon.gd` boomerang (chakrams): коридор возврата +35% ширины, урон возврата +30% | Только обратный проход (половина DPS оружия) — эффективный буст оружия ≈ +15-18%. | curved rune-etched chakram, glowing return arc trail |

### 4.2 Berserk — Телесный напор (sword / axe / hammer)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `crimson_grip` | Багровая рукоять | 3 | Удары в ближнем бою копят ярость: стаки урона и темпа атаки. | mods `rage_hit_stacks: 1.0` NEW — хук `player.gd:1442 _apply_meta_keystone_hit_effects` (melee-контекст) + консюм по образцу `kill_momentum_*` (`progression_data.gd:1154-1155`): +1 стак за удар, кап 5, 4с; стак = +2% урона, +1.5% скорости атаки | Пик +10%/+7.5% при непрерывной рубке; пауза 4с сбрасывает. | blood-soaked leather sword grip, crimson rage aura |
| `spectral_axe` | Призрачный топор | 2 | Взмахи топора рождают видимый призрачный топор-повтор по той же дуге. | mods `spectral_followup_bonus: 0.25` NEW — хук `berserk_weapon.gd` (melee followup: усиливает `melee_arc_followup_multiplier` топора 0.12→0.37 + спектральный VFX взмаха) | Работает на axe (у него followup-геометрия `melee_arc_followup_radius 160`); sword/hammer — без изменений. | ghostly translucent battle axe, spectral blue afterimage |
| `hammer_weight` | Вес молота | 2 | Удар молота ложится точно под Берсерком и надёжнее накрывает толпу. | mods `hammer_slam_focus: 1.0` NEW — хук `berserk_weapon.gd` (hammer circle): `circle_full_targets` 4→6, `circle_target_diminish` 0.62→0.78, радиус слэма +12% | Убирает «проседание» молота на плотных паках, не трогая одиночный DPS. | massive stone hammer head, ground crack impact |
| `blood_roar` | Кровавый рык | 2 | Получив урон, Берсерк испускает короткую волну отталкивания и урона. | active, trigger `on_take_hit`; mods `take_hit_pulse_chance: 0.30` EXISTS (`player.gd:1176`: волна 90% полученного урона + нокбэк, КД 3с) | Суммируется с counterwave_sigil до 0.52; шанс клампится ≤1.0 (:1181). | roaring bear skull emblem, red shockwave rings |
| `last_onslaught` | Последний натиск | 3 | Ниже 30% HP Берсерк бьёт сильнее и получает одноразовый щит-волну за порог. | active, trigger `on_low_hp`; mods `low_hp_damage_bonus: 0.35` EXISTS (`player.gd:1200`), `lowhp_guard: 1.0` EXISTS (`player.gd:1151`: нокбэк-волна + 1.5с неуязвимости, латч + КД 18с) | Стакается с blood_pact (+0.5) до +85% на грани смерти — осознанный high-risk пик класса. | cracked berserker helm, last stand red glow |

### 4.3 Biologist — Биореакция (spore_lens / sample_injector / symbiote_seed)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `spore_capacitor` | Споровый конденсатор | 2 | Замедление Споровой линзы становится главным пэйоффом и растёт с биоуроном. | mods `spore_slow_power: 0.25` NEW — хук `class_weapon.gd` (bio_spore_bloom: попадание кольца вешает `StatusEffects` slow `speed_multiplier 0.75`, 1.6с); `magic_damage_multiplier: 1.10` EXISTS | Слоу-мультипликаторы движка клампятся ≥0.25 (`status_effects.gd:112`) — стак-safe. | bulbous fungal capacitor pod, glowing spore vents |
| `sample_chain` | Цепь образцов | 3 | Инъектор бьёт по всей линии луча, а финальный анализ расцветает шире. | mods `sample_beam_full_damage: 1.0` NEW — хук `class_weapon.gd` (bio_sample_dart: дротик наносит урон всем врагам на пути (70% основного), радиус терминального пульса +25%) | Превращает single-target дротик в line-clear; фактический буст ≈ +20-25% AoE-DPS. | chained specimen vials, linked green fluid tubes |
| `symbiote_sheath` | Симбиотическая оболочка | 2 | Семя бьёт сильнее при попадании, а DoT-идентичность сети живёт дольше. | mods `symbiote_impact_bonus: 0.35` NEW, `symbiote_dot_extra_ticks: 2.0` NEW — хук `class_weapon.gd` (bio_symbiote_web: первичный хит +35%, тики сети +2) | Сдвигает web из чистого разделителя урона в гибрид бурст+DoT. | organic symbiote husk shell, pulsing green membrane |
| `inhibitor_colony` | Колония торможения | 2 | Биоурон вешает стакающееся замедление до задуманного предела. | mods `bio_contact_slow: 0.08` NEW — хук `class_weapon.gd` (все bio_* попадания: `StatusEffects` slow 8%/стак, `max_stacks 3`, 2с, stack_mode add) | Кап −24% скорости (< engine-клампа); контроль, не урон. | petri colony disc, creeping inhibitor culture rings |
| `split_analysis` | Расщепленный анализ | 3 | Первый задетый враг делится ослабленными спорами с соседями. | mods `analysis_split_ratio: 0.4` NEW — хук `class_weapon.gd` (bio_*: первичная цель атаки сплэшит 40% урона на 2 ближайших врагов, `TARGET_QUERY`) | Пассивный мини-chain на каждый каст; ≈ +15% крауд-DPS. | split specimen flask, branching sample droplets |

### 4.4 Thief — Уловка и темп (coin_pouch / shadow_cloak / smoke_bomb)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `lucky_coin` | Счастливая монета | 2 | Монета скачет чаще (урон убывает по цепи) и крадёт больше золота. | mods `coin_extra_bounces: 2.0` NEW, `coin_steal_bonus: 1.0` NEW — хук `class_weapon.gd` (coin_ricochet: цепь 4→6 прыжков с тем же falloff 0.62; `steal_money` +1) | Хвост цепи даёт ~0.62^4-5 урона — прирост мягкий, экономика +1 голда/атаку. | gleaming lucky gold coin, four-leaf engraving |
| `magnetic_purse` | Магнитный кошель | 2 | Классовая идентичность подбора усиливается: золото, материалы и опыт сами липнут к Вору. | mods `pickup_radius_flat: 90.0` EXISTS, `money_gain_multiplier: 1.10` EXISTS | Утилити-пик: радиус ≈ +78% от базовых 115. | open leather purse, magnetic coin swirl |
| `paralyzing_blade` | Парализующее лезвие | 3 | Удар Плаща Захода коротко парализует (укореняет) задетых врагов. | mods `backstab_root_duration: 0.7` NEW — хук `class_weapon.gd` (shadow_backstab: жертвы получают `StatusEffects` root `speed_multiplier 0.25`, 0.7с) | Движковый кламп скорости 0.25 = «паралич-лайт»; окно ≈ каждые 1.08с — сильный контроль, поэтому т3. | thin needle blade, paralytic blue venom coat |
| `smoke_cache` | Дымный тайник | 2 | Дымовая завеса дольше и даёт больше уворота — оборонительная зона, не урон. | mods `smoke_duration_mult: 0.40` NEW, `smoke_dodge_bonus: 0.12` NEW — хук `class_weapon.gd` (smoke_bomb: `smoke_duration` +40%, `dodge_bonus` 0.10→0.22) | Урон бомбы не трогается — чистая защита по драфту. | smoking satchel cache, grey haze curling out |
| `stolen_crest` | Украденный герб | 3 | На этот забег в пул попадают 2 случайных чужих классовых артефакта (см. §5). | mods `cross_class_artifact_slots: 2.0` NEW + run-флаг `cross_class_artifact_ids` (Array) — хук `player.gd apply_reward` + сэмплеры (§1.4) | Ролл при получении, честно проговорён в описании; обязателен тест (§7.4). | ornate stolen heraldic crest, torn ribbon |

### 4.5 Guitarist — Сценический контроль (electric_guitar / bass_guitar / sound_amp)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `overdrive_pick` | Медиатор овердрайва | 3 | Непрерывная игра держит рифф-серию: пока она активна — больше урона и темпа. | mods `riff_streak_damage_bonus: 0.10` EXISTS (`player.gd:1458,906,993` — sound-хиты продлевают серию), `riff_streak_attack_speed_bonus: 0.12` NEW — хук: консюм рядом с `riff_streak_damage_bonus` в derived attack_speed | Серия живёт 1.8с и требует постоянных попаданий — даунтайм гасит пик. | overdriven guitar pick, lightning distortion sparks |
| `bass_resonator` | Басовый резонатор | 2 | Бас-аура шире и чётче — частый низкоурновый магический пульс-контроль. | mods `guitar_aura_radius_mult: 0.30` EXISTS (`player.gd:1055`, is_sound), `attack_speed_multiplier: 1.08` EXISTS | Бас и так контроль (x0.30 урона): растим покрытие, не DPS. | deep bass resonator coil, heavy sound rings |
| `stage_amplifier` | Сценический усилитель | 2 | Усилители живут дольше, а Лидерство поднимает их предел выше. | mods `amp_lifetime_bonus: 2.5` NEW, `amp_cap_bonus: 1.0` NEW — хук `class_weapon.gd` (amp deploy: `amp_lifetime` +2.5с, `max_summons_cap` 3→4) | +36% аптайма ампа; кап 4 достижим только с высоким LDR. | stage amplifier cabinet, glowing rune dials |
| `feedback_loop` | Петля фидбэка | 3 | Пульсы усилителей стакают на врагах звуковую уязвимость-резонанс. | mods `amp_resonance_vuln: 0.05` NEW — хук `class_weapon.gd` (amp pulse hit: `StatusEffects` `damage_taken_multiplier 1.05`/стак, `max_stacks 3`, 2.5с, stack_mode add) | Кап +15% входящего урона, только пока цель стоит в пульсах. | tangled feedback cable loop, resonating waves |
| `rhythm_counter` | Счетчик ритма | 2 | Каждый 4-й гитарный пульс срабатывает дважды с ослабленным повтором. | mods `rhythm_echo_every: 4.0` NEW — хук `class_weapon.gd` (sound-атаки: счётчик; каждый 4-й каст повторяется на 55% урона) | Эквивалент ≈ +14% DPS, но читается как ритм-механика, не плоский буст. | ticking rhythm counter dial, four beat marks |

### 4.6 Doctor — Клинический drain (restore_potion / plague_syringe / bone_saw)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `surgical_oath` | Хирургическая клятва | 2 | Чужой сустейн по-прежнему запрещён, зато лечение от оружия усилено и пропускает больше в секунду. | mods `healing_multiplier: 1.20` EXISTS, `drain_heal_per_second_cap: 2.0` EXISTS (`player.gd:1530` — поднимает бюджет drain-хила) | Doctor-гейт `DOCTOR_FORBIDDEN_SUSTAIN_*` (`progression_data.gd:169-195`) не трогается — артефакт качает только weapon-drain канал. | surgeon oath scroll, scalpel seal wax |
| `bonesaw_teeth` | Зубья костяной пилы | 2 | Костяная пила режет шире и возвращает больше здоровья с урона. | mods `saw_arc_width_mult: 0.30` NEW, `saw_heal_ratio_bonus: 0.08` NEW — хук `class_weapon.gd` (stab_flurry/bone_saw: `wave_width` +30%, `heal_percent_of_damage` 0.18→0.26) | Требует ближнего риска (range 190) — сустейн оправдан. | jagged bone saw blade, serrated bloody teeth |
| `plague_carrier` | Чумной носитель | 3 | Чума расползается: смерть заражённого передаёт DoT соседям, тики идут чаще. | mods `dot_death_spread_duration: 2.2` EXISTS (`player.gd:2207 _apply_dot_death_spread`), `dot_speed_flat: 0.25` EXISTS | Спред уже анти-runaway (радиус 0.72×aoe, extend-режим). | plague doctor mask, green miasma wisps |
| `restorative_vapor` | Восстановительный пар | 3 | Зелье оставляет короткую паровую зону: жжёт врагов и подлечивает Доктора. | mods `restore_vapor_power: 1.0` NEW — хук `class_weapon.gd` (drain_link/restore_potion: по завершении связи — пар 1.4с у цели, тик 28% урона связи, 20% урона пара → `apply_drain_heal`) | Хил идёт через drain-бюджет (`_drain_heal_budget`) — капы сустейна соблюдены. | steaming restorative flask, healing vapor cloud |
| `triage_protocol` | Протокол триажа | 2 | Падение ниже 30% HP заряжает следующий лечащий импульс оружия; с перезарядкой. | active, trigger `on_low_hp`; mods `triage_heal_burst: 1.5` NEW — хук `player.gd` (`_update_low_hp_state` + `apply_drain_heal`: примированный хил ×2.5, затем КД 12с) | Одноразовый спасательный бурст, не постоянный отхил. | triage tag card, red cross stamp, worn edges |

### 4.7 Druid — Командование стаей (summon_amulet / briar_staff / raven_totem)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `spirit_pack_banner` | Знамя духовной стаи | 2 | Аура урона сильнее кормит и духов, и самого Друида. | mods `buff_power_flat: 0.20` EXISTS, `pet_damage_mult: 0.15` EXISTS (`summoner_weapon.gd:176`) | Двухканальный (стая+ауры), но оба канала мягкие. | carved spirit banner totem, wolf pack markings |
| `wolf_call` | Зов волков | 3 | Зов приводит лишних физических волков; ближние духи рвут сильнее. | mods `summon_bonus: 2.0` EXISTS, `pack_wolf_bias: 1.0` NEW — хук `summoner_weapon.gd` (состав стаи: приоритет melee-зверей, melee-духи +20% урона) | Кап стаи растёт от summon_amount как сейчас (floor/4) — bias не ломает лимит. | howling wolf head carving, moon backdrop |
| `blue_totem` | Голубой тотем | 2 | Тотем воронов пульсирует злее — ставка на магических духов и вороньи снаряды. | mods `raven_pulse_bonus: 0.25` NEW — хук `class_weapon.gd`/`summoner_weapon.gd` (raven_totem: урон пульса +25%, `amp_pulse_interval` −15%); `sound_damage_multiplier: 1.10` EXISTS | Зеркало wolf_call для второй ветки билда (тотем/дальний). | blue painted raven totem, glowing feathers |
| `briar_seal` | Печать терновника | 2 | Терновые зоны сильнее замедляют и тикают стабильнее, оставаясь прозрачными. | mods `briar_slow_power: 0.20` NEW — хук `class_weapon.gd` (briar pool tick: slow 20%, 1.2с); `dot_speed_flat: 0.25` EXISTS. Виз. контракт: альфа зоны не выше текущей (читаемость поля) | Контроль-зона; slow не стакается (refresh). | thorned bramble seal ring, green wax stamp |
| `pack_alpha` | Альфа стаи | 3 | Радиус и сила аур растут — игра строится вокруг стаи. | mods `aura_radius_flat: 40.0` EXISTS (`progression_data.gd:1187`), `buff_power_flat: 0.15` EXISTS, `summon_bonus: 1.5` EXISTS | Капстоун-агрегатор трёх summon-осей; каждая добавка умеренная. | alpha wolf pelt mantle, dominant stance emblem |

### 4.8 Engineer — Мастерская приказов (sentry_wrench / repair_drone / pressure_mines)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `turret_magazine` | Магазин турели | 2 | Турели уходят, лишь расстреляв боезапас, и получают дополнительные выстрелы. | mods `sentry_magazine_bonus: 6.0` NEW — хук `scripts/sentry_turret.gd`: вводится магазин (база 14 выстрелов, деспаун по расстрелу вместо немедленной замены старейшей) +6 выстрелов от ключа | Без артефакта поведение турелей не меняется (магазин активируется ключом). | rune-etched turret ammo drum, brass shells |
| `drone_gyroscope` | Гироскоп дрона | 2 | Дрон крутится быстрее и цепляет больше целей; устройства работают чаще. | mods `drone_extra_links: 1.0` NEW — хук `class_weapon.gd` (engineer_repair_drone: +1 цель цепи); `device_attack_speed_bonus: 0.12` EXISTS (`player.gd:1077`, is_device) | Devices-канал общий (турели/мины тоже ускоряются) — держим 0.12. | spinning brass gyroscope, orbit rings |
| `mine_satchel` | Минная сумка | 3 | Мины лежат до срабатывания, а после защитной задержки подрываются сами. | mods `mine_persistent_arm: 1.0` NEW — хук `class_weapon.gd` (engineer_pressure_mines: жизнь мины → до срабатывания, кап 5 живых; автоподрыв через 6с после установки, не раньше safe-delay 2.5с) | Минное поле становится плановым инструментом; кап 5 против бесконечного ковра. | worn leather mine satchel, fuse cords |
| `field_blueprint` | Полевой чертеж | 3 | Лидерство улучшает пределы, боезапас и время жизни всех развёрнутых устройств. | mods `blueprint_leadership_scaling: 1.0` NEW — хук `class_weapon.gd` + `sentry_turret.gd`: за каждые 6 Лидерства — +1 к капу deploy (amp-семейство), +2 выстрела турели, +12% жизни мин/ловушек | Скейлинг-движок класса: без LDR почти нулевой, к late — ощутимый. | rolled field blueprint, schematic glow lines |
| `salvage_core` | Ядро утилизации | 2 | Отжившие и подорванные устройства возвращают перезарядку или дают короткий бафф устройствам. | mods `salvage_refund_ratio: 0.35` NEW — хук `class_weapon.gd` (коллбек истечения/подрыва устройства: возврат 35% `fire_interval` текущего deploy-оружия) | Ускоряет цикл переустановки, не сам урон. | salvaged power core, recycled gear fragments |

### 4.9 Ranger — Охотничья стойка (moon_crossbow / storm_longbow / hunter_trap)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `impact_string` | Ударная тетива | 2 | Попадания лука отбрасывают врагов от Рейнджера заметно сильнее. | mods `knockback_multiplier: 1.35` EXISTS | Дистанц-контроль в русле stance-идентичности; элитки/боссы имеют свои сопротивления. | taut reinforced bowstring, impact shockwave |
| `moon_splitter` | Лунный расщепитель | 3 | Болт Лунного арбалета ветвится с первой цели в четыре соседних. | mods `moon_split_targets: 4.0` NEW — хук `class_weapon.gd` (beam/moon_crossbow: при первом пробитии — 4 под-луча в ближайшие цели, 45% урона) | Превращает снайперский болт в crowd-ответ; под-лучи не ветвятся дальше. | crescent moon crossbow bolt, splitting light shards |
| `storm_piercer` | Грозовой пробойник | 2 | Грозовой лук бьёт дальше и пробивает строй глубже — линия-коридор. | mods `charged_shot_extra_pierce: 2.0` EXISTS (`player.gd:1024`, is_charged), `range_multiplier: 1.15` EXISTS | Оба ключа уже в контракте заряжаемых выстрелов Рейнджера. | storm-charged arrowhead, piercing lightning line |
| `root_snare` | Корневой капкан | 3 | Капканы вечны до срабатывания: жертву укореняет, затем она истекает кровью. | mods `trap_root_mode: 1.0` NEW — хук `class_weapon.gd` (trap/hunter_trap: жизнь → до срабатывания (кап 4 живых); при срабатывании root 1.1с (`StatusEffects` speed 0.25) + bleed 3 тика по `dot_damage`) | Совместим с `trap_extra_count` (instant-arm, `player.gd:1031`). | gnarled root snare trap, thorned jaws |
| `hunters_mark` | Метка охотника | 2 | Отброшенные и обездвиженные враги получают дополнительный физический урон. | mods `hunter_mark_bonus: 0.25` NEW — хук `player.gd meta_damage_multiplier` (ranger-атаки: если у цели статус root/staggered или активный нокбэк — +25% урона) | Синергия с impact_string/root_snare — комбо-ось класса. | glowing hunter rune mark, antler sigil |

### 4.10 Robot — Бронеконтур (magnetic_anchor / hydraulic_press / reactor_core)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `armor_protocol` | Бронепротокол | 2 | Броня-идентичность усилена: часть каждого удара просто игнорируется. | mods `absorb_flat: 5.0` EXISTS, `defense_flat: 0.08` EXISTS | Защита клампится `SURVIVABILITY_DEFENSE_CAP 0.62`; absorb пропускает мин. долю удара (`player.gd:652`) — «финальный игнор» кап-безопасен. | riveted armor protocol plate, hazard chevrons |
| `anchor_core` | Ядро якоря | 2 | Магнитный якорь шире и надёжнее стягивает обычных врагов в центр. | mods `magnet_radius_mult: 0.25` EXISTS (`player.gd:1047`), `anchor_pull_power: 0.35` NEW — хук `class_weapon.gd` (robot_magnetic_anchor: сила стягивания +35% для non-elite/non-boss) | Элитки/боссы прямо исключены — по драфту. | magnetized anchor core sphere, iron filings orbit |
| `press_calibrator` | Калибратор пресса | 2 | Коридор Пресса шире и прижимает врагов к осевой линии. | mods `press_corridor_bonus: 1.0` NEW — хук `class_weapon.gd` (robot_compression_line: ширина коридора +30%, поперечный нокбэк к осевой) | Компрессия = сетап под AoE, урон пресса не растёт. | hydraulic calibrator gauge, pressure pistons |
| `reactor_chronometer` | Реакторный хронометр | 3 | Четырёхсторонний реакторный цикл идёт плавно и разгоняется от скорости атаки. | mods `reactor_smooth_rotation: 1.0` NEW — хук `class_weapon.gd` (robot_reactor_vent: выбросы последовательной ротацией, цикл масштабируется от attack_speed без потери выбросов); `attack_speed_multiplier: 1.10` EXISTS | Убирает «мертвые сектора» вентов — равномерное покрытие круга. | ticking reactor chronometer, rotating vent dial |
| `repair_subroutine` | Ремонтная подпрограмма | 3 | Проигнорированный бронёй урон заряжает ремонтный щит-импульс. | active, trigger `on_take_hit`; mods `repair_charge_ratio: 0.5` NEW — хук `player.gd take_damage` (:651 absorb-ветка: 50% поглощённого копится; при заряде 8% max HP — +3 absorb на 5с по образцу `meta_apply_priest_ward` :1092) | Питается только реально съеденным absorb'ом — нет петли с бесконечным щитом. | mechanical repair arm subroutine, wrench circuits |

### 4.11 Knight — Щитовая клятва (long_spear / tower_shield / holy_flail)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `rebound_plate` | Отбойная пластина | 2 | Отбрасывание ударов по обычным и мини-элитным врагам заметно сильнее. | mods `knockback_multiplier: 1.40` EXISTS | Элитки/боссы имеют собственные сопротивления нокбэку — эффект по рядовым, как в драфте. | dented rebound shield plate, kinetic ripple |
| `triple_thrust` | Тройной укол | 3 | Копьё колет трижды: левый, центральный и правый быстрые уколы. | mods `spear_triple_thrust: 1.0` NEW — хук `berserk_weapon.gd` (strip/long_spear: выпад = 3 полосы — центр 100%, боковые 55% под ±14°) | Закрывает слабость узкой полосы 90px против веера врагов. | three spearheads fanned, quick thrust lines |
| `tower_slam` | Башенный удар | 2 | Конус Башенного щита шире, отталкивание масштабируется. | mods `sector_multiplier: 1.20` EXISTS, `knockback_multiplier: 1.20` EXISTS | sector_multiplier честно расширяет sweep-конус 95° щита. | tower shield slamming ground, stone shockwave |
| `holy_chain` | Святая цепь | 3 | Спираль Кистеня с каждым кастом раскручивается наружу от Рыцаря. | mods `flail_spiral_growth: 1.0` NEW — хук `berserk_weapon.gd` (circle/holy_flail: последовательные касты +12% радиуса за каст, кап +36%, сброс после 3с простоя) | Ramp-механика: пик требует непрерывного боя. | blessed flail chain spiral, radiant links |
| `vanguard_oath` | Авангардная клятва | 2 | Оборонная идентичность крепче: в стойке Рыцарь держит удар ещё лучше. | mods `bastion_defense_bonus: 0.10` EXISTS (`player.gd:647`, действует при `_stance_active` — неподвижность ≥0.8с), `defense_flat: 0.05` EXISTS | Боссы/элитки не затрагиваются некорректно: чистая самозащита, без taunt-части. | vanguard oath gauntlet, raised fist seal |

### 4.12 Priest — Священная формула (reliquary / censer / chime)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `prayer_beads` | Четки молитвы | 2 | Молитва перед боем сильнее и понятнее: первые секунды боя усилены. | mods `prayer_opening_power: 0.30` NEW; trigger `on_battle_start` NEW — хук `combat_director.gd` (старт боя → `player`): первые 6с боя +30% магического урона и +30% исходящего лечения | Реализация «выбора молитв» сведена к открывающему баффу; если появится выбор молитв — ключ станет его силой. | worn wooden prayer beads, glowing cross pendant |
| `reliquary_salvo` | Реликварный залп | 3 | Реликварий забывает лечение и переходит на частые взрывные залпы. | mods `reliquary_barrage_mode: 1.0` NEW — хук `class_weapon.gd` (priest_sanctify: `heal_percent_of_damage` → 0, `fire_interval` −25%, взрыв +20%) | Осознанный трейд сустейна на DPS — вторая грань жреца. | open reliquary box, burst of holy bolts |
| `censer_vow` | Обет кадила | 2 | Кадило пульсирует реже, но шире — площадь растёт, DPS выровнен. | mods `censer_vow_mode: 1.0` NEW — хук `class_weapon.gd` (priest_ward: `aoe_radius` +45%, `fire_interval` +35%, урон пульса +35% — DPS ≈ паритет) | Пейсинг-переработка без роста бюджета урона. | swinging brass censer, wide incense ring |
| `twin_bell` | Двойной колокол | 3 | Колокол Молитвы взрывается и у цели, и у Жреца — с защитой от двойного урона. | mods `chime_twin_toll: 1.0` NEW — хук `class_weapon.gd` (priest_prayer_chain: доп. взрывы 55% у первой цели и у жреца; враг получает урон один раз за каст — дедуп по instance id) | Overlap-protection прописан в контракте хука. | twin bronze bells, mirrored chime waves |
| `martyr_shroud` | Покров мученика | 2 | На низком HP молитва укрывает: временно больше защиты и восстановления. | active, trigger `on_low_hp`; mods `lowhp_defense_bonus: 0.12` NEW — хук `player.gd` (защита в `take_damage` :646 по образцу `bastion_defense_bonus`, при `low_hp_active`); `lowhp_regen_bonus: 3.0` EXISTS (`player.gd:1414`) | Оборонительное зеркало blood_pact; клампится общим кэпом защиты. | torn martyr shroud cloth, faint halo thread |

### 4.13 Sniper — Точная ликвидация (deadeye_rifle / spotter_scope / shatter_rounds)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `longshot_scope` | Дальнобойный прицел | 3 | Чем дальше цель, тем больнее выстрел — рост усилен и ограничен капом. | mods `longshot_scaling: 1.0` NEW — хук `player.gd meta_damage_multiplier` (по дистанции до цели: +3% урона за 100px, кап +30%) | На rifle-дистанции 940 достигает капа; в упор — ~0. | long brass sniper scope, extended range reticle |
| `deadeye_round` | Патрон мертвого глаза | 3 | Винтовка предпочитает дальнюю цель, а в конце линии гремит терминальный взрыв. | mods `deadeye_terminal_blast: 0.45` NEW — хук `class_weapon.gd` (sniper_lockshot: приоритет самой дальней цели в радиусе; взрыв 45% урона в конце линии) | Синергия с longshot_scope — задумана как пара т3. | engraved deadeye bullet, skull eye casing |
| `spotter_mark` | Метка наводчика | 2 | Отложенная зона наводчика ложится быстрее и бьёт плотнее. | mods `spotter_fast_mark: 1.0` NEW — хук `class_weapon.gd` (sniper_kill_zone: телеграф −35%, +1 удар серии (4→5)) | Меньше «промахов зоной» по бегущим — комфорт-ось. | spotter binoculars, marked target zone glow |
| `shatter_drum` | Барабан осколков | 2 | Осколочные патроны дают больше осколков по ближайшим траекториям. | mods `shatter_extra_splits: 2.0` NEW — хук `class_weapon.gd` (sniper_split_round: `split_count` 3→5) | Осколки наследуют falloff 0.55 — прирост контролируем. | revolver drum of shattered rounds, splintered tips |
| `clean_line` | Чистая линия | 2 | Снаряды быстрее, линия длиннее — класс ощущается хирургически точным. | mods `projectile_speed_flat: 120.0` EXISTS, `range_multiplier: 1.12` EXISTS | Комфорт/точность, без прямого DPS. | perfectly straight tracer line, polished barrel |

### 4.14 Soldier — Тактическая линия огня (rifle / grenade / bayonet)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `second_volley` | Второй залп | 3 | Фирменный дубль-выстрел: шанс повторить попадание ослабленным залпом, с капом. | mods `duplicate_hit_chance: 0.12` NEW — хук `class_weapon.gd` (нанесение урона атаками солдата: 12% шанс повторить попадание на 50% урона; суммарный шанс дубля жёстко капится 0.65) | Кап страхует стак с будущим классовым трейтом 50%-дубля. | twin musket volley emblem, double muzzle flash |
| `arquebus_shrapnel` | Шрапнель аркебузы | 2 | Взрывная идентичность аркебузы: коридор подавления шире, соседям прилетает больше. | mods `arquebus_shrapnel_bonus: 1.0` NEW — хук `class_weapon.gd` (suppression_burst: `suppression_width` +25%, falloff соседей 0.38→0.52) | Растит crowd-ветку залпа, основная цель без изменений. | burst arquebus barrel, shrapnel fragments |
| `long_fuse` | Длинный фитиль | 2 | Фитиль горит дольше — взрыв гранаты окупается сторицей. | mods `long_fuse_bonus: 0.5` NEW — хук `class_weapon.gd` (grenade_cook: `grenade_delay` +0.35с, урон +50%, радиус +10%) | Трейд «ждать дольше → бить больнее», телеграф честный. | grenade with long burning fuse cord |
| `bayonet_trigger` | Спуск штыка | 2 | Штыковой укол иногда выпускает пулю дальше конуса стойки. | mods `bayonet_shot_chance: 0.35` NEW — хук `class_weapon.gd` (bayonet_brace: при уколе 35% шанс пули по линии, дальность 420, 70% урона) | Закрывает мёртвую зону штыка по дальним. | bayonet blade on rifle muzzle, single shot spark |
| `battle_doctrine` | Боевой устав | 3 | Дубли по уставу: повторные попадания работают на пулях, гранатах и штыке одинаково. | mods `duplicate_hit_universal: 1.0` NEW (дубль-шанс распространяется на все режимы: rifle/grenade/bayonet), `duplicate_hit_chance: 0.06` NEW — хук общий с second_volley | Самодостаточен (6% свой), с second_volley = 18% на всё — под тем же капом 0.65. | leather-bound battle doctrine manual, brass clasp |

### 4.15 Dark Mage — Темная формула (dark_book / cursed_skull / dark_wand)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `chain_wand` | Цепная палочка | 2 | Цепь палочки прыгает на одну цель дальше, бурсты +15%. | mods `wand_extra_chain: 1.0, wand_burst_bonus: 0.15` (SCRUM-939: цепь и бурсты теперь база dark_chain_burst; артефакт удлиняет цепь и усиливает бурсты) | Бурсты не порождают новые рикошеты — без каскада. | crooked dark wand, chained spark orbs |
| `curse_font` | Купель проклятий | 2 | Проклятый череп тикает чаще и больнее — чистый урон проклятия. | mods `dot_damage_flat: 3.0` EXISTS, `dot_speed_flat: 0.35` EXISTS | Прямой прокач DoT-канала (dot_ticks 5 у черепа). | dark baptismal font, swirling curse liquid |
| `mirror_page` | Зеркальная страница | 3 | Оба взрыва Книги тьмы отдаются эхом (45%) через мгновение. | mods `book_mirror_echo: 0.45` (SCRUM-941: зеркало теперь база dark_mirror_blast; артефакт добавляет эхо-взрыв, эхо не зеркалится и не эхоится) | Эхо без каскада — фикс-доля от исходного взрыва. | torn grimoire page, mirrored ink explosion |
| `void_hunger` | Голод пустоты | 3 | Проклятые смерти голодны: DoT перекидывается на соседей погибшего. | mods `dot_death_spread_duration: 2.5` EXISTS (`player.gd:2207`) | Ключ уже анти-runaway (extend, радиус 0.72×aoe); стакается с plague_carrier доктрины нет — классы разные. | black hole maw, devouring void tendrils |
| `black_bargain` | Черная сделка | 2 | Сильная тёмная сделка: проклятия и DoT много сильнее, но здоровье платит цену. | mods `dot_damage_flat: 4.0` EXISTS, `dot_speed_flat: 0.25` EXISTS, `max_health_multiplier: 0.85` EXISTS | Трейдофф в духе cursed_crown; −15% HP ощутим на 60 базовых HP мага. | black contract scroll, blood signature seal |

### 4.16 Chemist — Алхимическая цепь (blast_powder / acid_flask / homunculus_vial)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `volatile_dust` | Летучая пыль | 2 | Взрывная пыль становится быстрым комфортным AoE — без базового облака-DoT. | mods `volatile_powder_mode: 1.0` NEW — хук `class_weapon.gd` (blast_powder: `fire_interval` −22%, прямой взрыв +25%, `leaves_pool` off) | Трейд DoT-облака на темп: чище против бегущих стай. | puff of volatile alchemical dust, sparks |
| `acid_catalyst` | Кислотный катализатор | 3 | Контакт с кислотной лужей навешивает постоянные стаки едкого DoT. | mods `acid_charge_stacks: 1.0` NEW — хук `class_weapon.gd` (acid pool tick: перманентный стак DoT 0.8/тик, кап 5 стаков, живёт до смерти врага) | «Постоянные» = до смерти носителя; кап 5 держит боссов в коридоре. | bubbling acid catalyst flask, corroded stand |
| `clear_acid` | Прозрачная кислота | 1 | Лужи кислоты читаемы и прозрачны, но опасность видна; держатся дольше. | mods `pool_duration_mult: 0.25` EXISTS (`player.gd:1070`, is_cloud). Виз. контракт: альфа лужи ниже, danger-кромка ярче (арт-примечание для реализации в hazard/pool VFX) | Лёгкий QoL-артефакт — единственный т1 среди классовых. | crystal-clear acid droplet, faint green rim |
| `tank_homunculus` | Гомункул-танк | 3 | Гомункул-здоровяк: много HP и провокация — враги грызут его, не Химика. | mods `homunculus_taunt: 1.0` NEW — хук `summoner_weapon.gd`/`ally_minion.gd` (гомункул: +60% HP, периодический taunt-пульс по образцу `bastion_taunt` `player.gd:1117`); `homunculus_power_mult: 0.25` EXISTS (`summoner_weapon.gd:173`) | Танк-роль уже в конфиге (`summon_role tank_control`) — растим её. | hulking clay homunculus torso, shield stance |
| `reactor_homunculus` | Гомункул-реактор | 3 | Второй гомункул — неуязвимый реактор: не бьёт, но волнами копит DoT на врагах. | mods `homunculus_reactor: 1.0` NEW — хук `summoner_weapon.gd` (homunculus_vial: +1 особый юнит — неуязвим, без атак, каждые 1.6с волна r140 вешает стак DoT 0.8/тик, кап 3) | Не занимает боевой лимит гомункулов; урон только через DoT-стаки. | glowing reactor homunculus vial, energy coils |

### 4.17 Elementalist — Стихийная формула (orb_ring / prism_focus / meteor_core)

| id | Название | T | Механика | Реализация | Balance note | Icon (style notes) |
| --- | --- | --- | --- | --- | --- | --- |
| `fourth_ring` | Четвертое кольцо | 3 | Земляное ядро укрепляет квадрат: физический канал на 60% сильнее и +1 тик поля. | mods `elemental_orb_extra_count: 1.0` EXISTS (`player.meta_extra_projectiles` → доп. тики, кап +2), `earth_orb_mode: 1.0` — хук `class_weapon.gd` (`SQUARE_EARTH_CORE_PHYS_BONUS`) | SCRUM-948: база уже квадрат четырёх стихий с физикой/DoT/отбросом — артефакт усиливает земляную ось поверх. | four elemental orbs in square formation, earth rune |
| `prismatic_cross` | Призматический крест | 3 | К диагоналям X добавляется крест «+» на 60% силы луча; +20% радиуса центра. | mods `prism_cross_pierce: 1.0` — хук `class_weapon.gd` (`PRISM_CROSS_EXTRA_SHARE`: два доп. луча по направлению атаки и перпендикуляру); `prism_rift_radius_mult: 0.20` EXISTS (`player.gd`) | SCRUM-949: база уже полнокартный X — артефакт превращает X в 8-лучевую звезду; дедуп: один луч-хит на врага. | crossed prism beams, x-shaped light lattice |
| `meteor_heart` | Сердце метеора | 2 | Метеор реже (+45% интервала), но центральный удар +55% и зона догорает на 2 тика дольше. | mods `meteor_heart_mode: 1.0` — хук `class_weapon.gd` (`METEOR_HEART_CENTER_BONUS`, `METEOR_HEART_EXTRA_ZONE_TICKS`; интервал ×1.45 в `_fire_interval_artifact_factor`) | SCRUM-950: база уже самый медленный нюк с DoT-зоной — артефакт растит пик-момент, DPS ≈ паритет. | molten meteor heart core, dripping magma |
| `mana_overflow` | Переполнение магии | 2 | Магический источник класса виден в артефактах: магия и заряд ульты текут щедрее. | mods `magic_damage_multiplier: 1.18` EXISTS, `ult_charge_multiplier: 1.12` EXISTS | Простой, но заметный прокач магической оси класса. | overflowing mana chalice, spilling blue energy |
| `elemental_recoil` | Стихийный отдачник | 2 | Стихийные области отталкивают монстров прочь от заклинателя. | mods `elemental_repulse_power: 90.0` NEW — хук `class_weapon.gd` (AoE-попадания элементалиста: радиальный пуш 90 от кастера); `knockback_multiplier: 1.15` EXISTS | Даёт «дыхание» ближней зоне класса без роста урона. | recoiling elemental blast ring, outward force arrows |

---

## 5. Cross-class исключение: `stolen_crest`

Единственный артефакт, пробивающий классовый гейт. Контракт:

1. **Получение:** `player.apply_reward` (или `ui_screens._apply_reward_to_run` :9643), увидев `cross_class_artifact_slots > 0`, роллит **N=2 случайных чужих классовых id** (из 85 минус текущий класс; равновероятно, без дублей) и пишет `run_modifiers["cross_class_artifact_ids"] = [id, id]` (Array, кладётся напрямую — НЕ через `_apply_reward_mods`, по образцу латчей).
2. **Действие:** сэмплеры (§1.4) получают этот Array параметром `cross_class_ids` и пропускают эти id сквозь affinity/ascension-гейт. Только на текущий забег (`run_modifiers` пересоздаются в `configure_character`).
3. **Честность:** описание артефакта прямо говорит: «До конца забега в пул наград попадают 2 случайных артефакта чужих классов». UI SCRUM-963 показывает выпавшие чужие артефакты обычными карточками с пометкой класса.
4. **Тест обязателен** (SCRUM-961 + 964): с активным флагом чужие id появляются в пуле; без флага — ни один из 85 не течёт в чужой класс (см. §7.4).

---

## 6. Сводка иконок (контракт SCRUM-962)

Путь рантайма: `assets/sprites/ui/icons/artifacts/artifact_<id>.png`, 256×256 RGBA. Референсы: `docs/design/references/icons/artifacts/<id>/`.

| Категория | Кол-во | Состав |
| --- | --- | --- |
| **NEW** | **100** | 15 атрибут-семей без донора (§2.2) + 85 классовых (§4) |
| **REUSE** | **54** | 17 мигрированных (8 стат + 9 атрибут-доноров) + 37 сохранённых |
| **DELETE** | **17** | blood_sigil, void_ink, echo_pick, jagged_blade, heavy_grip, war_belt, warriors_rage, dark_crystal, ash_page, skull_resonator, ink_candle, copper_string, broken_pick, loud_amp, bass_cable, split_core, swift_ink |

Итог на диске после 962: **154 PNG** (сейчас 71). Style_notes каждого NEW — в таблицах §2.2/§4. Общий стиль: D&D + Dark Fantasy Dragon game icon, isolated object, transparent background, no text/letters/frames/panels; классовые — намёк на класс силуэтом/материалом; читаемость на 32/40/64px; после генерации — alpha-cleanup (border-connected flood-fill) и contact sheet + readability-отчёт в `docs/design/previews/` / `docs/design/reports/`.

---

## 7. Зависимости фаз

### 7.1 SCRUM-960 — универсальный пул (бекенд)

- `scripts/progression_data_content.gd`: переписать `ARTIFACTS`-блок универсалов: 32 семьи по схеме §1.3 (значения §2), 37 сохранённых без изменений.
- `scripts/progression_data.gd`: `materialize_family_offer(family, tier)`; ролл тира в `reward_pool` / `shop_items` / `elite_artifact_choices` / `boss_completion_artifact_rewards` (тир 3 фикс.) по §1.3; `artifact_definition()` для семьи возвращает запись целиком (материализация — только в сэмплерах).
- `scripts/player.gd:1230`: сохранять `tier` в `player.artifacts`, если есть в reward.
- Совместимость: старые `{id, title}` записи и вызовы сэмплеров без новых параметров работают без правок.
- Тесты: обновить/прогнать `rewards_data_integrity_test` (154 записи; проверку no-op наград научить `tiers`-схеме), `content_rewards_integrity_test`, `route_chest_artifact_test`, `null_artifacts_snapshot_test`, `runtime_smoke_progression_economy_test`, `event_random_artifact_empty_pool_test` (пул не пустеет: 69 универсалов доступны всем при asc=0), `runtime_smoke_test.gd:7507` (счётчик ARTIFACTS+SHOP_ITEMS), `weapon_integrity_test.gd:168`. Новый тест: ролл семьи — материализованный оффер имеет валидные tier/cost/description/mods и три уникальных выбора наград живы.
- Доки: `docs/design/systems/progression_balance.md` (`## Artifacts` :240), `docs/design/content_registry.md` (§Артефакты — полная перезапись таблицы).

### 7.2 SCRUM-961 — классовые (бекенд)

- Данные: 85 записей §4 в `ARTIFACTS`; удалить 17 записей §1.6; `affinity_mods` из данных убрать полностью (`player.gd:1223` остаётся no-op).
- Гейт: `is_reward_relevant` + сигнатуры §1.4; call sites `ui_screens.gd:7099/7200/8959/8979/9032/9052` передают ascension (`main.gd:951`) и `cross_class_artifact_ids`.
- NEW-ключи: 69 ключей из §4 (хуки: `class_weapon.gd`, `berserk_weapon.gd`, `summoner_weapon.gd`, `sentry_turret.gd`, `player.gd`, `combat_director.gd` — место указано в каждой строке). Все аддитивные (не `*_multiplier`) — `_apply_reward_mods` раскладывает без правок. NEW-триггер `on_battle_start` (prayer_beads) — диспетчеризация из `combat_director` по образцу `on_room_clear`.
- `tools/live_combat_harness.gd:36 KNOWN_ARTIFACTS` — вычистить легаси id, добавить представителей новых.
- Тесты: ascension-гейт (asc 0 → 0 классовых; asc 5 → 5 своих во всех сэмплерах; чужой класс → 0), cross-class тест §5, триггерные новые ключи в `runtime_smoke_triggered_artifacts_test` (порог ≥6 остаётся), `attribute_relevance_test` не задет (классовые вне реестра атрибутов).

### 7.3 SCRUM-962 — иконки

По §6: 100 NEW (промпты из style_notes), 17 DELETE (PNG + `.import` + референсы + строки манифеста `artifact_icons_scrum340_manifest.json`), 54 REUSE не трогать. Валидатор `tools/validate_artifact_icons.py` парсит id из `ARTIFACTS` — прогнать после 960/961. `no_duplicate_artifact_files_test`, `asset_reference_integrity_test` — зелёные.

### 7.4 SCRUM-963 — UI/локализация

- `TIER_LABELS` → «Обычный/Редкий/Эпический» (+ `TIER_COLORS` сохранить); показывать тир из `player.artifacts[].tier` (fallback: без тира).
- Reward-карточки: `_make_elite_artifact_card`/`_reward_icon_id` (`ui_screens.gd:7805/9309`) переключить на `artifact_<id>.png` (резолвер `:12577` уже есть) — гэп из разведки.
- Убрать англ. дубли: title семей уже RU после 960; codex id-chip (`:4873`) скрыть от игрока; `CLASS_RU` (`:12590`) дополнить до 17/17 (брать `CHARACTER_CONFIGS[*].display_name`).
- Классовые: на карточке/в кодексе показывать «Класс: <RU> · Возвышение 5»; запертые не попадают в офферы by design (гейт в сэмплерах) — UI не показывает их до анлока нигде, кроме кодекса (там — силуэт/замок).
- Fallback-иконка (`buff_power`) допустима только в dev; финал — 0 fallback (см. 962).
- Тесты: `ui_no_overlap_matrix_test` (HUD-ряд артефактов, карточки), `codex_data_smoke_test`, `runtime_smoke_test.gd:6778-6779` — см. §7.5.

### 7.5 Правка runtime_smoke_test.gd:6778-6779

Тест `_artifact_affinity_note` использует удаляемые `split_core`/`void_ink`. Заменить: `split_core` → `stolen_crest` (thief), `void_ink` → `void_hunger` (dark_mage); ожидание нового формата пометки (класс+возвышение вместо «Интерпретация:») — синхронно с реализацией пометки в 963. `warrior_charm`-ветка (универсал без пометки) остаётся валидной.

### 7.6 SCRUM-964 — QA

Прогнать: все источники (reward_pool события, элитка, сундук, магазин+гарантия редкого, босс, кодекс, HUD-ряд, run summary, экипировка паузы); гейт per-class asc 0 / asc 5+; cross-class забег со `stolen_crest`; отсутствие 17 удалённых id везде (grep + рантайм); иконки без fallback; RU-only тексты; сейв со старым `{id,title}` артефактом грузится. Баланс — §8.

---

## 8. Баланс-коридоры (проверяет SCRUM-964)

1. **Классовые киты сопоставимы.** Неформальная сумма тиров пятёрки = 12 у всех 17 классов (16×{2,2,2,3,3}, chemist {1,2,3,3,3}). Харнесс-проверка: полный кит из 5 классовых артефактов даёт классу +15…+45% эффективного DPS-бюджета и не выбивает TTD/выживаемость из коридоров `balance_harness`/`live_combat_harness` (сценарии с триггерными — через live-харнесс, не CSV).
2. **Семьи не ломают level-up экономику.** Целевое соотношение к level-up карточке: т1 ≈ 0.65–0.85×, т2 ≈ 1.0–1.4×, т3 ≈ 2×. Артефакт стоит золота/слота выбора — паритет т2 с бесплатной карточкой уровня допустим.
3. **Кап-ограниченные атрибуты** — первые кандидаты пост-тюнинга: `vampiric_chance` (кап 0.20 — т2/т3 упираются, `VAMPIRIC_CHANCE_CAP`), `crit_chance` (diminish 0.45 + кап 0.55 — эффективный т3 ≈ +21%), `defense` (кап 0.62), `crit_damage` (т1-т3 ниже карточки 0.35 — осознанно, карточка щедрая). Единое правило Jira сохраняется как старт; отклонения фиксирует харнесс-отчёт 964.
4. **Дубль-каскады запрещены:** duplicate_hit (кап 0.65), take_hit_pulse (кламп 1.0), spread-DoT (extend, без рекурсии), взрывы рикошетов/зеркал не порождают новые взрывы.
5. **Экономика редкости:** доля т3 в офферах ≈ 8% (reward/shop), растёт глубиной у элиток (depth-weight) — распределение роллов семей сверить с фактическими весами `TIER_WEIGHTS` на выборке ≥1000 роллов (dev-консоль `~`).

---

*SCRUM-959 · дизайн-спека финализирована 2026-07-09 · владелец: claude-design-scrum959-artifact-matrix-20260708*
