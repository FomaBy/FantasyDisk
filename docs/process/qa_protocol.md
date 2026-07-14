# QA-Протокол FantasyDisk

Введен: 2026-06-12 (решение пользователя). Исполнители: чат «QA testing chat»
и фоновый воркер `fantasydisk-qa-board-worker`.
Обновлено: 2026-07-13 — Multica-first: dispatcher назначает QA отдельную child
issue в проекте FantasyDisk для parent `FAN-*` в статусе `in_review`; QA не
self-select'ит parent. Локальные `docs/tasks/*.md` — spec/evidence mirror.

## Правило «UI не наползает» (пользователь, 2026-06-12, ОБЯЗАТЕЛЬНО)

Элементы интерфейса не должны наползать друг на друга ни на одном
поддерживаемом разрешении (1152x648 / 1280x720 / 1469x908 / 2560x1440 /
широкие-низкие окна). Для КАЖДОЙ задачи, затрагивающей UI/HUD/экраны, QA
обязан проверить отсутствие пересечений ФАКТИЧЕСКИХ `global_rect` видимых
плашек (скриншот или дамп rect'ов; есть переиспользуемый no-overlap хелпер из
bug_hud_elements_overlap_task — использовать его). Пересечение = FAILED +
bug-задача, даже если все остальные критерии прошли.

## Правило «Контент только в пустой зоне фрейма» (пользователь, 2026-06-14, ОБЯЗАТЕЛЬНО)

Никакие элементы интерфейса — кнопки, портреты/герои, области выбора (карусели,
списки, слоты), иконки, текст — НЕ должны накладываться на текстуру/окантовку/
орнамент рамки (frame). Контент размещается ТОЛЬКО в пустой зоне фрейма: либо в
прозрачной/тёмной внутренней области, либо на подложке фона. Декоративная рамка
остаётся полностью видимой и не перекрытой контентом.

Техническое следствие: у текстурных стилей (StyleBoxTexture / 9-slice)
**content margins ≥ texture margins (толщины окантовки) + запас** — контент не
залезает под орнамент. Для радиальных/нестандартных рамок (роза ветров и т.п.)
content-зона = реальная внутренняя пустая область, а не bounding box.

QA для КАЖДОЙ задачи с рамками/панелями проверяет: контент в пределах content-зоны,
рамка не перекрыта (скриншот). Наложение контента на орнамент рамки = FAILED +
bug-задача, даже если no-overlap между плашками прошёл.

## Правило
КАЖДАЯ задача после завершения исполнителем (статус `in_review`) проходит
обязательное QA-тестирование — максимально точное и детальное. Задача считается
полностью закрытой (`done`) только после QA-Вердикта PASSED и блока
«## QA-Вердикт» в её файле.

## Цикл задачи (обновленный)
```text
parent: todo → in_progress → in_review ───────────────→ done (QA PASS)
QA child: backlog(reserved) → todo → in_progress → done + verdict
                                                ↘ RED: parent stays in_review + linked bug
```
Исполнители НИЧЕГО не меняют в своем процессе: ставят issue в `in_review` по
завершении. Единственный dispatcher находит parent без verdict, создаёт отдельную
QA child issue, резервирует exact QA agent UUID и enqueue'ит её. QA worker не
self-select'ит implementation parent и не меняет его owner.

## Как QA получает задачу
1. Dispatcher сканирует Multica parent issues `FAN-*` в `in_review`, проверяет
   отсутствие существующей QA child/verdict и создаёт child с parent ID, exact
   candidate SHA и acceptance/evidence links.
2. Child создаётся в `backlog` с exact QA `assignee_id`, затем dispatcher
   перепроверяет ownership/comment locks и переводит child в `todo`.
3. QA worker принимает только назначенную child, повторно читает parent/child и
   recent comments, ставит child `in_progress` и пишет start comment через
   `--content-file`. Одна child за прогон.

## Как тестировать (минимальный обязательный объем)
1. **По Acceptance Criteria задачи** — каждый пункт проверяется фактически,
   а не «по отчету исполнителя»: прогнать команды, открыть экраны, замерить.
2. **Целевые тесты задачи** — прогнать все упомянутые тесты headless; убедиться,
   что тест реально проверяет заявленное (заглянуть в код теста), а не пустышка.
3. **Регрессия**: `python3 tools/quality_gate.py --profile changed` для task diff;
   `--profile full` перед release. Runner обнаруживает direct и inherited suites,
   изолирует user-data и вызывает Godot только через semaphore. Ручной
   focused-запуск не заменяет certifying profile.
4. **Краевые случаи** — минимум 3 на задачу: граничные значения, повторные
   входы/выходы, пауза посреди эффекта, разрешение 1280x720, смерть/победа
   в момент действия механики.
5. **Визуальные задачи**: оконный запуск, скриншоты до сохранять в
   `build/qa/<task>/`, смотреть глазами (артефакты, перекрытия, читаемость).
6. **Производительность**, если задача массовая (волны/VFX): детерминированный
   сценарий на целевом cap (или 100+, если это AC задачи) с проверяемым бюджетом:
   число group snapshots/candidate visits, cap активных узлов и отсутствие
   per-frame allocations. Формулировка «без заметных просадок» без счётчика или
   профиля не является достаточным evidence. Для enemy separation обязательный
   минимум — `tests/runtime_hotpath_cache_test.gd`: 48 enemies, один общий group
   snapshot в кадре, не более четырёх cached neighbors на enemy.

## Windowed lifecycle gate (SCRUM-1031)

Оконный focused test считается чистым только если он завершился не только с
exit `0`, но и без `ObjectDB instances were leaked` / `resources still in use at
exit`. При таком diagnostic QA повторяет запуск с `--verbose` и фиксирует точные
типы объектов/ресурсов; скрывать warning или фильтровать stderr запрещено.

Owned `SubViewport`/`Main` fixtures освобождаются child-first с ожидаемым
frame-barrier и проверкой `WeakRef`. Если fixture запускает музыку глобального
`AudioManager`, перед `SceneTree.quit()` тест вызывает публичный `stop_music()`
и даёт audio thread несколько кадров снять Ogg playback handles: autoload
`_exit_tree()` может выполняться слишком поздно относительно windowed
`AudioServer` shutdown. Headless и production audio behavior этим test-only
teardown не меняются.

SCRUM-1045 добавляет общий helper `tools/qa_capture_teardown.gd` для windowed
capture tools. Fixture отключает новые SubViewport updates, освобождает owned
children, ждёт 3 process frames и проверяет их `WeakRef`, затем освобождает сам
viewport, ждёт ещё 4 frames и проверяет его `WeakRef`. После всей матрицы helper
вызывает `AudioManager.stop_music()` и ждёт 8 frames до quit. Capture обязан
сделать любую ошибку этих ownership-barriers реальным exit `1`; сам helper не
глушит stderr и не меняет production `AudioManager`/UI.

## Main-dependency gate фокусных Main-тестов (FAN-1087)

`tests/main_compile_guard.gd` — общий RefCounted-хелпер для тестов, которые
preload'ят `res://scenes/Main.tscn` (`lore_screens_test`,
`codex_unread_victory_test`, `codex_scrum954_layout_test`,
`ui_no_overlap_matrix_test`). В начале `_initialize()` он проверяет, что
`main.gd` и `ui_screens.gd` компилируются (`can_instantiate()`) и что инстанс
Main получает script и `ui`/`route`/`combat`; любой провал — немедленный
`quit(1)`. Причина: PackedScene загружается даже с некомпилирующимися
скриптами, и без гейта тест продолжал работу на «пустом» Main, глотал
runtime-ошибки и печатал success с exit 0 (false-green FAN-1087). Новые
фокусные тесты, инстанцирующие Main, обязаны вызывать этот гейт первым шагом.

## Мета 4.1 Keystone Behavioral Gate (SCRUM-837)

Для задач Меты 4.1, которые меняют keystone-эффекты, QA обязан прогнать
`tests/meta_keystone_behavioral_smoke_test.gd` через `python3 tools/godot_gate.py`
и проверить лог на отсутствие `SCRIPT ERROR`. Этот тест должен проверять
фактические боевые исходы в headless SceneTree mini-arena, а не только словари
модификаторов. Допускается максимум 2 повторных прогона при флаке; тяжёлые
сценарии запускаются одним инстансом через Godot gate.

## Геймпад-чеклист (SCRUM-815, ОБЯЗАТЕЛЬНО для задач, трогающих UI/ввод)
Пользователь требует полной проходимости игры с геймпада. Любая задача, которая
добавляет/меняет экран, попап или ввод, проходит этот чеклист на приёмке:
1. **Гейт**: `tests/gamepad_full_flow_smoke_test.gd` зелёный headless (2–3 прогона
   подряд, флаки-чек) через `tools/godot_gate.py`. Это сквозной сценарий
   «игра проходима только с геймпада» (меню → выбор героя → бой → пауза → level-up
   → смерть → настройки), навигация — синтетическими InputEventJoypadButton/Motion.
2. **Per-screen** для нового/изменённого экрана (синтетика joypad):
   - на старте есть фокус (`gui_get_focus_owner() != null`) на логичном элементе;
   - крестовина/стик двигают фокус по ВСЕМ интерактивным элементам (недостижимых нет);
   - A (`ui_accept`) активирует сфокусированное, B (`ui_cancel`) = «Назад»/закрыть;
   - вкладки/секции листаются LB/RB, если они есть;
   - мышь/клавиатура продолжают работать (гибрид не сломан).
3. **Focus-стиль** различим и НЕ жёлтый (курс «без жёлтых рамок»).
4. Профильные тесты пакета зелёные: `gamepad_menu_focus_test.gd` (мета-меню,
   SCRUM-813), `gamepad_inrun_ui_test.gd` (внутризабеговые экраны, SCRUM-812),
   `gamepad_core_input_test.gd` (ядро, SCRUM-811).
Карта управления — `docs/design/systems/input_controls.md`.

## Вердикт (дописывается в файл задачи)
Вердикт сначала фиксируется comment'ом в QA child issue, после чего завершённая
QA child переводится в `done` при любом фактическом verdict. Затем verdict
дублируется в локальный task mirror при наличии:

```md
## QA-Вердикт (<дата>)
Статус: PASSED | FAILED
Проверено: <список фактических проверок и команд>
Краевые случаи: <что прогнали>
Баги: нет | список с ссылками на bug-таски
```
При `PASSED` parent переводится в `done`. При `FAILED` parent остаётся
`in_review` с blocker, а defect получает отдельную child issue. Вернуть parent в
`todo` может только dispatcher/PM после явного решения о повторной реализации;
QA worker не меняет parent owner или execution status самостоятельно.

## Баги
На КАЖДЫЙ найденный баг — сначала отдельный Multica bug issue (проект FantasyDisk,
FAN-*), затем локальный mirror-файл `docs/tasks/bug_<short_name>_task.md` при
необходимости:
```md
# BUG: <короткое название>
Статус: new
Приоритет: critical | high | normal
Роль: Back-end | Design (по зоне бага)
Найдено QA при тестировании: <task файл>

## Воспроизведение
<точные шаги, 1-2-3>
## Ожидание / Реальность
## Окружение
<разрешение, класс, уровень возвышения, коммит>
```
+ строка на локальный dashboard `docs/process/task_board.md` (секция «Баги от QA»,
создать при первом баге) со статусом new — только как mirror; воркеры/чаты берут
чинить Multica issue (FAN-*).
Критический баг (краш, потеря сейва, софтлок) — дополнительно пометить
ПРИОРИТЕТ в начале строки доски.

## Запреты QA
- Не чинить баги самому (кроме опечаток в доках) — только фиксировать и заводить таски.
- Не перепроверять задачи с уже имеющимся QA-Вердиктом (если код не менялся).
- Не держать больше одной review issue `in_progress` за прогон.
