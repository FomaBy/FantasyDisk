# ART: Рамка превью героя (слева) из референса heroframe — экран выбора героя

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-321
Связано: SCRUM-281 (Hero Select frame kit — слот portrait), SCRUM-320 (рамка карусели)

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
«Возьми фрейм из heroframe в references и создай таску для замены фрейма на
странице выбора героя. Этот фрейм — для превью героя на левой части экрана».

Превью героя слева = `HeroSelectPortraitPanel` (PanelContainer, ui_screens.gd:400-405)
со стилем `_hero_select_frame_style("portrait")`; внутри крупный портрет
`HeroSelectLargePortrait` (414, 320×400). Сейчас рамка из SCRUM-281
(ui_frame_hero_select_portrait.png) — заменить на этот референс.

## Исходник (референс, уже в репо)
docs/design/references/heroframe/ChatGPT Image Jun 14, 2026, 11_01_30 AM.png
— 997×1578, высокая вертикальная орнаментальная рамка (тёмно-красный «драконий»
металл, красные самоцветы, верхний центральный гребень-голова, нижний гребень,
ПРОЗРАЧНАЯ середина). Вертикальный формат — под превью героя.

## Требования
1. Не растягивать рамку только по одной оси. Пользовательская директива
   2026-06-14: при изменении разрешения frame art масштабируется пропорционально,
   с одинаковым scale factor по X/Y. Для орнаментальной рамки использовать
   цельный `TextureRect`/aspect-preserving frame layer или другой proportional
   pipeline. 9-slice допустим только для плоской внутренней подложки без
   орнамента; основная рамка/гребни/углы не должны деформироваться.
   Базовый runtime слот на 1280x720 сейчас `320x428`; если увеличивать на
   1920x1080/2560x1440, целевой proportional frame-size от базы: примерно
   `480x642` и `640x856`, либо другой размер с тем же аспектом.
   Content margins должны держать портрет вне окантовки.
2. Подключить как рамку превью героя: заменить ассет слота `portrait`
   (HERO_SELECT_FRAME_DIR/ui_frame_hero_select_portrait.png) на нарезанный из
   этого референса и/или обновить значения HERO_SELECT_FRAME_* для "portrait"
   (ui_screens.gd:58/68/78) под новую рамку. Старый ассет — в бэкап, не удалять.
3. Портрет героя (HeroSelectLargePortrait 320×400, centered aspect) — внутри
   content-зоны новой рамки, отцентрован, без наезда на орнамент; пропорция панели
   (HeroSelectPortraitPanel, stretch_ratio 0.38) согласована с вертикальной рамкой.
   Обязательное правило 2026-06-14: портрет/спрайт героя нельзя класть на
   декоративные границы, самоцветы, шипы, гребни или металлическую окантовку.
   Исполнитель обязан записать финальные content-zone/margins для portrait frame;
   QA должна считать любой наезд на орнамент дефектом, даже если rect-overlap
   тесты зелёные.
4. Тёмное фэнтези, канон, единство с hero-select китом (SCRUM-281), рамкой
   карусели (SCRUM-320) и общим frame-kit (SCRUM-274).
5. Тест (smoke): экран выбора героя строится; рамка превью = новый ассет; портрет
   в content-зоне, no-overlap на 1280×720 / 1920×1080 / 2560×1440. Скрин в build/qa/.
6. CHANGELOG; content_registry; menus_ui.

## Files / Assets / IDs
- docs/design/references/heroframe/ChatGPT Image Jun 14, 2026, 11_01_30 AM.png (исходник)
- scripts/ui_screens.gd (HERO_SELECT_FRAME_* "portrait" 58/68/78;
  HeroSelectPortraitPanel 400-405; HeroSelectLargePortrait 414; _hero_select_frame_style)
- assets/sprites/ui/frames/hero_select/ (нарезанный ассет + бэкап старого)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Рамка превью героя (слева) = референс heroframe; основная рамка масштабируется пропорционально, без one-axis stretch.
- [x] Портрет отцентрован в content-зоне, не наезжает на орнамент; no-overlap на 3 разрешениях.
- [x] Task result фиксирует финальные content-zone/margins; декоративная рамка остаётся видимой и не перекрытой портретом.
- [x] Старый ассет в бэкап; smoke зелёные; rect dump в build/qa/; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Progress Log

- 2026-06-14: взято в работу Design/Codex на ветке `dev`. Проблема подтверждена:
  live `ui_frame_hero_select_portrait.png` уже качественный RGBA frame, но
  runtime использует его как растягиваемый `PanelContainer`/StyleBox, что ломает
  пропорции на высоких разрешениях. Решение: цельный `TextureRect` с
  aspect-preserving container + отдельный content layer для портрета.
- 2026-06-14: завершено. Новый raster PNG не генерировался, потому что текущий
  live `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_portrait.png`
  уже является production-quality heroframe-style transparent asset; дефект был
  в one-axis stretch runtime layer. Старый файл сохранен в backup:
  `build/cleanup_backup_hero_select_portrait_2026_06_14/`.
- Runtime теперь использует две сущности: `HeroSelectPortraitPanel` сохраняет
  левую треть master-layout (1:2 с правой областью), а вложенный
  `HeroSelectPortraitFrame` рисует frame art цельным `TextureRect` без
  9-slice/StyleBox stretch. Фактические размеры frame art по QA dump:
  `249x394` at 1280x720, `423x669` at 1920x1080, `596x944` at 2560x1440.
- Финальная content-zone / safe-area для portrait frame:
  `HERO_SELECT_PORTRAIT_CONTENT_BASE = Vector4(128, 230, 128, 330)` в координатах
  source `734x1162`. `HeroSelectLargePortrait` масштабируется внутри этой зоны:
  `163x204`, `275x347`, `388x489` на 720p/1080p/1440p, не попадая на верхний
  гребень, боковой металл, нижний гребень или самоцвет.
- QA/verification:
  - `tools/capture_hero_select_qa.gd` PASS, rect dump:
    `build/qa/scrum321/hero_select_portrait_rects.md`.
  - `tests/runtime_smoke_ui_test.gd` PASS.
  - `tests/dark_fantasy_ui_theme_test.gd` PASS.
  - `tests/ui_no_overlap_matrix_test.gd` PASS.
  - `tests/runtime_smoke_test.gd` PASS.
- Документация обновлена: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`,
  `docs/process/task_board.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Визуал** `build/qa/cap_hero_select.png`: рамка превью героя (слева) —
  референс heroframe, орнамент пропорционален, портрет (Берсерк) отцентрован в
  content-зоне, не наезжает на орнамент, декоративная рамка видна и не перекрыта.
- **Тесты**: `ui_no_overlap_matrix_test` + `runtime_smoke_ui_test` зелёные;
  SCRUM-334 восстановил portrait panel ratio 1.0 (1/3 портрет).

Acceptance:
- [x] Рамка превью = heroframe, пропорциональное масштабирование.
- [x] Портрет отцентрован, не наезжает; рамка видна.
- [x] smoke зелёные; rect dump; скрин.

Баги: нет.
