# ART: Заменить фреймы экрана выбора героя на набор references/herouiframe

Статус: in_progress
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-281
Связано: SCRUM-274 (ornate frame kit), SCRUM-276 (описание залазит на рамку)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

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
- [ ] Все 8 элементов Hero Select используют новые фреймы из herouiframe на размерах из таблицы.
- [ ] Content margins ≥ окантовки; контент центрирован, не залазит на рамку (закрывает и SCRUM-276).
- [ ] Ascension +/- = 54×62 без регрессов других мест; старые стили в бэкап.
- [ ] 6 smoke зелёные; скрин в build/qa/; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.
