# Enemies, Elites And Bosses

Обновлено: 2026-06-13 (0.1.5)

Канонические enemy/boss IDs и assets находятся в `docs/design/content_registry.md`. Основная логика врагов: `scripts/enemy.gd`, боссов: `scripts/boss.gd`, спавна: `scripts/combat_director.gd`. Data-driven enemy slices после SCRUM-198 находятся в `scripts/progression_data_enemies.gd` и экспортируются через `ProgressionData`.

## Standard Enemies

MVP поддерживает несколько архетипов:

- melee pressure enemy;
- ranged/shooter enemy;
- bruiser/high HP enemy;
- fast runner;
- summoner/minion pressure;
- additional mage/spitter/shield/biter/bone/flying variants from the expanded pool.

Все враги имеют HP bars и contact damage range, подогнанный под фактический визуальный размер.

## Elites

SCRUM-260 развел размеры по data-driven профилям `ProgressionData.ENEMY_SIZE_PROFILES`
(`scripts/progression_data_enemies.gd`):

| Profile | Scale | Runtime meaning |
| --- | ---: | --- |
| `ordinary` | 1.00 | обычные враги |
| `mini_elite` | 1.05 | свита Возвышения L7: усиленный моб, меньше полноценной элитки |
| `elite` | 1.68 | карточная элитка узла маршрута, крупная и страшная |
| `boss` | 1.90 | боссы, самые крупные сущности |

Профиль передается в meta `epic_scale_profile` до `_ready()`, поэтому один node
scale согласованно тянет visible rig/body, `CollisionShape2D`, auto-fit
`contact_range` и HP-bar. С SCRUM-135 активные elite source sprites и cutout
manifests переведены на native `512x512`, поэтому epic-scale рендер не апскейлит
прежний 256px-арт на QHD/Retina.

| Elite | Attack | Pattern |
| --- | --- | --- |
| `iron_bastion` | `slam_wave` | shield block, thorn reflect while shielded, windup shockwave, knockback |
| `night_stalker` | `shadow_strike` | telegraph, исчезновение/телепорт за спину, phase-2 mirror second strike |
| `plague_prophet` | `poison_volley` | lob-снаряды, ядовитые лужи с тиками, plague/healing-inversion hook |
| `shard_marshal` | `shard_fan` | aura buff, веер кристальных снарядов, phase-2 ring volley |

Параметры data-driven в `ProgressionData.ELITE_ATTACK_CONFIGS`, reusable mechanics — в `ProgressionData.ENEMY_MECHANIC_CATALOG`, unique signatures — в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`; сами сущности также получают meta `unique_pattern_id`, `unique_pattern_title`, `unique_mechanics`. Урон уникальной атаки ограничен 25% max HP игрока.

## Bosses

Boss node выбирает одного из доступных боссов: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`. С SCRUM-135 первые два активных boss source sprites и cutout parts также `512x512`; `rift_warden` сохраняет отдельный `vortex` cutout part, `disk_devourer` остается single-torso rig. SCRUM-156 подготовил source sprites для трех новых боссов; runtime mechanics/scenes уже заведены, а полный art/cutout wiring остается отдельным content/animation scope.

| Boss | Scene | Pattern |
| --- | --- | --- |
| `rift_warden` | `scenes/BossWarden.tscn` | залпы, зоны разлома, призыв, щит, увороты, `BossGravityWell` |
| `disk_devourer` | `scenes/BossDiskDevourer.tscn` | рывки, disk slam AoE, radial burst, `BossVampiricBite`, enrage |
| `bone_archon` | `scenes/BossBoneArchon.tscn` | волны скелетов, веер черепов, bone prison/wall через `BossRiftZone` с проходом |
| `brood_mother` | `scenes/BossBroodMother.tscn` | выводок, `BroodWebZone`, дополнительный web pressure, рывок в фазе 3 |
| `ashen_colossus` | `scenes/BossAshenColossus.tscn` | slam-волны, тлеющие зоны, `BossMoltenArmorPulse`, enrage ниже 25% HP |

SCRUM-259 добавил boss-specific telegraph mechanics, SCRUM-261 закрыл их визуальный слой. Новые зоны продолжают использовать `HazardVfx.telegraph`/`detonate`, но helper выбирает dedicated painterly textures по runtime node name: `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`. SCRUM-378 добавил visual-only boss full-frame skill-state hooks: эти callbacks запрашивают matching `skill_*` animation state, если для босса есть `FullFrameBody`, и fallback'аются на прежние `cast`/`attack`/`shoot` rig actions. Щиты, reflect-thorns, command aura и summon portal также получили отдельные VFX PNG. Runtime smoke проверяет, что каждая boss scene получает unique-pattern meta и реально создает свой named mechanic node; Design smoke проверяет текстурный hazard pipeline.

## Mini-Elites

`ProgressionData.MINI_ELITE_KINDS` содержит 6 видов L7-свиты Возвышения:
`mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
`mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`. Их source PNG из
SCRUM-156 лежат в `assets/sprites/elites/`, но SCRUM-193 cleanup их не удалял:
raw audit видит их как candidates до полного content wiring, поэтому это не
legacy cleanup scope.

Мини-элитки используют те же elite-сцены и поведенческие паттерны, но перед
добавлением в дерево получают meta `drop_class=mini_elite` и
`epic_scale_profile=mini_elite`; поэтому визуально они читаются как усиленная
свита, а не как полноценный route elite или босс.

Минимальные правила:

- boss fight завершает run;
- boss имеет больше HP и несколько attack patterns;
- victory screen появляется после смерти босса;
- defeat/death screen появляется при смерти игрока;
- boss fight не использует обычный таймер боя.

## Balance Notes

- Обычные враги стали жирнее и чуть медленнее относительно ранних прототипов.
- Количество врагов растет по stage/wave, но early-game не должен зажимать игрока со всех сторон.
- Мини-элитки меньше карточных элиток, но дают повышенный drop class.
- Карточные элитки редкие, крупные и опасные, но их атаки читаемы через telegraph.
- Боссы остаются крупнейшими enemy entities.

## Tests

`tests/runtime_smoke_test.gd` и `tests/runtime_smoke_boss_elite_test.gd`
проверяют elite scenes, attack phases, boss pool, spawn bounds, wave pacing,
mini/card elite/boss scale order и базовые combat flows.
