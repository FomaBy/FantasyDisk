# SCRUM-575 — UI-редизайн: Настройки (@2K 2560×1440)

Эпик SCRUM-481 (UI Overhaul). Экран `_show_settings_menu` (`scripts/ui_screens.gd`),
нода `SettingsContentPanel` (корень `SettingsV2Root`). Стиль: D&D + Dark Fantasy Dragon.

## SCRUM-674 — Settings tabs, compact controls and pending Apply flow

SCRUM-674 keeps the SCRUM-575/SCRUM-439 dark fantasy Settings frame contract but
changes the Screen tab semantics:

- `SettingsScreenOption`, `SettingsResolutionOption` and
  `SettingsWindowModeOption` write into a runtime pending buffer.
- `_apply_video_settings()` is called only by `SettingsApplyButton`.
- `SettingsRevertButton` clears staged screen changes without touching persisted
  settings.
- `SettingsApplyButton` and `SettingsRevertButton` are `240×72`, disabled when
  the pending buffer matches current settings, and placed in the modal bottom
  action row next to `SettingsBackButton`.
- Sound sliders are compact `420×42` rows with the same visible dark track,
  gold fill and keyboard focus.

OpenAI mockup/spec package:
`docs/design/mockups/scrum674_settings_ui/spec.md`.

## ЭТАП 1 — Раскладка / метрики @2560×1440 (база)

Экран — V2-модалка с вкладками (TabContainer, tabs скрыты, переключение через
кастомный switcher) + content-panel со строками-контролами. Метрики
зафиксированы код-константами и масштабируются от modal_rect (responsive):

| Элемент | Нода | 2K-метрика |
|---|---|---|
| Модалка | `SettingsV2Modal` | `SETTINGS_PANEL_2K` Rect2(256,104,2048,1232) |
| Safe-зона | — | `SETTINGS_SAFE_2K` Rect2(430,229,1700,1062) |
| Заголовок | `SettingsV2Title` | `SETTINGS_TITLE_2K` Rect2(448,229,1664,64), center |
| Переключатель вкладок | `SettingsTabSwitcher` | `SETTINGS_TAB_SWITCHER_2K` Rect2(730,316,1100,220) |
| Content-панель | `SettingsContentPanel` | `SETTINGS_CONTENT_PANEL_2K` Rect2(430,570,1700,610), clip_contents |
| Строка контрола | (шаблон) | `SETTINGS_CONTROL_ROW_2K` Rect2(658,602,1438,62) |
| Назад | `SettingsBackButton` | `SETTINGS_BACK_2K` Rect2(1140,1204,280,87) |

### Компактные подписи, всё помещается (требование таска)
- Вкладки (Экран/Звук/Управление и т.д.) — короткие подписи в switcher’е.
- Каждый контрол — строка `_add_settings_control_row(box, "<короткая подпись>",
  control)` фикс-высоты 62; OptionButton’ы 520×62, EXPAND_FILL по ширине.
- Content-панель `clip_contents=true` + MarginContainer (18/14/18/14) — длинные
  списки опций ужимаются/скроллятся внутри панели, за рамку не вылазят, орнамент
  не растягивают.
- Title/строки центрированы в safe-зоне модалки.

### Инварианты — PASS на 1080p/2K/4K
- Ничего не вылазит: модалка ⊆ экран (256/104), контролы ⊆ content-панель (clip).
- Нет наслоений: title → switcher → content-panel → back — вертикально разнесены.
- Текст в рамке: clip_contents + фикс-высота строк + короткие подписи.
- Тесты: `ui_no_overlap_matrix_test` (`SettingsTabSwitcher/ContentPanel/
  ResolutionOption/WindowModeOption/BackButton`), `display_resolution_test`,
  `runtime_smoke_test`.

## ЭТАП 2 — Генерация красоты

Раньше настройки заимствовали общий `system`-собор. Сгенерирован ВЫДЕЛЕННЫЙ
тематичный бэкдроп — «арканный кабинет управления»:

- **`ui_backdrop_settings.png`** (2560×1440) — обсерватория-мастерская дракон-мага:
  дальняя стена с латунными астролябиями/шестернями/рунными циферблатами и
  янтарными управляющими сигилами (визуальная метафора «настроек/управления»),
  дракон-колонны по бокам, тёплый свет свечей по краям, тёмный спокойный ЦЕНТР под
  панель настроек. Сгенерирован `fantasydisk-asset-generator` (gpt-image-2).
- Фон-id `settings` в `SCREEN_BACKGROUND_PATHS` перенаправлен на новый ассет
  (id используется ТОЛЬКО экраном настроек — system/codex не затронуты);
  fallback-цвет → тёплый тёмный `0.050,0.044,0.038`.
- Рамки/кнопки/переключатель — общие settings-V2 стили (уже единый стиль), не дублирую.
- Источник: `docs/design/references/settings_backdrop/`,
  рантайм: `assets/backgrounds/ui/ui_backdrop_settings.png`.
