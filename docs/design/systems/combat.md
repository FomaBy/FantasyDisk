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
7. После boss Act 1 игрок ровно один раз получает boss reward и 70% max-HP heal,
   сохраняет билд и переходит на новую route map Act 2. После boss Act 2
   показывается финальная победа либо запускается разрешённый secret boss; после
   финального результата autosave очищается.

### Combat Player lifecycle (SCRUM-1071)

- Принятый старт боя владеет ровно одним `Player`, одной включённой камерой и
  одним поколением HUD/сигнальных hooks. Повторный `_start_combat` в том же или
  соседнем кадре — идемпотентный no-op, пока старт строится или активный флаг
  подтверждён живыми owned Player/generation/HUD. Если карта уже очистила мир и
  HUD, stale `combat_active` нормализуется и не блокирует RouteNode A/pressed.
- Полный `Player.tscn`, временно используемый досье/магазином/событием как модель
  run snapshot, явно имеет роль `menu_snapshot`: он не входит в combat-группу
  `player`, не обрабатывает input/physics, не имеет активной камеры и принадлежит
  конкретному `Main` до централизованной очистки.
- Переходы Settings/Resume/Main Menu/новый бой и autosave Continue не полагаются
  только на `current_player`. UI teardown удаляет все временные Player этого
  Main, а world teardown синхронно выводит из дерева все принадлежащие ему
  combat/temp Player до создания следующего экземпляра. Поэтому enemy targeting,
  камера, HUD и battle-start hooks никогда не могут выбрать «замершую» копию.

## Player Control And Attacks

- Движение: WASD / переназначаемые hotkeys.
- SCRUM-823 sets playable character combat visuals to
  `BASE_SPRITE_SCALE = Vector2(0.64, 0.64)` for accepted full-frame
  `AnimatedSprite2D` characters, skeletal rigs and the legacy cutout-rig fallback,
  about x1.5 from the previous `0.425` combat scale. The player collision radius
  remains `8.9`, so readability improves without changing combat ranges, contact
  behavior or balance.
- FAN-1071 makes the gameplay origin/GroundCircle the authoritative playable
  footline. `Player` measures the current full-frame texture's visible alpha
  bottom, caches its center-to-foot distance and reapplies the visual-only lift
  on every `animation_changed`/`frame_changed`. All 17 heroes therefore keep
  every idle/move/walk frame on the damage-position platform even when a
  PixelLab pack uses a different transparent canvas placement than its legacy
  `sliced_rig_manifest` art. Collision, hurtbox, world position, targeting,
  camera ownership and combat ranges remain unchanged.
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
- SCRUM-894: итоговый шанс уворота считает `Player.current_dodge_chance()`:
  derived dodge (кап `SURVIVABILITY_DODGE_CAP` 55%) плюс, только для Ассасина,
  ситуативный бонус «Теневой завесы» — самоцентричной ауры уворота, активной
  лишь пока враг находится внутри derived `aura_radius` (величина =
  `veil_dodge_bonus × buff_power`, кап `veil_dodge_cap`; сумма всё равно ≤ 55%,
  бессмертия нет). Крит-шанс игрока капится per-class
  (`ProgressionData.class_crit_profile`): Ассасин — 100%, остальные — 55%.
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
  | Чистый | `true` | `Color(1.0, 0.96, 0.82, 1.0)` (тёплый белый) | нетипизированный/истинный урон (дефолт) |

- Канал попадания оружия определяется его `damage_parameter` (см.
  `progression_data_weapons.gd`): `magic_damage` → `magic`, прочее (`damage`) →
  `physical`. Историческое: до SCRUM-898 существовал звуковой канал `sound`
  (`sound_wave_damage`, голубой) — удалён, оружия Гитариста/Друида бьют магией.
  Маппинг — `class_weapon._weapon_damage_type()`;
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
- Class weapons используют reusable modes: `aoe_projectile`, `homing_curse`, `beam`, `dot_beam`, `sound_wave`, `riff_strip`, `pulse`, `amp`, `trap`, `boomerang`, `stab_flurry`.
- Прицеливание имеет два runtime-режима. `nearest` оставляет автонаводку на ближайшего врага, `cursor` берет единые `Player.attack_aim_direction()` / `attack_aim_position()` для melee, projectiles, beams, deploys и point-AoE. Summoner commands в cursor mode выбирают цель рядом с точкой курсора.
- SCRUM-886: contact-stuck enemies remain hittable when they overlap the player.
  `BerserkWeapon` accepts targets within a 40px close-contact rescue radius before
  applying strip/sweep/frustum rejection, and `ClassWeapon` line/corridor helpers
  give player-origin beams, vents, brace/compression lines and sound-wave cones a
  40px back allowance. This is a hit-query fix only: attack ranges, cooldowns,
  target caps, falloff, DPS budgets and enemy movement/pathfinding are unchanged.
- Темный маг использует AoE projectile, DoT и beam; новые caster/control классы переиспользуют эти режимы с другими параметрами.
- Гитарист (SCRUM-899) — магический кастер с деплой-геймплеем: `riff_strip` (узкая передняя полоса постоянной ширины, частые низко-средние магические хиты, все цели в полосе без pierce-капа), большой кайт-`pulse` баса и амп-турели `amp` (Лидерство = число+uptime ампов, summon_amount = темп пульса, урон — magic_damage владельца); trait «Разогрев» (SCRUM-1006) копит +2 п.п./сек магического урона без полученных ударов (кап +20%, сброс при квалифицированном ударе). Друид использует pulse / deployable totem; Рейнджер использует deploy trap.
- Друидский `druid_beast` summon использует `AllyMinion/AnimatedBody` с готовым `SpriteFrames`: `move` loop при движении/ожидании, `attack` one-shot при фактическом ударе и `flip_h` вправо по движению/атаке. Остальные ally visuals остаются статичными `Sprite2D` через fallback `Body`.
- Мобильные summons получают групповые команды от `SummonerWeapon`: цели выбираются в leash radius вокруг владельца, назначенный burst damage учитывается как overkill pressure, поэтому несколько союзников расходятся по слабым врагам вместо погони всей стаей за одной целью. Если старая `command_target` ушла за leash radius, `AllyMinion` сбрасывает ее и возвращается к локальной цели/guard behavior.
- Удар `AllyMinion` наносит основной цели полный урон один раз, затем бьет соседних врагов в data-driven малом splash radius (`summon_aoe_radius`, обычно 72-78 px) с `summon_aoe_damage_multiplier`, без повторного урона primary target.
- SCRUM-854/864/SCRUM-875/SCRUM-880: Berserk `sweep` damage remains an outward wedge from the character, but sword/axe attacks no longer show the exact sector overlay during the animation. Their visible crescent slash is rotated 180 degrees while targeting, damage geometry, cooldowns and balance stay unchanged. SCRUM-880 makes the `axe` visual read as a broad 180-degree, 250px cleave by widening only the VFX lateral scale and adding the actual two-handed axe sprite into the weapon-signature layer. Chemist/Druid-style ground pools keep up to 6 active pools per weapon owner and expire by their own `pool_duration`; Engineer pressure mines are persistent hazards that tick each `pool_tick_interval` while enemies remain inside and clean up only at lifetime end.
- SCRUM-854: mobile summon weapons prefill about half of the current `max_summons` at battle start (`ceil(max_summons / 2)`), then fill the rest through normal summon cadence. Summon command/counting is scoped by owner+weapon metadata so different summon sources do not consume each other's caps.
- SCRUM-859/SCRUM-906/FAN-1075: ClassWeapon deploys may define `deploy_role` and `max_summons_cap`. Guitarist amp is `stage_pulse`, Druid raven totem is `support_totem`, Engineer sentry is `turret_dps`, the orbital drone is `orbit_drone` (2 enlarged drones by default, opposite on a 121 px ring, cap 6), and pressure mines are `mine_grid`; sentry shots remember already-hit targets during one cycle, then retarget only after exhausting the local pool, with a small capped splash around the primary target.
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
- Биолог (SCRUM-896/1005): статус `bio_infection` — периодический урон с
  атрибуцией владельца (`source_id`, тики `player_owned`; refresh, 1 стак —
  устоявшийся DPS = тик × каденция, перекаст не мультиплицирует тики); статус
  `bio_spore_slow` — замедление колец Линзы 5→20% от прогрессии (refresh, 1
  стак, поверх — артефакт «Споровый конденсатор»). Прямые хиты Биолога по
  целям под его `bio_infection` усилены ×1.20 (trait «Разбор образцов»,
  generic-гейт в `ClassWeapon._damage_enemy`; тики не усиливаются,
  `StatusEffects.has_dot_from_source` отсекает чужие/истёкшие статусы).
- Рейнджер (SCRUM-913): статус `hunter_trap_paralysis` — ЖЁСТКИЙ паралич
  (`movement_locked: true`, новый generic-ключ статусов): враг под ним
  полностью стоит (`Enemy._physics_process` гейтит скорость в ноль —
  перемещение/рывки/стрельба/призыв заморожены; `StatusEffects.is_movement_locked`),
  двигают его только внешние импульсы `apply_knockback`, контактный урон
  сохраняется. В отличие от `speed_multiplier`-статусов движковый кламп ≥0.25
  здесь не применяется — это осознанный полный стоп; конечность гарантирована
  длительностью (2.2с базы) и контроль-резистом боссов/элит ×0.25
  (`POISON_PARALYSIS_BOSS_FACTOR` — пермалок босса невозможен). Статус
  `hunter_trap_bleed` — зелёное кровотечение по dot-оси (тик = `dot_damage`
  владельца, `apply_status_from` — «Катализатор»-паттерн атрибуции), 10 тиков
  × 0.5с = 5с: течёт во время паралича и продолжается после его конца.
  Отброса на триггере капкана нет — паралич держит жертву; trait-отброс
  «Сторожевого лука» распространяется только на лучные хиты (SCRUM-909).
- Knight block/counter uses weapon passive data on `Player.take_damage()`:
  incoming damage reduction, incoming-scaled retaliation, `counter_radius`,
  `counter_arc_degrees`, target caps/diminish and optional knockback/stagger.
  This keeps tank identity reactive without permanent immunity.
- Support/Leadership classes (`guitarist`, `druid`, `engineer`, `priest`) обновляют class aura примерно раз в 0.55с. Союзники получают `command_aura`, враги в радиусе — `command_pressure`, Priest получает мягкий self-support tick.
- SCRUM-897 «Отравленный Кинжал» (Вор): статус `poison_paralysis` —
  `speed_multiplier 0.12` (движковый кламп группы статусов держит фактические
  0.25 — «паралич-лайт», не абсолютный стан). Базовое окно 0.85с встроено в
  оружие; артефакт «Парализующее лезвие» (`backstab_root_duration`) продлевает,
  суммарно не выше `POISON_PARALYSIS_CAP` 1.8с; боссы/элиты (группы
  `bosses`/`elite_enemies`) получают срез ×0.25 (`POISON_PARALYSIS_BOSS_FACTOR`)
  — сохраняют мобильность заметную часть времени даже под фокусом. Паралич —
  строгое замедление (не полный стан): на одиночной обычной жертве окно может
  поддерживаться непрерывно — это ниша оружия («время сбежать или добить»),
  остальная толпа не контролится.
- SCRUM-897 «Дымовая Бомба» (Вор): позиционные дым-облака НЕ статусы — реестр
  `Player._smoke_clouds` (`register_smoke_cloud`/`smoke_cloud_dodge_bonus`).
  Бонус уклонения действует ТОЛЬКО пока герой стоит внутри живого облака;
  перекрытия не стакаются (берётся максимум). Ролл уворота
  `Player._current_dodge_chance()`: базовый dodge капится
  `SURVIVABILITY_DODGE_CAP` 0.55, бонус облака добавляется поверх с суммарным
  капом `SMOKE_CLOUD_DODGE_CAP` 0.90 — «почти неуязвим в дыму при тяжёлом
  dodge-билде», вне облака кап обычный. Облако урона не наносит; единственное
  дамажащее событие дыма — AoE-взрыв на детонации.
- Визуально используется существующий `AttackVfx.ring_pulse` и marker metadata; новых Design/VFX ассетов для SCRUM-245 не потребовалось.

## Gameplay Sandbox Runtime (SCRUM-976)

- `scripts/gameplay_sandbox.gd` owns the five clamped, `0.1`-snapped
  multipliers; neutral `1.0` is value-equivalent to release gameplay.
- `Enemy._ready()` applies monster HP and outgoing damage exactly once before
  health initialization. Because boss and every normal/elite/summoned enemy
  share this base, direct summon paths cannot bypass the layer.
- Monster attack speed scales only cooldown countdowns: contact, shooting,
  summoning, elite offensive rotations and boss attack rotations. Movement,
  shield duration, telegraphs, windups, strike and recovery windows keep their
  authored timing.
- Player damage and attack speed are final exact multipliers in
  `ProgressionData.derived_parameters()`, outside normal run softcaps and upgrade
  exponents. `Player` also bridges attack speed to `SummonerWeapon` deployment
  and allied-unit intervals; existing minimum interval floors remain active.
- Custom-run metadata is stored in `run_metrics.sandbox`; balance evidence must
  require `release_balance_evidence_eligible=true`.

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
- Act 2 получает более опасный mob mix: shooter/mage/spitter/bone-shaman,
  summoner and heavy/shield/bruiser weights grow from route scaling stage 4.
  Mini-elites can appear in ordinary waves from a base chance `0.015`, growing
  by stage/wave/time to cap `0.12` before Ascension modifiers.
- Для двухактного забега combat scaling использует `route_scaling_stage()`, а не
  act-local `route_stage`: Act 2 стартует с новым маршрутом на stage 8, ровно с
  бюджета boss Act 1, и доходит до финального stage 16 без удлинения боёв.
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
- Player lifecycle stress (SCRUM-1071):
  `tests/duplicate_player_spawn_regression_test.gd` — 50 циклов new/continue,
  battle/elite/boss, leaked-menu-snapshot simulation, rapid/double triggers и
  stale-combat route-map A activation, проверки после process+physics frames.
- Dev console smoke: `tests/dev_console_smoke_test.gd` проверяет, что открытая консоль не ставит бой на паузу и не останавливает таймер/движение.
- Фокус-сьюты (SCRUM-202, split зонтика): `tests/runtime_smoke_combat_test.gd`, `runtime_smoke_boss_elite_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_ui_test.gd`.
- Targeting-specific smoke: `tests/melee_weapon_targeting_test.gd`.
- Weapon integrity gate (SCRUM-277): `tests/weapon_integrity_test.gd` проверяет все 51 оружие 17 классов от `ProgressionData.weapon_ids()` до реальной scene/equipped visual, чтобы сцена не показывала чужой proxy-спрайт или пассивный item вместо выбранного оружия.
- Status/aura smoke: `tests/status_effects_aura_test.gd`.
- VFX smoke: `tests/attack_vfx_smoke_test.gd`, `tests/hazard_vfx_smoke_test.gd`.
- Снаряды: `tests/projectile_smoke_test.gd`, `tests/enemy_projectile_smoke_test.gd`.
- SCRUM-1066: player projectile art resolves through
  `ProjectileVisualRegistry` from the accepted SCRUM-1065 manifest. All 20
  flying/projectile-like weapon profiles use their canonical texture, display
  size, orientation and trail/impact palette; the other 31 weapons deliberately
  remain non-projectile. Runtime routing is visual-only and preserves damage,
  targeting, count, speed, timing, collision and hit geometry. Focused gate:
  `tests/projectile_visual_registry_test.gd`.
- SCRUM-1085 hardens the legacy `Projectile.setup()` lifecycle: a non-empty
  visual override is applied both before and after `_ready()`, an empty override
  preserves the current profile, and an invalid override clears stale canonical
  metadata/sprite state instead of leaving a mismatched previous texture.
  Regression: `tests/projectile_setup_visual_order_test.gd`.
- Балансовые харнессы (отчёты в `build/`): `tools/balance_harness.gd` (формульный), `tools/live_combat_harness.gd` (живой DPS/TTK), `tools/survivability_harness.gd` (выживаемость профилей). Прогон всех standalone-тестов: `tools/run_focused_tests.sh`.

## Enemy HP Bars

SCRUM-414 keeps normal enemy health bars in their original world-space
overhead position, but elite and boss bars clamp into the active viewport when
their large sprite would place the bar above the top screen edge. The clamp uses
the current canvas transform so camera/zoom are respected, preserves the
existing `scripts/enemy_health_bar.gd` drawing node, and keeps boss phase marker
metadata on the same bar.

# SCRUM-1068 runtime: weapon-scoped meta finals

SCRUM-1067 определяет design contract; SCRUM-1068 подключает его в runtime. Каждый из
306 branch nodes и 34 hidden profiles имеют explicit weapon-scoped consumer;
51 финал дополнительно имеет уникальный `mechanic_id`, hard caps, positive
fixture и два negative-controls. Финалы не должны попадать в общий class-wide
modifier bag.

Consumer contract:

- применить boon/final только при совпадении текущего `weapon_id`;
- сохранить действующие target/deploy/summon/sustain caps и cleanup;
- не считать один control/sustain эффект полностью и как damage, и как defense;
- неизвестный/no-op `mechanic_id` является hard failure;
- generic subsystem reuse не отменяет weapon-specific behavior и fixture.

Полная матрица и A5 anti-runaway gates:
`docs/design/reports/scrum1067_constellation_3x6_balance_spec.md`.

Production implementation использует `ConstellationFinalRuntime` с точным
`mechanic_id → required event` registry. Неверное событие нейтрально и не меняет
lifecycle-state; неизвестный ID fail-closed. Реальные consumers вызывают только
свои события (`hit`, `cast`, `return`, `dodge`, `block`, `damage_absorbed`,
`overheal`, `summon_death` и специализированные impact/deploy events).
`tools/validate_scrum1068_runtime_manifest.py` требует все 51 route и для 40
ClassWeapon-финалов проверяет точный bound method, а mutation gate удаляет
rifle-hit route и доказывает, что одноимённые события других оружий не дают
false-green. Behavioral matrix проверяет 51 positive + 102 same-class foreign
negatives. Secondary/share/aftershock damage идёт низкоуровневым путём без
повторного proc, а consumer-owned state очищается вместе с weapon/minion.

Post-review gate 2026-07-11 запрещает считать registry-строку или общий damage
gateway реализацией финала. Explicit-hit consumers имеют отдельный marker и не
считают generic/DoT hits повторно. Setup finals сначала ставят timed target mark
и выплачиваются только следующим квалифицированным hit; delayed waves, unique
targets, chain depth и same-target caps проверяются живыми ClassWeapon fixtures.
Временные absorb/dodge источники принадлежат Player, пересчитывают derived stats,
имеют monotonic expiry token и не переживают configure/cleanup. Authoritative
kill callback покрывает curse/mark death lifecycle без двойной выплаты.
Shatter хранит hit-cap отдельно для каждого перекрывающегося залпа; Dark Book
связывает endpoints по pair и допускает ровно один midpoint collapse на cast.
Censer создаёт один cast-scoped absorb на 18% одного удара: unrelated flat
absorb не может запустить retaliation. Reactor на четвёртом cast применяет
настоящий pulse knockback 110, а Acid rearm-ится только после падения живых
стаков ниже пяти.
