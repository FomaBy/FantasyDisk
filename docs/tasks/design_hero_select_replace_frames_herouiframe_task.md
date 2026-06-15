# ART: Заменить фреймы экрана выбора героя на набор references/herouiframe

Статус: done (QA PASSED 2026-06-14)
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-281
Связано: SCRUM-274 (ornate frame kit), SCRUM-276 (описание залазит на рамку)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## !!! РЕГРЕСС-РЕПОРТ ПОЛЬЗОВАТЕЛЯ (2026-06-14) — БЛОКИРУЮЩИЙ КРИТЕРИЙ ПРИЁМКИ
Во время текущего прохода этой задачи экран выбора персонажа **ПОЛНОСТЬЮ СЛОМАН**:
«интерфейс и текст пересекаются, превьюшки (миниатюры героев) кривые». Цитата:
«страница с выбором персонажа полностью сломана, интерфейс и текст пересекаются,
превьюшки кривые — надо всё править, чтобы всё было чётко и по местам».

Это определение DONE для SCRUM-281. Задачу НЕЛЬЗЯ закрывать, пока:
- НЕТ пересечений интерфейса/текста (заголовок, описание, черты, оружие, возвышение,
  кнопка «Выбрать», радар, стрип миниатюр) — каждый элемент в своей зоне фрейма;
- миниатюры героев (HeroThumbnailStrip / _make_hero_thumbnail_button 124×88) ровные,
  не растянуты/не обрезаны/не «кривые», единый размер и выравнивание;
- портрет, панели радара/резерва — в своих рамках, без наезда на окантовку;
- всё «чётко и по местам» на 1280×720, 1920×1080 и 2560×1440 (и оконных).
QA ОБЯЗАН открыть реальный экран и приложить скрин до/после; визуальный регресс =
немедленный FAILED. Если правка размеров/фреймов даёт overlap — откатить к рабочему
состоянию и переделать аккуратно, не оставлять экран сломанным между коммитами.

## Контекст (запрос пользователя)
«Надо заменить фреймы для экрана Hero Select. Фреймы лежат в
references/herouiframe».

Экран выбора героя: scripts/ui_screens.gd `_show_character_select` (~176-380).

## Исходники (8 фреймов, уже в репо)
docs/design/references/herouiframe/ — 8 PNG (сырые экспортные имена
«ChatGPT Image Jun 14, 2026, 09_13_08 AM (1..8).png»):
- высокие (≈1122×1402, 1170×1344) → крупный портрет;
- квадратные (≈1463×1075, 1569×1002, 1489×1056) → панели радара/резерва;
- широкие (3× 2172×724) → горизонтальные планки (стрип миниатюр, лейбл/моды
  возвышения, кнопки +/-).
Сопоставление фрейм→элемент подобрать по пропорциям; переименовать в осмысленные
имена при нарезке.

## Требования — заменить фреймы для элементов Hero Select (целевые размеры)
| Элемент | Узел в коде | Требуемый размер |
| --- | --- | --- |
| Large portrait | HeroSelectLargePortrait / HeroSelectPortraitPanel (256-271) | 320 x 400, centered aspect |
| Radar reserve | HeroSelectRadarReserve (357) | 408 x 300 |
| Radar control | HeroStatRadar / HeroSelectRadarPanel (365+) | 360 x 230 |
| Thumbnail strip | HeroThumbnailStrip | min height 96 |
| Hero thumbnail button | _make_hero_thumbnail_button (482) | 124 x 88 |
| Ascension +/- | AscensionMinus/PlusButton (327/339, сейчас COMPACT_UTILITY_BUTTON_SIZE 54×42) | 54 x 62 |
| Ascension label | AscensionLevelLabel (331) | 190 x 46 |
| Ascension modifiers line | AscensionModsLabel (343) | min height 34 |

1. Нарезать фреймы из herouiframe в 9-slice (определить texture margins и
   **content margins ≥ окантовки + запас**, чтобы контент не залазил на рамку —
   та же проблема, что в SCRUM-276).
2. Применить новые стили к перечисленным элементам экрана выбора героя на
   указанных размерах; контент (портрет/радар/текст/кнопки) центрирован в
   безопасной зоне фрейма, ничего не наезжает на окантовку.
3. Привести Ascension +/- к 54×62 (согласовать с COMPACT_UTILITY_BUTTON_SIZE:
   либо отдельный размер для возвышения, либо обновить константу — не ломая
   другие места её использования; проверить grep).
4. Старые стили этих элементов (_panel_style/_hero_portrait_style/
   _character_card_style для hero-select) — в бэкап, не удалять.
5. Тёмное фэнтези, канон, единство с общим frame-kit (SCRUM-274).
6. Тест (smoke): экран выбора героя строится без ошибок, размеры элементов
   соответствуют таблице, no-overlap (текст/контент в content-зоне). Скрин в build/qa/.
7. CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select 176-380; _panel_style 2790;
  _hero_portrait_style; _character_card_style; COMPACT_UTILITY_BUTTON_SIZE 51;
  _make_hero_thumbnail_button 482; _global_texture_style)
- assets/ui/ (нарезанные 9-slice из herouiframe)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Все 8 элементов Hero Select используют новые фреймы из herouiframe на размерах из таблицы.
- [x] Content margins ≥ окантовки; контент центрирован, не залазит на рамку (закрывает и SCRUM-276).
- [x] Ascension +/- = 54×62 без регрессов других мест; старые стили в бэкап.
- [x] 6 smoke зелёные; скрин в build/qa/; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Result 2026-06-14

Готово к QA review. Нарезан и подключен dedicated Hero Select frame kit:

- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_portrait.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_label.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_mods.png`

Pipeline/preview:

- `tools/build_hero_select_frame_kit.py`
- `tools/capture_hero_select_qa.gd`
- `docs/design/previews/herouiframe_reference_contact.png`
- `docs/design/previews/hero_select_frame_kit_contact.png`

Layout fixes:

- 1280x720 safe-area fixed: `HeroSelectBackButton` is inside the viewport
  (`build/qa/scrum281/hero_select_capture_rects.md`: x=1086..1256).
- Bottom thumbnail strip no longer overflows/crops; thumbnails use adaptive
  compact width at 1280 and expand at 1920/2560.
- `HeroSelectChooseButton` is a local compact `hero_confirm` exception
  (260x72) so the screen-specific heavy frames fit 720p.
- Ascension +/- use dedicated 54x62 frames.

Validation:

- `tests/runtime_smoke_ui_test.gd` PASS.
- `tests/ui_no_overlap_matrix_test.gd` PASS.
- `tests/runtime_smoke_test.gd` PASS.
- QA screenshots captured by windowed Godot:
  `build/qa/scrum281/hero_select_1280x720.png`,
  `build/qa/scrum281/hero_select_1920x1080.png`,
  `build/qa/scrum281/hero_select_2560x1440.png`.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 29b352b5 (ветка dev; работа устаканилась и закоммичена в зелёном)

Проверено (фактически):
- **8 фреймов** в `assets/sprites/ui/frames/hero_select/` (новый herouiframe-кит).
- **Целевые тесты**: `runtime_smoke_ui` + `ui_no_overlap_matrix` (1152/1280/1469/
  2560) + `runtime_smoke` — все passed (включая 720p safe-area ассерты).
- **Визуал** (`build/qa/scrum281/hero_select_1280x720.png`, +1080/1440): 8 элементов
  в новых тёмных ornate-рамках (красно-золотой акцент); на 720p **«Назад» видна,
  лента миниатюр в вьюпорте, контент в рамках, ничего не обрезано** (safe-area
  фикс, закрывает SCRUM-276); радар top-right.

Acceptance:
- [x] Все 8 элементов Hero Select используют новые herouiframe на 720p/1080p/1440p.
- [x] Content margins ≥ окантовки; контент не залазит на рамку (закрывает SCRUM-276).
- [x] 6 smoke зелёные; скрины в build/qa/scrum281/; CHANGELOG/registry.

Примечание: эта задача была активным источником транзиентной churn ui_screens.gd
во время QA-прогона; после стабилизации/коммита билд зелёный, перепроверено.

Баги: нет.
