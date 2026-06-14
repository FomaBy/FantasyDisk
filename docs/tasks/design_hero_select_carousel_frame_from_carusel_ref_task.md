# ART: Рамка карусели персонажей из референса Carusel (экран выбора героя)

Статус: review
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
героя: `HeroThumbnailStripFrame` (ui_screens.gd:543-548). Сейчас там рамка из
SCRUM-281 (ui_frame_hero_select_thumbnail_strip.png) — заменить на этот референс.

## Исходник (референс, уже в репо)
docs/design/references/carusel/ChatGPT Image Jun 14, 2026, 10_57_24 AM.png
— 2482×633, широкая орнаментальная тёмная рамка-баннер: декоративные углы
(чёрный металл/чешуя + красные самоцветы), центральные гребни сверху/снизу,
ПРОЗРАЧНАЯ плоская середина. Горизонтальный формат — точно под карусель.

## Требования
1. Использовать референс как цельную пропорциональную рамку: не растягивать
   только по одной оси; не использовать 9-slice для этого орнаментального
   элемента, чтобы не ломать рисунок на разных разрешениях.
   Рамка должна масштабироваться одним коэффициентом, сохраняя исходный aspect
   ratio и декоративные углы/центральные гребни.
2. Подключить как рамку карусели: заменить ассет слота `thumbnail_strip`
   (HERO_SELECT_FRAME_DIR/ui_frame_hero_select_thumbnail_strip.png) на нарезанный
   из этого референса, и/или обновить значения в
   HERO_SELECT_FRAME_* (ui_screens.gd:61/71/81) под новую рамку. Старый ассет —
   в бэкап, не удалять.
3. Миниатюры героев (HeroThumbnailStrip / _make_hero_thumbnail_button) и
   их выравнивание — только внутри пустой content-зоны новой рамки, без наезда
   на боковые камни, нижний/верхний металлический кант, центральные гребни или
   любой другой декоративный орнамент. Финальную content-zone/margins записать
   в task result и docs.
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
- [x] Рамка карусели персонажей = обработанный референс Carusel с прозрачным фоном, который масштабируется пропорционально без one-axis stretch.
- [x] Миниатюры в content-зоне, не наезжают на орнамент; no-overlap на 3 разрешениях.
- [x] Старый ассет в бэкап; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Progress Log

- 2026-06-14: взято в работу Design/Codex на ветке `dev`; референс Carusel
  проверен как `2482x633` RGB PNG с baked checkerboard вокруг рамки. Решение:
  использовать исходный орнамент как source-of-truth, локально убрать фон в
  alpha и заменить только `thumbnail_strip` frame, без изменения gameplay.
- 2026-06-14: Design result готов к QA review. Добавлен reproducible pipeline
  `tools/build_hero_select_carousel_frame.py`: flood-fill удаляет baked
  checkerboard вокруг reference, сохраняет live RGBA `1536x255` PNG в
  `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`
  и preview `docs/design/previews/hero_select_carousel_frame_contact.png`.
  Старый SCRUM-281 strip сохранен в
  `build/cleanup_backup_hero_select_carousel_2026_06_14/`.
- 2026-06-14: учтена правка пользователя — отказ от 9-slice/one-axis stretch.
  `HeroThumbnailStripFrame` теперь является aspect-preserving Control:
  цельный `TextureRect` масштабируется как 1024x170 / 1536x255 / 2048x340 для
  720p/1080p/1440p, а миниатюры живут в отдельном content layer.

## Result Summary / 2026-06-14

- Live asset replaced in-place:
  `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`.
- `HeroThumbnailStripFrame` no longer uses `_hero_select_frame_style("thumbnail_strip")`;
  it draws the Carusel PNG as a whole `TextureRect` with proportional runtime
  sizes: `1024x170` at 1280x720, `1536x255` at 1920x1080,
  `2048x340` at 2560x1440.
- Hero thumbnails are horizontally centered in the strip and adapt `42-124px`
  width for the current 17-character roster so they stay inside the dark
  content zone instead of touching side jewels.
- Mandatory UI content-zone rule applied: carousel content margins are
  `Vector4(112, 46, 112, 46)` at 1280x720 base and scale proportionally with
  the frame (`168/69/168/69` at 1080p, `224/92/224/92` at 1440p). The decorative
  border/corners/jewels/spikes remain unobstructed; thumbnails are contained in
  `HeroThumbnailStripContent`.
- QA artifacts:
  `build/qa/scrum320/hero_select_carousel_1280x720.png`,
  `hero_select_carousel_1920x1080.png`,
  `hero_select_carousel_2560x1440.png`,
  `hero_select_carousel_rects.md`.
- Verification passed:
  `runtime_smoke_ui_test.gd`,
  `dark_fantasy_ui_theme_test.gd`,
  `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_test.gd`,
  `runtime_smoke_combat_test.gd`,
  `runtime_smoke_progression_economy_test.gd`,
  `runtime_smoke_weapon_mechanics_test.gd`.
- Docs updated: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`.
