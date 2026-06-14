# ART: Рамка превью героя (слева) из референса heroframe — экран выбора героя

Статус: new
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-321
Связано: SCRUM-281 (Hero Select frame kit — слот portrait), SCRUM-320 (рамка карусели)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

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
- [ ] Рамка превью героя (слева) = референс heroframe; основная рамка масштабируется пропорционально, без one-axis stretch.
- [ ] Портрет отцентрован в content-зоне, не наезжает на орнамент; no-overlap на 3 разрешениях.
- [ ] Task result фиксирует финальные content-zone/margins; декоративная рамка остаётся видимой и не перекрытой портретом.
- [ ] Старый ассет в бэкап; 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.
