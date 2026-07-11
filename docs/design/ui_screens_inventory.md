# UI Screens Inventory — FantasyDisk

Создано: 2026-06-27. Канонический список ВСЕХ уникальных экранов/UI-состояний игры
для глобального редизайна интерфейса (база 2K). Источник: `scripts/ui_screens.gd`,
`scripts/main.gd`.

## Базовое разрешение и масштабирование (политика редизайна)

- **База дизайна: 2K = 2560×1440 (16:9).** Все элементы проектируются под этот размер.
- **Full HD (1920×1080)** — ужимает 2K (тот же 16:9, uniform downscale).
- **4K (3840×2160)** — растягивает 2K (тот же 16:9, uniform upscale).
- **Другие соотношения сторон** (ultrawide 21:9, 16:10, 4:3) в фуллскрине — **чёрные
  полосы** (letterbox сверху/снизу или pillarbox по бокам, в зависимости от лишнего).
- Реализация в Godot: `display/window/size/viewport_width=2560`, `viewport_height=1440`,
  `stretch/mode=canvas_items`, `stretch/aspect=keep` (keep = uniform scale + чёрные полосы).
- Runtime Settings дополнительно синхронизирует `Window.content_scale_size` с выбранным
  режимом/разрешением, чтобы Windows/Godot preview реально менял viewport для проверки
  1280×720/1600×900/1920×1080/2560×1440, а не только размер внешнего окна.
- **Инварианты для КАЖДОГО элемента:** ничего не вылазит за экран; элементы не
  наслаиваются; текст не выходит за рамки фрейма; ассеты рендерятся в свой точный
  размер (без растяжения орнамента).

## A. Полноэкранные экраны (19)

| # | Экран | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 1 | Главное меню | `MainMenuScreen` | `_show_main_menu` | ui_screens.gd:291 |
| 2 | Выбор героя (black minimal portrait/dossier/ascension/carousel) | `HeroSelectScreen` | `_show_character_select` → `_build_character_select_v4` | ui_screens.gd:969 / 704 |
| 3 | Выбор оружия | — | `_show_weapon_select` | ui_screens.gd:3803 |
| 4 | Карта маршрута | `RouteMapScreen` | `_show_battle_map` | main.gd:962 |
| 5 | Бой / HUD (таймер, статы, дамаг-флэш) | `CombatTimerPanel`, `DerivedStatsPanel`, `DamageFlashOverlay` | in-run | ui_screens.gd |
| 6 | Событие | `EventScreen` | `_show_event_screen` | ui_screens.gd:4911 |
| 7 | Отдых / костёр | — | `_show_rest_screen` | ui_screens.gd:4870 |
| 8 | Магазин | `ShopScreen` | `_show_shop_screen` | ui_screens.gd:4395 |
| 9 | Докача (атрибут-шоп) | `AttributeShopScreen` | `_show_attribute_shop` | ui_screens.gd:1755 |
| 10 | Дерево навыков | `SkillTreeScreen` | `_show_skill_tree_screen` | ui_screens.gd:1967 |
| 11 | Повышение уровня | `LevelUpOverlay` / `LevelUpPanel` | `_show_level_up_screen` | ui_screens.gd:3953 |
| 12 | Награда (обычная) | — | `_show_reward_screen` | ui_screens.gd:3919 |
| 13 | Награда элитки / артефакт | `EliteArtifactRewardScreen` | `_show_elite_artifact_reward` | ui_screens.gd:4039 |
| 14 | Улучшение | — | `_show_upgrade_screen` | ui_screens.gd:4894 |
| 15 | Кодекс (+ разделы) | `CodexScreen` (`CodexNav/Main/Detail`) | `_show_codex_screen` / `_show_codex_section` | ui_screens.gd:2282 |
| 16 | Настройки | `SettingsContentPanel` | `_show_settings_menu` | ui_screens.gd:3011 |
| 17 | Что нового / патч-ноуты | `PatchNotesScreen` | `_show_patch_notes_screen` | ui_screens.gd:2215 |
| 18 | Победа | — | `_show_victory_screen` | ui_screens.gd:5003 |
| 19 | Смерть | — | `_show_death_screen` | ui_screens.gd:5038 |

**Разделы Кодекса** (под-вкладки одного экрана, не отдельные экраны): персонажи
(`_build_codex_characters`), монстры, артефакты, вознесения, статы, глоссарий.

## B. Паузы / модалки / оверлеи (6)

| # | Экран | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 20 | Пауза в забеге | `RunPauseMenuPanel` | `_show_pause_menu` → `_build_run_pause_menu` | ui_screens.gd:3497 / 3513 |
| 21 | Пауза — досье | — | `_show_pause_dossier_menu` | ui_screens.gd:3590 |
| 22 | Подтверждение выхода | `QuitConfirmationPanel` | `_show_quit_confirmation_dialog` | ui_screens.gd:423 |
| 23 | Продолжить забег | `ContinueRunPanel` | `_show_continue_run_dialog` | ui_screens.gd:532 |
| 24 | Форма фидбэка | `FeedbackOverlay` / `FeedbackPanel` | `_show_feedback_overlay` | ui_screens.gd:5940 |
| 25 | Конфликт переназначения клавиш | `RebindConflictPanel` | `_show_rebind_conflict` (в настройках) | ui_screens.gd:6131 |

## C. Тултипы / транзиентные баннеры (4)

| # | Элемент | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 26 | Тултип статов | `StatTooltipPanel` | — | ui_screens.gd |
| 27 | Тост повышения уровня | — | `_show_level_up_toast` | ui_screens.gd:5361 |
| 28 | Баннер заголовка боя | — | `_show_combat_title_banner` | ui_screens.gd:5396 |
| 29 | Баннер победы | — | `_show_victory_banner` | ui_screens.gd:1686 |

## Итого
**29 уникальных UI-состояний:** 19 полноэкранных + 6 модалок/пауз + 4 тултипа/баннера.

## Координатная спека @2560×1440 — блок Меню/Навигация (SCRUM-484)

Точные координаты контента `x, y, w, h` при базе 2560×1440 для всех 8 экранов блока
Меню/Навигация. Все значения вычислены из реальной раскладки билдеров. Каждому экрану
соответствуют **именованные const рядом с билдером** (см. колонку «const-блок») —
именно они отдаются рисующему скрипту как вход (он рисует ассеты ровно в эти размеры).

Инварианты соблюдены для каждого слота: ничего не вылазит за экран, слоты не
наслаиваются, текст в рамках фрейма, safe-area = пустая зона внутри рамки под контент.

### 1. Главное меню — `_show_main_menu` · const-блок `MM_*` (ui_screens.gd)
Левая колонка из 6 кнопок (фон обязан держать её пустой).

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Колонка кнопок (safe) | `MM_BUTTON_COLUMN_2K` / `MM_SAFE_2K` | 72 | 383 | 380 | 674 |
| Кнопка «Начать новую игру» | `MM_BTN_START_2K` | 72 | 383 | 380 | 104 |
| Кнопка «Настройки» | `MM_BTN_SETTINGS_2K` | 72 | 497 | 380 | 104 |
| Кнопка «Древо умений» | `MM_BTN_SKILLTREE_2K` | 72 | 611 | 380 | 104 |
| Кнопка «Что нового» | `MM_BTN_PATCHNOTES_2K` | 72 | 725 | 380 | 104 |
| Кнопка «Кодекс» | `MM_BTN_CODEX_2K` | 72 | 839 | 380 | 104 |
| Кнопка «Выйти из игры» | `MM_BTN_EXIT_2K` | 72 | 953 | 380 | 104 |
| Версия (bottom-right) | `MM_VERSION_LABEL_2K` | 2440 | 1406 | 104 | 24 |

### 2. Подтверждение выхода — `_show_quit_confirmation_dialog` · `QC_*`
Модалка по центру, dim на весь экран. safe-area = панель минус content-margins (58/72/58/66).

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Затемнение | `QC_DIM_2K` | 0 | 0 | 2560 | 1440 |
| Панель (фрейм) | `QC_PANEL_2K` | 980 | 550 | 600 | 340 |
| Safe-area | `QC_SAFE_2K` | 1038 | 622 | 484 | 202 |
| Заголовок | `QC_TITLE_2K` | 1038 | 627 | 484 | 44 |
| Подзаголовок | `QC_SUBTITLE_2K` | 1038 | 687 | 484 | 44 |
| Кнопка «Выйти» | `QC_BTN_EXIT_2K` | 1051 | 747 | 220 | 72 |
| Кнопка «Отмена» | `QC_BTN_CANCEL_2K` | 1289 | 747 | 220 | 72 |

### 3. Продолжить забег — `_show_continue_run_dialog` · `CR_*`

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Затемнение | `CR_DIM_2K` | 0 | 0 | 2560 | 1440 |
| Панель (фрейм) | `CR_PANEL_2K` | 940 | 530 | 680 | 380 |
| Safe-area | `CR_SAFE_2K` | 998 | 602 | 564 | 242 |
| Заголовок | `CR_TITLE_2K` | 998 | 614 | 564 | 44 |
| Подзаголовок (2 строки) | `CR_SUBTITLE_2K` | 998 | 674 | 564 | 66 |
| Кнопка «Продолжить» | `CR_BTN_CONTINUE_2K` | 1031 | 758 | 240 | 72 |
| Кнопка «Новая игра» | `CR_BTN_NEWGAME_2K` | 1289 | 758 | 240 | 72 |

**SCRUM-582 frame integration:** runtime uses exact @2K `cr_panel` and `cr_btn`
assets from `assets/sprites/ui/frames/overhaul_2k/`. Panel content margins are
`58/72/58/66`; both actions use the `240x72` `ui_frame_2k_cr_btn.png` button
frame. Title, subtitle, and buttons stay inside `CR_SAFE_2K`.

**SCRUM-584 rebind conflict integration:** `_show_rebind_conflict()` uses
`RebindConflictDialog` / `RebindConflictPanel` with the dedicated @2K
`rc_panel` and `rc_btn` frames. Runtime geometry is `RC_PANEL_2K = 940,530,680,380`,
`RC_SAFE_2K = 998,602,564,242`, and two `240x72` action buttons inside the safe
zone. Source/mockup evidence lives in `docs/design/references/scrum584_rebind_conflict_2k/`
and `docs/design/mockups/scrum584_rebind_conflict_2k/spec.md`.

### 4. Пауза в забеге — `_build_run_pause_menu` · `PM_*`
Панель из `_pause_end_modal_display_size("pause")` → 898×820; safe-area по
масштабированным content-margins (≈67/86/67/78). 5 кнопок 280×60.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `PM_PANEL_2K` | 831 | 310 | 898 | 820 |
| Safe-area | `PM_SAFE_2K` | 898 | 396 | 764 | 656 |
| Заголовок «Пауза» | `PM_TITLE_2K` | 898 | 509 | 764 | 58 |
| Подзаголовок | `PM_SUBTITLE_2K` | 898 | 575 | 764 | 24 |
| Кнопка «Продолжить» | `PM_BTN_CONTINUE_2K` | 1140 | 607 | 280 | 60 |
| Кнопка «Досье персонажа» | `PM_BTN_DOSSIER_2K` | 1140 | 675 | 280 | 60 |
| Кнопка «Настройки» | `PM_BTN_SETTINGS_2K` | 1140 | 743 | 280 | 60 |
| Кнопка «Покинуть забег» | `PM_BTN_ENDRUN_2K` | 1140 | 811 | 280 | 60 |
| Кнопка «Главное меню» | `PM_BTN_MAINMENU_2K` | 1140 | 879 | 280 | 60 |

### 5. Пауза — досье — `_build_layout` · `PD_*` (**scripts/pause_stats_menu.gd**)
Почти полноэкранная двухколоночная модалка (offset 20/18/-20/-18). safe-area по
масштабированным content-margins (×1.56). Контент list-driven; ниже — каркас зон.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `PD_PANEL_2K` | 20 | 18 | 2520 | 1404 |
| Safe-area | `PD_SAFE_2K` | 135 | 165 | 2290 | 1123 |
| Левая колонка управления | `PD_LEFT_COLUMN_2K` | 135 | 165 | 330 | 1123 |
| Правая область (статы/арты) | `PD_RIGHT_AREA_2K` | 483 | 165 | 1942 | 1123 |
| Кнопка управления (шаблон) | `PD_BTN_2K` | — | — | 280 | 60 |
| Панель группы статов (шаблон ширины) | `PD_STAT_GROUP_2K` | — | — | 430 | авто |

### 6. Тултип глоссария — `_show_glossary_tooltip` · `GT_*`
Плавающая панель, w фикс 460, h по контенту. Позиция динамическая: под якорем +8,
clamp 16px от краёв экрана.

| Параметр | const | значение |
|---|---|---|
| Размер-шаблон (w×h) | `GT_PANEL_2K` | 460 × ~140 (h по контенту) |
| Отступ от краёв экрана | `GT_VIEWPORT_MARGIN_2K` | 16 |
| Зазор от якоря | `GT_ANCHOR_GAP_2K` | 8 |

### 7. Тултип статов — `_make_custom_tooltip` · `ST_*` (**scripts/pause_stats_menu.gd**)
Плавающий tooltip у курсора/слота, w фикс 430, h по контенту, инсет текста 20.

| Параметр | const | значение |
|---|---|---|
| Размер-шаблон (w×h) | `ST_PANEL_2K` | 430 × авто |
| Инсет текста | `ST_LABEL_INSET_2K` | 20 (×2 = 40) |

SCRUM-586 подготовил новый Design-source package для 2K tooltip frame:
`docs/design/mockups/scrum586_stat_tooltip/spec.md`,
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`.
Новый ассет требует safe content margins `44,42,44,42`; старый `20` px inset
нельзя переносить на этот frame без Back-end интеграции/верификатора (handoff
SCRUM-593).

### 8. Форма фидбэка — `_show_feedback_overlay` · `FB_*`
Модалка со скроллом: фикс заголовок сверху, фикс статус + кнопки снизу, прокрутка в
середине (поле ввода + превью скриншота). Панель clamp → 940×780.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `FB_PANEL_2K` | 810 | 330 | 940 | 780 |
| Safe-area | `FB_SAFE_2K` | 868 | 402 | 824 | 642 |
| Заголовок | `FB_TITLE_2K` | 868 | 402 | 824 | 42 |
| Область скролла | `FB_SCROLL_2K` | 868 | 454 | 824 | 470 |
| Поле ввода | `FB_TEXTEDIT_2K` | 868 | 508 | 824 | 130 |
| Превью скриншота | `FB_SCREENSHOT_2K` | 868 | 648 | 824 | 240 |
| Статус | `FB_STATUS_2K` | 868 | 934 | 824 | 36 |
| Кнопка «Отправить» | `FB_BTN_SEND_2K` | 1031 | 980 | 260 | 64 |
| Кнопка «Отмена» | `FB_BTN_CANCEL_2K` | 1309 | 980 | 220 | 64 |

> **Примечание для рисующего скрипта.** «Safe-area» — пустая зона внутри рамки фрейма;
> орнамент рамки рисуется по краям `*_PANEL_2K`, контент — только внутри `*_SAFE_2K`.
> Координаты модалок при не-16:9 экранах не меняются (stretch=keep даёт чёрные полосы),
> при 1080p/4K — uniform-скейлятся вместе с viewport.

## Координатная спека @2560×1440 — блок Боевые (SCRUM-487)

Точные координаты контента `x, y, w, h` при базе 2560×1440 для 8 состояний боевого блока
(всё, что игрок видит во время и сразу после боя). Значения вычислены из фактической
раскладки билдеров и сверены с рантайм-дампом верификатора
(`build/qa/scrum487/combat_block_no_overlap_matrix.md`). База фиксирована
(`window/stretch=canvas_items`, `aspect=keep`): рантайм всегда лэйаутит в 2560×1440, окно
скейлится автоматически. Именованные `*_2K`-const — рядом с asset-блоком `COMBAT_HUD_*`
в `ui_screens.gd`; они отдаются рисующему скрипту как вход.

Контейнер-зависимые слоты (карточки/кнопки/ряды) центрируются контейнером — их `x/y`
помечены «—» (auto), задан только шаблонный размер `w×h` (`Rect2(0,0,w,h)` в коде).

### 5. Бой / HUD — `_create_hud` / `_layout_combat_hud` · const-блок `CHUD_*`
Верхний бар: ресурс-панель слева, таймер по центру, бейдж возвышения справа от таймера,
ряд артефактов прижат вправо; кнопка повышения — нижний правый угол; дамаг-флэш — overlay.
Процентная/клампленная раскладка переведена в детерминированную 2K-сетку (слоты не
пересекаются by-design). На боссе таймер не создаётся; бейдж возвышения только при asc>0.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Ресурс-панель (HP/XP/Gold/ULT) | `CHUD_RESOURCE_PANEL_2K` | 18 | 18 | 820 | 84 |
| Панель таймера (нет на боссе) | `CHUD_TIMER_2K` | 1136 | 14 | 288 | 96 |
| Бейдж возвышения (asc>0) | `CHUD_ASCENSION_BADGE_2K` | 1432 | 18 | 64 | 64 |
| Ряд артефактов | `CHUD_ARTIFACT_ROW_2K` | 2140 | 16 | 402 | 104 |
| Кнопка повышения (bottom-right) | `CHUD_LEVELUP_BUTTON_2K` | 2436 | 1316 | 96 | 117 |
| Бейдж счётчика пиков | `CHUD_LEVELUP_BADGE_2K` | 2498 | 1306 | 28 | 28 |
| Дамаг-флэш (overlay) | `CHUD_DAMAGE_FLASH_2K` | 0 | 0 | 2560 | 1440 |

### 6. Событие — `_show_event_screen` · `EVT_*`
Economy-панель «event»; safe-area по фикс content-margins (58/72/58/66). 3 карточки 480×340.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `EVT_PANEL_2K` | 420 | 330 | 1720 | 780 |
| Safe-area | `EVT_SAFE_2K` | 478 | 402 | 1604 | 642 |
| Карточка выбора (×3, gap 48) | `EVT_CARD_2K` | — | — | 480 | 340 |
| Кнопка «Назад» | `EVT_BACK_BUTTON_2K` | — | — | 380 | 54 |

### 11. Повышение уровня — `_show_level_up_screen` · `LU_*`
Оверлей; панель из `_level_up_layout_metrics` (1040×600 @2K). 3 карточки 238×210 + «Позже».
SCRUM-670 integrates the SCRUM-570 generated 2K runtime frame slots:
`level_up_panel` (`ui_frame_2k_level_up_panel.png`, 1040×600) and
`level_up_card` (`ui_frame_2k_level_up_card.png`, 238×210). The implementation
uses the SCRUM-570 `ui_plan.json` / `spec.md` safe-zone rectangles as
authoritative and does not sample frame/content bounds from the generated mockup
pixels.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `LU_PANEL_2K` | 760 | 420 | 1040 | 600 |
| Safe-area | `LU_SAFE_2K` | 818 | 492 | 924 | 462 |
| Карточка награды (×3, gap 12) | `LU_CARD_2K` | — | — | 238 | 210 |
| Кнопка «Позже» | `LU_LATER_BUTTON_2K` | — | — | 260 | 56 |

### 12. Награда обычная — `_show_reward_screen` · `RWD_*`
`_create_menu_box` (панель 1120×660). 3 карточки `REWARD_CARD_SIZE` 300×430, separation 18.
SCRUM-571 is design-source only as of SCRUM-670: it provides full-screen mockup
and safe-zone planning, but no isolated alpha runtime frames. Runtime therefore
continues to use the SCRUM-338 reward-card frame kit rather than slicing the
mockup.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `RWD_PANEL_2K` | 720 | 390 | 1120 | 660 |
| Safe-area | `RWD_SAFE_2K` | 778 | 462 | 1004 | 522 |
| Карточка награды (×3, gap 18) | `RWD_CARD_2K` | — | — | 300 | 430 |

### 13. Награда элитки — `_show_elite_artifact_reward` · `ELR_*`
Свой `CanvasLayer` + центрированная панель 1140×640. 3 карточки `REWARD_ELITE_CARD_SIZE`
320×430, separation 22.
SCRUM-572 is design-source only as of SCRUM-670: it provides full-screen mockup
and safe-zone planning, but no isolated alpha runtime frames. Runtime therefore
continues to use the SCRUM-338 elite reward-card frame kit rather than slicing
the mockup.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `ELR_PANEL_2K` | 710 | 400 | 1140 | 640 |
| Safe-area | `ELR_SAFE_2K` | 768 | 472 | 1024 | 502 |
| Карточка артефакта (×3, gap 22) | `ELR_CARD_2K` | — | — | 320 | 430 |

### 28. Тост повышения — `_show_level_up_toast` · `LUT_*`
Транзиентный full-rect burst (вспышка/кольцо/искры) на экранной позиции игрока (или центр).
SCRUM-588 добавляет generated @2K frame `lut_toast` вокруг textless sparkle/ring
акцента. Единственная текстовая подпись `Level Up` остаётся в world-space badge
`LevelUpEffect`; HUD-toast не содержит Label/icon и держит эффекты только в
пустой safe-зоне, не на ornament frame.

| Параметр | const | значение |
|---|---|---|
| Overlay (full-rect) | `LUT_OVERLAY_2K` | 0, 0, 2560, 1440 |
| Toast frame template | `LUT_TOAST_FRAME_2K` / `lut_toast` | 480 × 300, dynamic center |
| Toast safe content | `LUT_TOAST_SAFE_2K` | frame + 70/112/70/112 → 340 × 76 |

### 29. Баннер заголовка боя — `_show_combat_title_banner` · `CTB_*`
Имя/титул элитки/босса вспыхивает над ареной и гаснет (бой не на паузе, самоосвобождается).
Center-top. **Фикс SCRUM-487:** ширина была 1280 (720p-база) → теперь 2360 @2K (текст
центрируется и помещается на 2K, а не по 720p). Билдер читает ширину из `CTB_*_2K`.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Баннер босса (big) | `CTB_BIG_2K` | 100 | 120 | 2360 | 90 |
| Баннер элитки | `CTB_SMALL_2K` | 100 | 92 | 2360 | 56 |

**SCRUM-589 frame integration:** runtime uses `PanelContainer` frame assets
`ui_frame_2k_ctb_big.png` / `ui_frame_2k_ctb_small.png`. Texture margins are
`70/20/70/20` for big and `56/12/56/12` for small; content margins are
`86/10/86/10` and `72/8/72/8`. Title text lives only inside the safe content
zone (`CombatIntroBannerLabel` child), leaving all ornament/corners visible.

### 30. Баннер победы — `_show_victory_banner` · `VBN_*`
Свой `CanvasLayer` (layer 80): затемнение + framed «ПОБЕДА» по центру; авто-продолжение 1.3с.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Затемнение | `VBN_DIM_2K` | 0 | 0 | 2560 | 1440 |
| Рамка победы | `VBN_FRAME_2K` | 560 | 600 | 1440 | 240 |
| Safe content | `VBN_SAFE_2K` | 672 | 652 | 1216 | 136 |

**SCRUM-590 frame integration:** runtime uses `PanelContainer` frame asset
`ui_frame_2k_vbn_frame.png`. Texture margins are `84/44/84/44`; content margins
are `112/52/112/52`. The `VictoryBannerLabel` child stays inside the safe
content zone, preserving all decorative frame ornament.

> **Покрытие верификатором.** `tests/ui_no_overlap_matrix_test.gd` покрывает боевой HUD
> (`combat_hud`: ресурс-панель/таймер/бейдж/ряд артефактов/кнопка повышения — fit во вьюпорт
> + no-overlap) и баннер боя (`combat_title_banner`: ширина из `CTB_*_2K`, текст в рамке) на
> всех `VIEWPORT_SIZES`, гейт 1080p/2K/4K. Награды/событие/левелап уже были покрыты
> (`battle_reward`/`elite_reward`/`event_economy`/`level_up`). Тост и баннер победы —
> транзиентные эффекты (full-rect), проверяются дампом, отдельным no-overlap кейсом не
> гейтятся. Дамп блока: `build/qa/scrum487/combat_block_no_overlap_matrix.md`.

## Координатная спека @2560×1440 — блок Прогрессия/Экономика (SCRUM-488)

Точные координаты `x, y, w, h` @2560×1440 для 6 плотных экранов прогрессии/экономики.
Значения вычислены из фактической раскладки билдеров и сверены с рантайм-дампом
верификатора (`build/qa/ui_no_overlap_matrix.md`, секции `*_2560×1440`). База фиксирована
(`stretch=canvas_items`, `aspect=keep`). Контейнер-зависимые слоты помечены «—» (auto),
задан шаблонный `w×h`. **Кодекс/Настройки — путь (б):** рантайм-V2-масштабирование не
тронуто (оно уже uniform-заполняет вьюпорт — на 2K даёт ровно эти rect, кодекс = `CODEX_V2_*`
× 4/3); `*_2K`-const здесь — документирующий 2K-вход для рисующего скрипта.

### 8. Магазин — `_show_shop_screen` · `SHOP_*`
Backdrop-лавка: предметы лежат в центральной свободной зоне «стены», не как UI-карточки.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Заголовок (Магазин + подзаг.) | `SHOP_TITLE_2K` | 900 | 104 | 760 | 86 |
| Стена лавки / safe | `SHOP_WALL_2K` / `SHOP_SAFE_2K` | 512 | 547 | 1536 | 533 |
| Слот предмета (×4) | `SHOP_SLOT_2K` | — | — | 148 | 148 |
| Кнопка «Назад» | `SHOP_BACK_2K` | 1100 | 1314 | 360 | 104 |

Слоты предметов — anchor-фракции внутри стены: `(0.30,0.18) (0.70,0.18) (0.30,0.84) (0.70,0.84)`.

### 9. Докача / атрибут-шоп — `_show_attribute_shop` · `ATTR_*`
Панель на всю высоту (− поля 28); скролл опций (грид 2 кол.) + фикс-низ reroll/skip ВНЕ скролла.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `ATTR_PANEL_2K` | 730 | 28 | 1124 | 1384 |
| Safe-area | `ATTR_SAFE_2K` | 788 | 100 | 1008 | 1246 |
| Карточка опции (грид 2 кол.) | `ATTR_OFFER_2K` | — | — | 480 | 340 |
| Кнопка reroll/skip | `ATTR_ACTION_BUTTON_2K` | — | — | 420 | 62 |

### 10. Дерево навыков — `_show_skill_tree_screen` · `SKILL_*`
Самый плотный экран: класс-панель слева + ряд из N веток справа. @2K все ветки + класс-панель
влезают без горизонтального скролла (на 1080p допускается скролл без обрезки текста).

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Главная панель (фрейм) | `SKILL_MAIN_PANEL_2K` | 48 | 26 | 2464 | 1388 |
| Safe-area (layout) | `SKILL_SAFE_2K` | 136 | 118 | 2288 | 1214 |
| Бейдж очков | `SKILL_POINTS_BADGE_2K` | — | — | 215 | 96 |
| Кнопка «Назад в меню» | `SKILL_BACK_2K` | — | — | 260 | 104 |
| Класс-панель (левая колонка) | `SKILL_CLASS_PANEL_2K` | 136 | 262 | 330 | 1070 |
| Ряд веток | `SKILL_BRANCHES_2K` | 484 | 262 | 1932 | 1276 |
| Панель ветки (шаблон) | `SKILL_BRANCH_2K` | — | — | 164 | 430 |

### 15. Кодекс — `_show_codex_screen` / `_show_codex_section` · `CODEX_*` (2K)
3 колонки: навигация / список / деталь. V2-база 1920×1080 уже scaled-fill во вьюпорт; на 2K
даёт ровно `CODEX_V2_*` × 4/3 (рантайм не тронут — путь (б)).

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Внешняя рамка | `CODEX_OUTER_FRAME_2K` | 32 | 27 | 2496 | 1387 |
| Заголовок (safe) | `CODEX_HEADER_TITLE_2K` | 149 | 99 | 1493 | 85 |
| Кнопка «Назад» (safe) | `CODEX_BACK_BUTTON_2K` | 2245 | 80 | 168 | 128 |
| Колонка навигации | `CODEX_NAV_PANEL_2K` | 96 | 227 | 405 | 1163 |
| Навигация (safe) | `CODEX_NAV_SAFE_2K` | 117 | 264 | 344 | 960 |
| Колонка списка | `CODEX_LIST_PANEL_2K` | 517 | 227 | 1113 | 1163 |
| Колонка детали | `CODEX_DETAIL_PANEL_2K` | 1656 | 227 | 808 | 1163 |
| Портрет (safe) | `CODEX_PORTRAIT_SAFE_2K` | 1861 | 301 | 427 | 400 |
| Ряд чипов (safe) | `CODEX_CHIP_ROW_SAFE_2K` | 1731 | 731 | 648 | 107 |

Сумма колонок ≤ 2560: деталь правый край 2464 < 2528 (внутри рамки). Путь (б).

### 16. Настройки — `_show_settings_menu` · `SETTINGS_*` (2K)
V2-модалка scaled-fill: на 2K = 2048×1232 по центру. Табы «Экран»/«Управление» + строки
контролов; таб-свитчер не наезжает на заголовок, контент-панель не выходит за нижний back.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Модалка (фрейм) | `SETTINGS_PANEL_2K` | 256 | 104 | 2048 | 1232 |
| Safe-area | `SETTINGS_SAFE_2K` | 430 | 229 | 1700 | 1062 |
| Заголовок | `SETTINGS_TITLE_2K` | 448 | 229 | 1664 | 64 |
| Таб-свитчер | `SETTINGS_TAB_SWITCHER_2K` | 730 | 316 | 1100 | 220 |
| Контент-панель | `SETTINGS_CONTENT_PANEL_2K` | 430 | 570 | 1700 | 610 |
| Строка контрола (шаблон) | `SETTINGS_CONTROL_ROW_2K` | 658 | 602 | 1438 | 62 |
| Кнопка «Назад» | `SETTINGS_BACK_2K` | 1140 | 1204 | 280 | 87 |

> **Покрытие верификатором.** `tests/ui_no_overlap_matrix_test.gd` уже покрывает все 6 экранов
> (`shop_economy`/`attribute_shop_economy`/`skill_tree`/`codex`/`settings` + докача) на всех
> `VIEWPORT_SIZES`, гейт 1080p/2K/4K — без overflow/overlap/text-out (плотные экраны
> проходят: дерево навыков влезает без гориз-скролла @2K, докача с 4+ опциями не режется).

## Координатная спека @2560×1440 — блок Результаты/Старт (SCRUM-489)

Точные координаты `x, y, w, h` @2560×1440 для 5 экранов исходов/старта забега. Значения
вычислены из фактической раскладки билдеров и сверены с рантайм-дампом верификатора
(`build/qa/scrum489/results_block_no_overlap_matrix.md`). База фиксирована
(`stretch=canvas_items`, `aspect=keep`). Контейнер-зависимые слоты (внутри VBox/HBox с
center-align) помечены «—» (auto) с шаблонным `w×h`; для них `x,y` — задокументированный
слот в safe-area.

### 1–2. Победа / Поражение — `_show_victory_screen` / `_show_death_screen` · `RESULT_*` / `VS_*` / `DS_*`
Pause/end-модалки (через `_create_menu_box`). Геометрия победы и поражения **идентична**
(`_pause_end_modal_display_size` для "victory"/"death" → один 898×820, height упирается в
clamp 820). С SCRUM-841 эти result-экраны не используют `PauseEndModalScroll_*`:
контент лежит напрямую в safe-area как `ResultContent_*`, верх отдан title/subtitle,
середина — `ResultBody_*` с crest-slot слева и компактной `RunSummaryColumn_*` справа,
а action-кнопка всегда видима в нижнем safe-слоте.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель модалки | `RESULT_PANEL_2K` | 831 | 310 | 898 | 820 |
| Safe-area | `RESULT_SAFE_2K` | 898 | 396 | 764 | 656 |
| Заголовок | `RESULT_TITLE_2K` | 898 | 396 | 764 | 42 |
| Подзаголовок (autowrap) | `RESULT_SUBTITLE_2K` | 898 | 448 | 764 | 128 |
| Body: crest + summary | `RESULT_BODY_2K` | 898 | 586 | 764 | 352 |
| Эмблема-кольцо (crest) | `RESULT_CREST_2K` | 899 | 678 | 168 | 168 |
| Сводка забега | `RESULT_SUMMARY_2K` | 1086 | 586 | 576 | 352 |
| Кнопка «Новый забег» (победа) | `VS_BTN_NEWRUN_2K` | 1070 | 948 | 420 | 104 |
| Кнопка «Начать заново» (смерть) | `DS_BTN_RETRY_2K` | 1070 | 948 | 420 | 104 |

### 3. Выбор героя minimal black — `_build_character_select_v4` · `HS4*`
Полноэкранный black screen: `HS4BlackBackground`, маленькая кнопка Back, слева
выбранный герой, центр досье/характеристики, справа Возвышение, снизу карусель.
Старые `HS4_*_2K` frame/radar constants are historical and are not active.

| Слот | Runtime node / rule |
|---|---|
| Фон | `HS4BlackBackground`, pure black, full viewport |
| Back | `HS4BackButton`, compact top-left utility button |
| Портрет выбранного героя | `HS4Portrait` inside `HS4PortraitFrame`, fixed `250x250`; directional SpriteFrames rotate when available |
| Досье | `HS4DossierFrame`, center column with name, description, strengths, weaknesses, weapon list, class identity |
| Характеристики | `HS4StatsGrid`, 8 `HS4Stat_<stat_id>` buttons; each has tooltip with dependent attributes |
| Возвышение | `HS4AscensionFrame`, right column with description, `AscensionMinusButton`, `AscensionPlusButton`, `HS4ChooseButton` |
| Карусель | `HS4CarouselFrame` / `HS4Carousel`, bottom band; responsive square `HS4CarouselSlot_*` buttons are clamped to `180..320px` |
| Прокрутка карусели | SCRUM-979: `HS4CarouselPrevButton` / `HS4CarouselNextButton` use existing PixelLab `132x176` plates scaled to `52%` of slot height (`84..140px` high); each press shifts the clamped visible window by one, preserves selected slot position where possible, and never wraps |

### 4. Выбор оружия — `_show_weapon_select` · `WS_*_2K`
SCRUM-870 is the active live contract and supersedes the SCRUM-868 full-screen
PixelLab layer. `_show_weapon_select()` must not create or render
`WeaponSelectPixelLabRuntimeLayer`; the SCRUM-867/868 mockup/runtime-layer files
remain historical evidence only. Weapon Select now uses native Godot controls
with opaque high-contrast surfaces: a dark centered `MenuPanel_weapon_select`,
three large framed `WeaponOption_*` cards, live labels/icons, live focus states,
and the normal fantasy `WeaponSelectBackButton`. The start-boon picker keeps the
old shared `weapon_select` menu box, and SCRUM-563 route-map layout is not part
of this scope.

Each `WeaponOption_*` card contains:
- `WeaponSelectIconWell_*` at minimum `204x204`;
- `WeaponSelectSprite_*` at minimum `176x176`;
- `WeaponSelectTitle_*`;
- `WeaponSelectIdentity_*` with `Отличие:` from
  `ProgressionData.weapon_mechanic_identity(character_id, weapon_id)`;
- `WeaponSelectDescription_*` with a concise mechanic summary that fits the
  card instead of a clipped paragraph;
- `WeaponSelectRole_*` with archetype/mode/class scaling;
- `WeaponSelectStatsPanel_*` with `WeaponSelectStats_*`: archetype, range/radius,
  cooldown and one context line for summon limit, control or damage.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `WS_PANEL_2K` | 360 | 120 | 1840 | 1200 |
| Safe-area | `WS_SAFE_2K` | 443 | 229 | 1674 | 1016 |
| Заголовок | `WS_TITLE_2K` | 443 | 218 | 1674 | 62 |
| Подзаголовок | `WS_SUBTITLE_2K` | 443 | 288 | 1674 | 34 |
| Карточка оружия (шаблон; шаг Y=274) | `WS_CARD_2K` | 443 | 350 | 1674 | 260 |
| Иконка оружия | `WS_ICON_WELL_SIZE_2K` / `WS_ICON_SIZE_2K` | — | — | 204 / 176 | 204 / 176 |
| Панель статов | `WS_STATS_PANEL_SIZE_2K` | — | — | 310 | 204 |
| Кнопка «Назад» | `WS_BTN_BACK_2K` | 1140 | 1238 | 280 | 60 |

### 5. Карта маршрута — `_show_battle_map` · `RM_*_2K` (**scripts/route_map_screen.gd**)

SCRUM-563 source package: `docs/design/mockups/scrum563_route_map_2k/spec.md`,
OpenAI mockup `docs/design/references/scrum563_route_map_2k/route_map_2k_mockup.png`,
and safe-zone previews `docs/design/previews/scrum563_route_map_2k_*`. The
package keeps the SCRUM-489 runtime geometry but defines strict empty zones for
the header, scroll field, HUD strip, tooltip, node lane and FAB before any
route-map 2K runtime asset wiring.
Полноэкранный со скроллом: хедер сверху + вертикальный скролл canvas с узлами. Все опорные
значения абсолютные (не скейлятся от viewport, кроме ширины canvas). **Фикс SCRUM-489:**
`ROUTE_MAP_HEADER_HEIGHT` 118→140 — хедер (title 36px + stage 18px, content-min ≈110px) рос
вниз за band 88 и наезжал на скролл; 140 даёт band 18..128 под контент + зазор 12 до скролла.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Хедер (фрейм) | `RM_HEADER_2K` | 28 | 18 | 2504 | 110 |
| Заголовок (36px) | `RM_TITLE_2K` | 28 | 18 | 2200 | 44 |
| Stage-лейбл (18px) | `RM_STAGE_LABEL_2K` | 28 | 62 | 2200 | 24 |
| Скролл (вьюпорт карты) | `RM_SCROLL_2K` | 28 | 140 | 2504 | 1272 |
| Canvas (map_area; высота динамич.) | `RM_CANVAS_2K` | 28 | 140 | 2488 | 1882* |
| Узел маршрута (шаблон) | `RM_NODE_2K` | — | — | 88 | 88 |

\* Высота canvas = `ROUTE_MAP_PADDING.y*2 + MAP_NODE_SIZE.y + 165*(row_count−1)`,
`row_count = max(route_nodes, ROUTE_STEPS_TO_BOSS+1=11)` → минимум 1882 @ 11 рядов. Canvas
выше viewport — это **норма** для скролл-карты (viewport-fit не требуется); узлы рисуются
процедурно (`_draw_route_nodes`), ряд-gap 165, padding (170,72).

> **Покрытие верификатором.** `tests/ui_no_overlap_matrix_test.gd` покрывает victory/death/
> hero_select (ранее) + **добавлены** `weapon_select` и `route_map` на всех `VIEWPORT_SIZES`,
> гейт 1080p/2K/4K — без overflow/overlap/text-out. Для контролов внутри `ScrollContainer`
> overlap считается по ВИДИМОЙ (клипнутой) части (`_effective_rect`), иначе авто-центрированный
> длинный canvas карты давал ложное пересечение с хедером.

## Следующий шаг (для рисующего скрипта)
Блоки **готовы**: Меню/Навигация (8 экранов, SCRUM-484), Боевые (8 состояний, SCRUM-487),
Прогрессия/Экономика (6 экранов, SCRUM-488), Результаты/Старт (5 экранов: победа/смерть/
выбор героя/выбор оружия/карта маршрута, SCRUM-489). Остаётся: патч-ноуты.

### Рисующий пайплайн координаты→ассеты (SCRUM-485)
`tools/build_ui_2k_frame_kit.py` — генератор 9-slice-safe рамок ровно в пиксельный
размер слота @2K. ВХОД — `*_2K`-координаты из `ui_screens.gd`/`pause_stats_menu.gd`
(сверяются anti-drift guard'ом: при расхождении размеров скрипт падает). Маппинг
слот→тип→9-slice бордюры — из `UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS` /
`MINIMAL_METAL_BUTTON_MARGINS` (нативные, не скейлятся; тянется только плоский центр).
- Гонять: `python3 tools/build_ui_2k_frame_kit.py` (генерация + контактный лист),
  `--verify` (рендер-верификатор, exit!=0 при FAIL), `--all` (то и другое).
- Ассеты: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_<slug>.png` (активная тема
  `minimal_metal` НЕ перетёрта). Контактный лист: `docs/design/previews/ui_2k_frame_kit_contact.png`.
- Verdict верификатора (по каждому ассету): размер == ожидаемый; 9-slice валиден;
  симуляция 9-slice под 1080p/2K/4K — углы попиксельно идентичны (орнамент не плывёт);
  центр горизонтально однороден (safe-зона чистая); нет stray-островов/спеков/гало.
- Детерминирован (без `random`): повторный прогон → идентичные байты.
- Расширение на другие блоки эпика: добавить слоты в `SLOTS` (slug/const/kind/размер),
  когда их `*_2K`-координаты зафиксированы. Интеграция (подмена путей в `UIThemePaths`)
  — отдельной задачей блока, не здесь.
