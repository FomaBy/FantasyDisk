# UX: Роза ветров — убрать заголовок, центрировать, увеличить на 20-30%

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-347
QA: in_progress (2026-06-14)
Связано: SCRUM-322 (рамка розы ветров), SCRUM-333 (мастер-лейаут)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя, со скриншотом)
«Убрать надпись "Характеристики" и выровнять розу ветров по центру + увеличить её
размер по всем осям на 20-30%».

На скрине радар (полигон характеристик) смещён вверх-влево внутри рамки-компаса и
мелковат; заголовок «Характеристики» занимает место сверху.

Код: заголовок `HeroStatRadarTitle` «Характеристики» (ui_screens.gd:608-612) в
radar_box (VBox). Полигон рисует scripts/ui/hero_stat_radar.gd `_draw()`
(center = size*0.5; radius = min(size.x,size.y)*0.30; подписи на radius+28).

## Требования
1. **Убрать заголовок «Характеристики»** (HeroStatRadarTitle) — не создавать
   Label, либо скрыть; освободившееся место отдать радару.
2. **Центрировать розу ветров** строго по центру рамки-компаса
   (HeroSelectRadarPanel / content-зона): радар-Control отцентрован по обеим осям;
   после удаления заголовка VBox/контейнер не смещает полигон вверх. center
   полигона совпадает с центром рамки.
3. **Увеличить радар на 20-30% по всем осям**: поднять радиус (radius-фактор 0.30 →
   ~0.36-0.39) и/или custom_minimum_size радара; подписи осей (radius+28) и
   масштаб (_hero_select_radar_scale) согласовать, чтобы НЕ вылезали за рамку и не
   налезали на орнамент (глобальное правило фреймов). Текст подписей читаем.
4. Не ломать данные радара (значения/оси/макс), позицию панели top-right (SCRUM-322)
   и лейаут (SCRUM-333).
5. Тест (smoke + no-overlap): экран выбора героя строится; заголовка нет; полигон
   по центру, крупнее; подписи в пределах рамки на 1280×720/1920×1080/2560×1440.
   Скрин в build/qa/. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (HeroStatRadarTitle 608-612; radar_box 603; HeroSelectRadarPanel;
  _hero_select_radar_scale; _hero_select_radar_frame_size)
- scripts/ui/hero_stat_radar.gd (_draw 20; center 23; radius 24; подписи 45)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Заголовок «Характеристики» убран.
- [ ] Роза ветров по центру рамки-компаса; полигон крупнее на 20-30% по всем осям.
- [ ] Подписи в пределах рамки, не на орнаменте, читаемы; no-overlap на 3 разрешениях; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Result 2026-06-14

Implemented Back-end UI fix:
- removed the runtime `HeroStatRadarTitle` label from Hero Select;
- made `HeroStatRadar` the only child inside the windrose content container and
  centered it in the compass field;
- increased `HeroStatRadar` polygon radius factor from `0.30` to `0.36` (+20%);
- tightened label offset/width so axis labels remain inside the windrose frame.

Runtime smoke now asserts title removal, enlarged radius factor, centered radar
rects, top-right floating panel, dossier gap, square windrose frame and no
overlap at 1280x720, 1600x900 and 2560x1440. QA dump:
`build/qa/hero_select_radar_rects.md`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

Docs updated: `CHANGELOG.md`, `docs/design/systems/menus_ui.md`,
`docs/design/current_game_state.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Визуал** `build/qa/cap_hero_select.png`: роза ветров (top-right) БЕЗ заголовка
  «Характеристики», полигон по центру рамки-компаса, оси подписаны (Сил/Лов/Уот/
  Уст/Зна и т.д.), подписи в пределах рамки, не на орнаменте.
- Код: `hero_stat_radar.gd:HERO_RADAR_RADIUS_FACTOR := 0.36` (+20% к прежним 0.30).
- **Тесты**: `runtime_smoke_ui_test` + `runtime_smoke_test` + `ui_no_overlap_matrix_test`
  зелёные (no-overlap на 3+ разрешениях).

Acceptance:
- [x] Заголовок «Характеристики» убран.
- [x] Роза ветров по центру компаса; полигон крупнее (+20%).
- [x] Подписи в рамке читаемы; no-overlap; smoke зелёные; скрин.

Баги: нет.
