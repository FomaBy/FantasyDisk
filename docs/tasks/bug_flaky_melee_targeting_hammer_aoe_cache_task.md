# BUG: Флака `melee_weapon_targeting_test` — hammer AoE из-за покадрового кэша целей

Статус: in_progress
Приоритет: normal
Роль: Back-end
Найдено QA при тестировании: backend_ui_dark_fantasy_theme_integration_task.md (SCRUM-222 QA-прогон)
Jira: SCRUM-228

## Воспроизведение
1. `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script "res://tests/melee_weapon_targeting_test.gd"`
2. Прогнать 10–15 раз подряд.
3. Часть прогонов падает с `ERROR: Expected hammer AoE to damage enemies around Berserk.`
   (`tests/melee_weapon_targeting_test.gd:154`).

Замер QA на коммите e9aa3d3a: **2 падения из 12 прогонов (~17%)**, всегда одно
и то же утверждение (молот Берсерка), геометрия при этом корректна.

## Ожидание / Реальность
- Ожидание: тест детерминированный — молот AoE всегда бьёт врага в радиусе.
- Реальность: ~17% прогонов молот «не находит» только что добавленного врага.

## Корневая причина (диагностика QA)
`scripts/combat_target_query.gd:10-26` кэширует список врагов **на кадр**
(ключ `Engine.get_process_frames() + Engine.get_physics_frames()*1000000`).
Кэш не инвалидируется при изменении состава группы `enemies` внутри кадра.

В тесте (`tests/melee_weapon_targeting_test.gd:131-152`):
- `hammer_enemy` / `hammer_outside_enemy` добавляются в группу `enemies` и тут же
  атакуются `hammer.call("_attack")` **в том же кадре**, без промежуточного
  `await process_frame`.
- Меч-`player` (создан раньше) НЕ получает `set_process(false)`, поэтому его
  оружие продолжает тикать. После своего `_attack` оно гейтится `_cooldown`;
  на том кадре, где `_cooldown` пересекает ноль, `_process` вызывает
  `TARGET_QUERY` и наполняет покадровый кэш **до** появления молотовых врагов.
- Пересечёт ли `_cooldown` ноль именно на «await-кадре» перед атакой молота —
  зависит от накопленного `delta` (реальная длительность кадров) → недетерминизм.
  Если пересёк — кэш устаревший, молот промахивается (FAIL); если нет — первый
  `TARGET_QUERY` кадра делает свежий кэш с врагами (PASS).

Это дефект **надёжности теста**, не геймплея: в реальной игре враги существуют
много кадров до удара, и однокадровая устарелость кэша безвредна.

## Предлагаемое исправление (для исполнителя, не делалось QA)
Любой из вариантов в `tests/melee_weapon_targeting_test.gd`:
- Добавить `await process_frame` после создания `hammer_enemy`/`hammer_outside_enemy`
  и до `hammer.call("_attack")` (враги будут в группе до любого `_process`-запроса).
- И/или `set_process(false)` на меч-оружии (`weapon`) после его блока проверок,
  по аналогии с `hammer.set_process(false)` (строка 138).
Production-код `combat_target_query.gd` трогать не требуется (покадровый кэш —
намеренная оптимизация).

## Окружение
- Коммит: e9aa3d3a (ветка dev)
- Godot 4.6.3.stable, headless, macOS (M4)
- Класс/оружие: Berserk + hammer (circle AoE)
- Разрешение: н/п (headless логический тест)

## Dispatcher Note (2026-06-13)
Jira key `SCRUM-228` found in existing sync map/Jira and synced into this task. Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as an isolated test-flake fix. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. Duplicate audit: older melee targeting test work SCRUM-37 is already done and is not this hammer AoE cache flake.
