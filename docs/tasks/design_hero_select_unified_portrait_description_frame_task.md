# ART/UX: Выбор героя — портрет + описание в ОДНОМ фрейме (тонкие рамки), Выбрать+возвышение вниз

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-356
QA: in_progress (2026-06-14)
Связано: SCRUM-333 (мастер-лейаут), SCRUM-321 (рамка превью), SCRUM-323 (рамка описания),
SCRUM-346 (возвышение +/- маленькие кнопки вниз), SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Описание и изображение персонажа на странице выбора персонажа надо засунуть в
ОДИН фрейм с НЕ толстыми рамками. Кнопку "Выбрать" надо опустить вниз вместе с
переключением возвышения (кнопки + и − тоже сделать и подставить)».

ВАЖНО: это меняет текущий лейаут SCRUM-333, где портрет (HeroSelectPortraitPanel,
1/3) и описание (HeroSelectDossierPanel, 2/3) — в ДВУХ раздельных фреймах. Теперь
их надо объединить в ОДИН общий фрейм.

## ОБЯЗАТЕЛЬНО — скилл (директива пользователя)
Новый объединённый фрейм СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`generate_asset.py ... --output hero_select/unified_panel ...`, gpt-image-2, PNG,
ПРОЗРАЧНЫЙ фон), стиль D&D + Dark Fantasy Dragon, **ТОНКИЕ рамки** (тонкая
окантовка, не массивная). Исходник в references/, внедрить в assets/. Старые
раздельные рамки (321/323) — в бэкап.

## Требования
1. **Один общий фрейм** на портрет + описание героя (тонкая окантовка). Внутри:
   слева — изображение персонажа (портрет), справа/рядом — описание (заголовок,
   описание, черты, оружие). Всё в content-зоне одного фрейма, не на орнаменте
   (глобальное правило фреймов; content margins ≥ окантовки, но рамка тонкая).
2. **Кнопку «Выбрать» опустить вниз** этого фрейма, **вместе с блоком возвышения**
   (ряд −/label/+). Возвышение и «Выбрать» — внизу, по центру.
3. **Кнопки возвышения «+»/«−» сделать и подставить** — маленькие, по референсам
   интерфейса, скиллом (координация с SCRUM-346, не дублировать: если 346 уже
   сделала ассет asc-кнопки — переиспользовать). Знак по центру, hover без жёлтого.
4. Роза ветров (радар) остаётся отдельным плавающим виджетом top-right (SCRUM-322);
   карусель снизу (SCRUM-320). Объединяется ТОЛЬКО портрет+описание.
5. Ничего не накладывается; весь текст читаем; на 1280×720 / 1920×1080 / 2560×1440.
   Длинные описания умещаются/скроллятся в фрейме.
6. Не ломать логику выбора героя/возвышения, навигацию клава+геймпад.
7. Тест (smoke + no-overlap matrix): экран строится; портрет+описание в одном
   фрейме с тонкой рамкой; «Выбрать»+возвышение внизу; +/- маленькие; no-overlap.
   Скрины 3 разрешений в build/qa/. CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select; HeroSelectPortraitPanel /
  HeroSelectDossierPanel — объединить в один фрейм; content_row; asc_row;
  HeroSelectChooseButton; HERO_SELECT_FRAME_* ; _apply_hero_select_button_frame)
- assets/sprites/ui/frames/hero_select/ (новый unified-фрейм + asc-кнопка, скиллом) + бэкап
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Портрет + описание героя в ОДНОМ фрейме с ТОНКОЙ рамкой (скиллом); старые раздельные рамки в бэкап.
- [ ] «Выбрать» + возвышение (−/label/+) внизу фрейма, по центру; +/- маленькие кнопки сделаны и подставлены.
- [ ] Радар top-right и карусель снизу не тронуты; контент в content-зоне; ничего не накладывается; текст читаем на 3 разрешениях.
- [ ] Логика/навигация целы; smoke + no-overlap matrix зелёные; скрины; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Handoff — Documentation Dispatcher

2026-06-14: Routed to the existing Design Codex thread
`019eabf1-6d54-7561-8af9-ce25cdf483a9` for the Design-owned first pass.
Use High reasoning / no low. Current OpenAI env source is `~/.codex/.env`;
do not print or persist the key. Dispatcher retry verified that the
`fantasydisk-asset-generator` path can generate at valid OpenAI image sizes
(`1024x1024`); do not use unsupported tiny sizes such as `512x512`.

Design scope first:
- Create the unified portrait+description frame source/runtime PNG and strict
  content-zone metadata.
- Create or reuse the small ascension +/- button assets; coordinate with
  SCRUM-346 and avoid duplicate assets.
- Preserve the global frame safe-zone rule: no text, hero, button, icon,
  selection control, thumbnail, or interactive element may sit on decorative
  frame borders.
- If runtime layout/code integration is needed, update/create a Back-end
  handoff with exact asset paths, source dimensions, target rects, and margins.

## Result — 2026-06-14

Design pass complete and ready for Back-end UI integration.

Generated through the OpenAI Images / `fantasydisk-asset-generator` workflow
using the secure env source outside git, then postprocessed to RGBA/alpha:

- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_unified_panel.png`
  (`1536x1024`, RGBA)
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button_small.png`
  (`256x256`, RGBA)

Source/reference and QA files:

- `docs/design/references/hero_select_unified_panel/ui_frame_hero_select_unified_panel_source.png`
- `docs/design/references/hero_select_unified_panel/ui_frame_hero_select_asc_button_small_source.png`
- `docs/design/references/hero_select_unified_panel/scrum356_unified_panel_metadata.json`
- `docs/design/previews/scrum356_hero_select_unified_panel_content_zones.png`
- `build/qa/scrum356/hero_select_unified_frame_design_qa.md`
- `tools/generate_scrum356_hero_select_unified_assets.py`

Strict source-space content zones for Back-end:

- portrait: `Rect2(130, 145, 420, 560)`
- description: `Rect2(610, 145, 786, 500)`
- bottom controls: `Rect2(570, 705, 660, 178)`
- small ascension button margins: `[76, 74, 76, 76]`

Back-end handoff created:

- `docs/tasks/backend_hero_select_unified_portrait_description_frame_integration_task.md`

Design validation:

- Pillow dimension/alpha check passed (`RGBA`, alpha range `(0, 255)`).
- Preview confirms non-overlapping safe zones.
- Runtime integration/smoke are intentionally not done in Design scope; Back-end
  owns `scripts/ui_screens.gd` layout changes and no-overlap runtime checks.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: объединённый фрейм-ассет + asc-кнопка + content-zones + handoff)

Проверено (фактически):
- **Ассеты** (skill `fantasydisk-asset-generator`, OpenAI Images): `ui_frame_hero_select_unified_panel.png`
  `1536×1024` RGBA (alpha 0–255), `ui_frame_hero_select_asc_button_small.png`
  `256×256` RGBA — валидны (Pillow); source/metadata/генератор
  (`generate_scrum356_hero_select_unified_assets.py`) на месте.
- **Тонкая объединённая рамка** (превью `scrum356_hero_select_unified_panel_content_zones.png`):
  ОДИН фрейм, тонкая орнаментальная окантовка (угловые кресты/филигрань), внутри 3
  НЕпересекающиеся зоны — портрет слева `Rect2(130,145,420,560)`, описание справа
  `Rect2(610,145,786,500)`, нижний блок управления `Rect2(570,705,660,178)` с 2
  слотами asc +/- кнопок и «Выбрать». Зоны не на орнаменте.
- **Back-end handoff** `backend_hero_select_unified_portrait_description_frame_integration_task.md`
  содержит точные content-zones/margins (7 совпадений Rect2/margins/asset).
- **Тесты** (текущий 2-фреймовый лейаут): `runtime_smoke_test` + `ui_no_overlap_matrix_test`
  — passed (регрессии нет).

⚠️ **Видимое объединение портрет+описание в один фрейм + посадка «Выбрать»/возвышения
вниз ещё НЕ в рантайме**: ui_screens.gd всё ещё рисует ДВА раздельных фрейма
(`HeroSelectPortraitPanel` стр.551 + `HeroSelectDossierPanel` стр.612), unified-фрейм
НЕ подключён. Рантайм-интеграция (+ бэкап старых рамок 321/323) — Back-end задача
(статус **«new»**), явно вне Design-scope.

Acceptance (фактическое состояние):
- [x] Объединённый фрейм с тонкой рамкой (скиллом) + 3 непересекающиеся content-зоны.
- [x] Малые asc +/- кнопки сделаны (asc_button_small, общий с SCRUM-346, не дубль).
- [~] Рантайм: портрет+описание в одном фрейме, «Выбрать»/возвышение внизу, no-overlap
  на 3 разрешениях — пендинг Back-end интеграции («new»), вне Design-scope.
- [x] Радар/карусель не тронуты; превью non-overlap; handoff с точными числами.

Вывод: Design-деливерабл (тонкий unified-фрейм + asc-кнопка + строгие зоны + handoff)
выполнен корректно. Видимая перекомпоновка — на Back-end интеграции (отслеживается).
Баги: нет.
