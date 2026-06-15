# BUG: Выбор героя — описание залазит на текстуру рамки, центрировать в фрейме

Статус: done (closed by SCRUM-281 QA PASSED 2026-06-14)
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя)
Jira: SCRUM-276
QA: PASSED via SCRUM-281 (2026-06-14)
Закрыто: SCRUM-281 QA PASSED 2026-06-14 закрыл safe-area/content-margin проблему Hero Select без отдельного Back-end pass.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (отчёт пользователя)
«На экране выбора героя описание героя залазит на текстуру фрейма — давай по
центру фрейма будем это показывать».

Панель досье (`dossier_panel`, ui_screens.gd:~276-300) использует `_panel_style()`
(ui_screens.gd:2790). У этого стиля **texture margins = Vector4(34,34,34,34)**, а
**content margins = Vector4(28,26,28,26)** — content МЕНЬШЕ окантовки, поэтому
текст (`HeroSelectInfoTitle`/`HeroSelectInfoDescription`/`HeroSelectTraits`/
`HeroSelectWeapons`) наезжает на декоративную рамку фрейма. То же может касаться
портрета (`_hero_portrait_style`) и радара (`_character_card_style`).

## Требования
1. Контент досье героя не должен наезжать на текстуру рамки: внутренние отступы
   (content margins) панели ≥ толщины декоративной окантовки фрейма + небольшой
   запас (safe-area). Привести content_margin `_panel_style` (и при необходимости
   `_hero_portrait_style`, `_character_card_style`) в соответствие реальной
   безопасной зоне фрейма.
2. Описание/текст досье отображать **по центру безопасной зоны фрейма**
   (горизонтальное центрирование текста + сбалансированные поля слева/справа),
   как просил пользователь.
3. Проверить, что портрет героя и радар характеристик тоже внутри своих рамок
   (не залазят на окантовку).
4. Согласовать с задачей рамок SCRUM-274 (ornate frame kit): если её content-margin
   значения уже заданы — использовать их как источник истины для safe-area.
5. Тест (smoke): на 1280x720 и широком окне — текст досье в пределах content-зоны
   панели (отступы ≥ texture margin), описание центрировано; визуальный дамп.
6. CHANGELOG; current_game_state; скрин в build/qa/.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select ~176-300; _panel_style 2790;
  _hero_portrait_style; _character_card_style; _global_texture_style)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Текст досье не пересекает окантовку рамки на всех разрешениях.
- [ ] Описание центрировано в безопасной зоне фрейма.
- [ ] Портрет и радар внутри своих рамок; no-overlap; 6 smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/current_game_state.md (экран выбора героя).

## Dispatcher Closure — 2026-06-14
SCRUM-281 `design_hero_select_replace_frames_herouiframe_task.md` получил
QA PASSED и прямо фиксирует: content margins >= окантовки, контент не залазит
на рамку, safe-area фикс закрывает SCRUM-276, багов нет. Отдельный Back-end pass
для SCRUM-276 больше не нужен; баг закрыт как resolved by SCRUM-281.

## QA-Вердикт (2026-06-14)
Статус: PASSED via SCRUM-281

SCRUM-281 QA PASSED проверил Hero Select safe-area/content margins на 720p/1080p/
1440p и подтвердил, что контент больше не залазит на рамку. Этот bug закрыт
без отдельного Back-end pass.
