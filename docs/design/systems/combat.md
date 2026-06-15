# Combat

Обновлено: 2026-06-13 (0.1.5)

Этот файл описывает активную боевую систему `dev` / версии 0.1.5. Snapshot полного состояния: `docs/design/current_game_state.md`. Канонические ID: `docs/design/content_registry.md`. Балансовый аудит: `docs/design/reviews/mechanics_balance_audit_2026_06.md`.

## Arena And Camera

- Боевая арена: `2560x1440`, центр `ARENA_SIZE * 0.5` (`1280x720`).
- Камера боя: `COMBAT_CAMERA_ZOOM = Vector2(1.12, 1.12)`, лимиты `0..ARENA_SIZE`.
- Камера не показывает всю арену целиком на `1600x900` и `2560x1440`.
- Фон арены покрывает всю карту, физические стены совпадают с видимыми границами.
- Ямы и колонны отключены: активны только границы арены.

## Core Loop

1. Игрок входит в combat node маршрута.
2. Игрок появляется в центре арены.
3. Враги появляются через wave/spawn budget до конца раунда.
4. Обычный бой заканчивается по таймеру.
5. Boss fight заканчивается победой после смерти босса или смертью игрока.
6. После боя игрок получает XP/деньги/артефакты/route reward и возвращается на маршрут.

## Player Control And Attacks

- Движение: WASD / переназначаемые hotkeys.
- Дебаг-режим (SCRUM-375): если persisted setting `debug_mode` включен, то
  только в активном combat ПКМ или Shift+ЛКМ задают точку плавного движения
  игрока на арене, а средняя кнопка мыши мгновенно переносит игрока в выбранную
  clamped arena point. При `debug_mode=false` мышь не двигает игрока, и обычный
  aim/attack flow остается без изменений.
- Все оружия атакуют автоматически по cooldown.
- Targeting для оружия игрока: ближайший живой враг в `attack_range`, затем ближайший враг на арене, затем последнее направление атаки. Направление движения не перетирает направление атаки.
- Анимация, VFX и фактический урон используют одно направление.

## Damage And Feedback

- У игрока есть HP, defense и dodge.
- Враги наносят contact damage по `contact_range`, который подгоняется под видимый размер спрайта.
- При любом уроне по игроку HUD показывает `DamageFlashOverlay`: alpha peak ~0.20, fade ~0.32с, без стакания до непрозрачности, пауза-aware.
- Над обычными врагами, элитками, призванными врагами и боссами рисуются дешевые HP bars через `scripts/enemy_health_bar.gd`.
- HP bar всегда получает фактическую пару `health / max_health`: враги вызывают `refresh_health_bar()` после runtime-скейлинга волн/элиток/босса и сразу после получения урона. Boss overhead bar не заменяет отдельный boss UI и удаляется вместе с boss node.

## Weapons And Effects

- Берсерк использует melee shapes: `strip`, `sweep`, `circle`.
- Class weapons используют reusable modes: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`.
- Прицеливание имеет два runtime-режима. `nearest` оставляет автонаводку на ближайшего врага, `cursor` берет единые `Player.attack_aim_direction()` / `attack_aim_position()` для melee, projectiles, beams, deploys и point-AoE. Summoner commands в cursor mode выбирают цель рядом с точкой курсора.
- Темный маг использует AoE projectile, DoT и beam; новые caster/control классы переиспользуют эти режимы с другими параметрами.
- Гитарист и Друид используют sound wave / pulse / deployable amp/totem; Рейнджер использует deploy trap.
- Друидский `druid_beast` summon использует `AllyMinion/AnimatedBody` с готовым `SpriteFrames`: `move` loop при движении/ожидании, `attack` one-shot при фактическом ударе и `flip_h` вправо по движению/атаке. Остальные ally visuals остаются статичными `Sprite2D` через fallback `Body`.
- Мобильные summons получают групповые команды от `SummonerWeapon`: цели выбираются в leash radius вокруг владельца, назначенный burst damage учитывается как overkill pressure, поэтому несколько союзников расходятся по слабым врагам вместо погони всей стаей за одной целью. Если старая `command_target` ушла за leash radius, `AllyMinion` сбрасывает ее и возвращается к локальной цели/guard behavior.
- Удар `AllyMinion` наносит основной цели полный урон один раз, затем бьет соседних врагов в data-driven малом splash radius (`summon_aoe_radius`, обычно 72-78 px) с `summon_aoe_damage_multiplier`, без повторного урона primary target.
- Временные эффекты оружия добавляются в cleanup groups (`player_weapon_effects`, `deployed_sound_amps`, projectiles/hazards).
- Gameplay effects не должны использовать `SceneTreeTimer`; текущие длительные эффекты привязаны к node-bound tweens и уважают паузу.

## Status Effects / Auras

- Общий runtime-модуль: `scripts/status_effects.gd`.
- Статусы хранятся в meta `status_effects` на цели и тикают из `_physics_process()` владельца, поэтому пауза замораживает duration и DoT вместе с gameplay.
- Поддерживаются duration, refresh/add/extend stack policy, DoT ticks, `speed_multiplier`, `damage_multiplier`, `damage_taken_multiplier` и marker metadata.
- `Enemy` применяет status slow к движению и vulnerability к входящему урону.
- `AllyMinion` применяет status damage/speed buffs к атакам и перемещению.
- `Player` раздает thematic on-hit debuffs: arcane vulnerability (Dark Mage/Elementalist), toxic DoT (Chemist/Doctor/Assassin/Biologist), stagger slow (Soldier/Knight/Robot).
- Support/Leadership classes (`guitarist`, `druid`, `engineer`, `priest`) обновляют class aura примерно раз в 0.55с. Союзники получают `command_aura`, враги в радиусе — `command_pressure`, Priest получает мягкий self-support tick.
- Визуально используется существующий `AttackVfx.ring_pulse` и marker metadata; новых Design/VFX ассетов для SCRUM-245 не потребовалось.

## Spawn And Waves

- Спавн использует bounds новой арены, active cap и wave pacing.
- На ранних stage плотность ниже, дальше растет количество и сила врагов.
- Elite fights выбирают элитку из пула; boss node выбирает одного из доступных боссов.
- Boss-ростер: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`. У боссов уникальные паттерны и hazard-зоны: гравитационная воронка `rift_warden`, вампирский укус `disk_devourer`, костяные шипы/стены `bone_archon`, паутина-замедление `brood_mother`, ember/огненные лужи `ashen_colossus`; зоны привязаны к node-bound tweens.
- Мини-элитки (`mini_elite`): в обычные волны с шансом `mini_elite_chance` подмешиваются усиленные «мини-боссы» из `mini_elite_kinds` — меньше карточных элиток, но опаснее рядовых; имя/тип берётся из реестра.
- Projectiles clean up только за пределами `ARENA_SIZE + margin`, не по старым `1600x900`.

## Elite / Boss Escalation (epic terror)

- Атаки элиток и боссов дают тактильный фидбэк: `_hit_stop` (краткая остановка времени) и camera shake (`combat_director` / `enemy`), масштаб тряски — настройка `screen_shake` (умеренная, вкл. по умолчанию).
- Элитки в фазе 2 эскалируют (ускорение/доп-залпы); боссы разворачивают hazard-зоны по фазам.
- Эпик-скейл спрайтов элиток/боссов для читаемости угрозы.

## Pause

- Причины паузы: `escape_menu`, `level_up`.
- При паузе `get_tree().paused = true`, UI продолжает работать, gameplay objects/tweens заморожены.
- Level-up всегда ставит бой на паузу до выбора награды.

## Tests

- Зонтичный smoke: `tests/runtime_smoke_test.gd` (полный прогон).
- Фокус-сьюты (SCRUM-202, split зонтика): `tests/runtime_smoke_combat_test.gd`, `runtime_smoke_boss_elite_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_ui_test.gd`.
- Targeting-specific smoke: `tests/melee_weapon_targeting_test.gd`.
- Weapon integrity gate (SCRUM-277): `tests/weapon_integrity_test.gd` проверяет все 51 оружие 17 классов от `ProgressionData.weapon_ids()` до реальной scene/equipped visual, чтобы сцена не показывала чужой proxy-спрайт или пассивный item вместо выбранного оружия.
- Status/aura smoke: `tests/status_effects_aura_test.gd`.
- VFX smoke: `tests/attack_vfx_smoke_test.gd`, `tests/hazard_vfx_smoke_test.gd`.
- Снаряды: `tests/projectile_smoke_test.gd`, `tests/enemy_projectile_smoke_test.gd`.
- Балансовые харнессы (отчёты в `build/`): `tools/balance_harness.gd` (формульный), `tools/live_combat_harness.gd` (живой DPS/TTK), `tools/survivability_harness.gd` (выживаемость профилей). Прогон всех standalone-тестов: `tools/run_focused_tests.sh`.

## Enemy HP Bars

SCRUM-414 keeps normal enemy health bars in their original world-space
overhead position, but elite and boss bars clamp into the active viewport when
their large sprite would place the bar above the top screen edge. The clamp uses
the current canvas transform so camera/zoom are respected, preserves the
existing `scripts/enemy_health_bar.gd` drawing node, and keeps boss phase marker
metadata on the same bar.
