# BUG: События — текст опций не влезает в рамку + дубль «Риск: Риск:»

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (отчёт пользователя + скриншот)
Jira: SCRUM-415

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
- 2026-06-15T06:13Z — Board dispatcher routed to Back-end thread
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` as priority 2 in the Back-end bug
  queue (reasoning High/no low). Active-owner audit: Back-end was idle; Design
  main was actively working SCRUM-412; Designer 2 and Animator had no eligible
  owner work. Back-end owns UI text/layout/tests/docs for this bug.

## Контекст (отчёт пользователя + диагностика)
«В эвентах текст опций не поместился в рамки» (скрин «Зеркальный фантом»).

Найдено:
- **Дубль «Риск: Риск:»**: ui_screens.gd:4231/4240 добавляют префикс
  `marker := "Риск: "`, а описания в event_data.gd УЖЕ начинаются с «Риск: »
  (напр. строка 75: «Риск: элитный бой против фантома…») → выходит «Риск: Риск: …».
- **Переполнение карточки**: длинный текст опции не влезает в карточку
  `_make_economy_choice_card(..., Vector2(250, 375))` (ui_screens.gd:4071) — строки
  упираются в рамку/обрезаются.

## Требования
1. **Убрать дубль «Риск:»**: либо не добавлять префикс `marker` (4231/4240), если
   описание уже содержит «Риск:», либо убрать «Риск: » из описаний event_data.gd
   и оставить только программный маркер. Единый источник — без задвоения. Проверить
   ВСЕ события (event_data.gd) на «Риск:».
2. **Текст опции влезает в карточку**: автоперенос в пределах content-зоны рамки,
   при необходимости увеличить высоту карточки/уменьшить шрифт/добавить внутренний
   отступ; длинные описания не упираются в орнамент (правило фреймов) и не
   обрезаются. Заголовок/«Выбрать» остаются на местах.
3. Применить и к другим экономическим карточкам с длинным текстом (rest/upgrade),
   если там тоже упирается.
4. Тест (smoke + no-overlap): экран события строится; текст опций целиком в
   content-зоне, без дубля «Риск:», на 1280×720/1920×1080/2560×1440. Скрин в build/qa/.
5. CHANGELOG; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_event_screen 4046; EventChoice card 4071;
  marker «Риск: » 4231/4240; _make_economy_choice_card 5966)
- scripts/event_data.gd (описания опций — «Риск:» в тексте)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Нет дубля «Риск: Риск:» ни в одном событии; единый источник маркера.
- [ ] Текст опций целиком помещается в content-зоне карточки, не упирается в рамку/не обрезается на 3 разрешениях.
- [ ] smoke + no-overlap зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, content_registry.
