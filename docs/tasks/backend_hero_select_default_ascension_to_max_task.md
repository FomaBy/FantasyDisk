# UX: Выбор героя — по умолчанию выбирать последнее доступное возвышение

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-389
Связано: SCRUM-388 (очки меты за новое возвышение), SCRUM-360 (классовая прогрессия), SCRUM-346 (возвышение +/-)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
2026-06-14: Documentation dispatcher routed SCRUM-389 to existing Back-end
thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`. Keep reasoning High/no low;
work on existing `dev`; no branch switch, commits, pushes, merges, tags, new
worktrees or new threads. Linked SCRUM-388 is already marked done in its task
file; do not reimplement it unless verification shows a direct regression.

## Контекст (запрос пользователя)
«По умолчанию на классе надо выбирать последнее возможное возвышение».

Сейчас при выборе класса (ui_screens.gd `select_character` ~862-864) уровень
возвышения только КЛАМПИТСЯ к `ascension_selectable_max(character_id)`
(main.gd:610-611 = `selectable_max` = пройденное+1), но НЕ устанавливается на
максимум — остаётся прежнее/0.

## Требования
1. При выборе класса (и при первом открытии экрана выбора героя)
   `selected_ascension_level` по умолчанию = **максимально доступное возвышение
   этого класса** (`ascension_selectable_max(character_id)`), а не 0/прежнее.
2. Селектор +/- и подпись (refresh_asc) сразу отражают максимум; игрок может
   вручную понизить (−) при желании.
3. Корректно для каждого класса (per-character прогресс): у нового/непройденного
   класса max может быть 0/1 — тогда дефолт = это значение (не уходить за предел).
4. Не ломать запуск забега с выбранным уровнем, клампы (main.gd:623), сохранение.
5. Тест (smoke): при select_character уровень = selectable_max класса; смена класса
   пересчитывает дефолт; ручное понижение работает. runtime_smoke зелёный.
6. CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (select_character 862-864; refresh_asc 855-858; первичная
  инициализация экрана выбора героя)
- scripts/main.gd (selected_ascension_level 387; ascension_selectable_max 610)
- tests/runtime_smoke_test.gd, tests/meta_progression_smoke_test.gd

## Acceptance Criteria
- [x] При выборе/смене класса по умолчанию выбран максимально доступный уровень возвышения класса.
- [x] Ручное понижение −/повышение + работает; не уходит за selectable_max; забег стартует корректно.
- [x] smoke зелёные; CHANGELOG; current_game_state.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Result
2026-06-14 Back-end:
- `scripts/ui_screens.gd` теперь при выборе/первичном открытии героя ставит
  `selected_ascension_level = ascension_selectable_max(character_id)`, а
  существующие `-`/`+` продолжают вручную менять выбранный уровень в пределах
  доступного диапазона.
- `tests/runtime_smoke_test.gd` расширен smoke-проверкой max-default,
  ручного понижения и пересчета при переключении класса.
- Обновлены `CHANGELOG.md`, `docs/design/current_game_state.md` и
  `docs/design/systems/menus_ui.md`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/meta_progression_smoke_test.gd` — passed.
