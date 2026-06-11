# Задача Для Back-end-Агента: Полный Performance И Code Quality Review

Статус: done 2026-06-11. Итог ревью финального кода пакета:

ДЕБАГ-ОШИБКИ: headless-запуск игры (--quit-after) и все 3 smoke-теста — консоль чистая, ошибок/warnings/parse-проблем не обнаружено (все ранее найденные — утечки AudioStream в headless, parse-ошибки рига max()->maxf(), строковый call_deferred на перенесенный метод, недетерминированность тестов из-за dodge — были закрыты в предыдущих задачах пакета; это зафиксировано в их статусах).

PERFORMANCE-ФИКСЫ: (1) enemy.gd кэширует Body-спрайт, RigRoot и AudioManager — убраны get_node_or_null из _update_movement_animation (каждый кадр на каждого врага) и take_damage (каждое попадание при толпе); (2) player.gd кэширует AudioManager; (3) HUD-снапшот считает артефакты дешевым счетчиком без поэлементной нормализации каждый кадр.

МЕРТВЫЙ КОД: удалены (в build/unused_assets_backup/) MeleeWeapon.tscn+melee_weapon.gd и Weapon.tscn+weapon.gd — не инстанцировались ниоткуда; удалены константы ROUTE_MAP_CANVAS_SIZE, ACTIVE_ENEMY_CAP_BASE/PER_STAGE/BOSS (дублировали WAVE_SETTINGS), SHOP_INLINE_AREA_SIZE. Отладочных print не найдено. SummonerWeapon/AllyMinion сохранены как заготовка summon-механики (summon_amount в данных) — отмечено в current_game_state.

ПРОВЕРЕНО БЕЗ ЗАМЕЧАНИЙ: cleanup-группы (player_weapon_effects, enemy_hazards, deployed_sound_amps), отсутствие load() в hot paths (texture cache + preload повсеместно), HUD обновляется только по изменению снапшота, route map строится один раз за открытие, SceneTreeTimer-ов в gameplay-коде нет (всё на node-bound tween).

ОСТАВШИЕСЯ РИСКИ (некритичные): ui_screens.gd вырос до ~1800 строк — при дальнейшем росте стоит выделить shop/level-up в отдельные модули; _update_pickups сканирует группу pickups каждый кадр (приемлемо при текущих объемах); точный баланс маг-vs-берсерк ждет ручного плейтеста. Все 3 smoke-теста зеленые.
Дата: 2026-06-10
Перевыдана PM: 2026-06-11 (см. раздел «Дополнение PM 2026-06-11» в конце)

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: проведи ревью, исправь найденные проблемы, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

Нужно посмотреть на текущий код FantasyDisk со стороны, как будто ты ревьюишь код перед демонстрационной версией игры. Найти возможные performance проблемы, архитектурные слабые места, лишние runtime allocations, плохие практики Godot/GDScript, утечки временных объектов, проблемы cleanup, лишние `load()` во время игры/меню, тяжелые loops, дублирование и fragile UI/gameplay logic.

Важно: это не только ревью. Нужно сделать код лучше по best practices разработки, но без разрушительного переписывания всего проекта.

## Главная Цель

После задачи проект должен:

- работать стабильнее;
- меньше лагать во время боя, меню и route map;
- корректно чистить временные объекты;
- не подгружать ресурсы в неожиданных местах;
- иметь более понятную структуру для дальнейших задач;
- иметь обновленные тесты и документацию;
- сохранить текущий функционал игры.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/mechanics_extract.md`

Также учесть активные/недавние task-файлы в `docs/tasks/`, особенно:

- route map fixes;
- UI/HUD/stat icons;
- Dark Mage/Guitarist balance and amp cleanup;
- animation and design integration tasks.

## Review Scope

Проверить весь gameplay/runtime code, минимум:

- `scripts/main.gd`
- `scripts/player.gd`
- `scripts/enemy.gd`
- `scripts/boss.gd`
- `scripts/class_weapon.gd`
- `scripts/berserk_weapon.gd`
- `scripts/enemy_projectile.gd`
- `scripts/pickup.gd`
- `scripts/pause_stats_menu.gd`
- `scripts/progression_data.gd`
- `scripts/stat_formulas.gd`
- `scenes/*.tscn`
- `tests/runtime_smoke_test.gd`
- `tests/animation_smoke_test.gd`

## Performance Review Checklist

Проверить и исправить, где уместно:

### Runtime Resource Loading

- `load()` / texture loading во время меню, боя, attack loop, UI redraw.
- Заменить на `preload`, exported PackedScene/Texture references, centralized cache или scene-level references.
- Не грузить одни и те же textures/icons/projectiles многократно.

### Object Lifecycle / Cleanup

- Временные projectiles, AoE zones, amp visuals, attack visuals, pickups, summoned mobs.
- Очистка при смене персонажа, смене оружия, новом забеге, смерти, победе, route transition, pause/menu.
- Проверить groups для cleanup.
- Убедиться, что нет orphan nodes и persistent class-specific effects.

### Node Count And Spawn Pressure

- Волны врагов, active cap, projectiles, pickups.
- Не создавать слишком много nodes за кадр.
- Проверить, где нужен pooling или batching.
- Проверить deferred calls/timers, чтобы не было каскадов.

### Physics And Collision

- Collision layers/masks игрока, врагов, снарядов.
- Лишние Area2D checks или broad group scans.
- Частые `get_nodes_in_group()` внутри `_physics_process` или attack loops.
- Возможность кешировать списки/использовать spatial filtering/ограничивать частоту поиска целей.

### UI Performance

- Route map rebuilds.
- Full-screen route map scroll/drag.
- Escape stats menu redraw.
- Level-up/shop/event/rest screens.
- Tooltip creation/destruction.
- HUD updates: обновлять только изменившиеся значения, а не rebuild всего UI каждый кадр.

### GDScript Allocations

- Создание больших Array/Dictionary каждый кадр.
- Частые `duplicate(true)` в runtime loops.
- String formatting каждый кадр.
- Лишние Color/Vector/Callable allocations в hot paths.

### Animation / Visual Updates

- Не обновлять тяжелые animation/visual nodes для paused gameplay.
- Не держать невидимые effects активными.
- Проверить procedural animation loops на врагах при большом количестве enemies.

### Godot Best Practices

- Использовать `@onready`, typed variables, constants, helper methods.
- Разделять UI/gameplay/helper logic, если файл стал слишком большим.
- Не делать большой рефактор ради красоты, если это повышает риск.
- Убирать дублирование только там, где оно реально мешает поддержке.

## Code Quality Review Checklist

Проверить:

- слишком большие функции;
- дублированные блоки route map/UI/spawn logic;
- magic numbers без названия;
- fragile order-dependent code;
- inconsistent naming;
- отсутствие централизованных констант для arena/camera/UI;
- неочевидные side effects;
- отсутствие cleanup API у объектов, которые создают children/effects;
- тесты, которые устарели после последних изменений.

## Требования К Исправлениям

Исправлять приоритетно:

1. Реальные performance риски в hot paths.
2. Баги cleanup и persistent leftovers.
3. Runtime loads/stutter.
4. UI rebuild/click/scroll issues.
5. Дублирование, которое мешает будущей разработке.
6. Magic constants, влияющие на баланс/камеру/карту.

Не делать:

- полный rewrite проекта без необходимости;
- изменение дизайна/баланса вне scope, кроме очевидных технических bugfixes;
- удаление пользовательских изменений;
- опасные git/file operations.

## Suggested Deliverables

Сделать:

- список найденных performance/code quality проблем;
- исправления в коде;
- обновленные tests;
- обновленную документацию;
- краткий итог: что улучшено и какие риски остались.

Если какая-то проблема большая и рискованная, можно оставить отдельный follow-up task, но только после того, как быстрые и безопасные улучшения сделаны.

## Acceptance Criteria

Задача готова, если:

- проведен полный review основных runtime scripts;
- устранены найденные low-risk/high-impact performance проблемы;
- устранены очевидные cleanup leaks;
- нет runtime resource loading в hot paths, где это можно безопасно убрать;
- UI/HUD/route map не rebuild-ятся лишний раз без необходимости;
- тесты обновлены и проходят;
- документация обновлена;
- в финальном отчете есть список исправлений и оставшихся рисков.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Если затронуты анимации/ассеты/visual expectations:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Ручная проверка:

- старт нового забега;
- route map click/drag;
- обычный бой с большим количеством врагов;
- level-up pause;
- Escape stats menu;
- магазин/event/rest;
- Гитарист amp cleanup;
- бой с элиткой;
- оба босса.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md` - если поменялась architecture/runtime behavior.
- `docs/design/mechanics_extract.md` - если менялись формулы, баланс, spawn pacing или weapon timing.
- `docs/design/fantasydisk_design_brief.md` - если поменялись guardrails/UX behavior.
- `docs/design/content_registry.md` - если добавлены/переименованы effect IDs, assets, groups.

Не оставлять performance/code quality решения только в коде.

## Дополнение PM 2026-06-11

Задача перевыдана с расширением scope по решению пользователя:

1. **Debug-ошибки**: закрыть ВСЕ ошибки и warnings, которые появляются в консоли/debug
   при запуске и обычном прогоне игры (headless и обычный запуск): parse warnings,
   ошибки загрузки ресурсов, node path errors, signal errors и т.п. В финалке —
   список того, что было и что исправлено.
2. **Лишний код**: удалить мертвый код — неиспользуемые функции, переменные,
   закомментированные блоки, отладочные print/printerr, оставшиеся заглушки.
3. **Порядок выполнения**: выполнять ПОСЛЕДНЕЙ из текущего пакета backend-задач
   (после aim-fix, оружия Берсерка, мага/гитариста, артефактов/таймера, элиток,
   HP-баров и чистки ассетов) — чтобы ревьюить итоговый код, а не промежуточный.
4. В Review Scope добавить новые модули: `scripts/ui_screens.gd`,
   `scripts/route_map_screen.gd`, `scripts/combat_director.gd`, `scripts/melee_weapon.gd`,
   `scripts/attack_vfx.gd`, `scripts/meta_progression.gd` и все скрипты, появившиеся
   в задачах 2026-06-11.
