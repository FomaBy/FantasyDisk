# ART/UX: Выбор героя v3 — макап → зоны → production-рамки → вёрстка (с нуля)

Статус: done
Приоритет: high
Роль: Designer 2 (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-446
QA: in_progress (2026-06-15)
Связано: SCRUM-436 (предыдущая попытка — SUPERSEDED этим), ui-director, asset-generator

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Дизайнер рисует мокап страницы выбора героя. Определяет зоны на мокапе — где какие
элементы: Превью героя, Описание героя + выбор возвышения, Роза ветров, Карусель
персонажей. Затем по размерам с мокапа сгенерировать UI/UX рамки и поля, поверх
которых отображаются игровые элементы (можно использовать фон). Предварительно НЕ
использовать всё, что сейчас есть на этой странице (с нуля)».

ВАЖНО: рамки ГЕНЕРИРУЮТСЯ как чистые production-ассеты под зоны (НЕ нарезка макапа).
Макап — только референс компоновки. Старый layout/рамки выбора героя — НЕ использовать.

## ЧЁТКИЙ ПЛАН (4 фазы, выполнять по порядку)

### Фаза 1 — Макап (референс компоновки)
- Скиллом `fantasydisk-ui-director`/`fantasydisk-asset-generator` (gpt-image-2)
  сгенерировать макап страницы выбора героя (landscape 16:9), единый стиль
  D&D + Dark Fantasy Dragon. На макапе ЯВНО показаны 4 зоны:
  1) **Превью героя** (крупная вертикальная зона, обычно слева),
  2) **Описание героя + выбор возвышения** (центральная зона: имя/описание/черты/
     оружие + степпер «− Возвышение N/10 +» + кнопка «Выбрать»),
  3) **Роза ветров** (компас-радар характеристик, обычно справа-сверху),
  4) **Карусель персонажей** (горизонтальный ряд иконок героев, снизу).
  Плюс служебные: заголовок и кнопка «Назад».
- Сохранить макап в `docs/design/references/hero_select_v3/mockup.png` + превью в чат.

### Фаза 2 — Определение зон (координаты)
- Проанализировать макап (OpenAI Vision API) → для каждой из 4 зон (+ заголовок/назад)
  вернуть bounding box. Сохранить:
  - `zones.json` (пиксели) и `zones_normalized.json` (доли экрана 0..1) —
    nx/ny/nw/nh каждой зоны. Это источник истины для позиционирования.

### Фаза 3 — Генерация production UI-рамок/полей под зоны
- Для КАЖДОЙ зоны СГЕНЕРИРОВАТЬ ОТДЕЛЬНУЮ чистую рамку/поле (asset-generator,
  PNG, **ПРОЗРАЧНЫЙ фон**, 9-slice-пригодную) под её пропорции (из zones_normalized):
  - `frame_preview.png` (под превью героя),
  - `frame_dossier.png` (под описание+возвышение),
  - `frame_radar.png` (под розу ветров),
  - `frame_carousel.png` (под карусель).
  - опционально `background.png` (фон страницы — «можно использовать фон»).
- У каждой рамки определить **content-зону** (texture margins + content margins ≥
  окантовки) — пустую внутреннюю область, КУДА игра рендерит живой элемент; контент
  НЕ на орнаменте (глобальное правило фреймов). Записать margins в
  `frames_spec.json`. Чистая прозрачность (нет белого фона/каймы — `strip_white_background.py`).
- Ассеты → `assets/sprites/ui/frames/hero_select_v3/`.

### Фаза 4 — Вёрстка в Godot (с нуля, 1-в-1 с макапом)
- `_show_character_select` ПЕРЕСОБРАТЬ с нуля: НЕ использовать старые узлы/рамки
  (старое — в бэкап, убрать из кода).
- Каждую зону позиционировать по `zones_normalized` × размер вьюпорта (1-в-1 с
  макапом на любом разрешении); фон зоны = соответствующая сгенерированная рамка
  (StyleBoxTexture/TextureRect), опц. общий `background.png`.
- В content-зону каждой рамки рендерить ЖИВОЙ игровой элемент:
  - превью → крупный портрет героя;
  - описание+возвышение → имя/описание/черты/оружие + степпер −/label/+ + «Выбрать»;
  - роза ветров → существующий `HeroStatRadar` (логика радара переиспользуется);
  - карусель → ряд иконок героев (hover-подсветка + tooltip, клик меняет выбор).
- Контент строго в content-зонах, ничего не накладывается, текст читаем;
  адаптив 1280×720/1920×1080/2560×1440.

## Тест/верификация
- runtime_smoke + ui_no_overlap_matrix зелёные.
- **QA-сверка 1-в-1**: скриншот готового экрана РЯДОМ с макапом — композиция
  совпадает (позиции/пропорции зон). Расхождение = FAILED. Скрин-сравнение в build/qa/.
- CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select — пересобрать; HeroStatRadar сохранить)
- docs/design/references/hero_select_v3/ (mockup.png, zones.json, zones_normalized.json, frames_spec.json)
- assets/sprites/ui/frames/hero_select_v3/ (frame_preview/dossier/radar/carousel/background)
- tools/strip_white_background.py (чистка прозрачности)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] Фаза 1: макап со всеми 4 зонами (+заголовок/назад) сгенерирован, единый стиль.
- [x] Фаза 2: zones.json + zones_normalized.json (bbox каждой зоны) по анализу макапа.
- [x] Фаза 3: отдельные production-рамки под каждую зону (прозрачный фон, content-зоны/margins в frames_spec.json), опц. фон.
- [ ] Фаза 4: экран пересобран с нуля, зоны по координатам, живые элементы в content-зонах; старое не используется. Передано Back-end handoff.
- [ ] Экран 1-в-1 с макапом (QA скрин-сравнение); no-overlap; текст читаем на 3 разрешениях; smoke+matrix зелёные; CHANGELOG. Back-end scope.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Design Result (2026-06-15)

Статус: done (Design-source / handoff-ready). Runtime phase 4 не выполнялась в
этом Design 2 окне и передана отдельной Back-end задачей
`docs/tasks/backend_hero_select_v3_runtime_from_mockup_task.md`.

Artifacts:
- Mockup: `docs/design/references/hero_select_v3/mockup.png`
- Annotated zones: `docs/design/references/hero_select_v3/mockup_zones_annotated.png`
- Raw Vision zones: `docs/design/references/hero_select_v3/zones_vision_raw.json`
- Corrected source-of-truth zones: `docs/design/references/hero_select_v3/zones.json`
- Corrected normalized zones: `docs/design/references/hero_select_v3/zones_normalized.json`
- Frame/content spec: `docs/design/references/hero_select_v3/frames_spec.json`
- UI mockup spec: `docs/design/references/hero_select_v3/hero_select_v3_mockup_spec.md`
- UI-director package mirror: `docs/design/mockups/hero_select_v3/`
- Frame preview/contact sheet: `docs/design/previews/hero_select_v3_frames_contact.png`
- Runtime frame assets: `assets/sprites/ui/frames/hero_select_v3/frame_preview.png`,
  `frame_dossier.png`, `frame_radar.png`, `frame_carousel.png`, optional `background.png`.

Validation:
- OpenAI Images API used for mockup and production frame source art.
- OpenAI Vision API used for raw bbox detection; raw output preserved in
  `zones_vision_raw.json`.
- Designer overlay QA corrected Vision overreach so final `zones.json` zones are
  non-overlapping (`hero_preview` ends at y=622, carousel starts at y=626).
- Final frame PNG audit: RGBA, transparent content rects, `white_opaque_pixels=0`
  for all four transparent production frame assets and optional background.
- Runtime smoke/no-overlap not run by Design scope; Back-end handoff must run them
  after `_show_character_select` rebuild.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: Фазы 1-3 — макап, зоны, production-рамки) — Фаза 4 Back-end отдельно

Проверено (фактически, на артефактах):
- **Фаза 1 — макап** `hero_select_v3/mockup.png` (1536×864): D&D dark-fantasy, ЯВНО видны
  4 зоны (preview слева вертикально, dossier центр с «ASCENSION»-степпером, роза ветров
  справа-сверху, карусель снизу) + HERO SELECT баннер + BACK ✓.
- **Фаза 2 — зоны** `zones.json`+`zones_normalized.json` (OpenAI Vision + Designer-коррекция):
  4 ГЛАВНЫЕ content-зоны **не пересекаются** (hero_preview bottom=622 < carousel top=626;
  dossier right=1013 < radar left=1086; preview right=384 < dossier left=388) ✓.
- **Фаза 3 — production-рамки**: `frame_preview/dossier/radar/carousel.png` — все RGBA,
  **white_opaque=0** (прозрачный фон, без белой каймы), у каждой content-rect внутри
  орнамента (контакт-лист `hero_select_v3_frames_contact.png` — cyan-зоны). `frames_spec.json`
  фиксирует content_margins + правило «контент только в content_rect, орнамент запрещён» ✓.

Acceptance (Design-source scope):
- [x] Фаза 1: макап со всеми 4 зонами + заголовок/назад, единый стиль.
- [x] Фаза 2: zones.json + zones_normalized.json (bbox каждой зоны), 4 главные зоны не пересекаются.
- [x] Фаза 3: отдельные production-рамки под зоны (прозрачные, content-зоны/margins в frames_spec.json).
- [~] Фаза 4 (вёрстка с нуля + 1-в-1 с макапом + smoke/matrix) — Back-end scope, отдельный таск
  `backend_hero_select_v3_runtime_from_mockup_task.md`, НЕ в этом Design-вердикте.

Статус done (Design-source). Баги: нет. Заменяет провалившийся SCRUM-436.
⚠️ Для Back-end (Фаза 4): служебные элементы слегка перекрывают верхний край главных зон
(title↔dossier ~11px, back_button↔hero_preview ~7px) — это header-оверлеи; при вёрстке
рендерить title/back в header-band, чтобы живой контент dossier/preview (в content_rect) с
ними не сталкивался. runtime/no-overlap прогнать после пересборки `_show_character_select`.
