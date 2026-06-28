# SCRUM-565 — UI-редизайн «Событие» @2K (2560×1440)

Эпик: SCRUM-481 (UI Overhaul 2K). Экран: **Событие** · нода `EventScreen` · вход
`_show_event_screen` (`scripts/ui_screens.gd`). База дизайна 2560×1440, `stretch=canvas_items`,
`aspect=keep` (1080p — uniform downscale, 4K — uniform upscale, не-16:9 — чёрные полосы).

## ЭТАП 1 — раскладка / метрики (зафиксированы код-константами)

Координатная спека уже была закреплена в `docs/design/ui_screens_inventory.md` (блок
«Боевые», SCRUM-487) и продублирована рядом с asset-блоком в `scripts/ui_screens.gd`:

| Слот | const (`ui_screens.gd`) | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель события (фрейм) | `EVT_PANEL_2K` | 420 | 330 | 1720 | 780 |
| Safe-area (контент) | `EVT_SAFE_2K` | 478 | 402 | 1604 | 642 |
| Карточка выбора (×3, gap 48) | `EVT_CARD_2K` | — (центр) | — | 480 | 340 |
| Кнопка «Назад» | `EVT_BACK_BUTTON_2K` | — (центр) | — | 380 | 54 |

Раскладка: заголовок + история события сверху (длинный текст уходит в `ScrollContainer`,
не растягивает рамку), ряд из 3 карточек выбора по центру (gap 48 @2K), кнопка «Назад»
под рядом. Все три карточки + gaps = `480*3 + 48*2 = 1536 < 1604` (safe-area) — влезают.

**Инварианты (проверены верификатором):** ничего не вылазит за экран; слоты не
наслаиваются; текст карточки держится внутри content-зоны рамки (re-inset под evt_card);
ассеты рендерятся 9-slice-safe — орнамент в margin-band, тянется только плоская середина.

## ЭТАП 2 — генерация ассетов (по утверждённым метрикам)

Ассеты сгенерированы рисующим пайплайном эпика `tools/build_ui_2k_frame_kit.py`
(SCRUM-485, детерминированный, единый дарк-фэнтези стиль bright-минимал, прозрачный фон,
9-slice-валидный, рендер-верификатор зелёный на 1080p/2K/4K). Новые per-слот рамки
нарисованы РОВНО в пиксельный размер слота @2K:

| slug | ассет | размер | 9-slice margins | content inset |
|---|---|---|---|---|
| `evt_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_evt_panel.png` | 1720×780 | 38/52/38/48 | 58/72/58/66 |
| `evt_card` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_evt_card.png` | 480×340 | 32/42/32/40 | 46/58/46/54 |

Hover-состояние карточки переиспользует `evt_card` с нейтральным рантайм-тинтом
(`BUTTON_NEUTRAL_HOVER_TINT`) — отдельный идентичный PNG не нужен (как у economy-карт).

Контактный лист пайплайна (все слоты, включая evt_*):
`docs/design/previews/ui_2k_frame_kit_contact.png`.

## Интеграция в рантайм

- `scripts/ui/ui_theme_paths.gd`: `evt_panel`/`evt_card` добавлены в
  `OVERHAUL_2K_FRAME_PATHS` / `_SOURCE_SIZE` / `_TEXTURE_MARGINS` / `_CONTENT`.
- `scripts/ui_screens.gd`:
  - `_create_menu_box(...)` принимает опциональный `panel_style_override` (без изменения
    общего economy/pause-end роутинга);
  - `_event_panel_2k_style()` строит StyleBox панели из `evt_panel` через
    `_overhaul_2k_frame_style`; `_show_event_screen` передаёт его в `_create_menu_box`;
  - `_apply_event_choice_2k_theme()` переодевает normal/hover/pressed/focus/disabled
    карточек выбора в `evt_card`; `_reinset_event_choice_content()` пере-инсетит контент
    карточки под content-зону evt_card, чтобы текст не лез на орнамент.
- Прочие economy-экраны (магазин/отдых/докача/улучшение) НЕ затронуты — у них остаётся
  общий minimal-metal economy-фрейм.

## Тесты (green-gate)

- `tests/ui_no_overlap_matrix_test.gd` — PASS (event_economy: панель=evt_panel,
  карточки=evt_card на normal+hover; no-overlap/viewport-fit/text-containment на всех
  VIEWPORT_SIZES, гейт 1080p/2K/4K).
- `tests/display_resolution_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS (+ duplicate-artifact guard).
- `python3 tools/build_ui_2k_frame_kit.py --all` — VERDICT: PASS (evt_panel/evt_card
  9-slice валидны, орнамент не плывёт на 1080p/2K/4K, центр плоский, без артефактов).
