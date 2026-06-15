# UX: Карусель выбора героя — увеличить иконки персонажей, уменьшить отступы

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-342
QA: in_progress (2026-06-14)
Связано: SCRUM-333 (мастер-лейаут выбора героя, done), SCRUM-320 (рамка карусели)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Надо увеличить иконки персонажей внизу на карусели — там большие отступы друг от
друга и сверху/снизу. Сейчас очень плохо видно персонажей, надо сделать их
побольше».

Карусель: HeroThumbnailStrip (HBoxContainer) внутри HeroThumbnailStripFrame
(PanelContainer), иконки = `_make_hero_thumbnail_button` (124×88), портрет внутри
кнопки. Лейаут уже сделан в SCRUM-333 (done) — это точечный follow-up по размеру.

## УТОЧНЕНИЕ (пользователь 2026-06-15)
В карусели — ТОЛЬКО изображения персонажей в ряд, БЕЗ рамок/фреймов вокруг каждого
(убрать рамку миниатюры). Увеличить иконки так, чтобы весь ряд героев помещался по
ГОРИЗОНТАЛИ (равномерно, без обрезки/скролла на 1280×720). Прозрачный фон у иконок.

## Требования
1. **Увеличить иконки персонажей** в карусели заметно (поднять размер
   _make_hero_thumbnail_button с 124×88 до большего; портрет внутри —
   пропорционально), чтобы герои читались чётко.
2. **Уменьшить избыточные отступы**: разделитель между иконками
   (HBoxContainer separation) и вертикальные отступы полосы
   (HeroThumbnailStripFrame высота/паддинги) — чтобы иконки заняли слот по
   максимуму, без наезда на орнамент рамки (глобальное правило фреймов).
3. Сохранить ровный единый размер всех иконок и hover/selected/tooltip-поведение
   (не сломать SCRUM-333). Весь ряд героев влезает на 1280×720 (адаптивно сжимать
   только если иначе не помещается).
4. Тест (smoke + no-overlap): экран выбора героя строится; иконки крупнее,
   отступы меньше, ряд влезает, контент в content-зоне рамки на
   1280×720 / 1920×1080 / 2560×1440. Скрин в build/qa/.
5. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_hero_thumbnail_button 482; HeroThumbnailStrip /
  HeroThumbnailStripFrame ~543-560; separation/паддинги)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Иконки персонажей в карусели заметно крупнее; отступы (separation + верт.) уменьшены.
- [ ] Герои чётко видны; единый размер; hover/tooltip/выбор не сломаны; ряд влезает на 1280×720.
- [ ] Контент в content-зоне рамки; smoke + no-overlap зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Result / Verification
Готово 2026-06-14:
- Hero Select bottom carousel keeps the existing proportional Carusel frame, but runtime content margins are tightened to `Vector4(72, 36, 72, 36)` and thumbnail separation is reduced to 2px.
- Thumbnail slots are now taller portrait slots: QA rects show sample hero thumbnails `49x66` at 1280x720, `75x101` at 1920x1080 and `101x136` at 2560x1440, all inside the strip content-zone.
- Added runtime smoke coverage for compact separation, taller thumbnail sizing, image-only thumbnails, click selection, tooltip behavior and content-zone containment at 1280x720/1600x900/2560x1440.
- Kept decorative frame rules: no one-axis frame stretching, thumbnails do not overlap side stones/crests/metal borders.
- QA artifacts: `build/qa/scrum281/hero_select_capture_rects.md`, `build/qa/hero_select_radar_rects.md`, `build/qa/ui_no_overlap_matrix.md`.
- Verification:
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Rect-dump** `build/qa/scrum281/hero_select_capture_rects.md` @1280×720:
  `HeroThumbnail_berserk` = `S(49×66)` — портретные (высокие) слоты вместо прежних
  плоских 124×88, герои читаются; миниатюра `P(207,585)` внутри strip-контента
  `P(128,534) S(1024,170)` (content-зона, не на орнаменте).
- **Код**: `HERO_SELECT_CAROUSEL_COMPACT_CONTENT_BASE := Vector4(72,36,72,36)`
  (сжатые верт. паддинги) + separation уменьшен.
- **Визуал** `build/qa/cap_hero_select.png`: ряд героев в карусели крупнее, влезает,
  не наезжает на рамку.
- **Тесты**: `runtime_smoke_test` PASS, `ui_no_overlap_matrix_test` PASS
  (1280×720/1600×900/2560×1440).

Acceptance:
- [x] Иконки крупнее (портретные слоты), отступы/separation уменьшены.
- [x] Единый размер, ряд влезает, hover/tooltip/выбор целы (smoke).
- [x] Контент в content-зоне; smoke + no-overlap зелёные; скрин.

Баги: нет.
