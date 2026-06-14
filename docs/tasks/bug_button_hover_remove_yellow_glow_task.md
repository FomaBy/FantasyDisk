# UX: Переделать hover кнопок — ярче и контрастнее, БЕЗ жёлтого свечения

Статус: blocked
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-318
Блокируется: SCRUM-281 (активная Design-задача меняет `scripts/ui_screens.gd` и Hero Select frame/safe-area; не брать Back-end UI hover pass параллельно до результата/QA)
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
- [ ] Hover/focus всех кнопок — ярче и контрастнее, БЕЗ жёлтого свечения и золотого текста.
- [ ] Единообразно во всех экранах; pressed/disabled не сломаны.
- [ ] 6 smoke зелёные; скрин hover в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Dispatcher Hold — 2026-06-14
- Задача не dispatch'ится в Back-end, пока Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` активно правит `scripts/ui_screens.gd` по SCRUM-281.
- После SCRUM-281 result/QA dispatcher должен снять blocker и отправить SCRUM-318 в Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`, если hover/focus жёлтое свечение всё ещё актуально.
