# SCRUM-568 — UI-редизайн «Докача (атрибут-шоп)» @2K (2560×1440)

> **Historical / superseded.** Эта спецификация фиксирует прежний layout
> SCRUM-568 и сохранена как архивная evidence. С SCRUM-982/987/988 актуальный
> контракт удаляет ручной вход в Attribute Shop с Route/Rest/Shop/Event/Escape,
> сохраняет обязательный post-combat normal/elite flow и отдельный
> `LevelUpPlusButton`, использует shared hollow gold shell без второй центральной
> рамы, размещает 2 default / 3 Atlas offers в одном горизонтальном ряду с
> видимыми influence + derived previews и горизонтальными Reroll/Skip. Live
> layout targets: 1280×720, 1920×1080 и 2560×1440. Таблицы и asset notes ниже
> больше не являются источником runtime-геометрии.

Эпик: SCRUM-481 (UI Overhaul 2K). Экран: **Докача (атрибут-шоп)** · нода
`AttributeShopScreen` · вход `_show_attribute_shop` (`scripts/ui_screens.gd`).
База 2560×1440, `stretch=canvas_items`, `aspect=keep`.

## ЭТАП 1 — раскладка / метрики (код-константы)

Координатная спека закреплена в `docs/design/ui_screens_inventory.md` (блок «Прогрессия/
Экономика», SCRUM-488) и продублирована рядом с asset-блоком в `scripts/ui_screens.gd`:

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм, full-height) | `ATTR_PANEL_2K` | 730 | 28 | 1124 | 1384 |
| Safe-area (контент) | `ATTR_SAFE_2K` | 788 | 100 | 1008 | 1246 |
| Карточка опции (грид 2 кол.) | `ATTR_OFFER_2K` | — | — | 480 | 340 |
| Кнопка reroll/skip (ВНЕ скролла снизу) | `ATTR_ACTION_BUTTON_2K` | — | — | 420 | 62 |

Раскладка: высокая панель (поля сверху/снизу 28 @2K), заголовок «Докачка» + строка
золота, скролл сетки карточек опций (грид 2 колонки), фикс-низ кнопки «Обновить»/
«Пропустить» ВНЕ скролла. Строки атрибутов компактны: тело карточки держит
название+интерпретацию+цену, подробности (влияние/предпросмотр при +1) уходят в tooltip,
чтобы не ловить overflow на 720p. Недоступные (нет золота) карточки затемнены + поясняют
нехватку золота в tooltip.

**Инварианты (верификатор):** ничего не вылазит за экран; карточки/кнопки не наслаиваются;
текст в content-зоне рамки; ассеты 9-slice-safe (орнамент в margin-band).

## ЭТАП 2 — генерация ассетов

Пайплайн эпика `tools/build_ui_2k_frame_kit.py` (детерминированный, дарк-фэнтези
bright-минимал, прозрачный фон, 9-slice-валидный, верификатор PASS 1080p/2K/4K):

| slug | ассет | размер | 9-slice margins | content inset |
|---|---|---|---|---|
| `attr_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_attr_panel.png` | 1124×1384 | 38/52/38/48 | 58/72/58/66 |
| (карточка опции) | переиспользует `evt_card` (`ui_frame_2k_evt_card.png`) | 480×340 | 32/42/32/40 | 46/58/46/54 |

Карточка опции = `ATTR_OFFER_2K` 480×340 = `EVT_CARD_2K` (тот же размер/тип card), поэтому
переиспользует уже сгенерённую `evt_card`-рамку (SCRUM-565) — без дублирующего идентичного
PNG. Hover — `evt_card` с нейтральным рантайм-тинтом.

## Интеграция в рантайм

- `scripts/ui/ui_theme_paths.gd`: `attr_panel` добавлен в `OVERHAUL_2K_FRAME_PATHS` /
  `_SOURCE_SIZE` / `_TEXTURE_MARGINS` / `_CONTENT`.
- `scripts/ui_screens.gd`:
  - `_show_attribute_shop`: панель `AttributeShopPanel` рисуется
    `_overhaul_2k_frame_style("attr_panel", display)` (display = реальный rect панели);
  - `_refresh_attribute_shop`: карточки опций переодеты в `evt_card` через обобщённые
    `_apply_overhaul_choice_2k_theme(button, "evt_card", size)` +
    `_reinset_overhaul_choice_content(button, "evt_card", size)` (вынесены из SCRUM-565
    `_apply_event_choice_2k_theme`/`_reinset_event_choice_content`, чтобы переиспользовать).
- Прочие economy-экраны (магазин/отдых/улучшение) НЕ затронуты.

## Тесты (green-gate)

- `tests/ui_no_overlap_matrix_test.gd` — PASS (attribute_shop_economy: панель=attr_panel,
  карточки опций=evt_card normal+hover; no-overlap/viewport-fit/text-containment, гейт 2K).
- `tests/runtime_smoke_test.gd` — PASS (attr_panel + offer evt_card assertions обновлены).
- `tests/display_resolution_test.gd` — PASS.
- `python3 tools/build_ui_2k_frame_kit.py --all` — VERDICT: PASS (attr_panel валиден).
