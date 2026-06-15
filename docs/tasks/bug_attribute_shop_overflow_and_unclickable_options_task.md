# BUG: Экран «Докачка» переполнен и опции не кликабельны

Статус: done (2026-06-15, Claude Fable 5)
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (отчёт пользователя + скриншот)
Jira: SCRUM-413
QA: in_progress (2026-06-15)

## Результат (2026-06-15)
`_show_attribute_shop` / `_refresh_attribute_shop` (scripts/ui_screens.gd) — 3 детерминированных фикса:
1. **Переполнение убрано**: панель `AttributeShopPanel` больше не фикс 660px по высоте —
   анкоры top=0/bottom=1, поля 40px сверху/снизу → высота = вьюпорт минус поля
   (вписывается в 1280×720 и уже). Контент обёрнут в `ScrollContainer`
   (горизонтальный скролл выключен) → все опции + кнопки «Обновить»/«Пропустить»
   достижимы прокруткой даже при большом числе карточек.
2. **Недоступные опции явно затемнены**: при `money < buy_cost` карточка-кнопка
   получает серый `modulate` (0.5,0.5,0.55,0.85) — видно, что купить нельзя
   (раньше выглядела активной, но не реагировала).
3. **Клики доходят до кнопки**: иконка карточки `mouse_filter = IGNORE`
   (оверлеи `_make_economy_choice_card` уже были IGNORE) — ничего не перехватывает
   нажатие поверх Button.
Тесты: runtime_smoke + runtime_smoke_ui + ui_no_overlap_matrix — зелёные. HEAD компилируется.
Связано: SCRUM-275 (scroll настроек — тот же приём).

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
- 2026-06-15T06:13Z — Board dispatcher routed to Back-end thread
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` as priority 1 in the Back-end bug
  queue (reasoning High/no low). Active-owner audit: Back-end was idle; Design
  main was actively working SCRUM-412; Designer 2 and Animator had no eligible
  owner work. Back-end owns UI/layout/clickability/tests/docs for this bug.

## Контекст (отчёт пользователя + скриншот + диагностика)
«Экран докачки не влез на экран и опции НЕ кликабельны».

Экран `_show_attribute_shop` (ui_screens.gd:1369). Найдено:
- **Переполнение**: панель фикс-размера (offset_top -330 … offset_bottom 330 = 660px,
  центрирована, стр. ~1389-1397) — не влезает на меньшие/нестандартные вьюпорты;
  заголовок сверху и кнопки «Обновить»/«Пропустить» снизу прижаты к краям/уезжают.
- **Карточки не кликабельны**: `offer_button.disabled = money < buy_cost`
  (ui_screens.gd:1476) — при золоте 13 и цене 34 карточки DISABLED (купить нельзя),
  но **визуально выглядят активными** (нет серого) → игрок думает, что баг.
- Возможный доп.фактор: проверить, что новый фрейм/оверлей карточек и shade-слой
  не перехватывают клики (mouse_filter), и что кнопки «Обновить»/«Пропустить»
  (доступные при наличии золота/всегда) реально кликаются.

## Требования
1. **Вписать экран в любой вьюпорт**: панель «Докачки» адаптивна — не фикс 660px;
   на маленьком/нестандартном окне контент помещается (скролл ИЛИ масштаб/clamp по
   высоте), заголовок и обе нижние кнопки полностью видимы и достижимы. Проверить
   1280×720, 1920×1080, 2560×1440 и узкие/высокие окна (как на скрине).
2. **Кликабельность опций**:
   - кнопки «Обновить» (если хватает золота/остались рероллы) и «Пропустить»
     ВСЕГДА реально кликаются;
   - карточки-опции кликаются, когда золота хватает;
   - **disabled-карточки (не хватает золота) ВИЗУАЛЬНО затемнены/серые** (явная
     недоступность), а не выглядят активными — чтобы было понятно «нет золота», а
     не «сломано»; тултип/подсказка «недостаточно золота» приветствуется.
3. Убедиться, что фрейм-арт карточек/панели и shade не блокируют клики
   (mouse_filter оверлеев = IGNORE; кликает именно Button).
4. Контент в content-зоне рамок (правило фреймов), no-overlap.
5. Тест (smoke + no-overlap): экран строится и ВЛЕЗАЕТ на 1280×720/1920×1080/2560×1440
   и узких окнах; «Пропустить» эмулируемо нажимается; affordable-карточка enabled,
   unaffordable — disabled+серая. Скрин в build/qa/.
6. CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_attribute_shop 1369; панель offset 1389-1397;
  _refresh_attribute_shop 1455; offer_button.disabled 1476; _make_economy_choice_card
  5966; reroll/skip кнопки; shade mouse_filter)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] «Докачка» влезает на 1280×720/1920×1080/2560×1440 и узких окнах; обе нижние кнопки видимы и кликабельны.
- [x] Опции кликаются когда доступны; недоступные (нет золота) визуально серые/disabled с подсказкой, не выглядят активными.
- [x] Оверлеи не блокируют клики; no-overlap; smoke + matrix зелёные; QA dump; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## QA-Вердикт (2026-06-15)
Статус: PASSED — экран «Докачка» вписывается + опции читаемо доступны/недоступны

Проверено (фактически, против HEAD — фикс закоммичен; чужой 412 event-WIP в working-tree сломал компиляцию, к 413 не относится):
- **Переполнение убрано** (ui_screens.gd `_show_attribute_shop`): панель не фикс-660 —
  `anchor_bottom=1.0`, `offset_top=40`, `offset_bottom=-40` → высота = вьюпорт−80px
  (вписывается в 1280×720 и узкие окна). Контент в `ScrollContainer`
  (`horizontal_scroll_mode=SCROLL_MODE_DISABLED`) → опции + «Обновить»/«Пропустить»
  достижимы прокруткой. No-overlap дамп: AttributeShopPanel адаптивна (~576-640px vs
  прежние фикс-660).
- **Недоступные опции затемнены** (`_refresh_attribute_shop`): при `money < buy_cost`
  `offer_button.disabled=true` + `modulate=Color(0.5,0.5,0.55,0.85)` (серая) + tooltip —
  явно видно «нет золота», а не «сломано».
- **Кликабельность**: оверлеи/иконки карточки не перехватывают клик (mouse_filter IGNORE),
  кликает Button; affordable-карточка enabled, unaffordable disabled+серая.
- **Тесты (HEAD изолированно)**: `runtime_smoke_test` + `runtime_smoke_ui_test` +
  `ui_no_overlap_matrix_test` — все passed. HEAD компилируется.

Acceptance:
- [x] «Докачка» вписывается на 1280×720/1920×1080/2560×1440 и узких окнах; нижние кнопки достижимы (scroll).
- [x] Опции кликаются когда доступны; недоступные серые/disabled + tooltip, не выглядят активными.
- [x] Оверлеи не блокируют клики; no-overlap; smoke + matrix зелёные.

Статус done. Баги: нет. Закрывает watch-item attribute-shop overflow из QA SCRUM-406.
(Примечание: working-tree имел parse error от незакоммиченного 412 event-WIP — не относится к 413, фикс 413 в HEAD зелёный.)

## Result / Back-end follow-up
- 2026-06-15 — Current Back-end pass tightened the live fix in
  `scripts/ui_screens.gd`.
- `AttributeShopPanel` now also clamps width to the viewport, `AttributeOffers`
  is a grid instead of a single horizontal row, offer cards and reroll/skip
  actions use compact dimensions that fit 1152x648/1280x720, and disabled
  cards include an explicit insufficient-gold tooltip.
- QA dumps:
  `build/qa/scrum413/attribute_shop_no_overlap_matrix.md` plus the shared
  `build/qa/scrum332/economy_ui_no_overlap_matrix.md`.
- Verification:
  - `runtime_smoke_ui_test.gd` — PASS;
  - `ui_no_overlap_matrix_test.gd` — PASS;
  - `runtime_smoke_test.gd` — PASS.
