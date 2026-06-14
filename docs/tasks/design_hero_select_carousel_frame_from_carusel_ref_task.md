# ART: Рамка карусели персонажей из референса Carusel (экран выбора героя)

Статус: in_progress
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-320
Связано: SCRUM-281 (Hero Select frame kit — слот thumbnail_strip)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Возьми картинку из референсов Carusel и создай таску, чтобы использовать её как
фрейм для карусели персонажей на экране выбора персонажа».

Карусель персонажей = нижняя горизонтальная планка миниатюр на экране выбора
героя: `HeroThumbnailStripFrame` (PanelContainer, ui_screens.gd:543-548) со
стилем `_hero_select_frame_style("thumbnail_strip")`. Сейчас там рамка из
SCRUM-281 (ui_frame_hero_select_thumbnail_strip.png) — заменить на этот референс.

## Исходник (референс, уже в репо)
docs/design/references/carusel/ChatGPT Image Jun 14, 2026, 10_57_24 AM.png
— 2482×633, широкая орнаментальная тёмная рамка-баннер: декоративные углы
(чёрный металл/чешуя + красные самоцветы), центральные гребни сверху/снизу,
ПРОЗРАЧНАЯ плоская середина. Горизонтальный формат — точно под карусель.

## Требования
1. Нарезать референс в 9-slice так, чтобы при растяжении по ширине сохранялись
   декоративные углы и центральные гребни, а середина (тёмная зона) тянулась без
   искажения орнамента. Подобрать texture margins (углы крупные — ориентировочно
   ~150px по бокам, ~60-80px сверху/снизу; уточнить по факту) и
   **content margins ≥ окантовки + запас**, чтобы миниатюры не залезали на рамку.
2. Подключить как рамку карусели: заменить ассет слота `thumbnail_strip`
   (HERO_SELECT_FRAME_DIR/ui_frame_hero_select_thumbnail_strip.png) на нарезанный
   из этого референса, и/или обновить значения в
   HERO_SELECT_FRAME_* (ui_screens.gd:61/71/81) под новую рамку. Старый ассет —
   в бэкап, не удалять.
3. Миниатюры героев (HeroThumbnailStrip / _make_hero_thumbnail_button 124×88) и
   их выравнивание — внутри content-зоны новой рамки, без наезда на орнамент;
   высота полосы (HeroThumbnailStripFrame custom_minimum_size, сейчас 104)
   согласовать с пропорцией новой рамки.
4. Тёмное фэнтези, канон, единство с общим frame-kit (SCRUM-274) и hero-select
   китом (SCRUM-281).
5. Тест (smoke): экран выбора героя строится; рамка карусели = новый ассет;
   миниатюры в content-зоне, no-overlap на 1280×720 / 1920×1080 / 2560×1440.
   Скрин в build/qa/.
6. CHANGELOG; content_registry; menus_ui.

## Files / Assets / IDs
- docs/design/references/carusel/ChatGPT Image Jun 14, 2026, 10_57_24 AM.png (исходник)
- scripts/ui_screens.gd (HERO_SELECT_FRAME_* 61/71/81; HeroThumbnailStripFrame 543-548;
  _hero_select_frame_style; _make_hero_thumbnail_button 482)
- assets/sprites/ui/frames/hero_select/ (нарезанный ассет + бэкап старого)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Рамка карусели персонажей = нарезка из референса Carusel (9-slice, углы/гребни целы при растяжении).
- [ ] Миниатюры в content-зоне, не наезжают на орнамент; no-overlap на 3 разрешениях.
- [ ] Старый ассет в бэкап; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Progress Log

- 2026-06-14: взято в работу Design/Codex на ветке `dev`; референс Carusel
  проверен как `2482x633` RGB PNG с baked checkerboard вокруг рамки. Решение:
  использовать исходный орнамент как source-of-truth, локально убрать фон в
  alpha и заменить только `thumbnail_strip` frame, без изменения gameplay.
