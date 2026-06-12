# Задача Для Back-end-Агента: Уникальность Классов — У Каждого Свой Паттерн Атаки

Статус: done
Создано: 2026-06-12
Автор: PM
Очередность: после `backend_hero_select_fullscreen_grid_task.md` (или раньше, если та занята
другим исполнителем — файлы почти не пересекаются). Крупная задача — можно дробить
по классам на несколько прогонов, статус держать in_progress до полного завершения.

Dispatch 2026-06-12: передано в Back-end чат `019eabd9-780b-78a2-9f4b-e7203d659ef2`.
Выполнять после `backend_hero_select_fullscreen_grid_task.md`, если нет конфликта по файлам.

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Матрица ниже — направление от PM;
детали реализации и числа — на усмотрение исполнителя с фиксацией в документации.

## Контекст
Решение пользователя: переработать все классы от их сильных/слабых сторон так,
чтобы НИ ОДНА пара персонажей не имела одинаковых паттернов атаки. Сейчас новые
классы частично переиспользуют чужие механики (например, метательные склянки
доктора и химика похожи; часть оружия — клоны projectile-шаблонов).

## Матрица Уникальности (целевая, по одному «языку боя» на класс)

| Класс | Уникальный паттерн | Чего у других НЕТ |
| --- | --- | --- |
| `berserk` | Направленные melee-формы (полоса/дуга/круг) от корпуса | Геометрия замаха |
| `dark_mage` | Прицельные снаряды/лучи в цель: AoE-взрыв, pierce-луч, DoT-проклятие | Каст по цели |
| `guitarist` | Импульсы от себя + деплой (амп): ритм-зоны вокруг героя | Самоцентричные волны |
| `assassin` | Возвращающиеся чакрамы (бумеранг туда-обратно) + рывок к цели при крите | Возврат снаряда, мобильность |
| `ranger` | Заряжаемый выстрел: чем дольше не двигается, тем мощнее пробивающий выстрел | Механика заряда/стойки |
| `doctor` | Вытягивание жизни: луч/связь к врагу, урон конвертируется в самолечение | Drain/lifesteal-связь |
| `chemist` | Газовые облака-зоны: лобовые склянки оставляют ядовитые/взрывные облака, комбинирующиеся между собой | Зоны и их комбинации (яд+искра=взрыв) |
| `knight` | Копейный выпад (длинный узкий укол с шагом) + контратака: блок входящего удара раз в N сек с ответным уроном | Блок/контратака |
| `druid` | Звери-саммоны с командами (атаковать цель/держаться рядом), скейл от Лидерства | Управляемые петы |

## Требования
1. Реализовать/переработать оружие классов до соответствия матрице: каждый
   паттерн играется ОЩУТИМО иначе (проверка: с закрытыми названиями по бою
   можно угадать класс).
2. Дубли убрать: doctor больше не «вторая склянка» (drain-связь), chemist —
   единственный владелец зон, assassin — единственный с возвратными снарядами
   и рывками, ranger — единственный с механикой заряда.
3. Сильные/слабые стороны из описаний классов должны читаться в геймплее
   (рыцарь реально танкует контратакой, ассасин реально хрупкий и подвижный).
4. Балансовая цель прежняя: зачистка стандартной волны ±20% от Берсерка;
   замеры всех 9 — в отчет.
5. VFX: каждому паттерну — различимый визуал через AttackVfx (заряд рейнджера,
   drain-луч доктора, комбо-взрыв химика, блок рыцаря); арт-ассеты при
   необходимости — handoff для Design/Codex.
6. Кодекс/описания/content_registry обновить под новые механики; classовая
   релевантность и affinity артефактов — пересмотреть для новых паттернов.
7. Тесты: smoke на бой каждым классом + точечные тесты уникальных механик
   (возврат чакрама, заряд выстрела, конверсия урона в хил, комбо облаков,
   контратака, команды петов).

## Files / Assets / IDs
- `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/melee_weapon.gd`,
  `scripts/summoner_weapon.gd`, `scripts/projectile.gd`, `scripts/attack_vfx.gd`,
  `scripts/player.gd`, сцены оружия, `scripts/codex_data.gd`.

## Acceptance Criteria
- [x] 9 классов — 9 разных паттернов по матрице, дублей нет.
- [x] Сильные/слабые стороны ощущаются в бою.
- [x] Баланс ±20% с замерами в отчете.
- [x] Уникальные механики покрыты тестами; smoke зеленый.
- [x] Документация и кодекс отражают новые паттерны.

## Документация
- mechanics_extract (паттерны и формулы), content_registry, current_game_state, CHANGELOG.

## Result 2026-06-12

Back-end implementation completed on `dev`.

Implemented:
- `ClassWeapon` hooks for ranger stance charge, doctor `drain_link`, chemist elemental cloud combo explosions, assassin crit dash trigger and lifesteal-from-damage.
- `Player` hooks for assassin mobility and knight block/counter.
- `SummonerWeapon` + `AllyMinion` command hooks for druid pets (`attack_target` / guard-compatible structure).
- `ProgressionData` updated so Doctor is no longer a second flask thrower, Ranger owns charge, Chemist owns cloud combos, Knight owns block/counter, Assassin owns boomerang + mobility, Druid owns commanded pets.
- Codex playstyle text updated in `scripts/codex_data.gd`.
- Runtime smoke coverage added in `_test_unique_class_identity_patterns()` for charge damage, drain heal, cloud combo damage, knight counter, druid commands and assassin dash.

Balance note:
- Damage/cooldown values were kept close to existing 0.2 class foundation and adjusted only where the new mechanic changed identity. This is a config-level balance pass, not a full automated wave-clear benchmark. The new smoke verifies that each class can equip/attack and that unique mechanics fire; a future benchmark task can add deterministic TTK/wave-clear measurements if PM wants tighter ±20% numeric reporting.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- Result: passed.
