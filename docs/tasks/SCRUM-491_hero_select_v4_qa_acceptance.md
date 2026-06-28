# SCRUM-491: Hero Select v4: финальный QA-прогон и приёмка против брифа

Jira: SCRUM-491 · Роль: qa · Контур: integration · Приоритет: P1 · foma · Эпик: SCRUM-470
Статус: done

## Что и зачем

Экран выбора героя v4 (`_build_character_select_v4`) уже реализован в коде по брифу SCRUM-470:
заголовок, кнопка «Назад», крупный портрет слева, центральное досье (имя / описание / 5 строк
статов / контролы возвышения ± / строка модификаторов / кнопка «Выбрать»), роза статов
(HS4Radar) справа и прокручиваемая карусель из 9 слотов со стрелками снизу.

Тикет SCRUM-470 был закрыт **административно**, без финального QA-вердикта, привязанного к
реальному прогону. SCRUM-491 — это carry-over именно на финальную **приёмку**: подтвердить,
что экран читается 1:1 как в брифе, помещается без обрезаний/наложений на ключевых
разрешениях (1280x720 и 1600x900) и что все hero-select ассерты в трёх смоук-тестах зелёные
на Godot 4.6.3 headless.

Цель с точки зрения продукта: дать игроку рабочий, читаемый экран выбора героя на всех
поддерживаемых разрешениях. Цель этой задачи: зафиксировать **доказанный** вердикт
PASSED/FAILED (с привязкой к дампам и логам прогона), а не закрыть «на честном слове».
Это **QA-задача** — код менять НЕ нужно. На FAILED — завести bug-таски на доску, не чинить здесь.

## Текущее состояние в коде

Экран и тесты уже существуют. Точки правды:

- `scripts/ui_screens.gd:751` — `func _build_character_select_v4()`. Строит весь экран
  процедурно поверх канонического бэкдропа `hero_select` (`_add_screen_background(root, "hero_select")`).
  Ключевые узлы по `name` (по ним и идут ассерты):
  - `HeroSelectScreen` (root, PRESET_FULL_RECT) — `ui_screens.gd:758`
  - `HS4BackButton` — `ui_screens.gd:797`, размер через `_set_action_button_size(back_button, vp.x*0.085, top_h*0.8)`, `pressed -> _show_main_menu` (`ui_screens.gd:801`)
  - `HS4Portrait` (TextureRect, слева) — `ui_screens.gd:811`
  - досье: `name_label`, `desc_label`, `stats_grid` (5 строк из `HS4_DOSSIER_STATS`), `AscensionMinusButton`/`AscensionLevelLabel`/`AscensionPlusButton`, `AscensionModsLabel`, `HS4ChooseButton` — `ui_screens.gd:828-901`
  - `HS4Radar` (HeroStatRadar) — `ui_screens.gd:905`
  - `HS4Carousel` (Control с 9 слотами `TextureButton` + стрелки `◄`/`►`) — `ui_screens.gd:914-940`, `HS4_CAROUSEL_SLOTS = 9`
  - `select_button.pressed -> _show_weapon_select` (`ui_screens.gd:1008`)
- Раскладка адаптивна: все рект-зоны считаются от `vp = root.get_viewport_rect().size`
  (фолбэк 1600x900), маржины/высоты — доли от `vp.x`/`vp.y` (`ui_screens.gd:766-786`).

Тесты приёмки (acceptance), все три — `extends SceneTree`, гоняются headless:

- `tests/runtime_smoke_test.gd`
  - hero-select smoke: `tests/runtime_smoke_test.gd:314-344` — проверяет fullscreen-root,
    бэкдроп `hero_select`, наличие `HS4Portrait`/`HS4Radar`/`HS4Carousel`/`HS4ChooseButton`.
  - `_test_hero_select_radar_no_overlap_layouts(...)` — `tests/runtime_smoke_test.gd:7103`,
    гоняет раскладку на `[Vector2i(1280,720), Vector2i(1600,900), Vector2i(2560,1440)]`
    через `_assert_hero_select_radar_layout_at_size` (`:7123`), проверяет наличие узлов
    (`HS4BackButton`/`HS4Portrait`/`AscensionLevelLabel`/`AscensionModsLabel`/`HS4ChooseButton`/`HS4Radar`/`HS4Carousel`),
    отсутствие `HeroStatRadarTitle`, бэкдроп, и пишет дамп ректов в
    `build/qa/hero_select_radar_rects.md` **и** `build/qa/scrum470_hero_select_v4/hero_select_v4_runtime_rects.md` (`:7115-7120`).
  - ascension class-switch smoke по карусели: `tests/runtime_smoke_test.gd:5694-5758`
  - carousel nav / choose smoke: `tests/runtime_smoke_test.gd:6026-6076`
  - back-button safe smoke: `tests/runtime_smoke_test.gd:6175-6189`
- `tests/runtime_smoke_ui_test.gd`
  - hero-select экран: `tests/runtime_smoke_ui_test.gd:34`
  - вызывает `_test_hero_select_radar_no_overlap_layouts(main_scene)` — `tests/runtime_smoke_ui_test.gd:39`
- `tests/ui_no_overlap_matrix_test.gd`
  - матрица разрешений `VIEWPORT_SIZES` включает 1152x648, **1280x720**, **1600x900**,
    1920x1080, 2560x1440, 3840x2160 (`:4-11`).
  - hero_select-кейс: `:59-61` через `_open_hero_select` (`:253`, зовёт `_show_character_select`),
    контролы `HS4Portrait`/`HS4Radar`/`HS4Carousel`/`HS4ChooseButton`.
  - `_check_screen` (`:168`) проверяет: ≥2 видимых контрола, fit во вьюпорт (`:197`),
    отсутствие peer-overlap через `_first_peer_overlap(controls, 2.0)` (`:198-200`),
    text-overflow (`TEXT_OVERFLOW_TOLERANCE = 6.0`), parent containment, exact-frame stretch.
  - пишет hero-select секцию в `build/qa/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md` (`:148-152`).

Существующие (предыдущие) дампы лежат в `build/qa/scrum470_hero_select_v4/` —
`hero_select_v4_no_overlap_matrix.md` и `hero_select_v4_runtime_rects.md`. Их нужно перегенерить
свежим прогоном и сверить.

Godot для headless: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot` (версия 4.6.3,
см. AGENTS.md:160-161).

## Что сделать — по шагам

1. **Сетап.** Убедиться, что нет незакоммиченных правок в `scripts/ui_screens.gd` и в трёх
   тест-файлах (QA проверяет реальное состояние ветки `dev`). Зафиксировать commit SHA, на
   котором гоняется приёмка, — он войдёт в вердикт.
2. **Прогнать три теста headless** на Godot 4.6.3 (каждый — отдельным запуском, сохранить
   полный stdout/stderr в лог):
   - `…/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_test.gd`
   - `…/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_ui_test.gd`
   - `…/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/ui_no_overlap_matrix_test.gd`
   Зелёный = нет `push_error`/`_fail`, тест печатает свой success-маркер (например
   `UI no-overlap matrix test passed.`) и выходит с кодом 0. Любой `Expected …`/`escapes
   viewport`/`overlap` в логе = FAILED.
3. **Сверить hero-select ассерты по именам узлов** во всех трёх тестах: `HS4Portrait`,
   `HS4Radar`, `HS4Carousel`, `HS4ChooseButton`, `HS4BackButton` должны находиться и проходить
   на каждом разрешении из соответствующих матриц (1280x720 и 1600x900 — обязательны).
4. **Проверить дампы ректов** после прогона:
   - `build/qa/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md` — для секций
     `hero_select (1280, 720)` и `hero_select (1600, 900)` подтвердить, что все 4 контрола в
     пределах вьюпорта, нет пересечений, `text controls checked` > 0 и без overflow.
   - `build/qa/scrum470_hero_select_v4/hero_select_v4_runtime_rects.md` — сверить
     `HeroSelectScreen`/`HS4*`/`Ascension*` ректы на 1280x720 и 1600x900: ничего не выходит
     за `[0,0 .. W,H]`, портрет/досье/роза/карусель не накладываются друг на друга.
   - Отдельно проверить `HS4BackButton`: в текущем дампе на 1280x720 его rect = `[P:(28,26), S:(108.8, 179.0)]`,
     т.е. высота 179 (low-margin/min-size раздувает кнопку) — убедиться, что **низ кнопки
     (26+179=205) не перекрывает портрет** (`HS4Portrait` P.y=104) и заголовок. Если перекрытие
     есть на 1280x720 или 1600x900 — это FAILED-находка для bug-таски (визуальное наложение,
     даже если peer-overlap-чек тестов его не ловит, т.к. back-button не в наборе контролов
     hero_select-матрицы).
5. **Подтвердить помещаемость 1:1** на 1280x720 и 1600x900: заголовок, портрет, все 5 строк
   статов, контролы возвышения, строка модов (`AscensionModsLabel`, max_lines=2), «Выбрать»,
   роза и 9 слотов карусели читаются и не обрезаются (`TEXT_OVERFLOW_TOLERANCE = 6.0` —
   допуск, но фактических overflow быть не должно).
6. **Зафиксировать вердикт PASSED/FAILED** с привязкой к реальному прогону (commit SHA + пути
   к дампам + хвост лога), по конвенции `docs/process/qa_protocol.md` (PASSED → задача в
   «Готово»; FAILED → завести bug-таски и вернуть в работу). Не закрывать административно.
7. **Синхронизировать Jira**: после вердикта прогнать `python3 tools/jira_board_sync.py`
   (PASSED → «Готово»), см. память «QA closes Jira on verdict». Статус держать синхронным
   и в `.md`, и в Jira.

## Acceptance Criteria

- [ ] `tests/runtime_smoke_test.gd` зелёный headless на Godot 4.6.3 (exit 0, без `_fail`/`push_error`).
- [ ] `tests/runtime_smoke_ui_test.gd` зелёный headless на Godot 4.6.3.
- [ ] `tests/ui_no_overlap_matrix_test.gd` зелёный headless, печатает `UI no-overlap matrix test passed.`
- [ ] Hero-select ассерты (`HS4Portrait`/`HS4Radar`/`HS4Carousel`/`HS4ChooseButton`/`HS4BackButton`)
      проходят на всех разрешениях из матриц, включая обязательные 1280x720 и 1600x900.
- [ ] По дампам `hero_select_v4_runtime_rects.md` и `hero_select_v4_no_overlap_matrix.md`
      подтверждено отсутствие обрезаний/переполнений и наложений на 1280x720 и 1600x900.
- [ ] Отдельно проверено, что `HS4BackButton` не перекрывает заголовок/портрет на 1280x720 и 1600x900.
- [ ] Зафиксирован QA-вердикт PASSED/FAILED с привязкой к реальному прогону (commit SHA + пути
      к дампам + хвост лога), а не административный.
- [ ] При FAILED — заведены bug-таски на доску (с метками, эпик SCRUM-470, foma) на каждую находку.
- [ ] Jira синхронизирована (`tools/jira_board_sync.py`): PASSED → «Готово».

## Files / точки входа

- `tests/runtime_smoke_test.gd:314` — hero-select smoke (узлы/бэкдроп); `:7103`/`:7123` —
  `_test_hero_select_radar_no_overlap_layouts` / `_assert_hero_select_radar_layout_at_size`
  (дамп ректов 1280x720 / 1600x900 / 2560x1440). Прогнать, сверить дамп.
- `tests/runtime_smoke_ui_test.gd:34`/`:39` — hero-select экран + вызов layout-теста. Прогнать.
- `tests/ui_no_overlap_matrix_test.gd:59`/`:253`/`:168` — hero_select в матрице разрешений,
  `_open_hero_select`, `_check_screen`. Прогнать, сверить секцию matrix-дампа.
- `scripts/ui_screens.gd:751` — `_build_character_select_v4` (только ЧИТАТЬ для понимания
  раскладки; в этой задаче НЕ менять).
- `build/qa/scrum470_hero_select_v4/hero_select_v4_runtime_rects.md` — дамп ректов (перегенерится прогоном).
- `build/qa/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md` — дамп матрицы (перегенерится прогоном).
- `docs/process/qa_protocol.md` — формат вердикта PASSED/FAILED и поток QA.

## Замечания / подводные камни

- **Это QA-приёмка, код не трогаем.** `scripts/ui_screens.gd` — locked path (anti-collision,
  его правит Claude-контур). При FAILED фиксы в `ui_screens.gd` идут отдельными bug-тасками,
  не в этой задаче. `scripts/progression_data.gd` — тоже locked, его не касаемся (карусель
  только читает `PROGRESSION_DATA.character_ids()` / `character_config` / `base_stats`).
- **Прогонять ровно на Godot 4.6.3** (`~/Downloads/Godot.app`), как требует acceptance брифа.
  Другая версия движка делает вердикт непривязанным к реальности.
- **Изоляция мета-сейва.** Тесты могут читать реальный dev мета-сейв (unlocks/ascension max),
  что меняет видимый ростер/значения возвышения и даёт ложные red'ы. Если падает что-то,
  завязанное на разблокировки/возвышение, — не эскалировать в critical, перепроверить с
  нейтрализованным мета (см. память «Godot --user-data-dir не изолирует сейв»).
- **HS4BackButton height inflation.** В текущем runtime-дампе высота back-кнопки (179 при
  1280x720) сильно больше конфигурируемой `top_h*0.8` (~49) из-за `custom_minimum_size` +
  стиль-марджинов в `_set_action_button_size` (`ui_screens.gd:6712`). Тесты hero-select-матрицы
  back-кнопку в peer-overlap не проверяют (её нет в наборе контролов), поэтому визуальное
  наложение на портрет/заголовок надо проверить **глазами по дампу** и при наличии — оформить
  bug-таску. Это самый вероятный кандидат на FAILED.
- **Помещаемость на низком разрешении.** 1280x720 — самый тесный кейс: 9 слотов карусели +
  5 строк статов + строка модов в 2 строки. Следить за overflow в `AscensionModsLabel` и
  читаемостью имён статов.
- **Live-sync mandate.** Держать статус синхронным (.md + Jira) на каждом шаге; после вердикта
  обязателен `tools/jira_board_sync.py`. Не закрывать административно — именно за это
  SCRUM-470 и переоткрыли.
- **Связанные тикеты/контекст:** эпик SCRUM-470 (Hero Select v4), предыдущие итерации
  hero_select v2 (SCRUM-436) и v3 (SCRUM-446) — их QA-артефакты в `build/qa/scrum436_*`,
  `build/qa/scrum446_*` как референс формата.

## QA-Вердикт (2026-06-28 rerun)
Статус: PASSED

Проверено:
- Commit: `84e66c9597f7a6a1fe9c11befb5e10e25119707b` (`dev`, `git pull --ff-only` -> `Already up to date`).
- Godot: `C:\Users\FomaE\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`, версия `4.7.stable.official.5b4e0cb0f`; Godot 4.6.3 на Windows worker недоступен.
- `tests/runtime_smoke_test.gd`: PASSED, exit 0. Лог: `build/qa/SCRUM-491-rerun/runtime_smoke_test.log`, success marker `Runtime smoke test passed.`
- `tests/runtime_smoke_ui_test.gd`: PASSED, exit 0. Лог: `build/qa/SCRUM-491-rerun/runtime_smoke_ui_test.log`, success marker `Runtime UI smoke suite passed.`
- `tests/ui_no_overlap_matrix_test.gd`: PASSED, exit 0. Лог: `build/qa/SCRUM-491-rerun/ui_no_overlap_matrix_test.log`, success marker `UI no-overlap matrix test passed.`

Hero Select evidence:
- `build/qa/scrum470_hero_select_v4/hero_select_v4_runtime_rects.md`: 1280x720 `HS4BackButton` = `[P: (28.0, 29.0), S: (132.0, 44.0)]`, portrait starts at `y=104`; 1600x900 `HS4BackButton` = `[P: (35.0, 37.0), S: (136.0, 54.0)]`, portrait starts at `y=131`. Back button no longer overlaps portrait/title zones.
- `build/qa/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md`: hero_select sections for 1152x648, 1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160 are present; `text controls checked: 22`; no reported hero_select overlap/overflow.

Jira:
- Verified fixed and moved to `Готово`: SCRUM-548, SCRUM-549, SCRUM-550.
- SCRUM-491 moved to `Готово` with QA PASSED comment.
