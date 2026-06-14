# Progression And Balance

Обновлено: 2026-06-14 (0.1.5)

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

## Meta Progression

- Ascension levels: 10 уровней на персонажа.
- Победа над финальным боссом увеличивает ascension выбранного героя.
- Сохранение: `scripts/meta_progression.gd`, `user://fantasydisk_meta.cfg`.

### Древо умений (мета, SCRUM-150)

- 4 ветки (`Богатство`/`Знания`/`Мощь`/`Стойкость`), ~10 узлов каждая; покупка по тирам с пререквизитами.
- Очки умений (`skill_points`) начисляются за победу над боссом; бюджет полного древа ≈ +29% силы (кап ≤ ~+30%).
- Боевое подмножество модификаторов уходит в `run_modifiers` на старте забега (`player.apply_meta_skill_modifiers`); экономические узлы дают стартовое золото/скидки. Capstone «Вторая жизнь» (Стойкость) — раз за забег смертельный удар оставляет 1 HP.
- Экран древа доступен в главном меню; данные/состояние — `scripts/meta_progression.gd`.

### Патч-ноуты (SCRUM-159)

- Кнопка «Что нового» + бейдж в меню; данные — `scripts/patch_notes_data.gd`, последняя виденная версия — `last_seen_version` в `game_settings`.

## Balance Validation

- Формульный харнесс: `tools/balance_harness.gd` → `build/balance_report.md` (бюджеты классов `CLASS_BUDGET_PROFILES`).
- Живой DPS/TTK: `tools/live_combat_harness.gd` + гейт `tests/live_balance_simulation_test.gd`.
- Выживаемость профилей: `tools/survivability_harness.gd` + гейт `tests/survivability_scenario_test.gd`.
- Применение бюджет-тюнинга на рантайме: `tests/weapon_tuning_application_test.gd`. Экономика/XP маршрута: `tools/route_economy_xp_model.gd`.
- Финальный 0.1.5 numeric audit: `tools/balance_harness.gd` также пишет `build/balance_final_audit_0_1_5.md`; `tests/global_damage_balance_smoke_test.gd` проверяет solo DPS ±20% и crowd-clear 5/10/20 ±30% для всех 51 class+weapon pairs.

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- Performance/code review считает текущие числа пригодными для demo, но баланс должен продолжать уточняться после игровых прогонов.
