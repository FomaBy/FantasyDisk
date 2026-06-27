# SCRUM-502: Экран итогов забега (run summary) при победе и смерти

Jira: SCRUM-502 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: (не задан в тикете)
Статус: К выполнению

## Что и зачем

Сейчас завершение забега (победа над финальным боссом или смерть) почти ничего не сообщает игроку: экраны `_show_victory_screen` / `_show_death_screen` показывают короткий текст и одну кнопку «Новый забег»/«Начать заново», а autosave просто очищается. У игрока нет ощущения завершённости и нет обратной связи о том, что он сделал за прогон.

Цель: добавить **экран итогов забега (run summary)**, который показывается после смерти и после победы перед возвратом в меню и выводит метрики, собранные по ходу всего прогона:

- время забега (суммарная длительность всех боёв),
- достигнутый ряд маршрута (`route_stage`),
- число убийств (kills),
- нанесённый и полученный урон (dealt / taken damage),
- собранное за забег золото,
- финальный уровень персонажа,
- набранные артефакты (список/количество),
- причина исхода: какой враг/босс убил игрока, либо какой босс повержен при победе.

Продуктовый результат: игрок видит «сводку прогона», чувствует прогресс и завершённость, и понимает, чего достиг. Это часть мета-петли вовлечения (после экрана итогов уже идёт стандартный возврат в меню / новый забег).

## Текущее состояние в коде

### Поток завершения боя
- `scripts/combat_director.gd:107` `_end_combat(victory)` — единая точка завершения любого боя.
  - При смерти игрока (`player.died` → `scripts/combat_director.gd:43-45`) вызывается `_end_combat(false)` → ветка `else` (`scripts/combat_director.gd:147-148`) → `game.ui._show_death_screen()`.
  - При победе над боссом (`was_boss_fight`) — `scripts/combat_director.gd:125-128`: `_grant_boss_completion_rewards()` → `game.record_boss_victory()` → `game.ui._show_victory_screen()`.
  - При победе в обычном/элитном бою — `scripts/combat_director.gd:129-146`: инкремент `route_stage`, баннер «Победа», докачка атрибутов, возврат на карту (НЕ конец забега, экран итогов тут не нужен).
- Игрок, завершивший забег вручную (Pause → «Завершить забег»): `scripts/ui_screens.gd:3746` `_end_current_run_by_player()` → `_show_death_screen("Забег завершен игроком.")`.

### Экраны итогов (что есть сейчас)
- `scripts/ui_screens.gd:5088` `_show_victory_screen()` — `clear_run_autosave()`, строит `_create_menu_box("Победа", subtitle, "victory")`, добавляет crest (`_add_result_crest(box, "victory")`), кнопку `VictoryNewRunButton` («Новый забег») с колбэком `finish_run` (сбрасывает `route_stage`, `run_player_snapshot`, индексы, генерирует новый маршрут, `_show_main_menu()`). `subtitle` содержит только мета-инфо (очки наследия/умений/возвышение).
- `scripts/ui_screens.gd:5123` `_show_death_screen(reason)` — `clear_run_autosave()`, `_create_menu_box("Поражение", subtitle, "death")`, crest, кнопка `DeathRetryButton` («Начать заново») с колбэком `back_to_menu`. `subtitle` = `reason` или дефолт «Забег завершён на этапе маршрута N.».
- Оба экрана используют backdrop через `screen_background_id` (`"victory"`/`"death"`) → `SCREEN_BACKGROUND_PATHS` в `scripts/main.gd:89,91` (reward_hall / defeat_crypt). Это и есть «текущий defeat/victory backdrop» из AC — менять backdrop НЕ нужно, переиспользовать.
- Панель строится `_create_menu_box` (`scripts/ui_screens.gd:6246`): это `pause_end` модалка с `ScrollContainer` (`PauseEndModalScroll_*`) — значит длинный список метрик уже скроллится и центрируется; контент кладётся в `box` (VBoxContainer). Размеры адаптивны (`_pause_end_modal_display_size`, `_pause_end_result_button_height` `scripts/ui_screens.gd:6352`).

### Что собирается СЕЙЧАС (и чего нет)
- **Золото/уровень/артефакты** — живут в снапшоте игрока. `_store_player_snapshot` (`scripts/combat_director.gd:899-912`) сохраняет `money`, `level`, `artifacts`, `xp` и т.д. в `game.run_player_snapshot`. НО снапшот пишется только при ПОБЕДЕ (`scripts/combat_director.gd:116-119`), и на момент `_show_death_screen` игрок уже `queue_free()`-нут (`scripts/player.gd:607`), а снапшот может быть от предыдущего узла. На смерти актуальные данные надо снять с игрока ДО его удаления.
- **Kills** — нигде не считаются. Враги умирают через `_on_enemy_died` (`scripts/combat_director.gd:667`), боссы — там же (`if enemy.is_in_group("bosses")`). Готовая точка для инкремента счётчика убийств.
- **Нанесённый урон (dealt)** — нигде не агрегируется. Урон врагам наносится в их `take_damage` (см. `scripts/enemy.gd`/боссы), не централизованно. Самый дешёвый источник на стороне игрока отсутствует — потребуется либо хук на `_on_enemy_died` (грубо), либо агрегатор урона (точно). См. «Что сделать».
- **Полученный урон (taken)** — игрок эмитит `damaged(amount)` (`scripts/player.gd:588`), подключён к `game.ui._on_player_damaged` (`scripts/combat_director.gd:49`, обработчик `scripts/ui_screens.gd:7855` — сейчас no-op `_on_player_damaged(_amount)`). Это естественная точка аккумуляции полученного урона. NB: сигнал отдаёт `amount` (входящий до защиты), не финальный — для «полученного урона» это приемлемо, но реши осознанно (входящий vs `final_damage`).
- **Время забега** — нет суммарного таймера. Есть только `round_time_left` (per-round, `scripts/main.gd:310,751`). Нужен аккумулятор реального времени боёв за забег.
- **Причина исхода** — нет. На смерти неизвестно, кто убил; на победе известен `current_boss_id` (`scripts/main.gd:334`).

### Сброс состояния на старте/завершении
- Новый забег фактически начинается на переходе weapon-select → карта: `scripts/ui_screens.gd:3894-3896` (`_show_weapon_select` → `game.route._show_battle_map()`), снапшот при этом пуст.
- Полный сброс run-состояния делают: `finish_run`/`back_to_menu` (внутри victory/death экранов), `_quit_current_run` (`scripts/ui_screens.gd:3727`), `_end_current_run_by_player` (`scripts/ui_screens.gd:3746`). Везде чистится `run_player_snapshot` и пр.
- Autosave (`scripts/run_autosave.gd`, состояние в `scripts/main.gd:513` `_run_autosave_state`) персиститься НЕ должен метриками сводки — на старте нового забега и при загрузке autosave метрики обязаны быть нулевыми (AC «не текут из autosave/прошлого забега»).

### Тесты и документация
- `tests/ui_no_overlap_matrix_test.gd` — `_open_victory` (`:257`) и `_open_death` (`:262`) уже гоняют эти экраны на 6 разрешениях; ассерты на узлы `PauseEndModalPanel_victory/death`, `ResultCrest`, `VictoryNewRunButton`/`DeathRetryButton` (`:62-67`). Новые узлы метрик нужно добавить в этот же matrix.
- `docs/design/current_game_state.md:37-52` — раздел «Основной Поток Игры», шаг 11 «Победа или смерть» (описание core loop, которое надо дополнить экраном итогов).

## Что сделать — по шагам

1. **Run-snapshot метрик (новый агрегатор на `game`).** В `scripts/main.gd` завести поле, напр. `var run_metrics := {}` рядом с run-полями (`scripts/main.gd:305-363`), и хелперы:
   - `reset_run_metrics()` — обнуляет `{kills, damage_dealt, damage_taken, gold_collected, time_seconds, route_stage_reached, ...}`. Вызывать на старте нового забега (см. шаг 6).
   - `record_run_kill(is_boss: bool)`, `add_run_damage_dealt(amount)`, `add_run_damage_taken(amount)`, `add_run_time(delta)` — простые аккумуляторы.
   Поле НЕ включать в `_run_autosave_state()` (`scripts/main.gd:513`) — метрики не персистятся.

2. **Время забега.** В `scripts/main.gd:_process` (`scripts/main.gd:743-766`), пока `combat_active` и не пауза, прибавлять `delta` к `run_metrics.time_seconds` (рядом с уже имеющимся декрементом `round_time_left`). Так суммируется время и обычных, и боссовых боёв.

3. **Kills.** В `scripts/combat_director.gd:_on_enemy_died` (`:667`) инкрементировать счётчик: `game.record_run_kill(enemy.is_in_group("bosses"))`. Сделать в начале функции (до раннего `return` для боссов на `:680-681`), чтобы боссы тоже учитывались.

4. **Полученный урон.** В `scripts/ui_screens.gd:_on_player_damaged` (`:7855`, сейчас no-op) добавить `game.add_run_damage_taken(_amount)` (переименуй параметр в `amount`). Реши и зафиксируй: учитываем входящий `amount` (как эмитится в `scripts/player.gd:588`).

5. **Нанесённый урон (dealt).** Выбери ОДИН подход и опиши его в коде комментарием:
   - (предпочтительно) централизованный хук: в `scripts/player.gd`/оружии при нанесении урона врагу звать `game.add_run_damage_dealt(dealt)`. Если у игрока нет прямой ссылки на `game`, прокинуть через `get_tree().root` meta или сигнал — НЕ городить лишнего, посмотреть как уже сделано для `screen_shake`/`combat_feedback` (`scripts/main.gd:458-461`).
   - (запасной, если централизованно дорого) суммировать максимум HP убитых врагов в `_on_enemy_died`. Это приближение — пометь как fallback.
   Главное: число должно правдоподобно расти за забег и не падать между узлами.

6. **Сброс на старте забега.** Вызвать `reset_run_metrics()` ровно там, где начинается новый забег: при переходе weapon-select → карта (`scripts/ui_screens.gd:3894-3896`) ИЛИ в `_show_battle_map`, когда `route_stage == 0` и снапшот пуст. Также вызвать при `_quit_current_run`/`finish_run`/`back_to_menu`, чтобы метрики не утекли. Проверить, что загрузка autosave (`load_run_autosave`, `scripts/main.gd:501`) НЕ восстанавливает метрики (они остаются нулевыми/текущими, не из файла).

7. **Снятие финальных данных игрока на смерти.** В `scripts/combat_director.gd:_end_combat` для ветки `victory == false`: ДО `game._clear_world()` (`:120`) снять с `game.current_player` (если жив на этот тик) `level`, `money`, `artifacts` в `run_metrics` либо переиспользовать `_store_player_snapshot`. Учесть, что на смерти `player.died` эмитится прямо в `take_damage` перед `queue_free` (`scripts/player.gd:602-607`) — внутри обработчика `_end_combat(false)` инстанс ещё валиден ровно в этот кадр; снять данные надёжнее через `run_player_snapshot`, обновляя его и на смерти. На победе данные брать из `run_player_snapshot` (уже сохранён) + `current_boss_id`.

8. **Причина исхода.**
   - Смерть: в `scripts/combat_director.gd:_on_enemy_died`/в момент `player.died` зафиксировать «последнего обидчика» — проще всего хранить `run_metrics.last_damage_source`, обновляя его в `_on_player_damaged` по типу врага, либо отдать обобщённую причину («Пал в бою на этапе N» / имя босса, если `boss_combat_active`). На боссе при смерти — имя текущего босса из `current_boss_id`/`MAP_NODE_DEFINITIONS`.
   - Победа: «Повержен <имя финального босса>» через `current_boss_id`.
   Не переусложнять: если точный убийца недоступен дёшево — давать категорию (босс/враг) + этап.

9. **Рендер метрик на экранах итогов.** В `scripts/ui_screens.gd`:
   - Добавить хелпер `_add_run_summary_rows(box, is_victory)` — формирует строки метрик (Label или HBox «название — значение») и добавляет в `box` ПОСЛЕ subtitle, ДО кнопки. Каждой строке/контейнеру дать стабильное `name` (напр. `RunSummaryStat_kills`, `RunSummaryStat_time`, `RunSummaryArtifacts`, `RunSummaryOutcome`) — чтобы тест мог их найти.
   - Форматирование: время как `MM:SS`; золото/урон/убийства целыми; артефакты — количество + (опц.) список названий; финальный уровень; достигнутый ряд маршрута. Русские подписи в стиле существующего UI (см. `_modifier_summary_text`).
   - Вызвать `_add_run_summary_rows(box, true)` в `_show_victory_screen` (`:5104` после `_add_result_crest`) и `_add_run_summary_rows(box, false)` в `_show_death_screen` (`:5129`).
   - Учесть скролл: контент уже в `PauseEndModalScroll_*`, длинный список скроллится. Проверить, что строки не вылезают за панель на 1280x720 (мин. высота) — `autowrap`/мелкий шрифт как у subtitle.
   - `mouse_filter` строк = IGNORE, чтобы не перехватывать клики кнопки/escape (`game.ui_escape_action`).

10. **Тест matrix.** В `tests/ui_no_overlap_matrix_test.gd` дополнить ассерты `_open_victory`/`_open_death` (`:62-67`) новыми именами узлов метрик (минимум 2-3 ключевых: `RunSummaryStat_kills`, `RunSummaryOutcome`). В `_open_victory`/`_open_death` (`:257-263`) при необходимости заполнить `run_metrics` тестовыми значениями (через `main.set("run_metrics", {...})` или вызовы аккумуляторов), чтобы строки были непустыми на всех 6 разрешениях.

11. **Документация.** В `docs/design/current_game_state.md` обновить шаг 11 core loop (`:51`) и/или раздел про defeat/victory (`:1008-1019`): описать экран итогов и какие метрики показывает, где собираются.

## Acceptance Criteria

- [ ] Введён сбор run-метрик в течение забега: kills, нанесённый и полученный урон, собранное золото, время, достигнутый `route_stage`, финальный уровень, список/число артефактов.
- [ ] Экран итогов показывается после смерти (включая ручное «Завершить забег») и после победы над финальным боссом, перед возвратом в меню, и выводит все метрики выше + причину исхода (имя/категория босса или врага).
- [ ] Экран центрируется и читается на 1280x720, 1600x900 и 2560x1440; переиспользует текущие victory/death backdrop (`screen_background_id` `"victory"`/`"death"`); строки метрик не перехватывают клики кнопок и Escape.
- [ ] Метрики сбрасываются при старте нового забега (weapon-select → карта / новый прогон) и не текут из autosave или прошлого забега (поле метрик не входит в `_run_autosave_state`, после `load_run_autosave` метрики не из файла).
- [ ] `tests/ui_no_overlap_matrix_test.gd` (`_open_victory`/`_open_death`) проходит с новыми узлами метрик на всех 6 разрешениях; полный runtime smoke (death + victory ветки) зелёный.
- [ ] `docs/design/current_game_state.md` описывает экран итогов в core loop.
- [ ] Победная ветка обычного/элитного боя (НЕ финальный босс) не показывает экран итогов и работает как раньше (баннер → докачка → карта).

## Files / точки входа

- `scripts/main.gd` — добавить `run_metrics` + хелперы (`reset_run_metrics`/`record_run_kill`/`add_run_damage_dealt`/`add_run_damage_taken`/`add_run_time`); аккумуляция времени в `_process` (`:743-766`); НЕ добавлять метрики в `_run_autosave_state` (`:513`); вызвать reset на старте/сбросе забега.
- `scripts/combat_director.gd` — `_on_enemy_died` (`:667`) инкремент kills; `_end_combat` (`:107`) снятие финальных данных игрока на смерти до `_clear_world`; зафиксировать причину исхода.
- `scripts/ui_screens.gd` — `_on_player_damaged` (`:7855`) аккумулировать taken damage; `_show_victory_screen` (`:5088`)/`_show_death_screen` (`:5123`) рендер метрик через новый `_add_run_summary_rows`; вызвать reset на переходе weapon-select→карта (`:3894-3896`) и в `_quit_current_run`/`_end_current_run_by_player` (`:3727`,`:3746`).
- `scripts/player.gd` — (если выбран централизованный dealt-damage) хук `add_run_damage_dealt` при нанесении урона врагу; источник `damaged` сигнала (`:588`) — основа taken damage.
- `tests/ui_no_overlap_matrix_test.gd` — расширить ассерты и `_open_victory`/`_open_death` (`:62-67`, `:257-263`).
- `docs/design/current_game_state.md` — core loop шаг 11 (`:51`) и/или defeat/victory раздел (`:1008-1019`).

## Замечания / подводные камни

- **ANTI-COLLISION / locked paths.** `scripts/ui_screens.gd` — горячий, многократно конфликтный файл (см. memory: lane-изоляция «ui_screens.gd за Claude»). Этот тикет помечен `lane: claude` — допустимо. `scripts/progression_data.gd` тоже locked — его трогать НЕ требуется, не лезть туда. Перед коммитом коммитить ЯВНЫМ `git add` своих файлов (не `git add -A`), т.к. при churn чужие хунки втягиваются (memory: commit-explicit-add-during-churn). После коммита проверить HEAD в worktree (2-3 прогона теста), т.к. бывает что тест-ассерт коммитится без фикса.
- **Смерть и `queue_free` игрока.** На смерти `died.emit()` → `_end_combat(false)` идёт синхронно ещё до `queue_free()` (`scripts/player.gd:602-607`), но полагаться на это хрупко. Надёжнее держать актуальный снапшот игрока (level/money/artifacts) обновлённым на момент урона/смерти, а не читать инстанс в `_end_combat`. Проверить headless: на смерти `run_player_snapshot` может быть от предыдущего узла — нужны именно текущие значения.
- **Время и пауза.** Время забега не должно тикать в паузе (`get_tree().paused`) и вне боя — `_process` уже выходит на паузе (`scripts/main.gd:744`) и при `not combat_active` (`:747`), аккумулировать строго после этих гардов.
- **Урон dealt — не завышать.** Если возьмёшь fallback «HP убитых», крит/оверкилл/DoT исказят сумму — пометь как приближение и не выводи как «точный нанесённый урон», либо подпиши нейтрально («урон по врагам»).
- **Autosave-протечка — главный риск AC.** Дважды проверь: новый забег после «Продолжить» (load autosave) показывает метрики С НУЛЯ за новый прогон, а не из прошлого. `load_run_autosave` (`scripts/main.gd:501`) не должен поднимать метрики; reset вызывается на фактическом старте боевой части.
- **Скролл/overlap.** `_create_menu_box` для `victory/death` — `pause_end` модалка со скроллом; длинный список метрик безопасен по высоте, но на 1280x720 шрифт/wrap проверить (matrix-тест и есть гейт overlap). Новые Label-строки = `MOUSE_FILTER_IGNORE`, иначе перехватят клик кнопки.
- **Локализация.** UI на русском — подписи метрик по-русски, в стиле `_modifier_summary_text`/существующих subtitle.
- **Не трогать** победную ветку обычного/элитного боя (`scripts/combat_director.gd:129-146`) — там экран итогов не нужен; только финальный босс и смерть.
- Связанные системы: result crests (`_add_result_crest`, SCRUM-330), pause-end модалки (общий стиль), мета-награды на победе (`record_boss_victory`) — экран итогов добавляется НАД ними, не ломая существующий мета-текст subtitle.
