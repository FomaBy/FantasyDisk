# Задача Для Back-end-Агента: Карточки повышения уровня — стиль поля с текстом, не кнопки

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя со скриншотом)
Jira: SCRUM-226
QA: in_progress (2026-06-13)

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
- [x] Карточки level-up — стиль поля с текстом, не кнопки; текст читается.
- [x] Кликабельность/навигация/3 варианта/«Позже» сохранены; rare-акцент в стиле поля.
- [x] no-overlap; smoke зелёный; CHANGELOG/current_game_state обновлены.

## Документация
docs/design/current_game_state.md (экран повышения уровня).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of a serialized UI batch with SCRUM-224/SCRUM-225 because all three touch `scripts/ui_screens.gd`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.

## Result Summary (2026-06-13)

Implemented `_level_up_text_field_style()` and changed `_make_level_up_reward_button()` to build clickable text-field/panel cards instead of using `_apply_fantasy_button_theme(..., "reward")`. Cards retain full-button interaction, focus navigation, icons, title/preview/description hierarchy, rare gold accent and exactly 3 variants; `Позже` remains available for deferred choice.

Verification:
- Runtime smoke checks exactly 3 reward cards, `level_up_text_field_card` metadata, non-`StyleBoxTexture` styling, icon and description text.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 35b79e06 (ветка dev)

Проверено (фактически):
- **Код**: `_make_level_up_reward_button` (ui_screens.gd:2310) строит `Button` с
  мета `level_up_text_field_card=true`, все состояния через
  `_level_up_text_field_style()` (`StyleBoxFlat`, НЕ `_apply_fantasy_button_theme`),
  `focus_mode=FOCUS_ALL`, `clip_text=false`. Оставшийся вызов reward-button-темы
  (2399) принадлежит `_make_elite_artifact_card` — это ДРУГОЙ экран (награда
  элитки), не регресс.
- **Кликабельность функциональна**: caller (2151) подключает
  `button.pressed.connect(... _apply_reward_to_active_run(reward))` — клик
  карточки применяет усиление; клавиатурная навигация сохранена (FOCUS_ALL).
- **«Позже»/Escape**: `LevelUpLaterButton` + `game.ui_escape_action=defer_choice` —
  отложенный выбор без траты пика.
- **Целевой тест не пустышка** (runtime_smoke:803-836): ровно 3 карточки,
  каждая с мета-флагом text-field, normal/hover НЕ `StyleBoxTexture`, иконка
  `UIIcon_*`, непустой `LevelUpRewardDescription`, читаемые размеры (≥190×120).
  Прошёл.
- **Регрессия (4×smoke)**: runtime / animation / meta / targeting — зелёные;
  `ui_no_overlap_matrix_test` — passed (1152/1280/1469/2560).
- **Визуал** (`build/qa/scrum227/level_up.png`, тот же экран): 3 карточки в виде
  полей с текстом (название → параметр X→Y → описание), без тяжёлой
  reward-button рамки; перекрытий нет.
- **Доки**: CHANGELOG (строка 224/225/226/227) + `current_game_state.md:616`
  (level-up как text-field/panel карточки, кликабельные) обновлены.

Краевые случаи:
- Клик действительно применяет награду (pressed→`_apply_reward_to_active_run`).
- Отложенный выбор через «Позже» и Escape — пик не тратится.
- Описание не обрезается (`clip_text=false`, тест требует непустой текст).
- rare-акцент сохранён в стиле поля (`_level_up_text_field_style(..., is_rare)`).
- no-overlap на 1280/1600/2560.

Баги: нет.
