# BUG: В бою с боссом сверху висит панель таймера — таймер не нужен, место очистить

Статус: done
Приоритет: high
Роль: Back-end (UI)
Создано: 2026-06-12
Автор: PM (отчет пользователя со скриншотом босс-боя)
Jira: SCRUM-145

Dispatch: отправлено в существующий Back-end чат `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-12.

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений.

## Контекст
Скриншот пользователя (босс-файт, окно редактора ~1454x909): сверху по центру
рядом с панелью ULT висит рамка таймера с замороженным временем. В босс-бою
таймер не нужен (бой до победы, round_time_left не тикает — main.gd:515),
верх экрана должен быть чистым.

## Корень (НАЙДЕН, проверить и починить)
Защита уже написана: `ui_screens.gd:3558-3561` — «на босс-файтах таймера нет,
панель не создается», guard по `game.boss_combat_active`.

НО порядок инициализации боя ломает guard:
`combat_director.gd::_start_combat`:
- строка 19: `game.ui._create_hud()` — HUD создается ЗДЕСЬ;
- строка 26: `game.boss_combat_active = is_boss_fight` — флаг ставится ПОСЛЕ.

На момент `_create_combat_timer_panel` флаг еще false (сброшен прошлым боем) →
панель таймера создается в КАЖДОМ бою, включая боссов. Внутри — замороженное
значение `round_time_left` (в босс-бою не декрементится).

## Требования
1. Починить порядок: выставлять `combat_active`/`boss_combat_active`/
   `current_combat_type` ДО `_create_hud()` (или передавать `is_boss_fight`
   параметром в `_create_hud`/`_create_combat_timer_panel`). Проверить, что
   перенос флагов не ломает `_clear_ui`/`_clear_world`/`_setup_arena_world`
   (они выполняются до — убедиться, что они не читают эти флаги по-старому).
2. В босс-бою панель таймера не создается вовсе: ни рамки, ни лейбла,
   `game.timer_label == null`; верхний центр экрана чист (бейдж возвышения
   `AscensionHudBadge` — отдельный виджет, он остается как есть).
3. `_update_combat_timer`/`_update_hud` в босс-бою не должны падать и не должны
   воскрешать панель (guard на null уже есть — ui_screens.gd:3939, проверить).
4. Тест (smoke): в босс-бою после `_start_combat(true)` в HUD НЕТ узла
   `CombatTimerPanel` и `timer_label == null`; в обычном бою `_start_combat(false)`
   панель ЕСТЬ и текст тикает. Ассертить фактическое дерево узлов, не флаги
   (урок SCRUM-144: тест должен проверять реальный рендер/дерево, не намерение).
5. РЕАЛЬНЫЙ скриншот босс-боя без таймера — в build/qa/ (если оффскрин-кадр
   не снимается — лог дерева HUD + пометка «пиксельная сверка за плейтестом»).

## Files / Assets / IDs
- scripts/combat_director.gd (_start_combat, строки 13-27)
- scripts/ui_screens.gd (_create_hud, _create_combat_timer_panel, _update_combat_timer)
- tests/ — соответствующий smoke-сьют (runtime)

## Acceptance Criteria
- [ ] В босс-бою сверху нет панели/рамки таймера, место очищено.
- [ ] В обычном бою таймер работает как раньше (тикает, alarm ≤5с).
- [ ] Тест ассертит фактическое отсутствие/присутствие узла CombatTimerPanel.
- [ ] 6 smoke-сьютов зеленые.
- [ ] CHANGELOG (Unreleased) дополнен.

## Документация
- docs/design/current_game_state.md — раздел HUD: уточнить «таймер только в
  обычных боях; в босс-бою верхний центр свободен».

## Окружение
dev; скриншот пользователя из редактора Godot, босс «Пожиратель Дисков»,
панель таймера видна справа от ULT-панели.

## Результат

Done 2026-06-12.

- В `combat_director._start_combat()` порядок инициализации исправлен: `combat_active`, `boss_combat_active` и `current_combat_type` выставляются до `game.ui._create_hud()`.
- Guard в `ui_screens.gd::_create_combat_timer_panel()` теперь видит boss-state при создании HUD, поэтому в босс-бою не создаются ни `CombatTimerPanel`, ни `timer_label`.
- `tests/runtime_smoke_test.gd` расширен проверкой фактического дерева HUD: в boss combat `CombatTimerPanel` отсутствует и не возвращается после `_update_hud()`, в normal combat `CombatTimerPanel` и `timer_label` присутствуют, а текст таймера обновляется.
- QA-log дерева HUD: `build/qa/boss_fight_timer_panel_tree_log.md`. Headless screenshot не снимался; пиксельная сверка верхнего центра остается за плейтестом/QA.

Проверка:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Результат: passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED

- Код: в `combat_director._start_combat` флаги `combat_active`/`boss_combat_active`/
  `current_combat_type` выставляются ДО `game.ui._create_hud()`; guard
  `_create_combat_timer_panel` (ui_screens.gd:3703 `if boss_combat_active: return`)
  теперь видит boss-state.
- РЕАЛЬНЫЙ рендер босс-боя (Rift Warden, 1454×908→1600×900): `CombatTimerPanel`
  ОТСУТСТВУЕТ (`find_child=null`), верх-центр чистый, баннер босса на месте. Скрин:
  `build/qa/boss_timer_clean/`.
- Тест: в boss combat нет CombatTimerPanel и не возвращается после _update_hud; в
  normal combat таймер есть и тикает. runtime_smoke зелёный. Багов нет.
