# UX: Переделать hover кнопок — ярче и контрастнее, БЕЗ жёлтого свечения

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-318
QA: in_progress (2026-06-14)
Блокер снят: SCRUM-281 QA PASSED 2026-06-14; SCRUM-318 active in Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.
Связано: SCRUM-273 (Red&Gold button kit)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Hover-эффект при наведении на кнопку надо переделать: просто делать ярче и
контрастнее, БЕЗ жёлтого свечения. Надо переделать».

Сейчас hover главных кнопок даёт тёплое жёлтое свечение:
- `_button_state_style(button, role, "hover")` подставляет отдельную hover-текстуру
  Red&Gold-кита с золотым бликом/свечением (ui_screens.gd:4423-4429,
  RED_GOLD_BUTTON_TEXTURES[...]["hover"]);
- `font_hover_color = Color(1.0, 0.92, 0.45)` — золотисто-жёлтый текст
  (ui_screens.gd:4325; аналогично в compact 4439 = Color(1.0,0.82,0.32),
  secondary 4439, focus tint Color(1.08,1.05,0.86) на 4323).

## Требования
1. Убрать жёлтое свечение/тёплый блик из состояния hover у ВСЕХ кнопок
   (главные `_apply_fantasy_button_theme`, compact `_apply_compact_button_theme`,
   secondary/back, level-up return). Никакого золотого glow/bloom при наведении.
2. Вместо свечения hover должен **просто делать кнопку ярче и контрастнее**:
   - нейтральная подсветка (равномерно поднять яркость/контраст текстуры,
     напр. tint ~Color(1.15,1.15,1.15) поверх normal-текстуры ИЛИ светлее через
     `_global_texture_style` tint, без тёплого оттенка);
   - `font_hover_color` сделать ярко-нейтральным (near-white, напр.
     Color(1.0,1.0,1.0)), не золотым.
3. Если у Red&Gold-кита hover-текстура содержит запечённое жёлтое свечение —
   не использовать её для hover: либо брать normal-текстуру с осветляющим tint,
   либо запросить у дизайнера (SCRUM-273) non-glow hover-вариант. Решение —
   на усмотрение исполнителя, результат: ярче+контрастнее, без жёлтого.
4. Состояние **focus** привести к тому же нейтральному виду (сейчас тёплый tint
   Color(1.08,1.05,0.86) на 4323) — без жёлтого.
5. pressed/disabled не трогать по смыслу (только убрать жёлтый из hover/focus).
6. Применить единообразно ко всем кнопкам игры (главное меню, настройки, бой,
   codex, магазин). Проверить, что наведение читается как «ярче/контрастнее».
7. Тест (smoke): кнопки строятся; hover/focus styleboxes не используют жёлтый
   glow-ассет и font_hover_color нейтральный. Скрин hover-состояния в build/qa/.
8. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_apply_fantasy_button_theme 4317-4327; _button_state_style
  4423-4429; _apply_compact_button_theme 4432-4441; secondary/back theme 4433+;
  RED_GOLD_BUTTON_TEXTURES; font_hover_color 4325/4439)
- assets/ui/ (Red&Gold кнопки, при необходимости non-glow hover, см. SCRUM-273)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Hover/focus всех кнопок — ярче и контрастнее, БЕЗ жёлтого свечения и золотого текста.
- [x] Единообразно во всех экранах; pressed/disabled не сломаны.
- [x] 6 smoke зелёные; скрин hover в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Dispatcher Hold — 2026-06-14
- Задача не dispatch'ится в Back-end, пока Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` активно правит `scripts/ui_screens.gd` по SCRUM-281.
- После SCRUM-281 result/QA dispatcher должен снять blocker и отправить SCRUM-318 в Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`, если hover/focus жёлтое свечение всё ещё актуально.

## Dispatcher Unblock — 2026-06-14

SCRUM-281 получил QA PASSED, UI-churn blocker снят. Задача взята в Back-end
thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Result 2026-06-14

Done:
- `scripts/ui_screens.gd`: global Red&Gold button hover/focus now reuses the
  normal texture with neutral bright tint (`1.16` hover / `1.20` focus) instead
  of baked `*_hover.png`; hover/focus font is near-white. Compact buttons,
  hero-select button frames/thumbnails and level-up return hover/focus were
  aligned to the same rule.
- `scripts/pause_stats_menu.gd`: Escape/pause buttons no longer load
  `ui_btn_red_gold_pause_hover.png`; hover/focus reuse normal pause texture
  with neutral bright tint and near-white text.
- Tests updated to assert non-glow hover/focus texture paths, neutral tint and
  neutral hover/focus font.
- QA preview: `build/qa/scrum318/button_hover_neutral_preview.png`.

Verification:
- PASS: `tests/dark_fantasy_ui_theme_test.gd`
- PASS: `tests/runtime_smoke_ui_test.gd`
- PASS: `tests/ui_no_overlap_matrix_test.gd`
- PASS: `tests/runtime_smoke_combat_test.gd`
- PASS: `tests/animation_smoke_test.gd`
- PASS: `tests/runtime_smoke_test.gd`

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`,
`docs/design/systems/menus_ui.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: cea33e22 (ветка dev)

Проверено (фактически):
- **Код**: `BUTTON_NEUTRAL_HOVER_FONT = Color(1,1,1,1)` (чисто белый текст),
  `BUTTON_NEUTRAL_HOVER_TINT = 1.16` (яркость). `_button_state_style`: для hover
  `texture_state := "normal"` (берёт normal-текстуру, НЕ золотую glow `*_hover.png`)
  + `final_tint = NEUTRAL_HOVER_TINT`. Применено ко всем кнопкам (primary/secondary/
  back/compact/hero-select/level-up) + `pause_stats_menu` (pause кнопки без
  `*_pause_hover.png`).
- **Тесты ассертят non-glow**: `dark_fantasy_ui_theme_test` (non-glow hover/focus
  пути, нейтральный tint/font); `runtime_smoke_ui` + `runtime_smoke` +
  `ui_no_overlap_matrix` — все passed.
- **Визуал** (`build/qa/scrum318/button_hover_neutral_preview.png`): NORMAL/HOVER/
  FOCUS — одна и та же Red&Gold текстура, ярче (tint 1.00/1.16/1.20), «no
  *_hover.png / no yellow font». Жёлтое свечение убрано, hover = ярче+контраст.

Acceptance:
- [x] Жёлтое свечение/тёплый блик убраны из hover у ВСЕХ кнопок.
- [x] Hover делает кнопку ярче/контрастнее (brightness tint, не glow-ассет).
- [x] `font_hover_color` нейтрально-белый; smoke зелёные; скрин в build/qa/.

Баги: нет.
