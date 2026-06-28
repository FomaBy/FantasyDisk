# SCRUM-486: Блок Меню/Навигация — интеграция ассетов @2K + верификация

Jira: SCRUM-486 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-481 (UI Overhaul 2K)
Статус: На QA (re-verified 2026-06-28 claude-backend-3 против origin/dev bef946b8 — verifier `tests/ui_no_overlap_matrix_test.gd` зелёный 1080p/2K/4K + оба смоука зелёные). Интеграция @2K блока Меню/Навигация доставлена в dev пер-экранными тикетами SCRUM-579/580/581 (+SCRUM-560 для кнопок главного меню), которые суперсед-нули потерянный бандл-коммит 011a0005 (остался dangling, не дошёл до dev из-за churn воркеров; повторно НЕ применять — он откатывал бы более новую работу).

## Что и зачем

Эпик SCRUM-481 переводит весь интерфейс на дизайн-базу 2K (2560×1440, stretch=canvas_items/keep): 1080p ужимает, 4K растягивает, иное соотношение — чёрные полосы. Конвейер блока: **координаты-константы → рисующий скрипт → ассеты точного размера → интеграция (этот тикет) → верификатор**.

Цель этой задачи — **подключить сгенерированные @2K-ассеты** (фреймы панелей, кнопки, фоны) к рантайм-билдерам блока **Меню/Навигация** (8 экранов) так, чтобы каждый ассет рендерился в свой точный пиксельный размер из координатной спеки SCRUM-484, без растяжения орнамента, и **прогнать рендер-верификатор SCRUM-483** зелёным на трёх разрешениях (1920×1080, 2560×1440, 3840×2160).

Зачем игроку: на 2K/4K мониторах меню и модалки должны выглядеть резко и сбалансированно (рамки не мылятся, орнамент не тянется), кнопки и текст не вылазят за рамку и не наслаиваются на любом из поддерживаемых разрешений. Это первый «контентный» блок эпика — он задаёт паттерн интеграции для остальных блоков (SCRUM-487 и далее).

Ожидаемый результат: все 8 экранов блока на новых 2K-ассетах; `tests/ui_no_overlap_matrix_test.gd` (гейт SCRUM-483) проходит без ошибок; матрица в `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md` обновлена и показывает корректные bbox на 1080p/2K/4K.

## Текущее состояние в коде

### Координаты (SCRUM-484 — ГОТОВО)
Именованные const уже лежат рядом с билдерами в `scripts/ui_screens.gd`:
- Главное меню — `MM_*` (ui_screens.gd:296–307), билдер `_show_main_menu` (ui_screens.gd:310).
- Подтверждение выхода — `QC_*` (ui_screens.gd:446–452), билдер `_show_quit_confirmation_dialog`.
- Продолжить забег — `CR_*` (ui_screens.gd:568–574), билдер `_show_continue_run_dialog`.
- Пауза в забеге — `PM_*` (ui_screens.gd:3587–3595), билдер `_build_run_pause_menu`.
- Тултип глоссария — `GT_*` (ui_screens.gd:2771–2773), билдер `_show_glossary_tooltip`.
- Форма фидбэка — `FB_*` (ui_screens.gd:6031+), билдер `_show_feedback_overlay`.
- Пауза-досье — `PD_*` и тултип статов `ST_*` живут в **`scripts/pause_stats_menu.gd`** (`_build_layout`, `_make_custom_tooltip`).
- База: `MENU_NAV_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)` (ui_screens.gd:296).
- Полная таблица x,y,w,h по всем 8 экранам: `docs/design/ui_screens_inventory.md` секция «Координатная спека @2560×1440 — блок Меню/Навигация (SCRUM-484)» (строки 71–186).

### Ассеты и пути (текущая тема — minimal_metal)
- Пути ассетов централизованы в `scripts/ui/ui_theme_paths.gd` (class_name `UIThemePaths`). `ui_screens.gd:22–51` реэкспортит их как локальные const.
- Активные глобалы блока: `GLOBAL_PANEL_FRAME_PATH := MINIMAL_METAL_PANEL_PATH`, `GLOBAL_BUTTON_FRAME_PATH := …minimal_metal_buttons/ui_btn_minimal_metal_standard.png` (ui_theme_paths.gd:108–117). Кнопки меню строятся через `_make_button` + `_set_action_button_size` (ui_screens.gd), фон главного меню — `game.MAIN_MENU_BACKGROUND` (`res://assets/backgrounds/main_menu_epic_battle_v2.png`, main.gd:73), `STRETCH_KEEP_ASPECT_COVERED` (ui_screens.gd:337–342).
- Фрейм-метаданные (source size / texture margins / content / safe rect) для minimal_metal: `MINIMAL_METAL_FRAME_SOURCE_SIZE`, `…TEXTURE_MARGINS`, `…CONTENT`, `…SAFE_RECTS` (ui_theme_paths.gd:55–86). Это шаблон того, как новые @2K-ассеты тоже должны нести размер+9-slice-маржины.
- Существующих **menu/nav-специфичных @2K-ассетов НЕТ** (поиск `find assets/sprites/ui -iname "*2k*" -o -iname "*menu_nav*"` пуст). Дир `assets/sprites/ui/frames/global/` содержит старые низкорез фреймы (`ui_panel_frame.png` и т.п.).

### Верификатор (SCRUM-483 — ГОТОВО)
- Гейт: `tests/ui_no_overlap_matrix_test.gd` (extends SceneTree). Гоняет каждый экран на `VIEWPORT_SIZES` (включая 1920×1080/2560×1440/3840×2160 — это `SCRUM483_GATE_SIZES`).
- Проверки на экран: fit во вьюпорт (для перечисленных в `_requires_viewport_fit`), пересечения пиров (`_first_peer_overlap`, толеранс 2px), overflow текста за родителя/за свой rect (`_append_text_overflow_errors`, `TEXT_OVERFLOW_TOLERANCE=6`), и **STRETCH_SCALE на «точных» фрейм-текстурах** (`_append_texture_stretch_errors` + `_is_exact_frame_texture_path`: путь под `res://assets/sprites/ui/frames/`, кроме `divider`). Любая ошибка → `push_error` + `quit(1)`.
- Билдеры открываются хелперами `_open_main_menu`/`_open_pause_menu`/`_open_pause_stats`/`_open_feedback`(если есть) и т.д. Дамп пишется в `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md` через `_filter_dump_viewport_sections`.
- Запуск headless:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/ui_no_overlap_matrix_test.gd`

### Что реально «не доделано» под этот тикет
Билдеры пользуются общими minimal_metal-ассетами, не нарезанными под точные @2K-размеры спеки. «Интеграция @2K-ассетов» = подменить/добавить пути в `UIThemePaths` на сгенерированные SCRUM-485 ассеты для слотов блока и убедиться, что каждый TextureRect/StyleBoxTexture использует source size + texture margins нового ассета (9-slice по плоской середине, без растяжения орнамента), а билдеры рисуют слот в размер из `*_2K`-const.

## Что сделать — по шагам

1. **Дождаться/проверить вход от SCRUM-485.** Этот тикет потребляет ассеты рисующего скрипта (SCRUM-485, «К выполнению»). Перед началом убедиться, что сгенерированы @2K-ассеты для слотов блока Меню/Навигация (панель выхода/продолжить/паузы/фидбэка, фон главного меню, кнопки колонки). Если ассетов ещё нет — блокер, эскалировать в Jira-комментарий SCRUM-486↔SCRUM-485, НЕ выдумывать ассеты.

2. **Зарегистрировать новые пути в `scripts/ui/ui_theme_paths.gd`.** Добавить константы дир и путей для menu/nav @2K-ассетов (по образцу `MINIMAL_METAL_*`): для каждого нового фрейма — путь + `SOURCE_SIZE` (Vector2 в пикселях ассета) + `TEXTURE_MARGINS` (Vector4 для 9-slice) + `CONTENT`/`SAFE_RECT`, чтобы безопасная зона совпадала с `*_SAFE_2K` из спеки. НЕ хардкодить пути в `ui_screens.gd` — только через `UIThemePaths`.

3. **Подключить ассеты в билдерах блока (`scripts/ui_screens.gd`).**
   - Главное меню `_show_main_menu` (310): если SCRUM-485 даёт новый фон @2K — подменить `MAIN_MENU_BACKGROUND`/текстуру (оставить `STRETCH_KEEP_ASPECT_COVERED`); кнопки колонки — на @2K-кнопочный StyleBoxTexture с корректными margins, размер слота = `MM_BTN_*_2K`. Версия — `MM_VERSION_LABEL_2K` (bottom-right, уже якорится offset -120/-34).
   - Модалки `_show_quit_confirmation_dialog`, `_show_continue_run_dialog` — панель-фрейм @2K, safe-area = `QC_SAFE_2K`/`CR_SAFE_2K`, кнопки в `*_BTN_*_2K`.
   - Пауза `_build_run_pause_menu` — панель `PM_PANEL_2K` (898×820), 5 кнопок 280×60 по `PM_BTN_*_2K`.
   - Тултипы `_show_glossary_tooltip` (`GT_*`) — w фикс 460, clamp 16px, gap 8.
   - Фидбэк `_show_feedback_overlay` (`FB_*`) — панель 940×780, фикс шапка/низ, скролл в середине.
   - Пауза-досье и тултип статов — в **`scripts/pause_stats_menu.gd`** (`_build_layout` `PD_*`, `_make_custom_tooltip` `ST_*`).

4. **Гарантировать no-stretch.** Все «точные» фрейм-текстуры под `res://assets/sprites/ui/frames/` рендерить через StyleBoxTexture с `texture_margins` (9-slice) ИЛИ TextureRect без `STRETCH_SCALE` — иначе верификатор падает (`_append_texture_stretch_errors`). Орнамент тянуть нельзя, тянется только плоская середина по margins.

5. **Прогнать верификатор** на 1080p/2K/4K headless (команда выше). Чинить любые overflow/overlap/escape/STRETCH_SCALE до зелёного. Сверить обновлённый `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md` — bbox слотов должны соответствовать `*_2K`-координатам спеки (с поправкой на uniform-скейл вьюпорта).

6. **Прогнать смоук** `tests/runtime_smoke_ui_test.gd` и `tests/runtime_smoke_test.gd`, чтобы интеграция не сломала открытие экранов.

7. **Обновить статус в Jira** (live-sync mandate): по зелёному верификатору — в «Контроль качества», приложить путь матрицы и результат прогонов.

## Acceptance Criteria

- [ ] Все 8 экранов блока Меню/Навигация рендерятся на сгенерированных @2K-ассетах (главное меню, подтверждение выхода, продолжить забег, пауза, пауза-досье, тултип глоссария, тултип статов, форма фидбэка).
- [ ] Рендер-верификатор `tests/ui_no_overlap_matrix_test.gd` (гейт SCRUM-483) **зелёный** на 1920×1080, 2560×1440, 3840×2160 (нет overflow текста, нет пересечений пиров, нет escape за вьюпорт/родителя, нет `STRETCH_SCALE` на точных фрейм-текстурах).
- [ ] Каждый интегрированный фрейм несёт корректные `SOURCE_SIZE` + `TEXTURE_MARGINS` в `UIThemePaths`; орнамент не растягивается (9-slice только по плоской середине).
- [ ] safe-area контента совпадает с `*_SAFE_2K` из спеки — текст и кнопки строго внутри пустой зоны рамки (правило frame-content safe-area).
- [ ] Все пути ассетов идут через `scripts/ui/ui_theme_paths.gd`, без хардкода в `ui_screens.gd`.
- [ ] `tests/runtime_smoke_ui_test.gd` и `tests/runtime_smoke_test.gd` проходят.
- [ ] Матрица `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md` обновлена и приложена к тикету.

## Files / точки входа

- `scripts/ui/ui_theme_paths.gd` — добавить const путей/размеров/margins новых @2K menu-nav ассетов (по образцу блока `MINIMAL_METAL_*`, строки 47–86). Единственное место для путей.
- `scripts/ui_screens.gd:_show_main_menu` (310) — фон + кнопки колонки на @2K, размеры по `MM_*`.
- `scripts/ui_screens.gd:_show_quit_confirmation_dialog` — панель/safe-area/кнопки по `QC_*`.
- `scripts/ui_screens.gd:_show_continue_run_dialog` — по `CR_*`.
- `scripts/ui_screens.gd:_build_run_pause_menu` (~3513) — панель/кнопки по `PM_*`.
- `scripts/ui_screens.gd:_show_glossary_tooltip` (~2722) — по `GT_*`.
- `scripts/ui_screens.gd:_show_feedback_overlay` (~5940) — по `FB_*`.
- `scripts/pause_stats_menu.gd:_build_layout` / `_make_custom_tooltip` — пауза-досье `PD_*` и тултип статов `ST_*`.
- `tests/ui_no_overlap_matrix_test.gd` — НЕ менять контракт верификатора без причины; гнать как гейт.
- `docs/design/ui_screens_inventory.md` (строки 71–186) — источник истины по x,y,w,h всех слотов блока.

## Замечания / подводные камни

- **Блокирующая зависимость:** SCRUM-485 (рисующий скрипт) ещё «К выполнению». 486 потребляет его ассеты. Если ассетов нет — это блокер, не генерировать ассеты руками в этом тикете (область SCRUM-485 и скилла asset-generator).
- **Anti-collision / locked paths:** `scripts/ui_screens.gd` — горячий файл за Claude-контуром (по memory: ui_screens.gd изолирован за Claude). `scripts/progression_data.gd` — locked, его НЕ трогать (к этому тикету не относится, но держать в уме). Коммитить **явным `git add`** своих файлов (не `-A`) из-за multi-worker churn; green-gate ДО коммита; после коммита проверить HEAD в worktree.
- **No-stretch — главный источник красных.** Верификатор валит любой TextureRect под `frames/` со `STRETCH_SCALE`. Использовать StyleBoxTexture с `texture_margins` (9-slice) либо `STRETCH_KEEP_ASPECT*`/tile, никогда не `STRETCH_SCALE` на орнаментной рамке. Исключение в коде — только пути с `divider`.
- **Координаты модалок при не-16:9 не меняются** (stretch=keep даёт чёрные полосы), на 1080p/4K они uniform-скейлятся вместе с вьюпортом — bbox в матрице будут масштабированы соответственно базе 2560×1440 (см. примечание в спеке, строки 183–186).
- **Текст в рамках:** content margins нового ассета должны давать safe-area ≥ `*_SAFE_2K`; иначе длинные русские строки кнопок («Начать новую игру», «Покинуть забег») выйдут за рамку и завалят `_text_control_contract_error`.
- **Пауза-досье и тултип статов живут в отдельном файле** (`scripts/pause_stats_menu.gd`), не забыть их при интеграции — `EscapeStatsPanelFrame`/`PauseControlButtons`/`BaseStatsList`/`DerivedStatsGroups` проверяются верификатором (`_open_pause_stats`).
- **Связанные тикеты:** SCRUM-482 (2K viewport, done), SCRUM-483 (верификатор, done), SCRUM-484 (координаты, done), SCRUM-485 (рисующий скрипт — апстрим), SCRUM-487 (следующий блок «Боевые» — тот же паттерн интеграции, после этого тикета).
- **Версия в правом нижнем углу** (`MM_VERSION_LABEL_2K`) — при смене не забывать про правило version-bump (project.godot config/version), но в рамках интеграции просто сохранить корректный якорь bottom-right.
