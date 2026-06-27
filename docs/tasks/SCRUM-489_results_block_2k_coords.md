# SCRUM-489: Блок Результаты: координаты @2K + интеграция (победа/смерть/выбор героя/оружия/карта)

Jira: SCRUM-489 · Роль: backend (UI) · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-481 (UI Overhaul 2K)
Статус: Выполнено (Feature) — на Контроль качества

## Что и зачем

Эпик SCRUM-481 переводит весь UI на базу **2560×1440 (16:9)**: 1080p ужимает (uniform
downscale), 4K растягивает (uniform upscale), нестандартное соотношение → чёрные полосы
(`stretch=canvas_items/keep`, фундамент уже заложен SCRUM-482). Для каждого экрана нужно
зафиксировать **точные координаты контента @2K в именованных код-константах** — ровно как
сделал SCRUM-484 для блока «Меню/Навигация» (см. `ui_screens.gd:291..` блоки `MM_*`/`QC_*`/
`CR_*`/`PM_*`/`FB_*` и таблицы в `docs/design/ui_screens_inventory.md` §71+). Эти прямоугольники
`x,y,w,h` — это вход для «рисующего скрипта» (fantasydisk-asset-generator): он генерит ассеты
ровно в свой размер, орнамент рамки не растягивается, контент живёт только в пустой safe-area.

Эта задача закрывает **блок «Результаты/Исходы + старт забега»** — 5 экранов:
1. **Победа** (`_show_victory_screen`) — итог забега над финальным боссом.
2. **Поражение/Смерть** (`_show_death_screen`).
3. **Выбор героя v4** (`_build_character_select_v4`) — портрет / досье / радар / карусель.
4. **Выбор оружия** (`_show_weapon_select`) — карточки подклассов/оружий.
5. **Карта маршрута** (`_show_battle_map`, **scripts/route_map_screen.gd**) — хедер + вертикальный
   скролл узлов.

Цель с точки зрения игрока: на всех трёх gate-разрешениях (1080p/2K/4K) эти экраны без
overflow/overlap/text-out, элементы не наслаиваются, текст в рамках, ассеты в точном размере.
Ожидаемый результат: координатный блок-константы @2K в коде + строки в inventory-доке +
зелёный верификатор `tests/ui_no_overlap_matrix_test.gd` на 1920×1080 / 2560×1440 / 3840×2160.

## Текущее состояние в коде

### Общий фундамент (уже есть)
- `project.godot`: viewport 2560×1440, `stretch=canvas_items`, `aspect=keep` (SCRUM-482).
- Верификатор: `tests/ui_no_overlap_matrix_test.gd` — гоняет матрицу размеров
  `[1152×648,1280×720,1600×900,1920×1080,2560×1440,3840×2160]`, gate (SCRUM-483) =
  `{1920×1080, 2560×1440, 3840×2160}`. Проверяет: viewport-fit, peer-overlap (tol 2px),
  text-overflow (нужная высота/ширина текста vs аллокация, tol 6px), parent-containment,
  exact-frame TextureRect не на `STRETCH_SCALE`. Дамп → `build/qa/.../*.md`.
- Паттерн именованных const @2K из SCRUM-484: `const MENU_NAV_DESIGN_BASE_2K := Vector2(2560,1440)`,
  далее `const XX_PANEL_2K := Rect2(x,y,w,h)`, `XX_SAFE_2K`, `XX_BTN_*_2K` (ui_screens.gd:296-307,
  446-452, 568+, 3587-3595, 6025+). Зеркало в `docs/design/ui_screens_inventory.md` §71-186.

### 1. Победа — `_show_victory_screen` · ui_screens.gd:5088
Через `_create_menu_box("Победа", subtitle, "victory")` (ui_screens.gd:6246) + `_add_result_crest(box,"victory")`
(6327). Это **pause/end-модалка** (`_is_pause_end_screen_background` → `["pause","victory","death"]`,
6986). Размер панели = `_pause_end_modal_display_size("victory")` (6990): при viewport 2560×1440 →
**898×820** (height clamp 520..820 упирается в 820; source_aspect 986/900). Центр экрана →
панель top-left **(831, 310)**. Content-margins масштабируются из `PAUSE_END_MODAL_CONTENT
(74,94,74,86)` при source `986×900` → **(67,86,67,78)** → safe-area **(898, 396, 764, 656)**
(идентично `PM_SAFE_2K`). Контент в VBox (center align, separation 12): crest (size
`_pause_end_result_crest_size`=clamp(vp.y*0.17,112,176)=176@2K) → title (42px) → subtitle
(17px, autowrap) → кнопка «Новый забег» (`VictoryNewRunButton`, width `STANDARD_ACTION_BUTTON_WIDTH`=420,
height `_pause_end_result_button_height`=104@2K). Панель в ScrollContainer (вертикальный скролл
включён) — длинный subtitle победы (5 строк) не вызовет overflow, но обрежется скроллом.
Источники модалки: `PAUSE_END_MODAL_SOURCE_SIZE (986,900)`, `..._TEXTURE_MARGINS (51,70,51,63)`,
`..._CONTENT (74,94,74,86)`, `..._PATH = MINIMAL_MODAL_PATH` (ui_screens.gd:176-179).

### 2. Поражение — `_show_death_screen` · ui_screens.gd:5123
Полностью симметрично победе: `_create_menu_box("Поражение", subtitle, "death")` + crest "defeat",
кнопка `DeathRetryButton` (420×104). Та же геометрия панели **898×820 @ (831,310)**, safe
**(898,396,764,656)**.

### 3. Выбор героя v4 — `_build_character_select_v4` · ui_screens.gd:749
**Полноэкранный** (root `HeroSelectScreen`, фон `_add_screen_background(root,"hero_select")`).
ВАЖНО: билдер **НЕ использует** существующий нормализованный блок `HS4_*` (ui_screens.gd:693-700,
`const HS4_TITLE := Rect2(0.265,…)` и т.д. от SCRUM-470) — он пересчитывает всё «на лету» из
множителей `vp.x*0.022` / `vp.y*0.028` и пр. (строки 764-776). Раскладка @2560×1440 (vp=2560×1440):
- mx = round(2560*0.022)=56; my = round(1440*0.028)=40; top_h = round(1440*0.085)=122;
  car_h = round(1440*0.17)=245; gap = round(2560*0.014)=36; pad = round(1440*0.02)=29.
- content_w = 2560 - 56*2 = 2448. mid_y = 40+122+round(1440*0.012=17)=179.
  car_y = 1440-40-245 = 1155. mid_h = 1155-179-17 = 959.
- left_w = round(2448*0.27)=661; right_w = round(2448*0.255)=624; center_w = 2448-661-624-72 = 1091.
- Заголовок «Выбор героя» (740): pos(56,40) size(2448,122), font ~58. Кнопка «Назад»
  `HS4BackButton` (790): width vp.x*0.085=217.6, height round(122*0.8)=98, pos(56, 40+round(122*0.2*0.5)=12).
- portrait_panel (797): pos(56,179) size(661,959); `HS4Portrait` внутри pos(29,29) size(603,901).
- dossier_panel (812): pos(56+661+36=753,179) size(1091,959); VBox `dossier` pos(29,29):
  name(35px) / desc(autowrap 19px) / stats GridContainer 2col / spacer / asc HBox
  (`AscensionMinusButton`/`AscensionLevelLabel`/`AscensionPlusButton`, кнопки vp.x*0.04=102 × vp.y*0.05=72)
  / `AscensionModsLabel` (autowrap, max 2 lines) / `HS4ChooseButton` (vp.x*0.2=512 × vp.y*0.062=89).
- radar_panel (892): pos(753+1091+36=1880,179) size(624,959); `HS4Radar` (HeroStatRadar) pos(29,29) size(566,901).
- carousel_panel (905): pos(56,1155) size(2448,245); `HS4Carousel` внутри. cpad=round(245*0.1)=25,
  arrow_w=round(245*0.5)=123, slot_h=245-50=195, slot_w=(2448-246-50)/9=239. 9 слотов (`HS4_CAROUSEL_SLOTS`),
  стрелки `◄`/`►`. Слот i: pos(25+123 + i*239 + 239*0.06, 25) size(239*0.88, 195).
Верификатор уже знает `HS4Portrait/HS4Radar/HS4Carousel/HS4ChooseButton` (ui_no_overlap_matrix:59-61).

### 4. Выбор оружия — `_show_weapon_select` · ui_screens.gd:3888
Через `_create_menu_box("Выбор оружия", subtitle, "weapon_select")` — это **economy-панель**
(не pause/end и не в списке economy-id явно → `_economy_menu_panel_half_size("weapon_select")`
6007 возвращает дефолт target `1120×660`, clamp по viewport). Панель **1120×660 @ центр** →
top-left **(720, 390)** @2K. Внутри ScrollContainer + VBox: title(42px) / subtitle(17px autowrap) /
N карточек оружия (`_make_weapon_select_card` 3906: `WeaponOption_<id>`, custom_min_size
**860×173**, `size_flags_horizontal=EXPAND_FILL`, внутри HBox offset 18/12 → sprite 112×112 +
text VBox: title/desc/stat-строки) / кнопка «Назад». Карточка 860 шире safe-области панели 1120
минус content-margins (~74/94 у minimal-frame), потому карточки EXPAND_FILL ужимаются по ширине
панели; высота VBox-стека из 2-4 карточек + title/subtitle/back должна влезть в 660 → **РИСК
overflow по высоте**: при 3-4 оружиях и крупных шрифтах стек > 660, ScrollContainer спасает от
вылета, но визуально режет. Этот экран **НЕ покрыт верификатором** сейчас (его нет в матрице
ui_no_overlap_matrix_test.gd).

### 5. Карта маршрута — `_show_battle_map` · **scripts/route_map_screen.gd:13**
Полноэкранный root `RouteMapScreen`. Фон: backdrop PNG (или fallback ColorRect) + 2 shade-слоя
(full-rect). Хедер `RouteMapHeader` (PanelContainer, 62): anchor top, offset_left/right =
`ROUTE_MAP_SCREEN_MARGIN`=28 (main.gd:32), offset_top=18, offset_bottom=`ROUTE_MAP_HEADER_HEIGHT`-12
= 118-12 = 106 (main.gd:31). Внутри HBox→VBox: title «Карта маршрута» (36px) + stage_label (18px,
прогресс/таймер) + опц. debug-label (16px). Скролл `RouteMapScroll` (116): full-rect, offset
left/right=±28, top=118, bottom=-28; внутри `VerticalRouteMap` (map_area) размер
`_route_map_canvas_size()` (166): width = max(vp.x - 28*2 - 16, 1000) = **2488 @2K**, height =
`ROUTE_MAP_PADDING.y*2 + MAP_NODE_SIZE.y + 165*(row_count-1)` (ROUTE_MAP_PADDING=(170,72),
MAP_NODE_SIZE=(88,88), main.gd:29-30; row_count=max(route_nodes, ROUTE_STEPS_TO_BOSS+1=11)).
Узлы рисуются процедурно `_map_node_positions`/`_draw_route_nodes` (88×88 кнопки), плюс HUD-панель
ресурсов и upgrade-FAB. **НЕ покрыт верификатором** (нет в матрице). Все размеры — абсолютные
пиксели (28/118/88/170/72/165), НЕ масштабируются от viewport, кроме width canvas.

## Что сделать — по шагам

> Образец для копирования — блок SCRUM-484 в ui_screens.gd (const `MM_*`/`QC_*`/`PM_*` +
> комментарий-шапка) и таблицы в inventory §71-186. Все значения — **абсолютные px @2560×1440**,
> тип `Rect2(x,y,w,h)`; safe-area = пустая зона внутри рамки под контент.

1. **Победа/Поражение — const-блок `VS_*`/`DS_*`** (можно общий `RESULT_*`, т.к. геометрия
   идентична) рядом с `_show_victory_screen`/`_show_death_screen` (ui_screens.gd:5088). Завести:
   `RESULT_DESIGN_BASE_2K := Vector2(2560,1440)`, `RESULT_PANEL_2K := Rect2(831,310,898,820)`,
   `RESULT_SAFE_2K := Rect2(898,396,764,656)`, `RESULT_CREST_2K := Rect2(?, 401, 176, 176)`
   (crest центрирован по safe-x: x = 898 + (764-176)/2 = 1192), `RESULT_TITLE_2K`,
   `RESULT_SUBTITLE_2K`, `VS_BTN_NEWRUN_2K := Rect2(?, ?, 420, 104)` (центр по safe-x: x = 898+(764-420)/2 = 1070),
   `DS_BTN_RETRY_2K := Rect2(1070, ?, 420, 104)`. Y-раскладку взять по факту VBox-стека
   (crest→title→subtitle→spacer→button, separation 12) — вычислить из реального прогона или
   уложить вертикально в safe 396..1052 с фиксированными слотами и задокументировать.
2. **Выбор героя — const-блок `HS4_*_2K`** рядом с `_build_character_select_v4`. Перевести
   текущие множители в абсолютные Rect2 @2K (значения выше в «Текущее состояние»):
   `HS4_TITLE_2K := Rect2(56,40,2448,122)`, `HS4_BACK_2K := Rect2(56,12,218,98)`,
   `HS4_PORTRAIT_FRAME_2K := Rect2(56,179,661,959)`, `HS4_PORTRAIT_SAFE_2K := Rect2(85,208,603,901)`,
   `HS4_DOSSIER_2K := Rect2(753,179,1091,959)`, `HS4_RADAR_2K := Rect2(1880,179,624,959)`,
   `HS4_CAROUSEL_2K := Rect2(56,1155,2448,245)`, `HS4_CHOOSE_BTN_2K`, `HS4_ASC_BTN_2K`,
   `HS4_CAROUSEL_SLOT_2K` (шаблон 210×195, шаг 239). Старые нормализованные `HS4_*` (Rect2 в долях,
   693-700) от SCRUM-470 **оставить как есть** (на них может опираться mockup-валидация) ИЛИ
   пометить депрекейт-комментом — НЕ удалять без проверки ссылок (`grep HS4_TITLE`).
3. **Выбор оружия — const-блок `WS_*_2K`** рядом с `_show_weapon_select` (3888):
   `WS_PANEL_2K := Rect2(720,390,1120,660)`, `WS_SAFE_2K` (минус minimal-frame content-margins),
   `WS_TITLE_2K`, `WS_SUBTITLE_2K`, `WS_CARD_2K := Rect2(?, ?, ~972, 173)` (шаблон карточки —
   ширина по safe панели, высота 173, шаг = 173 + separation 16), `WS_BTN_BACK_2K`.
   Карточка `_make_weapon_select_card` уже даёт фикс высоту 173 — задокументировать как шаблон,
   стек до 4 карточек (см. риск overflow).
4. **Карта маршрута — const-блок `RM_*_2K`** в **scripts/route_map_screen.gd** (или в main.gd рядом
   с ROUTE_MAP_*): `RM_DESIGN_BASE_2K`, `RM_HEADER_2K := Rect2(28,18,2504,88)` (right = 2560-28*2),
   `RM_HEADER_SAFE_2K`, `RM_TITLE_2K`, `RM_STAGE_LABEL_2K`, `RM_SCROLL_2K := Rect2(28,118,2504,1294)`
   (bottom = 1440-28), `RM_CANVAS_2K := Rect2(28,118,2488,…)` (width 2488), `RM_NODE_2K := Rect2(0,0,88,88)`
   (шаблон узла), `RM_ROW_GAP_2K := 165`, `RM_PADDING_2K := Vector2(170,72)`. Высота canvas
   динамическая (row_count) — задокументировать формулу, не хардкодить высоту.
5. **Подключить ассеты** (если для блока есть сгенерённые фоны/рамки — фон выбора героя
   `hero_select`, backdrop карты `route_map_backdrop.png`, modal-рамка победы/смерти). Сверить
   пути в `_screen_background_texture`/`_add_screen_background` и что TextureRect не на
   `STRETCH_SCALE` для exact-frame (верификатор это валит).
6. **Расширить верификатор** `tests/ui_no_overlap_matrix_test.gd`: добавить кейсы
   `weapon_select` и `route_map` в матрицу (`_check_screen` + `_open_*` хелперы), назвать
   ключевые контролы (`WeaponOption_*`, `RouteMapHeader`/`RouteMapScroll`/`VerticalRouteMap`),
   при необходимости проставить `.name` тем нодам, у которых их нет. Victory/death/hero_select
   уже в матрице — проверить, что после правок остаются зелёными.
7. **Обновить `docs/design/ui_screens_inventory.md`**: добавить секцию «Координатная спека
   @2560×1440 — блок Результаты/Старт» с таблицами по образцу §81-186, и снять пункты в
   «Следующий шаг» §188-191.
8. **Прогнать верификатор** headless и приложить дамп `build/qa/scrum483_ui_render_verifier/` /
   `build/qa/scrum470_hero_select_v4/`.

## Acceptance Criteria

- [ ] Координаты ВСЕХ элементов 5 экранов (победа, смерть, выбор героя v4, выбор оружия, карта
      маршрута) заданы именованными const `Rect2 @2560×1440` рядом с соответствующим билдером
      (паттерн SCRUM-484), для каждого фрейм-экрана есть `*_PANEL_2K`/`*_SAFE_2K`.
- [ ] Ассеты блока подключены; ни один exact-frame TextureRect не использует `STRETCH_SCALE`.
- [ ] Верификатор `tests/ui_no_overlap_matrix_test.gd` **зелёный** на gate-размерах
      1920×1080 / 2560×1440 / 3840×2160 (а также проходит весь набор 1152..3840) — без
      overflow/overlap/text-out/viewport-escape.
- [ ] В матрицу верификатора добавлены и зелены кейсы `weapon_select` и `route_map`; существующие
      `hero_select`/`victory`/`death` остаются зелёными.
- [ ] `docs/design/ui_screens_inventory.md` дополнен таблицами координат блока Результаты/Старт
      и обновлён «Следующий шаг».
- [ ] `runtime_smoke_ui_test.gd` и `runtime_smoke_test.gd` PASS (нет регрессий).
- [ ] Дамп-эвиденс в `build/qa/scrum483_ui_render_verifier/` приложен.

## Files / точки входа

- `scripts/ui_screens.gd:5088 _show_victory_screen` — добавить const-блок `RESULT_*/VS_*`, спека @2K.
- `scripts/ui_screens.gd:5123 _show_death_screen` — const `DS_*` (геометрия = RESULT_*).
- `scripts/ui_screens.gd:749 _build_character_select_v4` — добавить const-блок `HS4_*_2K` (абсолютные px),
  перевести множители 764-928 в задокументированные координаты; старые доли `HS4_*` (693-700) не трогать/депрекейт.
- `scripts/ui_screens.gd:3888 _show_weapon_select` + `:3906 _make_weapon_select_card` — const `WS_*_2K`.
- `scripts/ui_screens.gd:6246 _create_menu_box`, `:6990 _pause_end_modal_display_size`,
  `:6327 _add_result_crest`, `:176-179` (PAUSE_END_MODAL_*) — источники геометрии победы/смерти/оружия (читать, не менять контракт).
- `scripts/route_map_screen.gd:13 _show_battle_map` + `:166 _route_map_canvas_size` — const-блок `RM_*_2K`.
- `scripts/main.gd:26-32` (ROUTE_STEPS_TO_BOSS / MAP_NODE_SIZE / ROUTE_MAP_PADDING / HEADER_HEIGHT / SCREEN_MARGIN) — опорные значения карты.
- `tests/ui_no_overlap_matrix_test.gd:28-91` (матрица) + `:253-264` (`_open_hero_select/_open_victory/_open_death`) —
  добавить `_open_weapon_select` / `_open_route_map` и кейсы в цикл.
- `docs/design/ui_screens_inventory.md:71-191` — образец таблиц + «Следующий шаг».

## Замечания / подводные камни

- **LOCKED PATH `scripts/ui_screens.gd`** (anti-collision, 8114 строк) — экран блокируется за один
  агент-контур (метка `claude`); не пускать сюда параллельные lane. `scripts/progression_data.gd`
  тоже locked — эту задачу он не затрагивает, не лезть.
- **HS4 не использует `HS4_*` доли** (SCRUM-470): билдер `_build_character_select_v4` считает геометрию
  множителями, а `HS4_TITLE`/`HS4_BACK`/… (693-700) — это отдельный нормализованный блок mockup-спеки.
  Новые `*_2K` const должны отражать **реальную** раскладку билдера, не значения долей (они не совпадают:
  напр. `HS4_PORTRAIT_FRAME=Rect2(0.020,0.135,0.247,0.580)` ≈ (51,194,632,835) против реальных (56,179,661,959)).
  Это расхождение задокументировать. Перед удалением/правкой старых `HS4_*` — `grep -rn HS4_TITLE scripts/ tests/`.
- **Победа/смерть — единая геометрия**: панель/safe одинаковы (`_pause_end_modal_display_size` для
  "victory" и "death" даёт тот же 898×820, т.к. height упирается в clamp 820). Можно вынести в общий
  `RESULT_*`. Subtitle победы — 5 строк (`_victory_ascension_summary`), это самый длинный текст: проверить,
  что при 2K он не превышает safe-высоту до скролла; верификатор меряет нужную высоту текста (tol 6px).
- **Выбор оружия и карта НЕ в верификаторе** — их добавление обязательно по AC; route map содержит
  процедурно-рисованные узлы (`_draw_route_nodes`) и ScrollContainer (контент выше viewport — это норма,
  не overflow; верификатор требует viewport-fit только для `_requires_viewport_fit` = level_up/economy,
  карта туда не входит). Не вешать viewport-fit на скроллящийся map_area.
- **Динамическая высота canvas карты** (row_count зависит от `route_nodes`/`ROUTE_STEPS_TO_BOSS`) —
  не хардкодить высоту в const, задокументировать формулой; в const только width (2488), padding, node-size, row_gap.
- **Weapon-select высота-overflow**: стек title+subtitle+(до 4 карточек×189)+back при панели 660 может
  превысить → ScrollContainer скрывает вылет, но дизайн-инвариант «всё помещается» формально нарушится на
  персонажах с 4 оружиями. Если так — либо увеличить таргет панели для weapon_select в
  `_economy_menu_panel_half_size` (добавить ветку match), либо явно задокументировать скролл как приемлемый.
- **Координаты модалок при не-16:9** не меняются (stretch=keep даёт чёрные полосы); при 1080p/4K —
  uniform-скейлятся с viewport. В таблицах указывать значения только @2K (база).
- **Связанные тикеты**: SCRUM-481 (эпик), SCRUM-482 (2K-фундамент, viewport+keep), SCRUM-483 (верификатор-gate —
  расширяем его матрицу), SCRUM-484 (образец блока Меню/Навигация), SCRUM-470 (hero select v4 mockup/доли).
- После правок верификатора пишутся дампы в `build/qa/...` — добавить в `.gitignore`-исключения уже учтено
  (билд-артефакты); коммитить эвиденс по правилам проекта (явный `git add` своих файлов при churn, green-gate ДО коммита).

## QA-Вердикт (2026-06-28)
Статус: PASSED

Проверено:
- Jira issue/current sprint/status/labels/result comment: SCRUM-489, `Контроль качества` -> `Готово`, current `Спринт 0.1.7`, result commit noted by implementer; QA target was current `dev` HEAD `1671e521`.
- Code/docs audit: `RESULT_*`/`VS_*`/`DS_*`, `HS4_*_2K`, `WS_*_2K`, `RM_*_2K`, `ROUTE_MAP_HEADER_HEIGHT := 140.0`, `tests/ui_no_overlap_matrix_test.gd` cases `weapon_select`/`route_map`, and `docs/design/ui_screens_inventory.md` SCRUM-489 section are present.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — PASS; SCRUM-489 dump: `build/qa/scrum489/results_block_no_overlap_matrix.md`.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_combat_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_progression_economy_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS (exit 0; existing non-fatal `data.tree is null` warnings during weapon-attachment sampling).
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/meta_progression_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/melee_weapon_targeting_test.gd` — PASS (exit 0; same non-fatal `data.tree is null` warning pattern).
- Monolithic `runtime_smoke_test.gd`: two normal runs returned code 247 with no assertion output after duplicate-artifact guard; isolated rerun with `--user-data-dir /tmp/fsd_qa_489_runtime` PASS. Treated as environment/user-data noise, not a SCRUM-489 defect.

Краевые случаи:
- Matrix covers `1152x648`, `1280x720`, `1600x900`, `1920x1080`, `2560x1440`, `3840x2160`.
- Verified new SCRUM-489 surfaces specifically: victory, death, hero_select, weapon_select, route_map.
- Route map canvas taller than viewport is accepted as scroll-content; overlap uses visible clipped rects inside `ScrollContainer`.

Баги: нет.
