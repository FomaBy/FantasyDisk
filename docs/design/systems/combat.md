# Combat

Обновлено: 2026-06-13 (0.1.4)

Этот файл описывает активную боевую систему `dev` / версии 0.1.4. Snapshot полного состояния: `docs/design/current_game_state.md`. Канонические ID: `docs/design/content_registry.md`. Балансовый аудит: `docs/design/reviews/mechanics_balance_audit_2026_06.md`.

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
- Темный маг использует AoE projectile, DoT и beam; новые caster/control классы переиспользуют эти режимы с другими параметрами.
- Гитарист и Друид используют sound wave / pulse / deployable amp/totem; Рейнджер использует deploy trap.
- Временные эффекты оружия добавляются в cleanup groups (`player_weapon_effects`, `deployed_sound_amps`, projectiles/hazards).
- Gameplay effects не должны использовать `SceneTreeTimer`; текущие длительные эффекты привязаны к node-bound tweens и уважают паузу.

## Spawn And Waves

- Спавн использует bounds новой арены, active cap и wave pacing.
- На ранних stage плотность ниже, дальше растет количество и сила врагов.
- Elite fights выбирают элитку из пула; boss node выбирает одного из доступных боссов.
- Boss-ростер (0.1.4): `rift_warden` (исходный) + `ashen_colossus`, `bone_archon`, `brood_mother`. У боссов уникальные паттерны и hazard-зоны (паутина-замедление `brood_mother`, ember/огненные лужи `ashen_colossus`, костяные шипы `bone_archon`), привязанные к node-tween'ам.
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
- VFX smoke: `tests/attack_vfx_smoke_test.gd`, `tests/hazard_vfx_smoke_test.gd`.
- Снаряды: `tests/projectile_smoke_test.gd`, `tests/enemy_projectile_smoke_test.gd`.
- Балансовые харнессы (отчёты в `build/`): `tools/balance_harness.gd` (формульный), `tools/live_combat_harness.gd` (живой DPS/TTK), `tools/survivability_harness.gd` (выживаемость профилей). Прогон всех standalone-тестов: `tools/run_focused_tests.sh`.
