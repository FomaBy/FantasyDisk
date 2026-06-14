# UX/Layout: Редизайн экрана выбора героя — лейаут 1/3·2/3 + радар + карусель (МАСТЕР)

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-333
Связано: SCRUM-281 (frame kit), SCRUM-320 (карусель), SCRUM-321 (превью),
SCRUM-322 (роза ветров), SCRUM-323 (описание), SCRUM-324 (asset-skill), SCRUM-276 (overlap)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя — авторитетная спека экрана)
«Экран выбора персонажа должен быть улучшен:
- снизу карусель выбора героев в красивом фрейме, с иконками героев, которые при
  наведении мышки подсвечиваются и показывают подсказку, что это за герой;
- слева на 1/3 ширины экрана — превью выбранного героя;
- 2/3 справа от превью — описание героя + выбор возвышения;
- справа сверху — роза ветров с характеристиками;
- все элементы в красивых фреймах; все фреймы создавать новым скиллом по созданию
  картинок/ассетов (OpenAI генератор);
- изменения НЕ должны накладываться друг на друга; весь текст читаем».

Это МАСТЕР-задача: задаёт финальный лейаут и взаимодействие. Визуал рамок —
парные задачи SCRUM-320/321/322/323 (генерируются скиллом fantasydisk-asset-generator).
Экран: scripts/ui_screens.gd `_show_character_select` (~323-570).

## Требования — ЛЕЙАУТ (точная геометрия)
1. Горизонтальная компоновка контента (HeroSelectContent / content_row):
   - **ЛЕВО — превью выбранного героя ровно на 1/3 ширины** (portrait_panel;
     сейчас stretch_ratio 0.38 — привести к 1/3). Крупный портрет в рамке
     (SCRUM-321), отцентрован.
   - **ПРАВО — 2/3 ширины: описание героя + выбор возвышения** (dossier_panel;
     заголовок, описание, черты, оружие, селектор возвышения, кнопка «Выбрать»)
     в рамке (SCRUM-323).
2. **Роза ветров (радар характеристик) — справа сверху**, плавающий виджет в
   правом-верхнем углу (HeroSelectRadarPanel, anchor TOP_RIGHT) в рамке-компасе
   (SCRUM-322). Не перекрывает описание/превью.
3. **Карусель героев — снизу**, во всю ширину, в красивом фрейме (SCRUM-320):
   иконки героев в ряд (HeroThumbnailStrip / _make_hero_thumbnail_button 124×88).
   (Размер иконок крупнее — отдельный follow-up SCRUM-342.)
4. Каждая иконка героя при **наведении мышки подсвечивается** (hover-стиль:
   ярче/контрастнее, БЕЗ жёлтого свечения — согласовать с SCRUM-318) и показывает
   **подсказку (tooltip), что это за герой** (имя + краткое описание/класс).
5. Выбранная иконка визуально выделена (selected-состояние). Клик по иконке →
   меняет превью/описание/радар на этого героя. Навигация клавиатурой+геймпадом,
   фокус доходит до всех иконок, авто-скролл к выбранной если карусель длинная.

## Требования — РАМКИ и КАЧЕСТВО
6. ВСЕ элементы (превью, описание+возвышение, радар, карусель) — в красивых
   фреймах; рамки СОЗДАЮТСЯ скиллом `fantasydisk-asset-generator`
   (OpenAI Images, gpt-image-2, PNG, прозрачный фон), стиль D&D + Dark Fantasy
   Dragon (см. SCRUM-320/321/322/323).
7. **НИЧЕГО не накладывается** друг на друга и на орнамент рамок (глобальное
   правило фреймов: контент только в content-зоне; content margins ≥ окантовки)
   на 1280×720 / 1920×1080 / 2560×1440 и оконных. Закрывает SCRUM-276.
8. **Весь текст читаем**: достаточный размер/контраст, без обрезки и наезда;
   длинные имена/описания умещаются или скроллятся.
9. Тест (smoke + no-overlap matrix): экран строится; геометрия 1/3·2/3, радар
   top-right, карусель снизу; hover подсвечивает иконку и показывает tooltip;
   no-overlap; текст в пределах рамок. Скрины 3 разрешений в build/qa/.
10. CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select 323-570; content_row;
  portrait_panel 0.38→1/3; dossier_panel 0.62→2/3; HeroSelectRadarPanel;
  HeroThumbnailStrip; _make_hero_thumbnail_button 482 (hover/tooltip);
  HERO_SELECT_FRAME_* 58-81)
- assets/sprites/ui/frames/hero_select/ (рамки из SCRUM-320/321/322/323, скиллом)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Лейаут: превью 1/3 слева, описание+возвышение 2/3 справа, роза ветров top-right, карусель снизу.
- [ ] Иконки карусели: hover-подсветка (без жёлтого) + tooltip имени/класса; выбор меняет превью/описание/радар; клава+геймпад.
- [ ] Все элементы в скилл-сгенерированных рамках; контент только в content-зоне; ничего не накладывается.
- [ ] Весь текст читаем; no-overlap на 3 разрешениях; smoke + no-overlap matrix зелёные; скрины; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Result / Summary
- Реализован master layout: `HeroSelectContent` делится на `HeroSelectPortraitPanel` слева и `HeroSelectRightRegion` справа с фактической пропорцией 1/3·2/3 на 1280x720, 1600x900 и 2560x1440.
- `HeroSelectDossierPanel` перенесен внутрь правого региона, а невидимый `HeroSelectRadarReserve` удерживает текст слева от floating top-right `HeroSelectRadarPanel`; portrait, dossier, radar и carousel не накладываются друг на друга и на frame ornament.
- Hover/tooltip/selection behavior нижней карусели сохранен, новых ассетов или animation-scope не потребовалось.
- Verification: `runtime_smoke_ui_test.gd` PASS, `ui_no_overlap_matrix_test.gd` PASS, `runtime_smoke_test.gd` PASS, QA rect dump обновлен в `build/qa/hero_select_radar_rects.md` и `build/qa/scrum281/hero_select_capture_rects.md` (headless screenshot skipped by dummy renderer).
