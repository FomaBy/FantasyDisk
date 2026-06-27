# SCRUM-488: Блок Прогрессия: координаты @2K + интеграция (магазин/докача/дерево/кодекс/настройки)

Jira: SCRUM-488 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-481 (UI Overhaul 2K)
Статус: К выполнению / To Do

## Что и зачем

Эпик SCRUM-481 переводит ВЕСЬ интерфейс игры на единую дизайн-базу **2560×1440 (2K, 16:9)**:
1080p ужимает её uniform-downscale, 4K растягивает uniform-upscale, нестандартное
соотношение даёт чёрные полосы (`stretch=canvas_items`, `aspect=keep`). Для каждого
экрана точные координаты контента `x, y, w, h` @2K выносятся в **именованные const рядом
с билдером** — эти прямоугольники служат входом для рисующего скрипта (он генерит ассеты
рамок/фонов ровно в эти размеры) и гарантируют, что ничего не вылазит, не наслаивается и
текст не выходит за рамку фрейма.

Блок «Меню/Навигация» (8 экранов) уже сделан этим способом — **SCRUM-484** (см. коммит
`f0b0a5c2`, const-блоки `MM_*`, `QC_*`, `CR_*`, `PM_*`, `PD_*`, `GT_*`, `ST_*`, `FB_*` в
`scripts/ui_screens.gd` и секцию «Координатная спека @2560×1440 — блок Меню/Навигация» в
`docs/design/ui_screens_inventory.md`). SCRUM-488 — **следующий блок: Прогрессия/Экономика**,
6 экранов:

| # | Экран | Билдер | Текущее состояние |
|---|---|---|---|
| 8 | Магазин (`ShopScreen`) | `_show_shop_screen` | anchor-фракции, НЕТ 2K-const |
| 9 | Докача / атрибут-шоп (`AttributeShopScreen`) | `_show_attribute_shop` | clamp от вьюпорта, НЕТ 2K-const |
| 10 | Дерево навыков (`SkillTreeScreen`) | `_show_skill_tree_screen` | offset-раскладка, НЕТ 2K-const |
| 15 | Кодекс + разделы (`CodexScreen`) | `_show_codex_screen` / `_show_codex_section` | V2-const есть, но база **1920×1080**, НЕ 2K |
| 16 | Настройки (`SettingsContentPanel`) | `_show_settings_menu` | V2-const есть, но база **1536×924 / 986×900**, НЕ 2K |

Цель с точки зрения продукта: одинаковый, выверенный вид этих плотных экранов на 1080p/2K/4K,
без overflow/overlap/обрезки текста, плюс единый код-контракт координат для рисующего скрипта.
Особое внимание — **помещаемости плотных экранов**: дерево навыков (N веток × M узлов + панель
класса), кодекс (3 колонки: навигация/список/деталь), докача (до 4+ карточек опций), настройки
(табы + строки контролов).

## Текущее состояние в коде

Все билдеры — в `scripts/ui_screens.gd` (8114 строк, класс-хелпер UI). Раскладка сейчас НЕ
привязана к 2K-базе единообразно:

### Магазин — `_show_shop_screen` (ui_screens.gd:4480)
- Корень `ShopScreen` full-rect; фон через `_add_screen_background(root, "shop")`.
- Заголовок `ShopHeader` (`title_box`): anchor center-top, offset_top=104, h≈86 (строки 4499-4525).
- «Стена лавки» `ShopParchmentWall`: **anchor-фракции** `left=0.20, top=0.38, right=0.80, bottom=0.75`
  (строки 4529-4540) — слоты предметов раскидываются `_shop_wall_slot_anchor(index)` (ui_screens.gd:4705)
  внутри `ShopInlineItems` с размером `SHOP_INLINE_SLOT_SIZE` (const из `ShopUIConstants`, ui_screens.gd:62).
- Кнопка «Назад» `ShopLeaveButton`: anchor bottom-center, offset_top=-126, h=68 (строки 4562-4578).
- Слот предмета `_make_shop_item_slot` (ui_screens.gd:4581): иконка `SHOP_INLINE_ICON_SIZE`,
  contact-shadow, price-badge, affinity-note. **Нет ни одного `*_2K`-const для координат стены/слотов.**

### Докача — `_show_attribute_shop` (ui_screens.gd:1800)
- Панель `AttributeShopPanel`: ширина `clamp(viewport.x-48, [640, 1100])`, верт. поля
  `clamp(viewport.y*0.045, [18, 28])` (строки 1822-1836) — адаптив от вьюпорта, не фикс-2K.
- Внутри: `ScrollContainer` с карточками `AttributeOffers` (`GridContainer`, 1 колонка при
  panel_width<820, иначе 2; строки 1873-1879) + закреплённые ВНЕ скролла кнопки
  «Обновить»/«Пропустить» `AttributeShopActions` (строки 1883-1901, SCRUM-467).
- Карточки опций используют `ECONOMY_CHOICE_TARGET_*` (720/1080/1440, ui_screens.gd:169-171) —
  ЕДИНСТВЕННЫЙ задел под разрешения, но это размер карточки, не полная координатная спека панели.

### Дерево навыков — `_show_skill_tree_screen` (ui_screens.gd:2012)
- `SkillTreeMainPanel`: offset full-rect `48/26/-48/-26` (строки 2027-2035).
- `layout` (VBox) offset `136/118/-136/-108` (строки 2037-2044): header (title + points-badge +
  back) → hint → body (HBox).
- `body`: слева `SkillTreeClassPanel` `min_size 330×210` (SCRUM-360, класс-прогресс), справа
  `ScrollContainer`→`SkillTreeBranches` (HBox) с панелями веток `SkillTreeBranchPanel_*`
  `min_size 164×430` по `META_PROGRESSION.SKILL_BRANCHES` (строки 2082-2208).
- **Координаты — через offset/min_size, без 2K-const.** Самый плотный экран: ширина зависит от
  числа веток × ширину панели; на узких разрешениях горизонтальный скролл.

### Кодекс — `_show_codex_screen` / `_show_codex_section` (ui_screens.gd:2327 / 2415)
- **Уже на V2-координатной системе**, НО база `CODEX_V2_BASE_SIZE := Vector2(1920.0, 1080.0)`
  (ui_screens.gd:226), НЕ 2K. Const-блок `CODEX_V2_*` (ui_screens.gd:226-242):
  `CODEX_V2_OUTER_FRAME_RECT (24,20,1872,1040)`, `CODEX_V2_HEADER_TITLE_SAFE`,
  `CODEX_V2_BACK_BUTTON_SAFE`, `CODEX_V2_NAV_PANEL_RECT (72,170,304,872)`, `CODEX_V2_NAV_SAFE`,
  `CODEX_V2_LIST_PANEL_RECT (388,170,835,872)`, `CODEX_V2_DETAIL_PANEL_RECT (1242,170,606,872)`,
  `CODEX_V2_PORTRAIT_SAFE`, `CODEX_V2_CHIP_ROW_SAFE`, `CODEX_V2_ENTRY_CARD_SOURCE_SIZE`.
- Масштабирование: `_codex_v2_scale()` (ui_screens.gd:2541), `_codex_v2_scaled_rect`,
  `_codex_v2_apply_layout(entries)` (ui_screens.gd:2574), `_codex_v2_register_rect`.
- 3-колоночная раскладка (навигация/список/деталь) + хедер + back. Разделы (под-вкладки одного
  экрана): `_build_codex_characters` (2822), `_monsters` (2854), `_artifacts` (2883),
  `_ascensions` (2912), `_stats` (2928), `_glossary` (2954). Список — ленивая сборка по табу.

### Настройки — `_show_settings_menu` (ui_screens.gd:3065)
- **Уже на V2-системе**, НО база `_settings_v2_modal_rect()` считает референс **1536×924**
  (ui_screens.gd:2981-2996) и source-size рамки `SETTINGS_V2_MAIN_SOURCE_SIZE := Vector2(986.0, 900.0)`
  (ui_screens.gd:114) — НЕ 2K. Модалка: `width=clamp(viewport.x*0.80,[1024,2048])`, высота по
  аспекту `924/1536`, clamp по `viewport.y*0.88`.
- Структура: `SettingsV2Modal` → frame + title (референс-rect `144,94,1248,48` через
  `_settings_v2_scaled_modal_rect`, строка 3100) + таб-свитчер `_make_settings_tab_switcher`
  (`_settings_v2_tab_switcher_size`, `_settings_v2_switcher_top`) + `SettingsContentPanel`
  (`_settings_v2_content_panel_rect`, ui_screens.gd:3019) с табами «Экран»/«Управление».
- Строки контролов: `_add_settings_control_row` (ui_screens.gd:3482), OptionButton'ы
  разрешения/режима окна `min_size 520×62` и т.д.

### Верификатор (acceptance «зелёный 1080p/2K/4K»)
Эталон проверки уже есть: `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md`
(SCRUM-483) — снимает P (position) и S (size) ключевых нод на gate-размерах **1920×1080,
2560×1440, 3840×2160** и фиксирует, что текст-контролы не вылазят и фреймы не наслаиваются.
В матрице уже перечислены `shop`/`settings`/`codex`/`skill_tree`. Прогон верификатора на этих
трёх размерах должен быть зелёным после изменений.

## Что сделать — по шагам

Действуй ровно по образцу SCRUM-484 (тот же стиль const-блоков и та же секция в инвентаре).

1. **Дай каждому из 6 экранов именованный const-блок `*_2K` рядом с билдером** в
   `scripts/ui_screens.gd`. Для каждого слота контента — `Rect2(x, y, w, h)` при базе 2560×1440,
   плюс `*_SAFE_2K` (пустая зона внутри рамки под контент) и при необходимости `*_DESIGN_BASE_2K`
   / `*_DIM_2K`. Значения **вычислять из реальной раскладки билдера** (как в SCRUM-484:
   «все значения вычислены из реальной раскладки билдеров»), НЕ выдумывать. Префиксы — по аналогии:
   - Магазин → `SHOP_*_2K` (стена `SHOP_WALL_2K`, заголовок `SHOP_TITLE_2K`/`SHOP_SUBTITLE_2K`,
     сетка слотов `SHOP_SLOT_2K` × позиции из `_shop_wall_slot_anchor`, кнопка `SHOP_BACK_2K`,
     `SHOP_SAFE_2K`).
   - Докача → `ATTR_*_2K` (панель `ATTR_PANEL_2K`, `ATTR_SAFE_2K`, заголовок/деньги, грид опций
     `ATTR_OFFERS_2K` + карточка-шаблон, фикс-низ `ATTR_ACTIONS_2K` с кнопками reroll/skip).
   - Дерево навыков → `SKILL_*_2K` (`SKILL_MAIN_PANEL_2K`, `SKILL_SAFE_2K`, хедер
     `SKILL_TITLE_2K`/`SKILL_POINTS_BADGE_2K`/`SKILL_BACK_2K`, `SKILL_HINT_2K`,
     `SKILL_CLASS_PANEL_2K`, область веток `SKILL_BRANCHES_2K` + панель-ветка-шаблон
     `SKILL_BRANCH_2K` + узел-шаблон).
   - Кодекс → нормализовать `CODEX_V2_*` к 2K (см. шаг 2).
   - Настройки → нормализовать к 2K (см. шаг 2).

2. **Привести Кодекс и Настройки к 2K-базе.** Сейчас Кодекс на 1920×1080, Настройки на
   1536×924 / 986×900. Варианты (выбери минимально-инвазивный, не ломающий рантайм):
   - (а) пересчитать существующие V2-const на 2560×1440 (умножив 1920→2560 = ×4/3 для кодекса)
     и обновить `CODEX_V2_BASE_SIZE` / settings-референсы; ИЛИ
   - (б) если ради обратной совместимости рантайм-масштабирование оставляем как есть — добавить
     ОТДЕЛЬНЫЙ документирующий `*_2K`-блок (как у Меню/Нав) поверх существующих V2-const, чтобы
     рисующий скрипт получил 2K-вход, а рантайм не трогать.
   Реши и зафиксируй выбор в комментарии у блока. Главное: на выходе для рисующего скрипта есть
   2K-координаты, а рантайм по-прежнему uniform-скейлится без регрессий.

3. **Проверить помещаемость плотных экранов.** Для каждого экрана прогнать раскладку на
   1920×1080, 2560×1440, 3840×2160 и убедиться: ничего не за экраном, слоты не наслаиваются,
   текст в рамках. Особое внимание:
   - Дерево навыков: при максимальном числе веток (`META_PROGRESSION.SKILL_BRANCHES`) сумма
     ширин панелей-веток + class-panel не должна требовать горизонтального скролла на 2K;
     если требует — это и есть overflow, заложить ширины/separation так, чтобы влезало @2K.
   - Докача: при 4+ опциях (ветка Знаний, `attr_extra_options`) грид + фикс-кнопки без обреза.
   - Кодекс: 3 колонки (`NAV+LIST+DETAIL`) суммарно ≤ 2560 минус поля рамки.
   - Настройки: таб-свитчер не наезжает на заголовок, контент-панель не выходит за нижний back.

4. **Задокументировать в `docs/design/ui_screens_inventory.md`** новую секцию «Координатная
   спека @2560×1440 — блок Прогрессия/Экономика (SCRUM-488)» — ровно в формате секции SCRUM-484:
   на каждый из 6 экранов таблица `Слот | const | x | y | w | h`, ссылка на билдер и const-блок,
   строка про инварианты. Обновить нижний абзац «Следующий шаг» (вычеркнуть экономику/кодекс/
   настройки из списка остатков).

5. **Прогнать верификатор** (`build/qa/scrum483_ui_render_verifier`, матрица
   `ui_render_verifier_matrix.md`) на 1080p/2K/4K и убедиться, что секции shop/attribute_shop/
   skill_tree/codex/settings зелёные (нет overflow/overlap/text-out). При наличии headless-теста
   раскладки — добавить/обновить ассерты под новые `*_2K`-const.

## Acceptance Criteria

- [ ] Координаты ВСЕХ элементов 6 экранов блока (магазин, докача, дерево навыков, кодекс +
      разделы, настройки) вынесены в именованные `const ... _2K := Rect2(...)` рядом с билдерами
      в `scripts/ui_screens.gd`, при базе 2560×1440.
- [ ] У каждого экрана есть `*_SAFE_2K` (пустая зона под контент внутри рамки) — контент не
      ложится на орнамент рамки (frame content safe-area rule, AGENTS.md/qa_protocol).
- [ ] Кодекс и Настройки приведены к 2K-базе (либо пересчётом V2-const, либо отдельным 2K-блоком
      для рисующего скрипта) — выбор зафиксирован в комментарии.
- [ ] Плотные экраны без overflow/overlap/обрезки текста на 1920×1080, 2560×1440, 3840×2160
      (особенно дерево навыков при макс. числе веток и докача при 4+ опциях).
- [ ] Нестандартное соотношение — чёрные полосы (stretch=keep), координаты модалок не меняются.
- [ ] Секция «@2560×1440 — блок Прогрессия/Экономика (SCRUM-488)» добавлена в
      `docs/design/ui_screens_inventory.md` по формату SCRUM-484; обновлён «Следующий шаг».
- [ ] Верификатор (`scrum483_ui_render_verifier`) зелёный на 1080p/2K/4K для всех 6 экранов; парс
      `ui_screens.gd` без ошибок (Godot 4 headless), рантайм-открытие каждого экрана не падает.
- [ ] Рантайм-поведение не регрессировало: экраны открываются/масштабируются как раньше на всех
      трёх gate-размерах.

## Files / точки входа

- `scripts/ui_screens.gd:4480` — `_show_shop_screen`: добавить блок `SHOP_*_2K` рядом; вынести
  координаты стены/слотов/заголовка/кнопки. Связано: `_shop_wall_slot_anchor` (4705),
  `_make_shop_item_slot` (4581), `SHOP_INLINE_SLOT_SIZE`/`SHOP_INLINE_ICON_SIZE` (62-63).
- `scripts/ui_screens.gd:1800` — `_show_attribute_shop`: блок `ATTR_*_2K`; зафиксировать панель,
  грид опций, фикс-низ. Учесть `ECONOMY_CHOICE_TARGET_1440` (171) как размер карточки @2K.
- `scripts/ui_screens.gd:2012` — `_show_skill_tree_screen`: блок `SKILL_*_2K`; самый плотный
  экран — выверить ширины веток/class-panel под 2K без гориз. скролла.
- `scripts/ui_screens.gd:2327` / `2415` — `_show_codex_screen` / `_show_codex_section`:
  нормализовать `CODEX_V2_*` (226-242, база 226) к 2K; затронуть `_codex_v2_scale`/
  `_codex_v2_apply_layout` (2541-2590) если меняешь базу.
- `scripts/ui_screens.gd:3065` — `_show_settings_menu`: нормализовать к 2K; референсы
  `_settings_v2_modal_rect` (2981), `SETTINGS_V2_MAIN_SOURCE_SIZE` (114),
  `_settings_v2_content_panel_rect` (3019), `_make_settings_tab_switcher` (3367),
  `_add_settings_control_row` (3482).
- `docs/design/ui_screens_inventory.md` — новая секция + апдейт «Следующий шаг» (строки ~188-191).
- `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md` — эталон проверки на
  1080p/2K/4K (читать как образец; перегенерить/сверить после изменений).

## Замечания / подводные камни

- **ANTI-COLLISION / LOCKED PATHS.** `scripts/ui_screens.gd` — горячий многоисполнительский файл
  (он же locked path по MEMORY/AGENTS, как и `scripts/progression_data.gd`). Работай в своём
  worktree, коммить ЯВНЫМ `git add` СВОИХ хунков (не `git add -A` — чужие незакоммиченные хунки
  втягиваются), держи green-gate ДО коммита. `scripts/progression_data.gd` НЕ трогать —
  координаты живут в `ui_screens.gd`; данные веток/классов — read-only из `META_PROGRESSION`.
- **Образец — SCRUM-484** (коммит `f0b0a5c2`): тот же стиль `*_2K`-const, та же секция инвентаря,
  тот же набор инвариантов (ничего за экраном / без наслоений / текст в рамках / safe-area =
  пустая зона). Держи единообразие имён и формата.
- **Уже существующие V2-системы.** Кодекс (1920×1080) и Настройки (1536×924/986×900) уже имеют
  рабочее масштабирование — НЕ ломай рантайм при переводе на 2K. Если рантайм-формулы завязаны на
  старый референс, безопаснее путь (б) из шага 2: добавить документирующий 2K-блок поверх, не
  меняя рантайм-масштабирование.
- **Плотность — главный риск.** Дерево навыков масштабируется числом веток × шириной панели; на
  узких/нестандартных это даёт гориз. скролл (видно в матрице SCRUM-483: `SkillTreeBranches`
  S=(1292,1293) при content больше панели). @2K заложи ширины так, чтобы все ветки + class-panel
  влезали без скролла; на 1080p допускается скролл, но без обрезки текста.
- **Frame content safe-area rule** (глобально в AGENTS.md + qa_protocol): UI-контент только в
  пустой зоне фрейма, не на орнаменте рамки — отсюда обязательные `*_SAFE_2K`.
- **Связанные тикеты:** SCRUM-481 (эпик), SCRUM-484 (блок Меню/Нав — образец, done), SCRUM-483
  (верификатор рендера — инструмент проверки). Дизайн-ассеты рамок прогрессии/экономики —
  существующие `PROGRESSION_*`/`ECONOMY_*`/`CODEX_V2_*`/`SETTINGS_V2_*` source-size const
  (ui_screens.gd:153-242); если рисующий скрипт перегенерит их под 2K — это отдельная design-задача.
- **Верификация headless:** Godot 4.6.3 в `~/Downloads/Godot.app` (см. MEMORY qa-test-runner);
  парсить `ui_screens.gd` и гонять верификатор headless; помнить про `--user-data-dir` не
  изолирующий мета-сейв (ложные red'ы из реального unlocks-сейва — нейтрализовать мету при сомнении).
