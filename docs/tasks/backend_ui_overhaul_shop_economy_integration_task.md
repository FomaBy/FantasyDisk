# Задача Для Back-end-Агента: Интеграция SCRUM-332 Shop/Economy UI Frame Kit

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Designer 2 handoff from SCRUM-332
Jira: SCRUM-406

## Dispatch
2026-06-14 — Documentation dispatcher routed to Back-end window
`019eabd9-780b-78a2-9f4b-e7203d659ef2` after SCRUM-332 Design package moved to
review. Keep reasoning High / no low; Back-end scope only.

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи. Работать
автономно, не ждать дополнительных подтверждений.

## Контекст
Design SCRUM-332 подготовил mockup-first UI pack для economy node cluster:
merchant shop, attribute shop, rest/campfire, upgrade, and random event screens.
Design ownership завершает art/spec/safe-zone pass; live Godot layout and focus
behavior remain Back-end-owned.

## Что Уже Сделано
- OpenAI/API mockup:
  `docs/design/mockups/scrum332_shop_economy/scrum332_economy_cluster_mockup.png`.
- Spec and geometry:
  `docs/design/mockups/scrum332_shop_economy/spec.md`.
- Generated source sheet:
  `docs/design/references/ui_overhaul_shop_economy/scrum332_economy_frame_asset_sheet.png`.
- Runtime-ready frame assets:
  - `assets/sprites/ui/frames/economy/ui_frame_economy_panel.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_hover.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_dragon_panel.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_price_badge.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_tooltip.png`
- Contact preview:
  `docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`.
- Builder:
  `tools/build_scrum332_shop_economy_assets.py`.

## Что Нужно От Back-end
Integrate the SCRUM-332 frame kit into `scripts/ui_screens.gd` without changing
shop economy, route progression, reward logic, prices, rerolls, event outcomes,
or combat state.

Suggested scope:
- `_show_attribute_shop`: use `economy_panel` + `economy_choice_card` /
  `economy_choice_card_hover` for the 2 stat offers; keep reroll/skip button
  semantics.
- `_show_rest_screen`, `_show_upgrade_screen`, `_show_event_screen`: use
  `economy_panel` and choice-card frames while preserving `_add_text_action_block`
  behavior.
- `_show_shop_screen`: keep direct-on-background item layout; optionally switch
  tooltip/price badge to `economy_tooltip` / `economy_price_badge`.
- Do not squash `economy_choice_card` into square shop slots. If square shop
  slots must be replaced, create a Design follow-up for a dedicated square slot.

## Files / Assets / IDs
- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd` if a central texture path map is preferred
- `assets/sprites/ui/frames/economy/*.png`
- `docs/design/mockups/scrum332_shop_economy/spec.md`

## Acceptance Criteria
- Economy node screens build and preserve behavior:
  shop purchase/reentry, attribute reroll/buy/skip, rest choices, upgrade
  choices, event choices and back/escape actions.
- Runtime content stays inside SCRUM-332 safe zones; no text/icon/button/card
  overlaps frame ornament, gems, dragon head, metal, or tooltip notch.
- UI no-overlap matrix passes at `1280x720`, `1920x1080`, `2560x1440`.
- `runtime_smoke_ui_test.gd` and `runtime_smoke_test.gd` pass.
- QA screenshots or rect dumps are written under `build/qa/scrum332/`.

## Документация
Update `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`
and `CHANGELOG.md` after live integration.

## Result
2026-06-14 — Back-end integration complete.

- Wired SCRUM-332 economy frames into runtime: attribute shop, campfire/rest,
  upgrade and event screens now use `ui_frame_economy_panel` plus safe-zone
  `ui_frame_economy_choice_card` content containers.
- Preserved economy behavior: shop stock/purchase/reentry, attribute buy/reroll/
  skip, rest choices, upgrade choices, event choices/back and Escape flow remain
  unchanged.
- Kept shop as direct-on-wall items instead of squashing tall choice cards into
  slots; tightened the wall item layout to compact square slots and switched
  only the price badge to `ui_frame_economy_price_badge`.
- Updated smoke/no-overlap coverage and wrote
  `build/qa/scrum332/economy_ui_no_overlap_matrix.md`.

Verification:
- `runtime_smoke_ui_test.gd` PASS.
- `ui_no_overlap_matrix_test.gd` PASS.
- `runtime_smoke_test.gd` PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED — live-интеграция SCRUM-332 economy frame kit

Проверено (фактически):
- **Рантайм-привязка** (ui_screens.gd:126-131 `ECONOMY_*_PATH`): `_economy_panel_style`
  на attribute shop (1377), `_make_economy_choice_card` на attribute offers (1453),
  rest heal/guard (3914/3921), upgrade choices (3936); `ECONOMY_PRICE_BADGE_PATH`
  на shop price badge (3857). Content margins масштабируются из source в display.
- **No-overlap дамп** `build/qa/scrum332/economy_ui_no_overlap_matrix.md`: 5 экранов
  (shop/attribute/rest/upgrade/event) на 5 разрешениях (1152/1280/1600/1920/2560) —
  карточки/кнопки не накладываются (проверил x-координаты: upgrade 175/449/723 @250w,
  rest 262/586 @300w, attribute offers 348/620 @250w — зазоры положительные).
- **Тесты**: `ui_no_overlap_matrix_test` + `runtime_smoke_ui_test` + `runtime_smoke_test`
  — все passed. Economy-логика (`_random_rewards`/purchase/reroll/route) не тронута.

Acceptance:
- [x] Economy-экраны строятся, поведение (shop/attribute/rest/upgrade/event/escape) сохранено.
- [x] Контент в safe-zone SCRUM-332; нет наложений на орнамент (rect-дамп).
- [x] ui_no_overlap на 1280/1920/2560 PASS; runtime_smoke_ui + runtime_smoke PASS.
- [x] QA rect-дамп в build/qa/scrum332/.

⚠️ Watch-item (не дефект): вертикаль attribute shop тугая — `AttributeSkipButton`
низом y≈891/900 на базовом 1600×900 (зазор ~9px); спасает `window/stretch/mode=canvas_items`
+`aspect=expand` (база масштабируется в любое окно). Влезает на базе и всех ≥ разрешениях.

Статус done. Баги: нет. Закрывает live-economy петлю 332+406.
