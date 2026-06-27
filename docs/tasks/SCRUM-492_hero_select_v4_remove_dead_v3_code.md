# SCRUM-492: Hero Select v4: удалить мёртвый v3-код и legacy-константы

Jira: SCRUM-492 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-470 (Hero Select v4)
Статус: К выполнению

## Что и зачем

Экран выбора героя был переведён на v4-вёрстку (SCRUM-470): функция `_build_character_select_v4()` строит весь экран с нуля. Старая v3-реализация осталась в коде «мёртвым грузом» — в `_show_character_select()` стоит безусловный `return` сразу после вызова v4-билдера, а за ним лежат ~410 строк недостижимой v3-вёрстки. Вокруг неё висят неиспользуемые константы `HERO_SELECT_V3_*`, набор v3-хелперов и целое семейство `_hero_select_unified_*` / `_hero_thumbnail_*`, которое тоже завязано только на этот мёртвый блок.

Это чистый tech-debt: для игрока изменений ноль (экран уже рисуется v4), но мёртвый код:
- раздувает `ui_screens.gd` (файл и без того огромный, локнут под анти-коллизию),
- путает следующего исполнителя (легко принять v3-вёрстку за актуальную и править не то),
- держит ссылки на ассеты `hero_select_v3/` и оставляет в тестах орфанные v3-ассерты.

Ожидаемый результат: недостижимый v3-блок и связанные с ним только-мёртвые константы/хелперы удалены (либо явно помечены legacy там, где их нельзя выпилить без побочных эффектов), тесты приведены в порядок, все UI-смоуки зелёные, поведение экрана выбора героя не меняется ни на пиксель.

## Текущее состояние в коде

### `scripts/ui_screens.gd`

- `_show_character_select()` — `scripts/ui_screens.gd:1014`. Сбрасывает run-стейт, чистит UI, на строке **1030** вызывает `_build_character_select_v4()`, на строке **1031** — безусловный `return`. Всё ниже (строки **1033–1443**) недостижимо: это полная v3-вёрстка (фон `HeroSelectV3Background`, canvas, портрет/досье/радар/карусель, кнопки, фокус-навигация), завершается на строке 1443 `game.ui_escape_action = _show_main_menu`. Следующая функция `_hero_thumbnail_size` начинается на строке **1446**.
- `_build_character_select_v4()` — `scripts/ui_screens.gd:749`. АКТУАЛЬНАЯ реализация. Строит экран на голых `Panel`/`Label`/`TextureButton`, своя карусель на `HS4_CAROUSEL_SLOTS` (=9, строка 700) слотах, досье по `HS4_DOSSIER_STATS` (строка 701), радар `HeroStatRadar`. **НЕ использует** ни `_hero_thumbnail_size`, ни `_make_hero_thumbnail_button`, ни `_hero_select_thumbnail_style`, ни `_hero_select_frame_style`, ни семейство `_hero_select_unified_*`.

- Константы v3 — `scripts/ui_screens.gd:95–108`:
  `HERO_SELECT_V3_SOURCE_SIZE`, `HERO_SELECT_V3_FRAME_DIR`, `HERO_SELECT_V3_BACKGROUND_PATH`, `HERO_SELECT_V3_PREVIEW_FRAME`, `HERO_SELECT_V3_DOSSIER_FRAME`, `HERO_SELECT_V3_RADAR_ZONE`, `HERO_SELECT_V3_CAROUSEL_FRAME`, `HERO_SELECT_V3_TITLE_RECT`, `HERO_SELECT_V3_BACK_RECT`, `HERO_SELECT_V3_PREVIEW_CONTENT`, `HERO_SELECT_V3_DOSSIER_CONTENT`, `HERO_SELECT_V3_RADAR_CONTENT`, `HERO_SELECT_V3_CAROUSEL_CONTENT`, `HERO_SELECT_FRAME_DIR` (= алиас `HERO_SELECT_V3_FRAME_DIR`).

- v3-хелперы — `scripts/ui_screens.gd:1457–1498`:
  `_hero_select_v3_scale`, `_hero_select_v3_canvas_rect`, `_hero_select_v3_scaled_rect`, `_hero_select_v3_square_rect`, `_hero_select_v3_content_rect`, `_hero_select_v3_thumbnail_separation`.

### Карта реальной достижимости (важно — НЕ всё «v3» одинаково мёртвое)

Проверено `grep` по всем ссылкам. Делятся на три группы:

**A. Только-мёртвые (используются ИСКЛЮЧИТЕЛЬНО из блока 1033–1443) — можно удалять:**
- Все ссылки на `_hero_select_v3_*` хелперы (строки 1044–1377) находятся внутри dead-блока.
- `_hero_thumbnail_size` (1446) → зовётся только из 1368 (dead). Сам тянет `_hero_select_v3_scaled_rect/_content_rect/_thumbnail_separation` + `HERO_SELECT_V3_CAROUSEL_FRAME/_CAROUSEL_CONTENT`.
- `_make_hero_thumbnail_button` (1640) → зовётся только из 1414 (dead).
- `_hero_select_thumbnail_style` (7436) → зовётся из 1396 (dead) и из `_make_hero_thumbnail_button` (тоже мёртв).
- `_apply_hero_select_button_frame` (7449) → не зовётся вообще нигде (0 вызовов) — мёртв полностью.
- Семейство `_hero_select_unified_*` (1509–1638): `_hero_select_unified_scale`, `_hero_select_unified_frame_size`, `_hero_select_unified_scaled_rect`, `_hero_select_radar_frame_size`, `_hero_select_content_row_height` — ссылаются только друг на друга, наружу не вызываются. Связанные константы `HERO_SELECT_UNIFIED_*` (строки 76–79).

**B. ПОЛУ-живые — НЕЛЬЗЯ удалять как есть, нужна осторожность:**
- `HERO_SELECT_V3_FRAME_DIR` (96) → служит источником для `HERO_SELECT_FRAME_DIR` (108) → который используется в `HERO_SELECT_FRAME_TEXTURES` (строки 256–261) → а тот читается в ЖИВОМ `_hero_select_frame_style()` (7395, строки 7396–7398). НО `_hero_select_frame_style` сам зовётся только из dead-блока (1090/1114/1339) и из мёртвого `_apply_hero_select_button_frame` — то есть тоже транзитивно мёртв. Тем не менее v4-фон рисуется через `_add_screen_background(root, "hero_select")` — нужно ПРОВЕРИТЬ, не тянет ли `_add_screen_background` пути из `hero_select_v3/`. Если тянет — `HERO_SELECT_V3_FRAME_DIR` остаётся живым.

**C. `HERO_SELECT_FRAME_TEXTURES` / `HERO_SELECT_FRAME_MARGINS` / `HERO_SELECT_FRAME_CONTENT`** (256–283) — используются `_hero_select_frame_style` (7395). Удалять ТОЛЬКО если убираешь и `_hero_select_frame_style`, и `_apply_hero_select_button_frame` целиком, и убедился, что v4 их не зовёт.

### `tests/runtime_smoke_test.gd`

- Константы v3 — строки **19–37**: `HERO_SELECT_V3_SOURCE_SIZE`, `_OUTER_SAFE`, `_PORTRAIT_FRAME/_SAFE`, `_DOSSIER_FRAME/_CONTENT/_*_SAFE`, `_BACK_SAFE`, `_RADAR_PANEL/_CONTENT`, `_CAROUSEL_FRAME/_SAFE`, `_TOOLTIP_SAFE` (часть из них — алиасы на `HERO_SELECT_V3_DOSSIER_CONTENT`).
- v3-хелперы тестов — `_assert_hero_select_v3_back_button_safe` (**6265**) и `_hero_select_v3_expected_rect` (**6294**).
- **Ключевой факт:** оба этих хелпера ОРФАННЫЕ — `grep` показывает 0 вызовов `_assert_hero_select_v3_back_button_safe` и единственную ссылку на `_hero_select_v3_expected_rect` внутри самого же `_assert_hero_select_v3_back_button_safe`. Все живые (не-определения) ссылки на v3-константы — только внутри этих двух мёртвых хелперов (строки 6270, 6295, 6296). Значит весь v3-блок в тестах самозамкнут и удаляется чисто.
- Актуальный v4-аналог уже есть: `_hero_select_v4_expected_rect` (**6300**), `HERO_SELECT_V4_SOURCE_SIZE` (**39**) — их НЕ трогать.

## Что сделать — по шагам

1. **Удалить недостижимый блок в `_show_character_select`.** Убрать строки **1033–1443** (тело после `return` на 1031). Сам `return` можно убрать как лишний (после него теперь сразу `func`), оставив `_build_character_select_v4()` финальным вызовом. Комментарий на 1029 переписать на что-то вроде `# Экран выбора героя v4 (SCRUM-470).` без упоминания «старая v3-вёрстка ниже».

2. **Удалить только-мёртвые v3-хелперы** (`scripts/ui_screens.gd:1457–1498`): `_hero_select_v3_scale`, `_hero_select_v3_canvas_rect`, `_hero_select_v3_scaled_rect`, `_hero_select_v3_square_rect`, `_hero_select_v3_content_rect`, `_hero_select_v3_thumbnail_separation`.

3. **Удалить транзитивно-мёртвые хелперы рендера карусели/тамбнейлов:** `_hero_thumbnail_size` (1446), `_make_hero_thumbnail_button` (1640), `_hero_select_thumbnail_style` (7436), `_apply_hero_select_button_frame` (7449). Перед удалением ещё раз прогнать `grep -n "_hero_thumbnail_size\|_make_hero_thumbnail_button\|_hero_select_thumbnail_style\|_apply_hero_select_button_frame" scripts/` — после шага 1 у них должно остаться 0 живых вызовов.

4. **Удалить семейство `_hero_select_unified_*`** (1509–1638) и связанные константы `HERO_SELECT_UNIFIED_*` (76–79) — только после `grep`-подтверждения 0 внешних вызовов.

5. **Разобраться с `_hero_select_frame_style` + frame-dict'ами (группа C).** Прогнать `grep`: если после шагов 1–3 у `_hero_select_frame_style` 0 живых вызовов — удалить и его, и `_apply_hero_select_button_frame`, и при отсутствии других потребителей — `HERO_SELECT_FRAME_TEXTURES`/`_MARGINS`/`_CONTENT` (256–283). Если что-то живо — оставить и пометить остальное legacy.

6. **Удалить v3-константы `HERO_SELECT_V3_*`** (95–107) ПОСЛЕ удаления всех их потребителей. ВНИМАНИЕ к `HERO_SELECT_V3_FRAME_DIR` (96) и алиасу `HERO_SELECT_FRAME_DIR` (108):
   - Сначала проверь `_add_screen_background(root, "hero_select")` (вызов на 759) — какие пути он резолвит. Если он НЕ использует `hero_select_v3/`, и `HERO_SELECT_FRAME_DIR` больше нигде живо не нужен → удаляй обе константы.
   - Если `HERO_SELECT_FRAME_DIR` остаётся нужен живому коду → инлайнить литерал `"res://assets/sprites/ui/frames/hero_select_v3/"` напрямую в `HERO_SELECT_FRAME_DIR` и удалить только `HERO_SELECT_V3_FRAME_DIR`. Тогда `HERO_SELECT_FRAME_DIR` оставить с комментарием, что это исторический путь ассетов, а не v3-вёрстка.

7. **Почистить тесты `tests/runtime_smoke_test.gd`:**
   - Удалить орфанные хелперы `_assert_hero_select_v3_back_button_safe` (6265–6291) и `_hero_select_v3_expected_rect` (6294–6297).
   - Удалить v3-константы строк **19–37** (`HERO_SELECT_V3_*`). НЕ трогать `HERO_SELECT_V4_SOURCE_SIZE` (39) и `_hero_select_v4_expected_rect` (6300).

8. **Прогнать UI-смоуки headless** (Godot 4.6.3, `~/Downloads/Godot.app`) — `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd` и общий smoke-gate. Убедиться, что hero-select-v4 экран строится, кнопка «Назад» (`HS4BackButton`), карусель, досье, радар на местах. Все зелёные.

9. (Опционально, но желательно для чистоты) Проверить, остались ли в `assets/sprites/ui/frames/hero_select_v3/` ассеты, на которые больше никто не ссылается — НЕ удалять в рамках этого тикета, а зафиксировать отдельным наблюдением, т.к. удаление ассетов = смена .import и риск для других экранов.

## Acceptance Criteria

- [ ] Недостижимый v3-блок после `return` в `_show_character_select` (`scripts/ui_screens.gd:1033–1443`) удалён; лишний `return` убран.
- [ ] Только-мёртвые v3-хелперы (`_hero_select_v3_scale/_canvas_rect/_scaled_rect/_square_rect/_content_rect/_thumbnail_separation`) удалены либо явно помечены legacy с комментарием.
- [ ] Транзитивно-мёртвые `_hero_thumbnail_size`, `_make_hero_thumbnail_button`, `_hero_select_thumbnail_style`, `_apply_hero_select_button_frame`, семейство `_hero_select_unified_*` удалены (после grep-подтверждения 0 живых вызовов) либо обоснованно сохранены.
- [ ] Неиспользуемые константы `HERO_SELECT_V3_*` удалены; `HERO_SELECT_V3_FRAME_DIR`/`HERO_SELECT_FRAME_DIR` обработаны осознанно (инлайн или удаление, в зависимости от того, нужен ли путь живому коду) без поломки `_add_screen_background`.
- [ ] Орфанные тест-хелперы `_assert_hero_select_v3_back_button_safe` и `_hero_select_v3_expected_rect` и v3-константы (строки 19–37) удалены; v4-аналоги (`HERO_SELECT_V4_SOURCE_SIZE`, `_hero_select_v4_expected_rect`) нетронуты.
- [ ] `grep -n "HERO_SELECT_V3\|_hero_select_v3\|_hero_select_unified\|_apply_hero_select_button_frame" scripts/ tests/` не возвращает ни одного оставшегося живого использования (либо только осознанно-legacy-помеченные строки).
- [ ] Экран выбора героя визуально и функционально идентичен текущему (v4): портрет, досье со статами, радар, карусель из 9 слотов, кнопки −/+/Выбрать/Назад, Esc → главное меню.
- [ ] Все UI-смоуки (`runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`, smoke-gate) зелёные после чистки.
- [ ] Файл `ui_screens.gd` парсится Godot'ом без ошибок (нет осиротевших ссылок на удалённые символы).

## Files / точки входа

- `scripts/ui_screens.gd:_show_character_select` (1014) — удалить мёртвый блок 1033–1443 + лишний `return`.
- `scripts/ui_screens.gd` константы 76–79 (`HERO_SELECT_UNIFIED_*`), 95–108 (`HERO_SELECT_V3_*`, `HERO_SELECT_FRAME_DIR`) — удалить/инлайнить.
- `scripts/ui_screens.gd` 1446–1498 (`_hero_thumbnail_size`, v3-хелперы), 1509–1638 (`_hero_select_unified_*`), 7436–7454 (`_hero_select_thumbnail_style`, `_apply_hero_select_button_frame`) — удалить мёртвое.
- `scripts/ui_screens.gd:7395` `_hero_select_frame_style` + `HERO_SELECT_FRAME_TEXTURES/_MARGINS/_CONTENT` (256–283) — удалить только если транзитивно мёртвы (см. шаг 5).
- `tests/runtime_smoke_test.gd` 19–37 (v3-консты), 6265–6297 (`_assert_hero_select_v3_back_button_safe`, `_hero_select_v3_expected_rect`) — удалить орфанное.

## Замечания / подводные камни

- **ANTI-COLLISION / locked path:** `scripts/ui_screens.gd` — крупный локнутый файл. Этот тикет помечен lane `claude`; убедись, что параллельно по нему не идёт другой воркер (memory: ui_screens.gd закреплён за Claude-контуром). Коммить ЯВНЫМ `git add scripts/ui_screens.gd tests/runtime_smoke_test.gd`, не `git add -A`, чтобы не втянуть чужие хунки.
- `scripts/progression_data.gd` НЕ трогаем (тоже locked) — задача его не касается.
- **Порядок удаления критичен:** сначала убрать ВЫЗЫВАЮЩИЙ код (dead-блок), потом — вызываемые хелперы. Иначе Godot ругнётся на «используемую» функцию или, наоборот, оставишь висячую ссылку. После каждого крупного удаления — `grep` на остаточные ссылки перед следующим шагом.
- Группа B (`HERO_SELECT_V3_FRAME_DIR` → `HERO_SELECT_FRAME_DIR` → frame-textures) — самая хрупкая. Не удаляй `HERO_SELECT_FRAME_DIR` вслепую: сперва точно установи, тянет ли живой v4-путь (`_add_screen_background("hero_select")`) ассеты из `hero_select_v3/`. Если да — оставь директорию-константу как исторический путь, удали только v3-вёрстку и `_V3_`-зоны.
- Ассеты `assets/sprites/ui/frames/hero_select_v3/*.png` физически НЕ удалять в этом тикете (риск для .import и других экранов) — только код. При желании завести отдельное наблюдение/тикет на аудит осиротевших ассетов.
- Edge-case тестов: в `tests/runtime_smoke_test.gd` и `tests/ui_no_overlap_matrix_test.gd` остаются ЖИВЫЕ ссылки на каталог отчётов `scrum470_hero_select_v4` (runtime_smoke_test.gd:7115, ui_no_overlap_matrix_test.gd:148–149) — это v4-артефакты, их НЕ трогать.
- Связанные тикеты эпика SCRUM-470: вёрстка v4 уже в проде (`bug_runtime_smoke_hero_select_v4_backbutton_name_task.md`, `design_hero_select_v4_rebuild_clean_readable_task.md`). Чистка не должна менять видимое поведение — это строго tech-debt без фич (учитывая фриз 0.1.5).
- Проверка зелёного gate ДО коммита; после коммита — перепроверить HEAD в worktree (2–3 прогона смоука), чтобы не поймать красный из-за чужого `git add -A`.
