# Кнопки — не растягивать арт (широкие/высокие); много текста — в рамку над кнопкой

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-263
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«1) Если кнопка широкая — лучше её сильно не растягивать. 2) Если кнопка высокая —
тоже не растягивай. Если надо писать много текста на кнопке — лучше делать это во
фрейме НАД кнопкой, а стандартная кнопка ПОД фреймом».

Кнопки — пергамент+печать 9-slice (`_make_button`/`_apply_fantasy_button_theme`,
кадры `ui_df_button_*`). При сильном растяжении арт/печать/орнамент искажаются.

## Требования
1. **Дисциплина растяжения (ширина):** широкие кнопки не растягивать сверх
   разумного — задать МАКС визуальную ширину «капсулы» кнопки (или удерживать
   пропорцию через корректный 9-slice: тянется только центральная нейтральная
   зона, концевые сегменты с печатью/орнаментом — фиксированы). Очень широкие
   ряды — выравнивать контент, а не растягивать единую кнопку в полосу.
2. **Дисциплина растяжения (высота):** аналогично по вертикали — кадр не
   растягивается так, что печать/орнамент плющатся/мылятся (учесть SCRUM-227:
   высота достаточная, но не чрезмерная; центральная зона тянется, торцы — нет).
3. **Паттерн «много текста → рамка над кнопкой»:** ввести переиспользуемый
   хелпер — когда на элемент нужно много текста (описание/детали), текст идёт
   в ОТДЕЛЬНУЮ информ-рамку (панель-«фрейм») НАД кнопкой, а под ней — компактная
   СТАНДАРТНАЯ кнопка действия (короткий лейбл). Не пихать абзацы в саму кнопку.
   Применить там, где сейчас многострочный текст в кнопке (напр. награды/выборы,
   если остались — согласовать с уже сделанными text-field карточками level-up).
4. Сохранить кликабельность, клавиатурную навигацию, no-overlap (qa_protocol).
5. Тест (smoke): кнопки с большой шириной/высотой — фактический кадр без
   искажения торцов (проверка геометрии 9-slice/мин-макс); паттерн «рамка+кнопка»
   создаёт оба узла (информ-рамка + компактная кнопка) для text-heavy случаев.
6. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_button, _apply_fantasy_button_theme, потребители)
- assets/sprites/ui/frames/dark_fantasy/ui_df_button_*.png (.import nine-patch margins)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Широкие/высокие кнопки не искажают арт (торцы фиксированы, тянется центр).
- [ ] Хелпер «много текста → рамка над + стандартная кнопка под» введён и применён.
- [ ] Кликабельность/навигация/no-overlap сохранены; 6 smoke зелёные; скрин в build/qa/.

## Документация
docs/design/current_game_state.md (UI-кнопки), visual_style_assets.md.

## Result — 2026-06-13
Статус: done

- Added button stretch discipline through shared action button sizing: visual width is capped at 560px, preventing the parchment/wax-seal frame from becoming a long stretched strip.
- Added reusable `_add_text_action_block()` helper: long text is rendered in a leather/gold info frame above a short standard action button.
- Applied the frame+button pattern to text-heavy reward, rest, upgrade and event choices while keeping click behavior and expected node names (`EventChoiceButton*`, `RestHealButton`, `RestGuardButton`).
- Compact utility controls and card-style controls remain explicit exceptions and do not use wax-seal action styling.
- Smoke/no-overlap coverage passed with updated standard-height assertions.

Verification:
- `runtime_smoke_ui_test.gd` — passed.
- `ui_no_overlap_matrix_test.gd` — passed.
- `runtime_smoke_test.gd` — passed.
- `runtime_smoke_combat_test.gd` — passed.
- `runtime_smoke_progression_economy_test.gd` — passed.
- `runtime_smoke_weapon_mechanics_test.gd` — passed.
- `runtime_smoke_boss_elite_test.gd` — passed.

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/systems/visual_style_assets.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: a785da46 (ветка dev)

Проверено (фактически):
- **Дисциплина растяжения**: визуальная ширина action-кнопок capped 560px (рамка
  не вытягивается в полосу); хелпер «много текста → info-frame НАД + короткая
  стандартная кнопка ПОД» введён и применён к rewards/rest/upgrade/events.
- **Тесты**: `runtime_smoke_ui` + `ui_no_overlap_matrix` + `runtime_smoke`
  (+ combat/progression focused) — все passed; кликабельность/навигация/no-overlap
  сохранены.

Acceptance:
- [x] Широкие/высокие кнопки не искажают арт (cap 560px, торцы фиксированы).
- [x] Хелпер info-frame-над-кнопкой введён и применён.
- [x] Кликабельность/навигация/no-overlap; smoke зелёные.

Баги: нет.
