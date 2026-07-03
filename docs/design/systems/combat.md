# Combat

Обновлено: 2026-07-03 (0.2.0 refactor-wave reconcile; ядро системы — 0.1.5+)

Этот файл описывает активную боевую систему `dev`. Snapshot полного состояния: `docs/design/current_game_state.md`. Канонические ID: `docs/design/content_registry.md`. Балансовый аудит: `docs/design/reviews/mechanics_balance_audit_2026_06.md`.

## Arena And Camera

- Боевая арена: `2560x1440`, центр `ARENA_SIZE * 0.5` (`1280x720`).
- Камера боя: `COMBAT_CAMERA_ZOOM = Vector2(1.12, 1.12)`, лимиты `0..ARENA_SIZE`.
- Камера не показывает всю арену целиком на `1600x900` и `2560x1440`.
- Фон арены покрывает всю карту, физические стены совпадают с видимыми границами.
- Ямы и колонны отключены: активны только границы арены.

## Core Loop

1. Игрок входит в combat node маршрута.
2. Игрок появляется в центре арены.
3. Враги появляются через wave/spawn budget; бой плотный с первой секунды —
   первая волна выходит почти мгновенно и спавн идёт минимум с 2 краёв арены
   (до 3–4 на поздних стадиях/волнах), вне `SPAWN_PLAYER_SAFE_RADIUS` (SCRUM-784).
4. Обычный бой длится по таймеру (база `60с`, +3с/стадию до `90с`, с учётом
   множителя Возвышения) — выжил до конца таймера = победа (SCRUM-785).
5. Элитка и Босс — фиксированный таймер «убей или проиграл» `300с` (5 минут, без
   множителя Возвышения): победа = убить элитку/босса до истечения; таймаут с живой
   целью = поражение (death screen, `outcome_reason` поясняет «не успел убить … за
   5 минут»). Таймер тикает и в боссовом бою (SCRUM-785).
6. После обычного/elite боя игрок получает XP/деньги/route reward и возвращается на маршрут.
7. После boss Act 1/2 игрок получает boss reward, сохраняет билд и переходит на
   новую route map следующего акта. После boss Act 3 показывается финальная победа
   и начисляется мета-прогрессия.

## Player Control And Attacks

- Движение: WASD / переназначаемые hotkeys.
- SCRUM-823 sets playable character combat visuals to
  `BASE_SPRITE_SCALE = Vector2(0.64, 0.64)` for accepted full-frame
  `AnimatedSprite2D` characters, skeletal rigs and the legacy cutout-rig fallback,
  about x1.5 from the previous `0.425` combat scale. The player collision radius
  remains `8.9`, so readability improves without changing combat ranges, contact
  behavior or balance.
- Дебаг-режим (SCRUM-375): если persisted setting `debug_mode` включен, то
  только в активном combat ПКМ или Shift+ЛКМ задают точку плавного движения
  игрока на арене, а средняя кнопка мыши мгновенно переносит игрока в выбранную
  clamped arena point. При `debug_mode=false` мышь не двигает игрока, и обычный
  aim/attack flow остается без изменений.
- Все оружия атакуют автоматически по cooldown.
- Targeting для оружия игрока: ближайший живой враг в `attack_range`, затем ближайший враг на арене, затем последнее направление атаки. Направление движения не перетирает направление атаки.
- Анимация, VFX и фактический урон используют одно направление.
- Held-weapon visual placement (SCRUM-455): `Player/VisualRoot/WeaponSocket` is a runtime orbit anchor, not a body-center/hand overlap point. It sits on a 104px orbit toward the active aim/attack direction and renders behind the hero body (`z_index=-8`, attached weapon/root visual normalized to relative `z_index=0`) so weapon art reads as circling/held around the character without covering the playable sprite. Damage, cooldowns, hit shapes and targeting stay data-driven and unchanged.
- Attack VFX calmness (SCRUM-457/SCRUM-854): shared `AttackVfx` helpers apply `_calmed_color()` to additive flashes/beams/slashes, cap alpha, slightly narrow beam visuals, slow projectile/skull trail ghosting, and reduce dust/note particle counts. Weapon signature plates keep a dedicated non-additive `WeaponSignatureBody` at alpha `0.60` so the actual weapon silhouette is visible during every attack; glow/rim layers stay restrained. This is visual-only: the same damage radii, hit corridors, cooldowns, timings, targeting and VFX center positions remain authoritative.

## Damage And Feedback

- У игрока есть HP, defense и dodge.
- Враги наносят contact damage по `contact_range`, который подгоняется под видимый размер спрайта.
- При любом уроне по игроку HUD показывает `DamageFlashOverlay`: alpha peak ~0.20, fade ~0.32с, без стакания до непрозрачности, пауза-aware.
- SCRUM-497 добавляет visual-only боевой feedback над целями: каждый hit по `Enemy`
  показывает краткую floating damage number (~0.6с lift/fade), красный
  outline/flash по видимому телу и, если metadata hit содержит `critical=true`,
  отдельный красный `!` marker. Лечение игрока (`heal_percent` и vampirism/drain
  paths) показывает зелёное `+N` над игроком. Gameplay timing, damage, targeting
  и balance не меняются; плотные AoE ограничены глобальными caps
  `combat_feedback_labels=42` и `combat_feedback_flashes=36`.
- Feedback layer управляется persisted setting `combat_feedback` в
  `user://settings.cfg`; настройка включена по умолчанию.

### Типы урона и палитра боевых цифр (SCRUM-523)

- Урон по цели складывается из РАЗНЫХ типов (каналов). Итог по врагу = сумма всех
  типизированных попаданий: каждый вызов `take_damage` с `feedback["damage_type"]`
  уменьшает HP и порождает ОТДЕЛЬНУЮ цветную цифру, поэтому виден вклад каждого типа.
- Цвет цифры привязан к ТИПУ урона, НЕ к классу/оружию — бой читается одинаково во
  всех схватках. Палитра — единый источник правды в `scripts/enemy.gd`
  (`COMBAT_FEEDBACK_DAMAGE_COLORS`), доступ через статический `Enemy.damage_type_color(type)`;
  третьих копий палитры не заводить (player своих цифр не рисует — все боевые цифры
  спавнит `enemy.gd::_show_combat_feedback`).

  | Тип | Ключ | Цвет RGBA | Семантика |
  | --- | --- | --- | --- |
  | Физический | `physical` | `Color(1.0, 0.84, 0.42, 1.0)` (золотой) | melee, снаряды, добивания/осколки |
  | Магический | `magic` | `Color(0.68, 0.46, 1.0, 1.0)` (фиолетовый) | beam/AoE/curse мага, элементалист |
  | Периодический (DoT) | `dot` | `Color(0.46, 1.0, 0.42, 1.0)` (зелёный) | тики оружейного DoT и статус-эффектов |
  | Звуковой | `sound` | `Color(0.30, 0.86, 1.0, 1.0)` (голубой) | гитарист (sound_wave/pulse/amp), друид |
  | Чистый | `true` | `Color(1.0, 0.96, 0.82, 1.0)` (тёплый белый) | нетипизированный/истинный урон (дефолт) |

- Канал попадания оружия определяется его `damage_parameter` (см.
  `progression_data_weapons.gd`): `magic_damage` → `magic`, `sound_wave_damage` →
  `sound`, прочее (`damage`) → `physical`. Маппинг — `class_weapon._weapon_damage_type()`;
  DoT-тики (`_damage_enemy_with_dot` и тик `status_effects`) проставляют `dot` в точке
  тика. Берсерк-melee типизирует `physical` напрямую.
- Крит ПЕРЕБИВАЕТ цвет типа красным `Color(1.0, 0.24, 0.16, 1.0)` — ожидаемое
  поведение, не считается нарушением цветовой кодировки.
- Неизвестный/непроставленный тип откатывается на `true` (белый). Поэтому белая цифра
  означает именно чистый урон, а не «забыли проставить тип»: классовые попадания
  типизируются по каналу. Инвариант цвет↔тип закрыт `tests/damage_type_palette_test.gd`
  и проверкой `_test_damage_type_palette()` в umbrella `runtime_smoke`.
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
- SCRUM-854/864: Berserk `sweep` exact overlay is a readable outward wedge at alpha `0.60`; its apex remains on the character and its arc extends along attack direction, so the old low-alpha zone no longer reads as an inverted sickle. Chemist/Druid-style ground pools keep up to 6 active pools per weapon owner and expire by their own `pool_duration`; Engineer pressure mines are persistent hazards that tick each `pool_tick_interval` while enemies remain inside and clean up only at lifetime end.
- SCRUM-854: mobile summon weapons prefill about half of the current `max_summons` at battle start (`ceil(max_summons / 2)`), then fill the rest through normal summon cadence. Summon command/counting is scoped by owner+weapon metadata so different summon sources do not consume each other's caps.
- Временные эффекты оружия добавляются в cleanup groups (`player_weapon_effects`, `deployed_sound_amps`, projectiles/hazards).
- Gameplay effects не должны использовать `SceneTreeTimer`; текущие длительные эффекты привязаны к node-bound tweens и уважают паузу.

## Status Effects / Auras

- Общий runtime-модуль: `scripts/status_effects.gd`.
- Статусы хранятся в meta `status_effects` на цели и тикают из `_physics_process()` владельца, поэтому пауза замораживает duration и DoT вместе с gameplay.
- Поддерживаются duration, refresh/add/extend stack policy, DoT ticks, `speed_multiplier`, `damage_multiplier`, `damage_taken_multiplier` и marker metadata.
- `Enemy` применяет status slow к движению и vulnerability к входящему урону.
- `Enemy` также читает marker-status `bastion_taunt`: пока metadata `taunt_owner`
  указывает на живого валидного игрока/владельца в дереве, movement, shooting,
  contact damage и elite targeting используют владельца taunt как combat target;
  при истечении статуса или invalid owner враг возвращается к обычному `_player()`.
- `AllyMinion` применяет status damage/speed buffs к атакам и перемещению.
- `Player` раздает thematic on-hit debuffs: arcane vulnerability (Dark Mage/Elementalist), toxic DoT (Chemist/Doctor/Assassin/Biologist), stagger slow (Soldier/Knight/Robot).
- Knight block/counter uses weapon passive data on `Player.take_damage()`:
  incoming damage reduction, incoming-scaled retaliation, `counter_radius`,
  `counter_arc_degrees`, target caps/diminish and optional knockback/stagger.
  This keeps tank identity reactive without permanent immunity.
- Support/Leadership classes (`guitarist`, `druid`, `engineer`, `priest`) обновляют class aura примерно раз в 0.55с. Союзники получают `command_aura`, враги в радиусе — `command_pressure`, Priest получает мягкий self-support tick.
- Визуально используется существующий `AttackVfx.ring_pulse` и marker metadata; новых Design/VFX ассетов для SCRUM-245 не потребовалось.

## Spawn And Waves

- Спавн использует bounds новой арены, active cap и wave pacing.
- SCRUM-784/SCRUM-853: бой динамичен с первой секунды — `WAVE_SETTINGS` дают
  базовую волну `5` врагов (было 4 после SCRUM-784), normal active cap
  `22`→`48`, лимит обычной волны `10`, паузы спавна `0.7–1.2с` (было
  0.8–1.4), первая волна почти мгновенно (`spawn_cooldown=0.1`).
  `_choose_wave_spawn_edges`: минимум 2 края всегда, до 3–4 на поздних
  стадиях/волнах (босс держит 2). Без читерского спавна в лицо — позиции вне
  `SPAWN_PLAYER_SAFE_RADIUS`.
- SCRUM-853 добавляет pressure multipliers поверх базовых волн: normal-spawn
  pressure стартует с `1.14` на stage 0 (первый обычный raw wave фактически
  становится ~6 врагов), растёт от `route_scaling_stage`, номера волны и elapsed
  time и capped at `1.55`. HP pressure стартует с `1.05` и растёт до ~`1.37`;
  contact/projectile damage pressure стартует с `1.03` и растёт до ~`1.23`.
  Spawn cooldown получает дополнительное elapsed-time давление.
- Act 2/3 получают более опасный mob mix: shooter/mage/spitter/bone-shaman,
  summoner and heavy/shield/bruiser weights grow from route scaling stage 4.
  Mini-elites can appear in ordinary waves from a base chance `0.015`, growing
  by stage/wave/time to cap `0.12` before Ascension modifiers.
- Для 3-актного забега combat scaling использует `route_scaling_stage()`, а не
  act-local `route_stage`: Act 2/3 стартуют с новым маршрутом, но без tutorial
  ослабления волн/экономики.
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
- Dev console (`scripts/dev_console.gd`, SCRUM-845) не является gameplay pause reason: открытая консоль остаётся live overlay, перехватывает командный ввод, но не замораживает бой, таймер, движение игрока или врагов.

## Tests

- Зонтичный smoke: `tests/runtime_smoke_test.gd` (полный прогон).
- Dev console smoke: `tests/dev_console_smoke_test.gd` проверяет, что открытая консоль не ставит бой на паузу и не останавливает таймер/движение.
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
