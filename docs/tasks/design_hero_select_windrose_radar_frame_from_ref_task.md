# ART: Рамка розы ветров (радар характеристик) из референса windrose — выбор героя

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-322
Связано: SCRUM-281 (Hero Select kit, слот radar), SCRUM-320 (карусель), SCRUM-321 (превью)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## ГЕНЕРАЦИЯ РАМКИ — СКИЛЛОМ (директива пользователя 2026-06-14)
Рамку СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`scripts/generate_asset.py --prompt "<...>" --output <тема/файл> --size <WxH>
--quality high`, OpenAI Images, `gpt-image-2`, PNG, ПРОЗРАЧНЫЙ фон), в стиле
D&D + Dark Fantasy Dragon. Присланный референс из docs/design/references/ —
СТАЙЛ-ГАЙД (ориентир вида), а не финальный ассет: воспроизвести/улучшить вид
скиллом на прозрачном фоне, сохранить в references/<тема>/ + внедрить в assets/.
Затем 9-slice. См. SCRUM-324, мастер-задача hero-select redesign.

## Контекст (запрос пользователя)
«Возьми фрейм из windrose в references и создай таску для замены фрейма розы
ветров на странице выбора героя. Этот фрейм — для розы ветров в правом верхнем
углу».

Роза ветров (радар характеристик) = плавающий виджет в правом-верхнем углу:
`HeroSelectRadarPanel` (PanelContainer, ui_screens.gd:513-520, anchor TOP_RIGHT,
390×300) со стилем `_hero_select_frame_style("radar")`; внутри заголовок
«Характеристики» + `HeroStatRadar` (360×230). Сейчас рамка из SCRUM-281
(ui_frame_hero_select_radar.png) — заменить на этот референс.

## Исходник (референс, уже в репо)
docs/design/references/windrose/ChatGPT Image Jun 14, 2026, 11_07_47 AM.png
— 1254×1254, КРУГЛАЯ/радиальная орнаментальная рамка-компас: 8 лучей-остриёв
(тёмный металл, красные самоцветы), тёмный круглый центр. Форма — «роза ветров».

## Требования (важно: рамка радиальная — не искажать!)
1. Рамка радиально-симметричная: обычный 9-slice с НЕравномерным растяжением
   исказит лучи/центр. Решение (на усмотрение исполнителя):
   - использовать как ЦЕЛЬНУЮ текстуру с фиксированным квадратным аспектом
     (TextureRect/центрированный StyleBoxTexture без растяжки лучей), ЛИБО
   - сделать панель радара квадратной под рамку, ЛИБО
   - аккуратный 9-slice только по тонким прямым участкам между лучами с большими
     равными margins — но БЕЗ перекоса остриёв.
   Главное: лучи и центр компаса не растянуты/не сплющены.
   Пользовательская директива 2026-06-14: при изменении разрешения весь frame art
   масштабируется пропорционально, одинаково по X/Y; не растягивать розу ветров
   только по ширине или только по высоте. Базовый current panel `390x300`; для
   square frame использовать квадратную art-зону внутри/вместо panel и сохранять
   её аспект на 1280x720 / 1920x1080 / 2560x1440.
2. Подключить как рамку розы ветров: заменить ассет слота `radar`
   (HERO_SELECT_FRAME_DIR/ui_frame_hero_select_radar.png) и/или значения
   HERO_SELECT_FRAME_* для "radar" (ui_screens.gd:60/70/80). При необходимости
   подогнать геометрию HeroSelectRadarPanel (сейчас 390×300; offsets 514-518) под
   квадрат/пропорцию рамки, сохранив позицию в правом-верхнем углу и зазор от края.
   Старый ассет — в бэкап, не удалять.
3. Радар (HeroStatRadar 360×230) и заголовок «Характеристики» — по центру тёмной
   зоны рамки, без наезда на лучи/орнамент; content margins ≥ окантовки.
   Обязательное правило 2026-06-14: заголовок, radar polygon, stat labels и любые
   interactive/informational элементы должны сидеть только в пустой inner-зоне
   розы ветров. Лучи, шипы, самоцветы и металлический кант остаются чистыми.
   Финальные content-zone/margins записать в task result; QA должна fail-ить
   любой наезд контента на орнамент.
4. Тёмное фэнтези, канон, единство с hero-select китом (SCRUM-281) и рамками
   SCRUM-320/321, общим frame-kit (SCRUM-274).
5. Тест (smoke): экран строится; рамка радара = новый ассет; радар в content-зоне,
   лучи компаса не искажены, no-overlap и панель остаётся в правом-верхнем углу на
   1280×720 / 1920×1080 / 2560×1440. Скрин в build/qa/.
6. CHANGELOG; content_registry; menus_ui.

## Files / Assets / IDs
- docs/design/references/windrose/ChatGPT Image Jun 14, 2026, 11_07_47 AM.png (исходник)
- scripts/ui_screens.gd (HERO_SELECT_FRAME_* "radar" 60/70/80;
  HeroSelectRadarPanel 513-520; HeroStatRadar 536-538; _hero_select_frame_style)
- assets/sprites/ui/frames/hero_select/ (нарезанный/целый ассет + бэкап старого)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Рамка розы ветров = референс windrose; лучи/центр компаса НЕ искажены и масштабируются пропорционально.
- [x] Радар+заголовок отцентрованы в content-зоне; панель в правом-верхнем углу; no-overlap на 3 разрешениях.
- [x] Task result фиксирует финальные content-zone/margins; лучи/самоцветы/кант не перекрыты текстом или графиком.
- [x] Старый ассет в бэкап; smoke зелёные; rect dump в build/qa/; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Progress Log

- 2026-06-14: взято в работу Design/Codex на ветке `dev`. `fantasydisk-asset-generator`
  skill read; OpenAI generation unavailable in this environment (`OPENAI_API_KEY`
  missing), so task proceeds from the existing approved reference
  `docs/design/references/windrose/ChatGPT Image Jun 14, 2026, 11_07_47 AM.png`.
  Decision: create production RGBA asset by local cleanup/crop from the reference
  and integrate it as a whole-image proportional square frame, not 9-slice.
- 2026-06-14: завершено. Runtime PNG заменен на windrose production asset:
  `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png`
  (`1024x1024`, RGBA, transparent). Pipeline:
  `tools/build_hero_select_windrose_frame.py`. Старый SCRUM-281 radar backup:
  `build/cleanup_backup_hero_select_windrose_2026_06_14/`.
- Safe-area/content-zone: source margins
  `HERO_SELECT_RADAR_CONTENT_BASE = Vector4(245, 245, 245, 235)` for source
  `1024x1024`; preview:
  `docs/design/previews/hero_select_windrose_radar_content_zone.png`.
  Runtime title/graph are centered inside this inner field; red gems, metal
  tips, spikes and windrose ring remain outside actual label/graph bounds.
- Runtime integration: `HeroSelectRadarPanel` is now a square top-right
  `Control` with `HeroSelectRadarFrameArt` full-rect `TextureRect` and
  `HeroSelectRadarContent` margins. Display frame sizes from QA:
  `390x390` at 1280x720, `585x585` at 1920x1080, `780x780` at 2560x1440.
  Graph sizes: `200x150`, `300x225`, `400x300`.
- QA/verification:
  - `tools/capture_hero_select_qa.gd` PASS, rect dump:
    `build/qa/scrum322/hero_select_windrose_radar_rects.md`.
  - `tests/runtime_smoke_ui_test.gd` PASS.
  - `tests/ui_no_overlap_matrix_test.gd` PASS.
  - `tests/dark_fantasy_ui_theme_test.gd` PASS.
  - `tests/runtime_smoke_test.gd` PASS.
- Документация обновлена: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`,
  `docs/process/task_board.md`.
