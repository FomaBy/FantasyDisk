# Enemies, Elites And Bosses

Обновлено: 2026-06-13 (0.1.4)

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

Элитки крупнее обычных мобов примерно в 1.35x. С SCRUM-135 активные elite source sprites и cutout manifests переведены на native `512x512`, поэтому epic-scale рендер не апскейлит прежний 256px-арт на QHD/Retina. Collision shapes, contact range auto-fit и gameplay scale не менялись.

| Elite | Attack | Pattern |
| --- | --- | --- |
| `iron_bastion` | `slam_wave` | windup, кольцевая ударная волна, knockback |
| `night_stalker` | `shadow_strike` | telegraph, исчезновение/телепорт за спину, удар |
| `plague_prophet` | `poison_volley` | 3 lob-снаряда, ядовитые лужи с тиками |
| `shard_marshal` | `shard_fan` | веер кристальных снарядов |

Параметры data-driven в `scripts/enemy.gd::ELITE_ATTACK_CONFIG`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`. Урон уникальной атаки ограничен 25% max HP игрока.

## Bosses

Boss node выбирает одного из доступных боссов: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`. С SCRUM-135 первые два активных boss source sprites и cutout parts также `512x512`; `rift_warden` сохраняет отдельный `vortex` cutout part, `disk_devourer` остается single-torso rig. SCRUM-156 подготовил source sprites для трех новых боссов; runtime mechanics/scenes уже заведены, а полный art/cutout wiring остается отдельным content/animation scope.

| Boss | Scene | Pattern |
| --- | --- | --- |
| `rift_warden` | `scenes/BossWarden.tscn` | залпы, зоны разлома, призыв, щит, увороты |
| `disk_devourer` | `scenes/BossDiskDevourer.tscn` | рывки, disk slam AoE, radial burst, enrage |
| `bone_archon` | `scenes/BossBoneArchon.tscn` | волны скелетов, веер черепов, костяная стена |
| `brood_mother` | `scenes/BossBroodMother.tscn` | выводок, web slow zones, рывок в фазе 3 |
| `ashen_colossus` | `scenes/BossAshenColossus.tscn` | slam-волны, тлеющие зоны, enrage ниже 25% HP |

## Mini-Elites

`ProgressionData.MINI_ELITE_KINDS` содержит 6 видов L7-свиты Возвышения:
`mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
`mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`. Их source PNG из
SCRUM-156 лежат в `assets/sprites/elites/`, но SCRUM-193 cleanup их не удалял:
raw audit видит их как candidates до полного content wiring, поэтому это не
legacy cleanup scope.

Минимальные правила:

- boss fight завершает run;
- boss имеет больше HP и несколько attack patterns;
- victory screen появляется после смерти босса;
- defeat/death screen появляется при смерти игрока;
- boss fight не использует обычный таймер боя.

## Balance Notes

- Обычные враги стали жирнее и чуть медленнее относительно ранних прототипов.
- Количество врагов растет по stage/wave, но early-game не должен зажимать игрока со всех сторон.
- Элитки редкие и опасные, но их атаки читаемы через telegraph.

## Tests

`tests/runtime_smoke_test.gd` проверяет elite scenes, attack phases, boss pool, spawn bounds, wave pacing и базовые combat flows.
