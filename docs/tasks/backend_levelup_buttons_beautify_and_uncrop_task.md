# UX: Кнопка повышения уровня — красивая по референсу меню + «Позже» не обрезана

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-348
QA: in_progress (2026-06-14)
Связано: SCRUM-278 (кнопка повышения в углу), SCRUM-273 (button kit), SCRUM-343 (обрезка кнопок), SCRUM-318 (hover)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
1) «Надо сделать красивой кнопку повышения уровня — по референсу кнопки из меню».
2) «Кнопка "Позже" при повышении уровня обрезана — надо использовать необрезанную
кнопку».

Код:
- Кнопка повышения (HUD) `LevelUpPlusButton` (_update_level_up_button,
  ui_screens.gd:3822+) сейчас на «плоском» статичном стиле
  `_apply_static_level_up_return_button_theme` (3838) — не красивая рамка меню.
- Кнопка `LevelUpLaterButton` «Позже» (2569-2575), `_set_action_button_size(240.0)`
  — текст/орнамент обрезаются (тот же класс бага, что SCRUM-343).

## Требования
1. **Кнопка повышения уровня — в стиле кнопок главного меню**: применить
   красивую рамку меню (`_apply_fantasy_button_theme` / Red&Gold kit, как у
   MainMenu-кнопок) вместо плоского статичного стиля. Сохранить требования
   SCRUM-278: позиция в правом-нижнем углу, НЕпрозрачность, бейдж счётчика читаем;
   hover без жёлтого свечения (SCRUM-318). Не обрезать текст/бейдж.
2. **Кнопка «Позже» — необрезанная**: подобрать ширину/высоту/asset_type, при
   котором текст и орнамент НЕ режутся (можно чуть крупнее), контент в content-зоне
   рамки. Согласовать с фиксом SCRUM-343 (единый подход к обрезке кнопок).
3. Не ломать логику: открытие выбора улучшения (_open_pending_level_up), отложенный
   выбор (defer_choice), обновление видимости (_update_level_up_button), бейдж (N).
4. Тест (smoke): HUD-кнопка повышения красивая (рамка меню), не обрезана, в правом-
   нижнем углу, непрозрачная; «Позже» не обрезана. Скрин(ы) в build/qa/.
   CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_update_level_up_button 3809/3822+; LevelUpPlusButton;
  _apply_static_level_up_return_button_theme; _apply_fantasy_button_theme;
  LevelUpLaterButton 2569-2575; _set_action_button_size; _button_asset_type)
- scripts/main.gd (level_up_button 321)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Кнопка повышения уровня красивая (стиль кнопок меню), не обрезана; позиция/непрозрачность/бейдж (SCRUM-278) сохранены; hover без жёлтого.
- [ ] Кнопка «Позже» не обрезана (текст+орнамент), контент в content-зоне.
- [ ] Логика повышения цела; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Result / Verification
Готово 2026-06-14:
- `LevelUpPlusButton` переведена на Red & Gold `main_menu` frame через общую fantasy button theme: кнопка остается в правом нижнем углу, полностью непрозрачная, с читаемым pending-бейджем и нейтральным hover/focus без желтого свечения.
- `LevelUpLaterButton` расширена до 260x104 и использует `back_m`, чтобы «Позже» и орнамент не обрезались и оставались в content-зоне.
- Runtime smoke проверяет стиль/alpha/позицию `LevelUpPlusButton`, не обрезанный `LevelUpLaterButton` и пишет QA dump `build/qa/combat_level_up_button.md`.
- Verification: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
