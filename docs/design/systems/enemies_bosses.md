# Enemies, Elites And Bosses

Обновлено: 2026-06-11

Канонические enemy/boss IDs и assets находятся в `docs/design/content_registry.md`. Основная логика врагов: `scripts/enemy.gd`, боссов: `scripts/boss.gd`, спавна: `scripts/combat_director.gd`.

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

Элитки крупнее обычных мобов примерно в 1.35x. Design sprites 256x256 дают видимый upscale, collision shapes увеличены, contact range auto-fit.

| Elite | Attack | Pattern |
| --- | --- | --- |
| `iron_bastion` | `slam_wave` | windup, кольцевая ударная волна, knockback |
| `night_stalker` | `shadow_strike` | telegraph, исчезновение/телепорт за спину, удар |
| `plague_prophet` | `poison_volley` | 3 lob-снаряда, ядовитые лужи с тиками |
| `shard_marshal` | `shard_fan` | веер кристальных снарядов |

Параметры data-driven в `scripts/enemy.gd::ELITE_ATTACK_CONFIG`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`. Урон уникальной атаки ограничен 25% max HP игрока.

## Bosses

Boss node выбирает одного из доступных боссов, включая `rift_warden` и `disk_devourer`.

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
