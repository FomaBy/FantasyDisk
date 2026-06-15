# BALANCE: Усиление призывателей — масштаб от Лидерства/атрибутов, умные цели, AoE-удар

Статус: done
Приоритет: high
Роль: Back-end (геймплей/баланс)
Версия: 0.1.5
Jira: SCRUM-357
QA: in_progress (2026-06-14)
Создано: 2026-06-14
Автор: PM (запрос пользователя)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Ребаланс классов, в частности усилить призывателей:
1) призыв должен сильнее зависеть от Лидерства и атрибутов — призывные существа
   должны быть сильнее;
2) умная приоритизация целей: если существа могут быстро убить врага — другие
   пусть выбирают других врагов; оптимизировать, чтобы толпа суммонов не бегала
   за 1 мобом по карте, а убивала всех вокруг призывателя;
3) добавить всем суммонам AoE-урон небольшого радиуса во время удара».

Текущий код:
- Масштаб профиля: summoner_weapon.gd `_build_combat_profile` (118-140).
  **Лидерство влияет только на move_speed/lifetime/max_health (caps 0.16/0.32/0.45),
  но НЕ на урон**; урон скейлится от summon_amount (role_damage, cap +0.22).
- Цели: ally_minion.gd `_commanded_target` (120) → `_find_closest_enemy` (116) =
  TARGET_QUERY.nearest независимо у каждого союзника → все бегут к ближайшему.
- Удар: ally_minion.gd `_try_attack` (155) — одиночный урон по target, AoE нет.

## Требования
### 1. Сильнее зависеть от Лидерства и атрибутов
- Добавить **скейл УРОНА призыва от Лидерства** (сейчас его нет) и от основного
  атрибута призывателя (через derived_parameters/stats — напр. summon_amount,
  intelligence/leadership), с заметным, но контролируемым ростом; поднять
  существующие caps (speed/lifetime/HP), чтобы при высоком Лидерстве суммоны были
  ощутимо сильнее (урон + выживаемость).
- Значения data-driven, согласовать с derived_parameters; уровень 0 атрибутов не
  ломает базовый баланс. Документировать формулы.

### 2. Умная приоритизация целей (без «толпа за 1 мобом»)
- Координировать выбор целей по ВСЕЙ группе союзников (группа "allies"): не
  назначать несколько суммонов на одного слабого врага сверх необходимого —
  оценивать «overkill» (если назначенного урона хватает убить врага быстро,
  лишние суммоны берут ДРУГИХ врагов).
- **Лиш к призывателю**: приоритет врагам ВОКРУГ призывателя (в радиусе), а не
  бесконечная погоня за одним мобом по всей карте; распределять суммонов по
  ближайшим разным целям, чтобы зачищать толпу вокруг owner.
- Сохранить режимы command_mode (guard_owner/attack_target) и существующие
  TARGET_QUERY-хелперы; реализовать лёгкий групповой назначатель целей
  (без тяжёлых вычислений каждый кадр — троттлинг/кэш назначений).

### 3. AoE-урон при ударе (всем суммонам)
- В `_try_attack` добавить **AoE небольшого радиуса** вокруг точки удара/цели:
  основной target получает полный урон, враги в малом радиусе — урон (полный или
  с лёгким фолоффом). Радиус небольшой (напр. ~60-90 px, data-driven), чтобы
  суммоны зачищали скопления, но не превращались в дальнобойную AoE-пушку.
- Учесть knockback/статусы по затронутым (по необходимости), без двойного урона
  основной цели.

## Тест/верификация
- runtime_smoke + новый/расширенный тест: (а) при росте Лидерства урон+HP суммона
  растут; (б) при нескольких суммонах и группе врагов цели РАСПРЕДЕЛЯЮТСЯ (не все
  на одном), лиш к owner работает; (в) удар бьёт ≥2 врагов в малом радиусе.
- Баланс: суммонер-классы (друид и др. summon-оружие) ощутимо сильнее, но не
  ломают кривую; согласовать с общим балансом 0.1.5.
- CHANGELOG; current_game_state; systems/progression_balance + combat.

## Files / Assets / IDs
- scripts/summoner_weapon.gd (_build_combat_profile 118-140; leadership/summon_amount,
  max_summons, summon_role_damage_multiplier, derived_parameters)
- scripts/ally_minion.gd (_commanded_target 120; _find_closest_enemy 116;
  _find_closest_enemy_near; _try_attack 155; группа "allies"; combat_target_query)
- scripts/combat_target_query.gd (nearest/в радиусе — групповой назначатель)
- scripts/progression_data*.gd (summon-параметры классов/оружия, derived_parameters)
- tests/runtime_smoke_test.gd (+ summon-баланс/таргетинг проверки)

## Acceptance Criteria
- [x] Урон И выживаемость призывов заметно скейлятся от Лидерства/атрибутов (урон теперь тоже); формулы документированы, уровень 0 не ломает базу.
- [x] Цели распределяются по группе (нет overkill-погони толпой за 1 мобом); лиш к призывателю — зачистка врагов вокруг owner.
- [x] У всех суммонов AoE-урон малого радиуса при ударе (≥2 врага), без двойного урона основной цели.
- [x] runtime_smoke + баланс/таргетинг тесты зелёные; CHANGELOG; progression_balance/combat доки.

## Документация
docs/design/systems/progression_balance.md, docs/design/systems/combat.md, current_game_state.

## Result — 2026-06-14

Back-end реализация завершена.

- `SummonerWeapon` теперь строит combat profile с явным Leadership damage multiplier, attribute multiplier от `summon_amount`/Knowledge/Intelligence/Energy, более сильными capped HP/speed/lifetime/haste scaling и data-driven `summon_aoe_radius`, `summon_aoe_damage_multiplier`, `summon_leash_radius`.
- Команды союзникам теперь распределяются группой вокруг владельца: кандидаты берутся в leash radius, overkill pressure учитывает уже назначенный burst damage, поэтому лишние summons выбирают соседние цели вместо толпы на одного слабого моба.
- `AllyMinion` сбрасывает устаревший `command_target`, если он ушел за leash radius, и при атаке наносит full damage primary target + splash по соседям без double-hit primary.
- `homunculus_vial` и `summon_amulet` получили явные summon splash/leash параметры; `ProgressionData.estimate_weapon_budget()` использует ту же Leadership/attribute summon damage/haste формулу.
- Расширен `tests/summoner_strengthening_test.gd`: проверяет заметный Leadership damage/HP/AoE growth, group target split и splash damage без двойного урона primary.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/summoner_strengthening_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `git diff --check` — clean.

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/systems/progression_balance.md`, `docs/design/systems/combat.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **1) Скейл от Лидерства/атрибутов** (summoner_weapon.gd): `leadership_damage =
  1.0 + min(leadership*0.020, 0.42)` (УРОН теперь тоже скейлится, +42% cap, раньше
  не было); `role_damage = summon_role_damage_multiplier * leadership_damage *
  attribute_damage` (стр.134-136); усиленные capped HP/speed/lifetime/haste.
  Уровень 0 → множитель 1.0 (база не ломается).
- **2) Умный таргетинг** (ally_minion.gd): `leash_radius=520` (min 120),
  `_find_closest_enemy_near(owner, min(leash,360))` — лиш к призывателю; устаревший
  `command_target` сбрасывается за leash; групповое распределение учитывает overkill
  burst (лишние суммоны берут соседей, не толпой за 1 мобом).
- **3) AoE при ударе**: `summon_aoe_radius=70`, `aoe_damage_multiplier=0.55` —
  full damage primary + splash по соседям БЕЗ double-hit primary (data-driven для
  homunculus_vial/summon_amulet).
- **Целевой тест** `summoner_strengthening_test` — passed (Leadership damage/HP/AoE
  growth, group target split, splash без двойного урона primary).
- **Баланс-гейты 0.1.5 НЕ сломаны** (ключевая проверка усиления):
  `global_damage_balance_smoke` — passed (51 пара; combined ±25%/solo ±20%/CCT ±30%;
  худшее CCT +22% doctor/plague_syringe — в коридорах, суммоны кривую не выбили);
  `global_survivability_balance_smoke` — passed (TTD≤600с, митигация<98%,
  бессмертие недостижимо).
- **Регрессия** `runtime_smoke_test` — passed; `git diff --check` clean; доки обновлены.

Acceptance:
- [x] Урон+выживаемость скейлятся от Лидерства/атрибутов (урон теперь тоже); уровень 0 ок.
- [x] Цели распределяются по группе, лиш к owner (нет погони толпой за 1 мобом).
- [x] AoE малого радиуса при ударе (≥2 врага) без двойного урона primary.
- [x] runtime_smoke + баланс/таргетинг тесты зелёные; баланс-кривая цела; доки.

Баги: нет.
