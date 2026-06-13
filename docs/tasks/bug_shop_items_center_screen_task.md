# Задача Для Back-end-Агента: Артефакты в магазине — по центру экрана, не сбоку

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-211

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Разместить артефакты в магазине по центру экрана, а не сбоку как сейчас —
задник поменялся».

Раньше товары вешались на «пустую стену» справа от торговца, поэтому зона
смещена вправо: `ShopParchmentWall` (ui_screens.gd:2294-2298) anchor_left=0.50,
anchor_right=0.82. После замены фона магазина (SCRUM-158, dark fantasy backdrop)
торговца-сбоку больше нет — товары должны быть по ЦЕНТРУ экрана.

## Требования
1. Перецентрировать зону товаров `ShopParchmentWall`/`ShopInlineItems`: товары
   симметрично по горизонтали относительно центра экрана (например anchor_left
   ~0.5 с центрирующим контейнером, либо зона вроде 0.18-0.82 с центровкой).
   Подобрать так, чтобы сетка/раскладка товаров читалась по центру на новом фоне.
2. Заголовок «Магазин» и подпись — уже по центру (title_box anchor 0.5),
   согласовать вертикальный ритм: заголовок сверху, товары по центру, кнопка
   «Назад» снизу — без наезда (правило «UI не наползает», qa_protocol).
3. Сохранить frameless-стиль товаров (SCRUM-160: предметы на стене, тень,
   ценник, hover, куплено=снят) и привязку стока к узлу (SCRUM-207).
4. Тест: фактические global_rect товаров центрированы (центр сетки ≈ центр X
   экрана, допуск); no-overlap с заголовком/кнопкой/HUD на 1280x720 и 2560x1440.
5. Скриншот/дамп в build/qa/; CHANGELOG.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_shop_screen, ShopParchmentWall:2294, ShopInlineItems:2306)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Товары магазина центрированы по горизонтали на новом фоне.
- [x] Frameless-стиль и привязка стока к узлу сохранены.
- [x] no-overlap зелёный; тест центровки; 6 smoke зелёные; CHANGELOG; артефакт в build/qa/.

## Документация
docs/design/current_game_state.md (экран магазина).

## Result Summary (2026-06-13)

Done.

- Moved `ShopParchmentWall` from the old right-side merchant-wall region to a centered backdrop display region (`0.20-0.80` x, `0.33-0.79` y).
- Rebalanced the four frameless shop item anchor points into a symmetric centered 2x2 wall layout.
- Moved the shop header below the top run HUD on 720p so header, HUD, items and Back button do not overlap.
- Preserved SCRUM-160 frameless item style and SCRUM-207 node-bound shop stock/purchased state.
- Extended runtime smoke to assert actual item group `global_rect` center against viewport center, plus no-overlap with header, Back button, FAB and HUD.
- QA dump updated at `build/qa/shop_wall_frameless_rects.md`: center delta is `0.0` at 1280x720 and 2560x1440.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED

Проверено фактически (код + dump + РЕАЛЬНЫЙ рендер с замером):
- `ShopParchmentWall` перецентрирован: anchor 0.20-0.80 x / 0.33-0.79 y (было правое
  0.50-0.82). Симметричная 2×2 раскладка (ui_screens:2420-2424). ✓
- Центровка: QA-dump `center_delta_x=0.0` на 1280×720 и 2560×1440; РЕНДЕР-замер
  фактических `global_rect`: items_center_x=800 == viewport_center_x=800, **delta=0**. ✓
- Визуально (build/qa/shop_items_centered/): 4 предмета симметричной 2×2 сеткой ПО
  ЦЕНТРУ экрана (vs прежний сдвиг вправо), заголовок «Магазин» сверху, «Назад» снизу,
  без наездов на HUD/заголовок/кнопку.
- Сохранены: frameless-стиль SCRUM-160 (иконки/тени/ценники) и node-bound сток SCRUM-207
  (код стока не менялся — только зона раскладки). ✓
- Тест (runtime_smoke:1893): ассертит привязку сетки к центрированной зоне + no-overlap.
- 6 smoke зелёные. Багов нет.
