# Задача Для Back-end-Агента: Выбор оружия — показать спрайт оружия, убрать стиль кнопки, проще и читаемее

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-225

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«На выборе оружия надо показывать спрайт оружия и убрать стиль кнопки, сделать
попроще и более читаемо».

Сейчас `_show_weapon_select` (ui_screens.gd:1987-2009): вертикальный список из
крупных ТЕКСТОВЫХ кнопок 680x84 с многострочным текстом (title + description +
«Range/AoE/Cooldown») и тяжёлым стилем кнопки. Спрайта оружия НЕТ.
Спрайты оружия есть: `assets/sprites/weapons/<weapon_id>.png`.

## Требования
1. **Показать спрайт оружия** для каждого варианта: иконка/спрайт
   `assets/sprites/weapons/<weapon_id>.png` слева от текста (или сверху карточки).
   Размер читаемый (~96-128px), RGBA.
2. **Убрать тяжёлый стиль кнопки**: вместо громоздкой текстурной кнопки —
   чистая лёгкая карточка/строка (спрайт + название + краткое описание +
   ключевые статы компактно). Hover — мягкая подсветка; клик — выбор. Зона
   клика — вся карточка.
3. **Проще и читаемее**: убрать визуальный шум, выровнять колонками
   (спрайт | название+описание | статы), единый ритм; статы — компактно и
   подписанно по-русски (Дальность/Радиус/Перезарядка вместо Range/AoE/Cooldown).
4. Раскладка: варианты в ряд или сетку (если влезает) либо аккуратный вертикальный
   список; на узком окне без переполнения. Кнопка «Назад» и Escape сохраняются.
5. Правило «UI не наползает» (qa_protocol): карточки/спрайты/текст не пересекаются
   на 1280x720 и 2560x1440 (тест фактических rect).
6. Тест (smoke): фактическое дерево — у каждого варианта есть узел спрайта оружия
   (TextureRect с корректным путём), нет старого тяжёлого button-стиля; выбор
   оружия по клику работает (selected_weapon_id ставится).
7. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_weapon_select:1987-2009)
- assets/sprites/weapons/<weapon_id>.png (все оружия классов)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Спрайт оружия показан для каждого варианта.
- [ ] Тяжёлый button-стиль убран — лёгкая читаемая карточка; статы по-русски.
- [ ] Выбор по клику работает; no-overlap; 6 smoke зелёные; скрин в build/qa/.

## Документация
docs/design/current_game_state.md (экран выбора оружия).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of a serialized UI batch with SCRUM-224/SCRUM-226 because all three touch `scripts/ui_screens.gd`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.
