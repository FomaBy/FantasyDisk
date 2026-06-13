# Задача Для Back-end-Агента: Карточки повышения уровня — стиль поля с текстом, не кнопки

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя со скриншотом)
Jira: SCRUM-226

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Выбор улучшения при повышении уровня должен иметь не стиль кнопки, а стиль
поля с текстом».

Сейчас карточки level-up — это кнопки с рамочным button-стилем:
`_make_level_up_reward_button` (ui_screens.gd:2205) = `_make_button("")` +
`_apply_fantasy_button_theme(button, "reward")` (2215). Выглядит как тяжёлая
кнопка-свиток с рамкой; пользователь хочет вид ПОЛЯ С ТЕКСТОМ (чистая
читаемая панель-карточка), а не кнопки.

Согласовано по духу со SCRUM-225 (выбор оружия — убрать стиль кнопки) и SCRUM-147
(единый dark fantasy UI-канон): карточка может остаться на пергаменте, но как
информационное поле, без «нажимаемой кнопки» вида.

## Требования
1. Убрать button-стиль карточек: вместо `_apply_fantasy_button_theme(...,"reward")`
   — лёгкая панель-«поле» (пергамент/панель без массивной рамки-кнопки и
   hover-«нажатия»). Заголовок усиления, параметр (X -> Y), описание — читаемым
   текстом в поле.
2. Карточка остаётся КЛИКАБЕЛЬНОЙ (выбор усиления) — но визуально это поле, не
   кнопка: hover — мягкая подсветка/лёгкий акцент, без эффекта «вдавленной
   кнопки». Вся карточка — зона клика, клавиатурная навигация сохраняется.
3. Читаемость: чёткая иерархия (иконка усиления → название → параметр → описание),
   текст не обрезается (сейчас clip_text=true — пересмотреть, чтобы описание
   было видно целиком или аккуратно умещалось). Редкий слот (rare) сохраняет
   золотой акцент, но в стиле поля.
4. 3 карточки в ряд, кнопка «Позже» снизу — сохранить; правило «UI не наползает»
   (qa_protocol): карточки/текст не пересекаются на 1280x720 и 2560x1440.
5. Тест (smoke): фактическое дерево — карточки НЕ используют reward-button-тему
   (нет button-stylebox), текст усиления присутствует целиком; выбор по клику
   работает (усиление применяется), ровно 3 варианта (как в SCRUM-149).
6. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_level_up_reward_button:2205, _show_level_up_screen:2025,
  _apply_fantasy_button_theme)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Карточки level-up — стиль поля с текстом, не кнопки; текст читается целиком.
- [ ] Кликабельность/навигация/3 варианта/«Позже» сохранены; rare-акцент в стиле поля.
- [ ] no-overlap; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (экран повышения уровня).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of a serialized UI batch with SCRUM-224/SCRUM-225 because all three touch `scripts/ui_screens.gd`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.
