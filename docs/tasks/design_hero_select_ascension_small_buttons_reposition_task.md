# ART/UX: Возвышение +/- — маленькие кнопки по референсам, по центру, вниз фрейма + «Выбрать»

Статус: new
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-346
Связано: SCRUM-321/323/333 (выбор героя), SCRUM-324 (скилл), SCRUM-327 (стиль)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Переключение возвышений + и − сделать маленькими кнопками по референсам
интерфейса. Выровнять по центру и вместе с кнопкой "Выбрать" опустить вниз фрейма
описания героя».

Сейчас (ui_screens.gd, dossier): `AscensionSelectorRow` (525) = [−][label][+]
(asc_minus 529 / asc_label 535 / asc_plus 542, ASCENSION_BUTTON_SIZE,
_apply_hero_select_button_frame "asc_button"), затем asc_mods (560) и
`HeroSelectChooseButton` «Выбрать» (569, 260×72). Кнопки +/- крупноваты и не у
низа фрейма.

## ОБЯЗАТЕЛЬНО — скилл (директива пользователя)
Маленькие рамки кнопок +/- СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`generate_asset.py ... --output hero_select/asc_button_small ...`, gpt-image-2,
PNG, прозрачный фон) по референсам интерфейса (docs/design/references/Buttons +
общий стиль D&D + Dark Fantasy Dragon, опорная SCRUM-327). Старый ассет — в бэкап.

## Требования
1. Кнопки возвышения «+»/«−» — маленькие, аккуратные, по референсам интерфейса
   (новые рамки скиллом), единый размер, читаемый знак по центру; hover без
   жёлтого свечения (SCRUM-318), контент в content-зоне рамки.
2. Ряд возвышения (−, label, +) **выровнять по центру** по горизонтали.
3. **Опустить блок возвышения вместе с кнопкой «Выбрать» вниз фрейма описания**
   героя (прижать к низу dossier): добавить распорку/spacer так, чтобы
   возвышение + «Выбрать» были внизу content-зоны досье, по центру, не наезжая на
   орнамент рамки; описание/черты/оружие остаются сверху.
4. Не ломать логику возвышения (refresh_asc, clamp уровней) и выбор героя.
5. Тест (smoke + no-overlap): экран строится; +/- маленькие и по центру;
   возвышение и «Выбрать» внизу фрейма; no-overlap на 1280×720/1920×1080/2560×1440.
   Скрин в build/qa/. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (AscensionSelectorRow 525-560; HeroSelectChooseButton 569;
  ASCENSION_BUTTON_SIZE; _apply_hero_select_button_frame "asc_button";
  HERO_SELECT_FRAME_* "asc_button" )
- assets/sprites/ui/frames/hero_select/ (маленькая asc-кнопка, скиллом) + бэкап
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Кнопки возвышения +/- маленькие, по референсам (скиллом), по центру, hover без жёлтого.
- [ ] Возвышение + «Выбрать» прижаты к низу фрейма описания, по центру; описание сверху.
- [ ] Логика цела; no-overlap на 3 разрешениях; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.
