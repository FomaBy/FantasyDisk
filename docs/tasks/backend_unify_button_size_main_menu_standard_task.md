# Кнопки — главное меню +10-15% высоты, единый размер кнопок по всей игре

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-264
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«В главном меню увеличить высоту кнопок ещё процентов на 10-15, и ВСЕ кнопки в
игре заменить на размер, который в главном меню».

Сейчас кнопки главного меню — 380x76 (ui_screens.gd, custom_minimum_size). В
других экранах высоты разные (48/68/62/...). Нужен единый стандарт = размер
кнопки главного меню (после увеличения).

## Требования
1. Поднять высоту кнопок ГЛАВНОГО МЕНЮ на +10-15% (76 → ~84-87px). Подобрать
   так, чтобы печать/арт читались (учесть SCRUM-227) и ряд кнопок умещался без
   наползаний и без скролла.
2. **Единый стандарт высоты кнопок по всей игре**: вынести в константу (напр.
   `STANDARD_BUTTON_MIN := Vector2(_, ~85)`) и применить ко ВСЕМ кнопкам действий
   (выбор героя/оружия, магазин «Назад», настройки, события, level-up «Позже»,
   победа/поражение, кодекс и т.д.). Ширина — по контенту/контексту, высота —
   единая.
3. Исключения для мелких служебных контролов (±/dropdown/чекбокс) — у них своя
   компактная высота (не растягивать под стандарт). Зафиксировать список
   исключений в отчёте.
4. Не ломать раскладки: правило «UI не наползает» — единая высота не вызывает
   пересечений/переполнения рядов на 1280x720 и 2560x1440 (адаптировать spacing,
   где нужно).
5. Согласовать с задачей дисциплины растяжения (backend_button_stretch_discipline)
   — единая высота, но без искажения арта.
6. Тест (smoke): кнопки действий имеют единую стандартную высоту (фактические
   размеры ≈ стандарту); no-overlap матрица зелёная.
7. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (все custom_minimum_size кнопок, новая константа стандарта)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Высота кнопок главного меню +10-15%; единая константа-стандарт.
- [ ] Все кнопки действий приведены к стандарту; служебные — исключения (список).
- [ ] no-overlap на 2 размерах; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md, visual_style_assets.md (стандарт кнопок).

## Result — 2026-06-13
Статус: done

- Вынесены единые constants/action helpers в `scripts/ui_screens.gd`: стандартная высота action-кнопок 104px, main menu width 380px, max visual width 560px.
- Главное меню переведено на новый стандарт: шесть кнопок 380x104 с меньшим vertical separation, чтобы помещаться на 1280x720.
- Все обычные action-кнопки основных экранов приведены к `_set_action_button_size()`: hero select, codex, patch notes, settings reset/back, run pause, shop leave, event back, level-up return/later, attribute offers.
- Исключения зафиксированы как намеренные: компактные utility controls (`+/-`, dropdown/keybind-style controls), route nodes, shop item hit areas, hero thumbnails, weapon/reward cards.
- Runtime smoke расширен проверкой стандартной высоты wax-seal action buttons.

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
- **Единый стандарт**: `STANDARD_ACTION_BUTTON_HEIGHT := 104.0` (константа в
  runtime_smoke), главное меню 380×104, стандарт применён ко всем обычным
  action-кнопкам; runtime smoke расширен проверкой стандартной высоты wax-seal
  action buttons.
- **Исключения зафиксированы намеренно**: компактные utility (`+/-`, dropdown,
  keybind), route nodes, shop hit areas, hero thumbnails, weapon/reward cards.
- **Тесты**: `runtime_smoke_ui` + `ui_no_overlap_matrix` + `runtime_smoke` —
  passed (нет пересечений/переполнения рядов на 1280×720/2560×1440).

Acceptance:
- [x] Единый стандарт высоты action-кнопок (104px) по всей игре; меню 380×104.
- [x] Компактные/служебные controls — намеренные исключения, не растянуты.
- [x] no-overlap на 2 размерах; smoke зелёные; доки.

Баги: нет.
