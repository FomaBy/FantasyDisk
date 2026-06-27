# SCRUM-487: Блок Боевые: координаты @2K + интеграция (HUD/событие/награды/level-up)

Jira: SCRUM-487 · Роль: backend+design (claude) · Контур: ui-overhaul-2k · Приоритет: P1 · foma · Эпик: SCRUM-481
Статус: К выполнению

## Что и зачем

Это очередной блок глобального UI-редизайна под базу **2560×1440 (16:9)** (эпик SCRUM-481).
Аналог уже сделанного блока Меню/Навигация (SCRUM-484), но теперь для **боевого блока** —
всего, что игрок видит во время и сразу после боя.

Цель: вынести точные координаты `x, y, w, h` всех элементов боевого блока @2K в
**именованные код-константы рядом с билдерами** (как `MM_*`, `QC_*`, `PM_*`, `FB_*` в
SCRUM-484). Эти прямоугольники — единственный источник правды и для раскладки в рантайме,
и для **рисующего скрипта** (генератора ассетов: он рисует рамки/панели ровно в эти размеры,
без растяжения орнамента). Плюс прогнать это через верификатор no-overlap на 1080p/2K/4K.

Зачем игроку: на 2K/4K-мониторах боевой HUD сейчас раскладывается «на проценты» от ширины
вьюпорта (`viewport_width * 0.54` и т.п.) с рантайм-клампами — это держит элементы в экране,
но не даёт детерминированной 2K-раскладки, под которую можно нарисовать ассеты в точный
размер. После задачи HUD, баннеры, экраны события и наград имеют фиксированную @2K-сетку:
ничего не вылазит, не наслаивается, текст в рамках, ассеты в нативном размере на всех трёх
эталонных разрешениях.

**Состав боевого блока** (по `docs/design/ui_screens_inventory.md`):
- #5 Бой / HUD — таймер, панель ресурсов (HP/XP/Gold/ULT), бейдж возвышения, ряд артефактов,
  дамаг-флэш, угловая кнопка повышения уровня с бейджем.
- #6 Событие — `_show_event_screen` (карточки выбора).
- #11 Повышение уровня — `_show_level_up_screen` (оверлей с 3 карточками + «Позже»).
- #12 Награда обычная — `_show_reward_screen` (3 карточки).
- #13 Награда элитки / артефакт — `_show_elite_artifact_reward` (панель + 3 карточки).
- #28 Тост повышения уровня — `_show_level_up_toast`.
- #29 Баннер заголовка боя — `_show_combat_title_banner` (появление элитки/босса).
- #30 Баннер победы — `_show_victory_banner`.

Ожидаемый результат: новые `*_2K`-const для каждого слота этих 8 состояний, ассеты подключены,
верификатор `tests/ui_no_overlap_matrix_test.gd` зелёный на 1920×1080 / 2560×1440 / 3840×2160,
и описание координат добавлено в `docs/design/ui_screens_inventory.md` отдельной секцией
«Координатная спека @2560×1440 — блок Боевые (SCRUM-487)».

## Текущее состояние в коде

Файл: **`scripts/ui_screens.gd`** (8114 строк; locked path — см. подводные камни).

### HUD (#5) — `_create_hud` (7553) + `_layout_combat_hud` (7650)
- `_create_hud()` строит `CombatHudRoot` (Control, FULL_RECT) на отдельном `CanvasLayer` и
  вызывает: `_create_resource_hud_panel(root, Vector2(20,18))`, `_create_combat_timer_panel`,
  `_create_artifact_hud_row`, `_create_damage_flash_overlay`, потом `_layout_combat_hud(root)`
  (и `call_deferred`), `_update_level_up_button`, `_update_hud`.
- **Раскладка сейчас процентная/клампленная, без 2K-сетки.** `_layout_combat_hud` (7650):
  - `margin := 18.0`, `gap := 14.0`, `timer_size := Vector2(288, 96)`.
  - `RunResourceHud`: ширина `clampf(viewport_width * 0.54, 650, 820)`, на ≤1280 ужимается до 690;
    позиция `(margin, 18)`, высота 84.
  - `CombatTimerPanel`: центрируется `viewport_width*0.5 - timer.x*0.5`, с защитой от
    наезда на ресурс-панель и от выхода за `right_limit`; pos.y=14.
  - `AscensionHudBadge` (64×64): якорится справа от таймера (`timer_left + timer_size.x + 8`),
    с откатом под панель если не влезает.
  - `ArtifactHudRow` (HFlowContainer): ширина `clampf(viewport_width*0.28, 220, 402)`,
    прижата вправо `viewport_width - row_width - margin`, top=16, со сдвигом вниз при коллизии.
- `_create_combat_timer_panel` (7581): таймер-панель `custom_minimum_size = Vector2(192,64)`,
  стиль `_timer_panel_style` рисуется от source-size `Vector2(616,286)` через
  `COMBAT_HUD_TIMER_MARGINS`/`_CONTENT` (148–149). На боссах таймер не создаётся
  (`game.boss_combat_active`). Бейдж возвышения только при `selected_ascension_level > 0`.
- `_create_resource_hud_panel` (7886): `RunResourceHud` `custom_minimum_size = Vector2(690,72)`,
  внутри HBox с 4 карточками `Hud*Card` по `Vector2(132,48)` (HP/XP/Gold/ULT), бар 58×8.
- `_create_artifact_hud_row` (7637): `custom_minimum_size = Vector2(402,104)`, иконки 48×48.
- `_create_damage_flash_overlay` (7843): `DamageFlashOverlay` ColorRect FULL_RECT,
  красный, alpha 0 → 0.20 пик при `_on_player_damaged` (7855).
- Угловая кнопка повышения: `_update_level_up_button` (5519) — `LevelUpPlusButton` якорь
  bottom-right, offsets `(-124,-124)..(-28,-26)`, `custom_minimum_size Vector2(96,98)`,
  + `LevelUpPlusBadgePanel` (счётчик непотраченных пиков).
- Ассет-пути уже есть: `COMBAT_HUD_FRAME_DIR`/`COMBAT_HUD_FILL_DIR` (120–121),
  `COMBAT_HUD_TIMER_PATH`, `COMBAT_HUD_ASCENSION_BADGE_PATH`, `COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES`,
  бар-филлы, медальон золота (129–152). Координат @2K для слотов HUD **нет**.

### Событие (#6) — `_show_event_screen` (4996)
- Корень `EventScreen` через `_create_menu_box(title, story, "event")`; HUD через
  `_create_menu_run_hud`; ряд выборов `_make_economy_choice_row("EventChoiceRow", size, 3)`,
  карточки `EventChoiceButton{0..2}`, кнопка `EventBackButton` (380×54).
- Размер карточки `_economy_choice_display_size(3)` → выбирает из
  `ECONOMY_CHOICE_TARGET_720/1080/1440` (169–171). То есть у экономики 2K-таргеты уже есть,
  но это размер карточки, не полная сетка координат экрана события.

### Повышение уровня (#11) — `_show_level_up_screen` (4038)
- `_level_up_layout_metrics()` (6400) → dict с `card_size`, `card_gap` и т.п.;
  `_create_level_up_menu_box` (6428) строит панель `LevelUpPanel` со стилем `_level_up_panel_style`.
  `LevelUpRewardsRow` (HFlowContainer, 3 карточки `LevelUpRewardButton{0..2}`), кнопка
  `LevelUpLaterButton` (260×72). Координаты — из layout-метрик, **не** именованных `*_2K` const.

### Награда обычная (#12) — `_show_reward_screen` (4004)
- `_create_menu_box("Награда за бой", ...)`; `BattleRewardCardsRow` (HBox), карточки
  `BattleRewardButton{0..2}` размером `REWARD_CARD_SIZE = Vector2(300,430)` (250), separation 18.

### Награда элитки (#13) — `_show_elite_artifact_reward` (4124)
- Свой `CanvasLayer` + `EliteArtifactRewardScreen` (FULL_RECT) + shade + CenterContainer +
  `EliteArtifactRewardPanel` `custom_minimum_size = Vector2(1140,640)` (стиль `_level_up_panel_style`).
  Заголовок 52pt, сабтайтл 20pt, ряд `EliteArtifactRewardRow` (HBox), карточки
  `EliteArtifactRewardButton{0..2}` размером `REWARD_ELITE_CARD_SIZE = Vector2(320,430)` (251).

### Тост/баннеры (#28–#30)
- `_show_level_up_toast` (5446): инстанс `LEVEL_UP_TOAST_SCENE` → `LevelUpToast` в hud_layer
  (позиция/размер заданы в самой сцене, не в коде).
- `_show_combat_title_banner` (5481): `CombatIntroBanner` Label, anchor center-top,
  `offset_left=-640, offset_right=640, offset_top=120/92, offset_bottom=+90/56` (т.е. ширина
  1280 — ровно ширина 720p, НЕ 2K-база), font 66/40, твин fade-in/out, самоосвобождается.
- `_show_victory_banner` (1731): свой `CanvasLayer` (layer 80) + `VictoryBanner` (click-catcher
  FULL_RECT) + shade + `VictoryBannerLabel` "ПОБЕДА" 96pt по центру; авто-продолжение через 1.3с.

### Верификатор — `tests/ui_no_overlap_matrix_test.gd`
- `VIEWPORT_SIZES` (4–11): 1152×648, 1280×720, 1600×900, **1920×1080, 2560×1440, 3840×2160**.
  `SCRUM483_GATE_SIZES` (12) — именно эталонная тройка 1080p/2K/4K (это «зелёный» гейт из AC).
- `_check_screen(size, name, opener, [node_names], dump, errors[, require_text])` проверяет:
  fit во вьюпорт, peer-overlap, text-overflow (tolerance 6px), parent-containment, exact-frame
  stretch у TextureRect (комментарий на 24–25).
- Уже покрыты openers: `level_up` (47), `battle_reward` (68), `elite_reward` (71),
  `event_economy` (88). **НЕ покрыты:** боевой HUD (`_create_hud`), `combat_title_banner`,
  `victory_banner`, `level_up_toast`. Их openers (`_open_combat_hud`, …) в тесте отсутствуют.

### Инвентарь — `docs/design/ui_screens_inventory.md`
- Базовая политика 2K (7–18), список 30 экранов (#5 HUD, #6 событие, #11–13 награды/левелап,
  #28–30 тост/баннеры). Секция «Координатная спека @2560×1440 — блок Меню/Навигация (SCRUM-484)»
  (71–190). В конце (188–190) явно сказано, что блок «карта/бой/HUD … баннеры/тосты» ещё остаётся.

## Что сделать — по шагам

1. **Снять реальную @2K-сетку каждого слота.** Для каждого из 8 состояний посчитать
   `x, y, w, h` при базе 2560×1440 из фактической раскладки билдеров (как в SCRUM-484).
   Для HUD — перевести текущую процентную/клампленную раскладку в фиксированные 2K-прямоугольники
   (учесть верхний бар: ресурс-панель слева, таймер по центру, бейдж возвышения, ряд артефактов
   справа; кнопка повышения и её бейдж — нижний правый угол; дамаг-флэш — full-rect overlay).

2. **Добавить именованные const рядом с билдерами** (стиль SCRUM-484: `Rect2(x,y,w,h)` +
   `*_DESIGN_BASE_2K := Vector2(2560,1440)` + `*_SAFE_2K` для панелей с рамкой). Префиксы по
   состояниям, напр.:
   - HUD: `CHUD_DESIGN_BASE_2K`, `CHUD_RESOURCE_PANEL_2K`, `CHUD_TIMER_2K`, `CHUD_ASCENSION_BADGE_2K`,
     `CHUD_ARTIFACT_ROW_2K`, `CHUD_LEVELUP_BUTTON_2K`, `CHUD_LEVELUP_BADGE_2K`, `CHUD_DAMAGE_FLASH_2K`.
   - Событие: `EVT_*` (панель/safe/заголовок/история/ряд карточек/карточка/кнопка «Назад»).
   - Левелап: `LU_*` (панель/safe/заголовок/сабтайтл/ряд/карточка/кнопка «Позже»).
   - Награда обычная: `RWD_*` (заголовок/сабтайтл/ряд/карточка ×3).
   - Награда элитки: `ELR_*` (панель/safe/заголовок/сабтайтл/ряд/карточка ×3).
   - Тост: `LUT_*`; баннер боя: `CTB_*`; баннер победы: `VBN_*`.

3. **Переключить билдеры на эти const.** В `_layout_combat_hud`, `_create_*`-функциях HUD,
   `_show_event_screen`, `_show_level_up_screen`, `_show_reward_screen`,
   `_show_elite_artifact_reward`, `_show_combat_title_banner`, `_show_victory_banner`
   позиционировать/масштабировать от `*_2K`-const (масштабируя относительно
   `viewport.size / DESIGN_BASE_2K`, как делают остальные блоки), а не от «магических» процентов.
   Сохранить существующие защиты (босс без таймера; бейдж возвышения только при asc>0; авто-fade
   баннеров; самоосвобождение). Для `CombatIntroBanner` исправить ширину 1280 → 2K-эквивалент,
   чтобы текст центрировался по 2K-базе, а не по 720p.

4. **Подключить/проверить ассеты.** Убедиться, что фреймы/филлы боевого HUD и панелей наград
   существуют по путям `COMBAT_HUD_FRAME_DIR`/`COMBAT_HUD_FILL_DIR` (и `ARTIFACT_ICON_DIR`),
   рисуются в свой нативный размер (exact-frame stretch, без растяжения орнамента). Недостающие —
   сгенерировать рисующим скриптом ровно по `*_2K`-размерам (через `fantasydisk-asset-generator`,
   прозрачный фон). Координаты `*_2K` отдаются скрипту как вход.

5. **Расширить верификатор.** В `tests/ui_no_overlap_matrix_test.gd` добавить openers и
   `_check_screen`-вызовы для боевого HUD (`combat_hud` → `_open_combat_hud`, узлы
   `RunResourceHud`, `CombatTimerPanel`, `ArtifactHudRow`, `LevelUpPlusButton`), и при возможности
   для `combat_title_banner` / `victory_banner` / `level_up_toast` (или явно отметить транзиентные
   баннеры как проверяемые отдельным кейсом). Прогнать на всех `VIEWPORT_SIZES`, гейт —
   `SCRUM483_GATE_SIZES` (1080p/2K/4K) зелёный.

6. **Дописать секцию в инвентарь.** Добавить «## Координатная спека @2560×1440 — блок Боевые
   (SCRUM-487)» в `docs/design/ui_screens_inventory.md` (таблицы `Слот | const | x | y | w | h`
   по образцу секции SCRUM-484), и обновить «Следующий шаг» (убрать бой/HUD и баннеры/тосты из
   списка оставшегося).

7. **Прогнать smoke-тесты** (`runtime_smoke_combat_test.gd`, `runtime_smoke_ui_test.gd`,
   `ui_no_overlap_matrix_test.gd`, `display_resolution_test.gd`) headless через Godot 4.6.3.

## Acceptance Criteria

- [ ] Координаты всех элементов боевого блока @2K вынесены в именованные `*_2K`-const в
      `scripts/ui_screens.gd` рядом со своими билдерами (HUD, событие, награда обычная,
      награда элитки, повышение уровня, тост, баннер боя, баннер победы).
- [ ] Каждый билдер боевого блока позиционирует элементы от этих const (а не от процентов
      ширины вьюпорта / «магических» offset вроде 1280 в `CombatIntroBanner`).
- [ ] Ассеты боевого блока подключены и рисуются в свой нативный размер (exact-frame stretch,
      орнамент рамки не растягивается); недостающие сгенерированы по `*_2K`-размерам.
- [ ] Верификатор `tests/ui_no_overlap_matrix_test.gd` зелёный на 1920×1080 / 2560×1440 / 3840×2160
      (нет overflow / overlap / text-out), и покрывает боевой HUD (а не только level_up/reward/event).
- [ ] На 1080p 2K-сетка uniform-ужимается, на 4K — uniform-растягивается; нестандартное
      соотношение даёт чёрные полосы (stretch=keep) без смещения координат.
- [ ] На босс-файте таймер по-прежнему не создаётся; бейдж возвышения только при asc>0;
      баннеры по-прежнему авто-затухают и самоосвобождаются; дамаг-флэш работает.
- [ ] Секция «Координатная спека @2560×1440 — блок Боевые (SCRUM-487)» добавлена в
      `docs/design/ui_screens_inventory.md`; «Следующий шаг» обновлён.
- [ ] Smoke-тесты (combat/ui/no-overlap/display_resolution) проходят headless.

## Files / точки входа

- `scripts/ui_screens.gd:7553` — `_create_hud` — собирает боевой HUD; точка интеграции const.
- `scripts/ui_screens.gd:7650` — `_layout_combat_hud` — заменить процентную раскладку на `CHUD_*_2K`.
- `scripts/ui_screens.gd:7581` — `_create_combat_timer_panel` — таймер + бейдж возвышения от const.
- `scripts/ui_screens.gd:7637` — `_create_artifact_hud_row` — ряд артефактов от `CHUD_ARTIFACT_ROW_2K`.
- `scripts/ui_screens.gd:7886` — `_create_resource_hud_panel` — HP/XP/Gold/ULT панель от `CHUD_RESOURCE_PANEL_2K`.
- `scripts/ui_screens.gd:7843` — `_create_damage_flash_overlay` — `CHUD_DAMAGE_FLASH_2K`.
- `scripts/ui_screens.gd:5519` — `_update_level_up_button` — угловая кнопка/бейдж от `CHUD_LEVELUP_BUTTON_2K`.
- `scripts/ui_screens.gd:4996` — `_show_event_screen` — экран события (`EVT_*`).
- `scripts/ui_screens.gd:4038` — `_show_level_up_screen` — оверлей повышения (`LU_*`).
- `scripts/ui_screens.gd:4004` — `_show_reward_screen` — обычная награда (`RWD_*`).
- `scripts/ui_screens.gd:4124` — `_show_elite_artifact_reward` — награда элитки (`ELR_*`).
- `scripts/ui_screens.gd:5446` — `_show_level_up_toast` — тост (`LUT_*`).
- `scripts/ui_screens.gd:5481` — `_show_combat_title_banner` — баннер боя (`CTB_*`); чинить ширину 1280→2K.
- `scripts/ui_screens.gd:1731` — `_show_victory_banner` — баннер победы (`VBN_*`).
- `scripts/ui_screens.gd:120-152` — блок `COMBAT_HUD_*` const (ассет-пути/маржины) — рядом класть `CHUD_*_2K`.
- `scripts/ui_screens.gd:169-171,250-251` — `ECONOMY_CHOICE_TARGET_*`, `REWARD_CARD_SIZE`,
  `REWARD_ELITE_CARD_SIZE` — переиспользовать как размеры карточек в новых `*_2K`-блоках.
- `tests/ui_no_overlap_matrix_test.gd:4-12,28-91,210+` — добавить openers/проверки боевого HUD и баннеров.
- `docs/design/ui_screens_inventory.md:71-190` — секция-образец SCRUM-484; добавить аналог для SCRUM-487.

## Замечания / подводные камни

- **Locked path: `scripts/ui_screens.gd`.** Это контур Claude (anti-collision, метка `claude`).
  Весь UI-код боевого блока живёт в одном этом файле — не трогать `scripts/progression_data.gd`
  (тоже locked) и держать изоляцию по файлам. Перед стартом синхронизировать HEAD (воркеры
  делают `git add -A`, могут втянуть чужие хунки) — коммитить явным `git add` своих файлов.
- **Не ломать процентные защиты HUD.** `_layout_combat_hud` сейчас не просто расставляет —
  он рантайм-решает коллизии (таймер vs ресурс-панель, бейдж vs панель, ряд артефактов vs всё
  верхнее). При переводе на 2K-сетку эти инварианты должны выполняться by-design (слоты не
  пересекаются на 2K), но на узких 1152×648/1280×720 (есть в `VIEWPORT_SIZES`, хоть и не в гейте)
  uniform-даунскейл 2K не должен порождать overlap — проверить эти размеры тоже.
- **`boss_combat_active`**: таймер-панель не создаётся вовсе — `CHUD_TIMER_2K` не должен ломать
  раскладку, когда таймера нет (бейдж возвышения и ряд артефактов всё равно позиционируются).
- **`CombatIntroBanner` ширина 1280** (offset ±640) — это 720p-ширина, а не 2K. При центрировании
  на 2K длинные имена боссов/элиток могут не помещаться или центрироваться неверно — это и есть
  баг под фикс.
- **Тост/эффект левелапа** (`LEVEL_UP_TOAST_SCENE`, `LEVEL_UP_EFFECT_SCENE`) — координаты внутри
  `.tscn`-сцен, а не в коде. Если сцена не масштабируется под 2K — либо параметризовать через
  `setup()`, либо задать позицию/размер из `LUT_*_2K` при инстансе в `_show_level_up_toast`.
- **Safe-area правило (глобальное):** контент только в пустой зоне фрейма, орнамент рамки рисуется
  по краям `*_PANEL_2K`, контент — внутри `*_SAFE_2K`. Для рисующего скрипта это вход.
- **Экономика уже частично готова:** `ECONOMY_CHOICE_TARGET_1440` (карточка @2K) переиспользуется
  событием/наградами — не плодить дубли размеров, ссылаться на существующие const.
- **Верификатор пишет отчёты** в `build/qa/...` per-SCRUM (см. 92–129) — можно добавить дамп-секцию
  `scrum487/combat_block_no_overlap_matrix.md` через `_filter_dump_sections`.
- **Связанные тикеты:** SCRUM-481 (эпик), SCRUM-484 (готовый блок Меню/Навигация — образец
  стиля const и секции инвентаря), SCRUM-483 (render-verifier гейт 1080p/2K/4K, на который ссылается AC).
- **QA / Godot 4.6.3** в `~/Downloads/Godot.app`, smoke-тесты гонять headless
  (`--headless --script tests/<name>.gd`); после вердикта прогнать `tools/jira_board_sync.py`.
