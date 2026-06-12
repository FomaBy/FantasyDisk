# TASK: Level-up — убрать дубль точек возврата (FAB ⬆ + нижняя кнопка одновременно)

Статус: done
Приоритет: low
Роль: Back-end
Создано: 2026-06-12 (QA-агент, при ревью `backend_levelup_rework_five_options_task.md`)
Jira: SCRUM-123

Dispatch: отправлено в существующий Back-end чат `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-12.

## Контекст
Фича level-up rework принята QA (PASSED) — логика/редкость/отложенный выбор/тесты ок.
НО требование #3 исходной задачи гласило: «Существующую FAB-стрелку прокачки
согласовать с этой кнопкой (**не дублировать**: FAB и есть точка возврата —
переоформить и закрепить внизу)».

По факту при `pending_level_ups > 0` существуют ДВЕ точки входа в окно level-up
одновременно:
- `UpgradeFabButton` ⬆ с бейджем (top-right) — `ui_screens.gd:780-807`, при
  pending>0 открывает level-up (`:799-803`);
- `level_up_button` «Повышение уровня (N)» (низ по центру) — `_update_level_up_button`
  (`ui_screens.gd:2521+`).

Обе ведут в одно и то же окно с тем же `level_up_offer`. Функционально не сломано,
но это ровно та дубликация, которую спека просила убрать.

Нюанс: FAB — двухрежимный (level-up при pending, иначе докачка атрибутов за золото),
поэтому просто удалить его нельзя — нужно развести роли.

## Что сделать (направление)
Согласовать две кнопки в одну точку возврата к level-up:
- вариант A: при `pending_level_ups > 0` прятать/дизейблить level-up-режим FAB
  (оставить FAB только под атрибут-шоп), нижняя кнопка — единственный вход в level-up;
- вариант B: убрать отдельный `level_up_button`, а FAB переоформить и закрепить внизу
  как просила спека (с учётом его второго режима).
Сохранить: бейдж со счётчиком pending, отложенный выбор, фиксацию набора.

## Acceptance
- [ ] При pending>0 видна ровно ОДНА кнопка-вход в level-up.
- [ ] Докачка атрибутов за золото по-прежнему доступна (второй режим не потерян).
- [ ] runtime smoke зелёный.

## Окружение
Godot 4.6.3.stable. Фича закоммичена в `dev`.

## Result Summary — 2026-06-12

- Выбран вариант A: при `pending_level_ups > 0` `UpgradeFabButton` не создается, единственная точка входа в level-up — нижняя кнопка `LevelUpPlusButton`.
- Pending-счетчик сохранен как бейдж `LevelUpPlusBadge` на нижней кнопке.
- При `pending_level_ups == 0` FAB остается доступен для докачки атрибутов за золото.
- Runtime smoke обновлен проверкой отсутствия FAB при pending, наличия нижней кнопки с бейджем и восстановления FAB при pending=0.
- Документация обновлена: `docs/design/current_game_state.md`, `docs/design/mechanics_extract.md`, `CHANGELOG.md`.
- Verification: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-12)
Статус: PASSED (закрыта PM при релизной зачистке)
UI-дедупликация FAB: покрыта runtime smoke (level-up флоу), все сьюты зелёные при релиз-гейте.
