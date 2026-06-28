# SCRUM-577 — UI-редизайн: Победа (@2K 2560×1440)

Эпик SCRUM-481 (UI Overhaul). Экран `_show_victory_screen` (`scripts/ui_screens.gd`),
нода `VictoryScreen` (модалка `PauseEndModalPanel_victory`). Стиль: D&D + Dark
Fantasy Dragon.

## ЭТАП 1 — Раскладка / метрики @2560×1440 (база)

Экран — pause/end-модалка (общая с поражением: `_is_pause_end_screen_background`
→ `["pause","victory","death"]`) с эмблемой-кольцом и сводкой прогона. Метрики
зафиксированы код-константами:

| Элемент | Нода | 2K-метрика |
|---|---|---|
| Модалка | `PauseEndModalPanel_victory` | `RESULT_PANEL_2K` Rect2(831,310,898,820) (source 986×900, height clamp [520,820]) |
| Safe-зона | контент-VBox в ScrollContainer | `RESULT_SAFE_2K` Rect2(898,396,764,656) |
| Эмблема-кольцо | `ResultCrest` | `RESULT_CREST_2K` Rect2(1192,401,176,176), над заголовком |
| Кнопка | `VictoryNewRunButton` | STANDARD_ACTION_BUTTON_WIDTH × `_pause_end_result_button_height()` |

Состав (сверху-вниз, в `PauseEndModalScroll_victory`): crest → "Победа" (title) →
subtitle (итоги забега) → run-summary-rows → "Новый забег".

### Подгонка текста — всё помещается (требование таска)
- Subtitle многострочный (босс/наследие/очки умений/вознесение), но лежит в
  ScrollContainer модалки (`clip_contents=true`) — при малой высоте (compact <800px)
  title/subtitle ужимаются (font 34/15 вместо 42/17), переполнение скроллится,
  рамку НЕ растягивает.
- Кнопка «Новый забег» — короткая подпись, фикс-размер.
- Эмблема-кольцо в safe-зоне, не на орнаменте рамки.

### Инварианты — PASS на 1080p/2K/4K
- Ничего не вылазит: модалка центр-якорь, высота клампится [520,820]; контент в скролле.
- Нет наслоений: вертикальный VBox crest→title→subtitle→rows→button.
- Текст в рамке: ScrollContainer + clip_contents + compact-шрифты.
- Ассеты в точный размер: crest STRETCH_KEEP_ASPECT_CENTERED, фон без растяжения.
- Тесты: `ui_no_overlap_matrix_test` (`PauseEndModalPanel_victory/ResultCrest/
  VictoryNewRunButton`), `display_resolution_test`, `runtime_smoke_test`.

## ЭТАП 2 — Генерация красоты

Раньше «Победа» делила общий `reward_hall` с elite_reward/artifact_reward.
Сгенерирован ВЫДЕЛЕННЫЙ триумфальный бэкдроп:

- **`ui_backdrop_victory.png`** (2560×1440) — тронный зал триумфа: колоссальный
  череп поверженного дракона в золотых лучах сквозь разрушенный свод, блеск
  сокровищ-хоарда, дракон-колонны и боевые штандарты по бокам, золотая пыль;
  тёмный спокойный ЦЕНТР под результат-панель и эмблему. Сгенерирован
  `fantasydisk-asset-generator` (gpt-image-2).
- Фон-id `victory` в `SCREEN_BACKGROUND_PATHS` перенаправлен на новый ассет
  (elite_reward/artifact_reward сохраняют reward_hall); fallback-цвет (тёплое
  золото) уже подходит — не менял.
- Эмблема `ui_crest_victory.png` и pause/end-рамки — уже едины, не дублирую.
- Источник: `docs/design/references/victory_backdrop/`,
  рантайм: `assets/backgrounds/ui/ui_backdrop_victory.png`.

## Примечание по QA
runtime_smoke под нагрузкой флота дал известные ложные red’ы
`_test_run_autosave_continue_prompt` (гонка реального мета-сейва, memory
godot-userdatadir-not-isolating-real-save) — на изолированном повторе зелёный.
Дифф не трогает run/autosave-код (только фон + 1 строка фон-id).
