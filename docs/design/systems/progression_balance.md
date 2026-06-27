# Progression And Balance

Обновлено: 2026-06-27 (0.1.7)

Source of truth для чисел: `scripts/progression_data.gd` (фасад) + доменные файлы данных `scripts/progression_data_characters.gd`, `progression_data_weapons.gd`, `progression_data_content.gd`, `progression_data_shop.gd`, `progression_data_ascension.gd`, `progression_data_enemies.gd` (доменный сплит SCRUM-198 — фасад реэкспортит их как const, публичный API сохранён), `scripts/stat_formulas.gd`, `docs/design/mechanics_extract.md`. Балансовый аудит: `docs/design/reviews/mechanics_balance_audit_2026_06.md`.

## Base Stats

Поддерживаемые базовые характеристики:

- Strength / Сила;
- Agility / Ловкость;
- Intelligence / Интеллект;
- Perception / Восприятие;
- Energy / Энергия;
- Knowledge / Знание;
- Endurance / Выносливость;
- Leadership / Лидерство.

## Derived Parameters

Активные derived parameters:

- Damage;
- Magic Damage;
- Sound Wave Damage;
- Attack Speed;
- Crit Chance;
- Crit Damage Multiplier;
- Move Speed;
- Dodge;
- Defense;
- HealthPoint;
- Attack Range;
- AoE Radius;
- Pickup Radius;
- DoT / projectile / aura / buff / knockback / summon parameters.

Формулы могут быть упрощены относительно исходной таблицы, но направление влияния должно совпадать с `mechanics_extract.md`.

## Universal Attribute Usefulness

С 2026-06-12 старая модель скрытия «нерелевантных» атрибутов отключена. `ProgressionData.is_stat_relevant()` и `is_reward_relevant()` возвращают `true`, поэтому level-up, докачка за золото, артефакты, магазин, кодекс и Escape stats могут показывать любой stat/derived parameter любому классу.

Если эффект тематически «чужой», он применяется через class interpretation:
- Intelligence / Magic Damage: зачарование оружия, магический splash или резонанс;
- Leadership / Summon Amount: эхо-оружие, фантом, сокол, знаменосец, фамильяр или прямые pet-команды;
- Sound Wave Damage / Aura Radius: боевой клич и ближний контроль пространства;
- Knowledge / DoT Damage / DoT Speed: малый bleed/burn/poison след на ударах;
- Energy / Ultimate Power: ускорение уникального class mechanic cooldown/charge;
- Strength / Damage: физическая весомость, knockback и прямой урон.

UI обязан показывать эти интерпретации текстом в level-up cards, attribute-upgrade tooltips, artifact notes, shop/HUD/pause tooltips и кодексе. Старые пометки «Не работает на текущем классе» и «Работает вполсилы» больше не используются.

## XP, Money And Pickups

- Враги могут дропать XP и money pickups.
- Pickup radius — улучшаемый параметр.
- HUD показывает HP/XP/money; детали билда находятся в Escape stats / rewards / tooltips.

## Level-Up

- При достижении XP открывается выбор 1 из 3 reward cards.
- Бой ставится на паузу до выбора.
- Rewards меняют производные параметры сразу.
- Level-up UI использует icon mapping через `UIIconRegistry`.
- Level-up pool включает прямые карточки для основных derived parameters: crit, dodge, range, DoT, projectile speed, aura, buff, summon, absorb, regeneration, vampirism и ultimate scaling.

## Artifacts

- `player.artifacts` хранит `{id, title}` с совместимостью со старым title-only форматом.
- HUD показывает artifact icons в `ArtifactHudRow`.
- Pause stats menu имеет отдельный блок «Артефакты».
- Artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png`.
- `class_affinity` теперь означает тематику/источник артефакта, а не запрет. `affinity_mods` применяются любому классу через интерпретацию текущего героя.

## Summon Scaling

- `summon_amount = Leadership + Knowledge * 0.18 + Intelligence * 0.12 + Energy * 0.10`.
- Мобильные summons используют `SummonerWeapon._summon_profile()`:
  - damage = base derived damage * `summon_damage_multiplier` * role multiplier * Leadership multiplier `1 + min(Leadership * 0.020, 0.42)` * attribute multiplier `1 + min(summon_amount * 0.014 + Knowledge * 0.004 + Intelligence * 0.003 + Energy * 0.003, 0.34)`;
  - attack interval получает haste `min(summon_amount * 0.014 + Leadership * 0.006, 0.30)`;
  - max HP получает bulk `min(Leadership * 0.045 + summon_amount * 0.010, 0.75)`;
  - move speed/lifetime/splash radius также мягко растут от Leadership/`summon_amount`.
- Уровень 0 сохраняет базовый баланс: все множители начинаются с 1.0, caps ограничивают high-stat runaway.
- Balance facade `ProgressionData.estimate_weapon_budget()` использует ту же damage/haste формулу для summon DPS estimate, чтобы отчеты 0.1.5 не считали старую слабую версию призывателей.

## Shop

- Shop items берутся из `ProgressionData.SHOP_ITEMS` и artifact pool.
- Shop screen показывает 4 предложения на parchment wall.
- Покупка проверяет money, купленные items получают unavailable state.
- Сток привязан к конкретному `shop` route node: выход из лавки не очищает
  stock и не двигает маршрут, поэтому магазин можно открыть повторно до выбора
  следующего route node. Следующий route node финализирует прошлый магазин и
  очищает его stock/purchased state.
- Shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`.

## Random Events EV (SCRUM-494)

Случайные события (`scripts/event_data.gd`, применение в
`ui_screens._apply_event_choice/_resolve_event_choice_outcome`,
наградные множители боя — `combat_director._grant_combat_completion_rewards`).
EV-ребаланс свёл каждую опцию к `EV = P(успех) × награда − стоимость/штраф`.

**Принцип:** рискованные/платные опции дают заметно больший апсайд (статы,
артефакты, run-long моды), безопасные — скромную гарантию (мелкое золото/хил).
Награды-статы/артефакты/моды предпочтительны для риск-опций, т.к. их
gold-equivalent растёт вместе с экономикой; плоское `money` со стадией не
масштабируется (а `cost_money` — масштабируется через `stage_scaled_cost`),
поэтому крупное плоское золото на риск-опции не вешаем.

**Шкала ценности (gold-value, GV, ранний забег):** 1 GV = 1 золото; 1 стат ≈
20 GV (цена покупки атрибута stage0 ≈ `ceil(18×1.10)`); random_artifact ≈ 45 GV
(взвешенное среднее `COST_BY_TIER` {1:30,2:55,3:95} по `TIER_WEIGHTS`);
run-long damage/attack_speed ≈ 3 GV/1%; xp_gain ≈ 1.5 GV/1%; heal ≈ 0.35 GV/1%
(контекстно); −HP ≈ 0.45 GV/1%. P(check) ≈ 0.55 при difficulty 7, ≈ 0.45 при 8
(база раннего забега). combat-опции дают полный лут боя + completion-бонус
(`elite`: 10+stage×4 зол / 7+stage×2 xp; `battle`: 4+stage×2 / 3+stage, ×
event-множители) + `post_combat`.

| Событие / опция | Тип | Cost/Risk | Reward (GV) | EV (GV) |
| --- | --- | --- | --- | --- |
| bard / pay_ballad | платная | 18 зол | +12% atk_speed (36) | +16 |
| bard / sing_yourself | проверка kn7 | −1 Знание при провале | +1 Зн/Воспр/Лид (60) | +24 |
| bard / walk_away | безопасная | — | 6 зол +4% xp (12) | +12 |
| altar / blood_price | платная (HP) | −30% HP (−14) | артефакт (45) | +31 |
| altar / defile | риск (elite) | элита 1.12 HP | элит-лут +50% зол/+25% xp +Сила/Вынос (40) | топ-риск |
| altar / quiet_prayer | безопасная | −10% HP (−5) | +1 Выносливость (20) | +15 |
| ambush / stand_ground | риск (battle) | бой 1.18 HP | бой-лут +50% зол +Сила (20) | риск+ |
| ambush / break_through | проверка agi8 | −15% HP при провале | +1 Лов +6% atk_spd (38) | +13 |
| well / throw_coin | платная (рандом) | 8 зол | хил30%/28 зол/бой (avg ~19) | +10 |
| well / listen | проверка per7 | провал +5 зол | +1 Восприятие (20) | +13 |
| mercenary / help | платная | 20 зол | +1 Лид +1 призыв (35) | +13 |
| mercenary / loot | безопасная (жадная) | −1 Знание (−20) | 30 зол | +10 |
| mercenary / bind_wounds | проверка end7 | −6 зол при провале | defense_flat 0.06 (18) | +7 |
| goblin / buy_bag | риск+платная | 12 зол | артефакт/8 зол/мимик (avg ~25) | +13 |
| goblin / haggle | проверка per8 | −10 зол при провале | 30 зол | +7 |
| hot_spring / full_rest | безопасная (трейд) | след. бой 1.25 HP (−15) | полный хил (35) | +20 (контекст) |
| hot_spring / quick_dip | безопасная | — | хил 35% (12) | +12 |
| mirror / duel | риск (elite) | элита 1.05 HP | элит-лут +30% зол +Инт +8% урон (44) | топ-риск |
| mirror / study | проверка int8 | −12% HP при провале | +1 Инт +8% урон (44) | +17 |
| guardian / answer_riddle | проверка kn8 | бой при провале | артефакт (45) | +26 |
| guardian / fight_guardian | риск (battle) | бой 1.25 HP | бой-лут +30% зол +Сила/Вынос (40) | риск+ |
| graveyard / dig | риск (рандом) | бой 1.22 HP | артефакт ИЛИ бой+Вынос (avg ~33) | +33 |
| graveyard / pay_respects | безопасная | — | +1 Вынос +хил15% (24) | +24 |
| star / take_shard | платная (HP) | −12% HP (−5) | +2 Энергия (40) | +35 |
| star / observe | проверка int7 | −8% HP при провале | +1 Энергия +1 Знание (40) | +20 |
| dummies / speed_trial | проверка agi7 | −10% HP при провале | +1 Лов +8% atk_spd (44) | +22 |
| dummies / power_trial | проверка str7 | −10% HP при провале | +1 Сила +8% урон (44) | +22 |

Разнообразие исходов сохранено (статы, артефакты, моды, хил, золото, бои) —
не всё сведено к золоту. Тултипы в `event_data.gd` синхронизированы с
фактическими эффектами; `event_data_smoke_test.gd` + балансные/economy смоуки
зелёные.

## Meta Progression

- Ascension levels: 10 уровней на персонажа.
- Победа над финальным боссом увеличивает ascension выбранного героя.
- Сохранение: `scripts/meta_progression.gd`, `user://fantasydisk_meta.cfg`.

### Древо умений (мета, SCRUM-150)

- 4 ветки (`Богатство`/`Знания`/`Мощь`/`Стойкость`), ~10 узлов каждая; покупка по тирам с пререквизитами.
- Очки умений (`skill_points`) начисляются за победу над боссом; бюджет полного древа ≈ +29% силы (кап ≤ ~+30%).
- Боевое подмножество модификаторов уходит в `run_modifiers` на старте забега (`player.apply_meta_skill_modifiers`); экономические узлы дают стартовое золото/скидки. Capstone «Вторая жизнь» (Стойкость) — раз за забег смертельный удар оставляет 1 HP.
- Экран древа доступен в главном меню; данные/состояние — `scripts/meta_progression.gd`.

### Прогрессия По Классам (SCRUM-360)

- Победа над финальным боссом дополнительно увеличивает `class_boss_wins` для выбранного героя.
- `scripts/meta_progression.gd::CLASS_PROGRESSION` содержит 5 общих накопительных порогов: 1/2/4/6/9 побед этим классом.
- Пороги дают только class-scoped run modifiers (`class_damage_mult`, `class_max_health_mult`, `class_attack_speed_mult`). `Main.apply_ascension_bonuses()` передает `class_modifiers(meta_state, selected_character_id)` только текущему герою, а `Player.apply_meta_skill_modifiers()` сворачивает их в обычные `run_modifiers` поверх аккаунтного древа.
- Бонусы не протекают на другие классы: если победы есть у Берсерка, Солдат получает пустой `class_modifiers`, пока сам не победит боссов.
- Экран «Древо умений» показывает отдельный компактный раздел «Классы» для выбранного героя: число побед, открытые пороги, следующий порог и список активных бонусов.
- Персистентность использует тот же `user://fantasydisk_meta.cfg`; ключ `class_boss_wins` version-compatible и отсутствующие старые сейвы читаются как пустой прогресс.

### Патч-ноуты (SCRUM-159)

- Кнопка «Что нового» + бейдж в меню; данные — `scripts/patch_notes_data.gd`, последняя виденная версия — `last_seen_version` в `game_settings`.

## Balance Validation

- Формульный харнесс: `tools/balance_harness.gd` → `build/balance_report.md` (бюджеты классов `CLASS_BUDGET_PROFILES`).
- Сводная таблица урона классов SCRUM-453:
  `tools/class_damage_table_3variants.gd` → `docs/design/reports/class_damage_table_3variants.md`
  и `build/qa/scrum453/class_damage_table_3variants.csv`. Таблица покрывает
  live roster `ProgressionData.character_ids()` (17 классов / 51 оружие) по
  сценариям 1 цель, 5 целей рядом, 20 целей вокруг и трём вариантам прокачки:
  base lvl1, lvl20 optimum (greedy +19 base-stat points по class kit score) и
  lvl20 random avg (64 seeded samples, seed `45320260617`). После SCRUM-469
  таблица является контрольным гейтом для lvl20 optimum: все 17 классов должны
  держать `relative_score` в коридоре `0.90..1.10`. Аудит использует реальные
  `ProgressionData.weapon()`,
  `estimate_weapon_budget_for_stats()` и `estimate_crowd_clear_budget_for_stats()`
  с live balance values.
- SCRUM-469 нормализует рост optimum-прокачки через
  `CLASS_LEVEL_STAT_GROWTH_SCALARS`: class/stat-specific скаляры применяются
  только к очкам выше базовых статов класса перед расчётом derived-параметров.
  Base lvl1 не меняется, а три оружия класса сохраняют свои разные
  `budget_tuning`, геометрию, target-pattern и темп.
- SCRUM-503 срезал live runaway Берсерка с молотом в
  `tools/character_balance_csv.gd`: стартовый lvl1 молот не менялся, но
  `upgrade_aoe_exponent` снижен до 1.25, а `upgrade_damage_exponent` до 1.15.
  Регенерированный `build/character_balance_dps.csv` даёт `berserk/hammer`
  lvl20 optimum 2925.81 DPS на 1 цели и 61199.86 DPS на 20 целях вместо
  прежних ~7636 / ~184k; max class-best 20-target DPS теперь 68574.57 при
  class-best median gate 74785.73.
- Живой DPS/TTK: `tools/live_combat_harness.gd` + гейт `tests/live_balance_simulation_test.gd`.
- Выживаемость профилей: `tools/survivability_harness.gd` + гейт `tests/survivability_scenario_test.gd`.
- Применение бюджет-тюнинга на рантайме: `tests/weapon_tuning_application_test.gd`. Экономика/XP маршрута: `tools/route_economy_xp_model.gd`.
- Финальный 0.1.5 numeric audit: `tools/balance_harness.gd` также пишет `build/balance_final_audit_0_1_5.md`; `tests/global_damage_balance_smoke_test.gd` проверяет solo DPS ±20% и crowd-clear 5/10/20 ±30% для всех 51 class+weapon pairs.

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- SCRUM-469 закрыл SCRUM-453 optimum-выбросы: актуальный `Lvl20 optimum`
  `relative_score` держится в диапазоне `0.938..1.097`, Base lvl1 — в
  `0.982..1.010`, Lvl20 random avg не имеет HIGH/LOW-флагов. Остаточные
  различия остаются предметом ручного feel/playtest, а не блокером формульного
  баланса.
- Performance/code review считает текущие числа пригодными для demo, но баланс должен продолжать уточняться после игровых прогонов.
