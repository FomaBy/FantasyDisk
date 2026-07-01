# Skill Tree

Обновлено: 2026-07-01, SCRUM-726.

Финальное мета-древо умений живет в `scripts/meta_progression.gd` и остается общим графом в стиле Path of Exile. UI/API SCRUM-696/698 сохранены: `node_list`, `node_by_id`, `entry_map`, `node_status`, `allocate_node` / `buy_skill_node`, `reset_skill_tree`, `earned_meta_points`, `available_meta_points`, `allocated_meta_points`, `global_level`, `skill_tree_total_cost`, `skill_modifiers`.

## Топология

- `TREE_SCHEMA_VERSION = 3`; старые schema 2 saves получают безопасный full respec дерева, а meta points пересчитываются из `ascension_levels` / `meta_point_awards`.
- `META_POINTS_CAP = 100`; начисление за первый clear возвышения 0..5 осталось `1, 1, 2, 3, 4, 5`.
- Полный граф: 107 узлов, суммарная стоимость 183 метаочка, поэтому игрок не может купить все дерево при cap 100.
- Ядро: 7 нейтральных узлов, включая 4 account-wide keystone: `core_battle_cry`, `core_second_life`, `core_guild_ties`, `core_insight`.
- 8 атрибутных лепестков: `strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`. Каждый лепесток имеет gate, два minor `+1` к атрибуту и notable `+2` к атрибуту с малым профильным бонусом.
- 17 class pods: у каждого playable class id есть `entry_<class>`, minor, notable и один уникальный `sig_<class>_keystone` с `class_affinity`.

## Применение Эффектов

`skill_modifiers(state)` возвращает только account-wide эффекты и игнорирует узлы с `class_affinity`. Для старта забега `main.apply_ascension_bonuses()` вызывает `skill_modifiers_for_class(meta_state, selected_character_id)`, поэтому эффекты class pod применяются только активному герою.

Атрибутные эффекты используют ключи `strength_flat`, `agility_flat`, `intelligence_flat`, `perception_flat`, `energy_flat`, `knowledge_flat`, `endurance_flat`, `leadership_flat`. `Player.apply_meta_skill_modifiers()` добавляет их к `player.stats` до пересчета `ProgressionData.derived_parameters()`. Из-за разных `BASE_STATS` и class stat-growth scalars один и тот же путь по дереву дает разным героям разные боевые профили.

Поддержанные сигнатурные run-ключи SCRUM-726: `damage_mult`, `attack_speed_mult`, `move_speed_mult`, `max_health_mult`, `range_mult`, `aoe_radius_mult`, `aura_radius_mult`, `knockback_mult`, `crit_chance_flat`, `crit_damage_flat`, `defense_flat`, `regeneration_flat`, `dot_damage_flat`, `dot_speed_flat`, `summon_bonus`, `buff_power_flat`, `vampiric_chance_flat`, `vampiric_amount_flat`, `ultimate_flat`, `ult_charge_mult`, `low_hp_damage_bonus`, `lowhp_regen_bonus`, `money_gain_mult`, `elite_boss_damage_mult`.

`ult_charge_mult` теперь реально влияет на `_gain_ultimate_charge()` через `run_modifiers.ult_charge_multiplier`.

## Class Keystone Table

| Class | Home petal | Keystone | Signature direction |
| --- | --- | --- | --- |
| `berserk` | strength | Кровавая жатва | Low-HP damage and regeneration pressure |
| `soldier` | perception | Подавляющий огонь | Faster/ranged tactical pressure against dense or durable threats |
| `thief` | agility | Большой куш | Money gain, crit chance, movement tempo |
| `elementalist` | intelligence | Сверхновая | AoE radius, damage and ultimate power |
| `sniper` | perception | Идеальный выстрел | Crit chance, crit damage and range |
| `priest` | knowledge | Хор искупления | Vampiric sustain and aura reach |
| `biologist` | knowledge | Эпидемия | DoT pressure plus one summon-support point |
| `robot` | endurance | Овердрайв | Ultimate charge/power and defense |
| `engineer` | leadership | Армия машин | Summon count, support power and defense |
| `dark_mage` | intelligence | Запретное знание | High damage/DoT with max HP downside |
| `guitarist` | leadership | Крещендо | Buff power, aura radius and knockback |
| `assassin` | agility | Из тени | Crit damage, crit chance and movement |
| `ranger` | perception | Град стрел | Attack speed, range and AoE reach |
| `doctor` | knowledge | Триаж | Regeneration, HP and vampiric sustain |
| `chemist` | knowledge | Каталитический распад | DoT damage, DoT speed and AoE reach |
| `knight` | endurance | Несокрушимый | Defense and max HP with attack-speed tradeoff |
| `druid` | leadership | Зов стаи | Summon count, aura radius and buff power |

## Validation

Focused gates for SCRUM-726:

- `tests/meta_skill_tree_smoke_test.gd`: graph integrity, schema 3 migration, UI/API compatibility, economy and neutral capstones.
- `tests/skill_tree_per_hero_test.gd`: 17 unique class keystones, `class_affinity` filtering, and different derived profiles from the same attribute petal set.

Balance harnesses were not broadened for SCRUM-726 because this task changes meta-progression wiring and class-specific run modifiers, not weapon configs or class trio budgets. Follow-up balance playtests should look at high-investment class pods near the 100-point cap.
