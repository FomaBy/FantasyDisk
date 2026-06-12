# Progression And Balance

Обновлено: 2026-06-12

Source of truth для чисел: `scripts/progression_data.gd`, `scripts/stat_formulas.gd`, `docs/design/mechanics_extract.md`.

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

## Shop

- Shop items берутся из `ProgressionData.SHOP_ITEMS` и artifact pool.
- Shop screen показывает 4 предложения на parchment wall.
- Покупка проверяет money, купленные items получают unavailable state.
- Shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`.

## Meta Progression

- Ascension levels: 10 уровней на персонажа.
- Победа над финальным боссом увеличивает ascension выбранного героя.
- Сохранение: `scripts/meta_progression.gd`, `user://fantasydisk_meta.cfg`.

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- Performance/code review считает текущие числа пригодными для demo, но баланс должен продолжать уточняться после игровых прогонов.
