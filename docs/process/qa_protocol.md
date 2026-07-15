# QA-Протокол FantasyDisk

Введен: 2026-06-12 (решение пользователя). Исполнители: чат «QA testing chat»
и фоновый воркер `fantasydisk-qa-board-worker`.
Обновлено: 2026-07-15 — Multica-first autonomous QA: QA Codex Sol является
единственным writer review-очереди, сам выбирает одну eligible parent issue
`FAN-*` в `in_review` и владеет проверкой через отдельную QA child. Локальные
`docs/tasks/*.md` — только spec/evidence mirror.

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
QA child: backlog(self-reserved) → in_progress → done + verdict
                                            ↘ RED: parent stays in_review + linked follow-ups
```
Исполнители НИЧЕГО не меняют в своем процессе: ставят issue в `in_review` по
завершении. QA Codex Sol (`f992a646-a8ea-4935-ba94-212595803052`) автономно
сканирует review-очередь, claim'ит одну проверку через отдельную QA child и не
меняет implementation owner. Общий dispatcher может разбудить QA, но не создаёт
конкурирующий QA claim.

## Как QA получает задачу
1. QA runtime работает с `max_concurrent_tasks = 1`. В начале queue-sweep QA
   проверяет свои active tasks и уже существующие QA children; при другом живом
   QA claim новый не создаётся.
2. QA сканирует все страницы Multica parent issues `FAN-*` в `in_review` и
   выбирает ровно одну ready issue: сначала higher priority, затем самый старый
   ready item. Локальная доска не является источником очереди.
3. Перед claim QA читает parent, recent comments, children, metadata и evidence,
   проверяет dependencies/blockers, exact candidate SHA в `origin/dev`, reviewer
   independence, отсутствие существующего verdict/живой QA child и отсутствие
   locked-path overlap с продолжающимся writer scope.
4. QA пишет parent `QA claim` comment через `--content-file` с QA UUID,
   run/session, candidate SHA, environment/workdir и review scope; затем создаёт
   child в `backlog` с exact QA assignee или переиспользует только inactive child
   на том же SHA.
5. QA повторно читает parent/children/comments. При race, новом SHA или уже
   появившемся verdict собственная duplicate child отменяется. Иначе QA ставит
   child прямо в `in_progress` и выполняет её в текущем run, не создавая второй
   daemon task через `todo`.
6. Одна child за прогон. Parent assignee/status остаются неизменными до verdict.

## Полная самостоятельность QA

QA отвечает за весь verification scope, а не только за повтор команд
implementation-агента:

- превращает acceptance criteria в traceable risk-based test plan;
- читает changed code, тесты и test fixtures, чтобы исключить false-green;
- самостоятельно выбирает нужные focused, regression, integration, negative,
  edge, manual/windowed, performance, platform, save/load, pause/focus/input и
  visual проверки;
- создаёт disposable QA probes/capture helpers, когда существующей проверки
  недостаточно, но удаляет их до verdict и не меняет production behavior;
- фиксирует `passed`, `failed`, `blocked`, `not tested` и `inconclusive`
  раздельно; developer report, code review или CI сами по себе не заменяют QA;
- не заканчивает run без подробного отчёта и связанных follow-up issues.

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
5. **Визуальные задачи**: оконный запуск и фактический visual review. Скриншоты
   сохранять в task-owned `build/qa/<FAN-id>/` и/или прикладывать к Multica
   verdict comment; указывать viewport/platform/timestamp. Для динамического
   поведения использовать видео/GIF или последовательность кадров, если один
   screenshot не доказывает acceptance. Проверять артефакты, перекрытия,
   content zones, читаемость, focus и responsive layout глазами и измерениями.
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

## Вердикт и отчёт
Вердикт сначала фиксируется подробным comment'ом в QA child issue, затем summary
со ссылками на evidence/follow-ups добавляется в parent. QA child переводится в
`done` при любом фактическом verdict. Локальный task mirror обновляется при
наличии:

```md
## QA-Вердикт (<дата>)
Статус: PASSED | FAILED
Verified SHA / environment: <sha, OS, Godot, build/config>
Acceptance traceability: <criterion -> check/evidence>
Автоматические проверки: <commands + results>
Manual/windowed scenarios: <steps + results>
Evidence: <Multica attachments / repo paths / logs / screenshots / video>
Findings: <passed | failed | blocked | not tested | inconclusive>
Баги/улучшения: нет | linked FAN issues
Residual risks: <явно>
Release recommendation: Go | Go with known risks | No-Go
Disk cleanup: <removed paths | none created | blocked by lock>
```
При `PASSED` parent переводится в `done`. При `FAILED` parent остаётся
`in_review`, а все defects/required improvements получают отдельные linked child
issues. Вернуть parent в `todo` может только dispatcher/PM или новый
implementation owner после явного решения; QA worker не меняет parent owner и
не становится implementation executor.

## Баги и обязательные улучшения
На КАЖДЫЙ подтверждённый баг или обязательное улучшение — сначала отдельная
linked Multica child issue исходного implementation parent (проект FantasyDisk,
FAN-*; title `BUG:` или `IMPROVEMENT:`), затем локальный mirror-файл
`docs/tasks/bug_<short_name>_task.md` при необходимости:
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
## Evidence
<attachments, screenshots/video/logs/traces, частота/число попыток>
## Severity / Priority / Recommended Role
## Acceptance Criteria
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
- Не брать implementation parent в assignee и не использовать QA child как fix task.
- Не объявлять PASS при `not tested`, `blocked` или непокрытом critical acceptance.
