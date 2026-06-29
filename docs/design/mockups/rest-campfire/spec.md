# SCRUM-566 — UI-редизайн: Отдых / костёр (@2K 2560×1440)

Эпик SCRUM-481 (UI Overhaul). Экран `_show_rest_screen` (`scripts/ui_screens.gd`),
нода `RestScreen` (фон-id `campfire`). Стиль: D&D + Dark Fantasy Dragon.

## ЭТАП 1 — Раскладка / метрики @2560×1440 (база)

Экран строится через общую экономическую инфраструктуру выбора
(`_create_menu_box` + `_make_economy_choice_row` + `_make_economy_choice_card`),
ту же, что у магазина/события/улучшения. Это гарантирует единый стиль и уже
выверенные 2K-метрики. Костёр зарегистрирован как economy-фон
(`_is_economy_screen_background` → `["campfire","upgrade","event"]`).

### Полноэкранный фон
- `ScreenBackground_campfire`: TextureRect full-rect, 2560×1440, stretch keep-aspect-covered.
- Фолбэк-цвет (`SCREEN_BACKGROUND_FALLBACK_COLORS["campfire"]`): тёплый
  `Color(0.080, 0.045, 0.025, 1.0)` — угли костра.

### Центральная панель (`MenuPanel_campfire`)
- Якорь центр (0.5/0.5). Размер из `_economy_menu_panel_half_size("campfire")`:
  **1180×716** (half 590×358), clamp по вьюпорту `min(x, vp.x)`, `min(y, vp.y-48)`.
- Стиль `_economy_panel_style()` (9-slice economy-рамка,
  source 782×716, tex-margins 38/52/38/48, content 58/72/58/66 — без растяжения орнамента).
- Контент в ScrollContainer (вертикальный) → VBox (center, sep 16):
  title → subtitle → RestChoiceRow.

### Заголовок и подзаголовок (в safe-zone панели, не на орнаменте)
- Title: "Костер", font 42, цвет `(0.96,0.9,0.68)`, center.
- Subtitle: "Восстановись или подготовься перед следующим боем.", font 17,
  autowrap WORD_SMART, цвет `(0.93,0.89,0.80)`. Текст короткий — помещается в одну
  строку при ширине панели 1180 минус content-margins.

### Ряд вариантов отдыха (`RestChoiceRow`, 2 карты)
- Размер карты из `_economy_choice_display_size(2)` → **480×340** @2K
  (`ECONOMY_CHOICE_TARGET_1440`), 420×300 @1080, 480×340 @4K (>=2400×1200).
- Gap между картами: `_economy_choice_row_gap(480)` → **48** @2K.
- Ширина ряда: 480*2 + 48 = **1008** ≤ панель content-ширина
  (1180 − 2*58 = 1064). Помещается.
- Карта 9-slice: source 426×486, tex-margins 32/42/32/40,
  safe-rect `Rect2(46,58,334,374)`. Контент-VBox внутри карты с инсетами
  по `_economy_choice_content_margins(480)` — title/desc/action центрированы,
  autowrap, НИКОГДА на рамку.

### Карты (короткие подписи — требование таска)
1. **Передышка** / "Восстановить 35% максимального здоровья." / действие "Отдохнуть"
   (`RestHealButton`).
2. **Защитная стойка** / "Получить +6% защиты до конца забега." / действие
   "Подготовиться" (`RestGuardButton`).

Подписи короткие (≤ 1 строки заголовок, ≤ 2 строки описание) — влезают в safe-rect
карты 334×374 при font 17/13/15. Растягивания рамок нет.

### FAB докачки
- `_create_upgrade_fab(...)` — стандартный плавающий бэйдж, вне панели, угол экрана.

## Инварианты (проверка рендер-верификатором 1080p/2K/4K)
- Ничего не вылазит за экран: панель clamp по вьюпорту; ряд 1008 ≤ 1064 content.
- Нет наслоений: единственный ряд из 2 карт, gap 48.
- Текст в рамке: autowrap + короткие подписи + центр-инсеты карт.
- Ассеты в точный размер / 9-slice: economy-рамки и фон — без растяжения орнамента.
- Тесты: `tests/ui_no_overlap_matrix_test.gd`, `tests/display_resolution_test.gd`,
  `tests/runtime_smoke_test.gd`.

## ЭТАП 2 — Генерация красоты

Сейчас костёр заимствует общий `ui_backdrop_system_cathedral.png` (нейтральный
собор) — он не тематичен «отдыху у костра». Генерируем выделенный тёплый бэкдроп
**`ui_backdrop_rest_campfire.png`** (2560×1440), подключаем как
`SCREEN_BACKGROUND_PATHS["campfire"]`. Рамки/карты — общие economy-ассеты
(уже в едином стиле), не дублируем.

- Ассет: `assets/backgrounds/ui/ui_backdrop_rest_campfire.png` (2560×1440, 16:9).
- Превью-источник: `docs/design/references/rest_campfire_backdrop/`.
