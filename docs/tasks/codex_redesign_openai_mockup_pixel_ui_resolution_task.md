# Полный редизайн экрана «Кодекс»: OpenAI-мокап → карта layout → новый пиксельный UI без растяжения

Статус: blocked
Версия: 0.1.8
Создано: 2026-06-30
Роль: Design
Контур: Codex
Owner: unassigned
Thread/Worker: n/a (released by 019f1fbb-ac80-7013-90c6-5b8003afad49 / codex-scrum-725-verification-worker after blocker)
Locked paths: `docs/design/mockups/codex_redesign_2026_06/`, `assets/sprites/ui/frames/codex_pl/`, Codex-only section of `scripts/ui_screens.gd`, `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`, `build/qa/codex_redesign*`
Приоритет: P1
Метки: foma
Jira: SCRUM-725
Эпик: UI/Art

## Goal
Переделать внутриигровой экран «Кодекс» с нуля по новому дизайну: убрать баги при
смене разрешения, устранить растянутые/искажённые элементы, гарантировать
читаемость текста (контраст к фону и к картинкам), сделать полноценный фон.
Подход пользователя (зафиксирован): **сначала сделать мокап через OpenAI image
generation, на нём определить, что где должно лежать, затем собрать новый
интерфейс в пиксельной графике без растягивания элементов (9-slice/NinePatch).**

## Контекст — текущие проблемы (жалобы пользователя 2026-06-30)
Текущий «Кодекс» (V2 `codex_pl`, наработки SCRUM-574 / SCRUM-684 / SCRUM-699):
1. **Баги при изменении разрешения игры** — при ресайзе окна экран ломается
   (съезжает/обрезается/перекрывается). Текущий ресайз-обработчик
   (`root.resized.connect` → `_codex_v2_apply_layout`) не даёт стабильной картинки.
2. **Растянутые интерфейсы** — элементы/рамки тянутся и искажаются (не 9-slice,
   либо неправильные минимальные размеры → видно растяжение пикселей).
3. **Текст не виден** — цвет текста часто сливается с фоном или с картинками.
   В коде карточный/детальный текст очень тёмно-коричневый
   (`CODEX_PL_CARD_TITLE_COLOR` 0.28/0.13/0.06, `CODEX_PL_DETAIL_BODY_COLOR`
   0.20/0.13/0.07), плюс агрессивный тёмный shade-оверлей (0.62 alpha) →
   плохой контраст на тёмном фоне и на портретах/иконках.
4. **Нет фона** — по ощущению пользователя фон отсутствует/не читается как фон
   (backdrop `codex_pl_backdrop.png` либо не показывается, либо забит оверлеем).
5. Общий вердикт пользователя: «надо сделать хорошо».

## Текущее состояние в коде (что переделываем)
- `scripts/ui_screens.gd` — весь экран строится процедурно (НЕТ .tscn):
  - `_show_codex_screen()` (~строки 2619–2712) — корневой shell, фон, shade-оверлей,
    3-колоночный layout (Nav / List / Detail);
  - `_show_codex_section()` (~2715–2764) — ленивые секции;
  - `_codex_v2_*` хелперы (~2767–3400) — масштаб, layout, стили, карточки;
  - `_build_codex_*` (~3205–3367) — контент 6 секций.
  - Константы масштаба: `CODEX_V2_BASE_SIZE = (1920,1080)`,
    `CODEX_V2_SCREEN_INSET = (28,30)`; цвета карточек/деталей ~строки 484–489.
- `scripts/codex_data.gd` — данные (персонажи/монстры/артефакты/статы/глоссарий/
  возвышения). **НЕ трогать** — это контент, не UI.
- Текущие ассеты: `assets/sprites/ui/frames/codex_pl/` и `.../codex_pl/fit/`
  (main_shell, nav/list/detail panel, entry_card, category_button, back_button,
  backdrop, 6 иконок категорий).
- 6 секций (вкладок): Персонажи · Монстры · Артефакты · Статы · Глоссарий ·
  Возвышения. Все должны остаться рабочими.

## Подход (порядок работы — обязателен)
### Фаза 1 — Мокап через OpenAI image generation
Сгенерировать полноэкранный мокап экрана «Кодекс» (1920×1080, dark fantasy,
пиксель-арт каркас) через OpenAI gpt-image (скилл
`fantasydisk-asset-generator`). Мокап показывает финальную композицию:
- полноценный читаемый **фон** (атмосферный, но приглушённый, чтобы панели
  читались как передний план — без забивающего тёмного оверлея в 0.62);
- 3 зоны: левая навигация (6 категорий с иконками), центральный список записей
  (карточки: портрет + заголовок + краткое описание), правая панель деталей
  (заголовок, портрет, чипы-метаданные, прокручиваемый текст);
- заголовок-хедер + кнопка «Назад»;
- читаемые цвета текста (светлый кремовый/золотой по тёмным панелям; тёмный
  текст ТОЛЬКО по светлым пергаментным плашкам — с гарантированным контрастом).
Сложить мокап(ы) в `docs/design/mockups/codex_redesign_2026_06/`.

### Фаза 2 — Карта layout (по мокапу)
По утверждённому мокапу составить точную карту: какие зоны, их пропорции
(в долях от 1920×1080), какие элементы где, какие 9-slice-края у рамок, размеры
шрифтов по уровням (заголовок/подзаголовок/тело/чип) и палитра текста/фона с
указанием контраста. Зафиксировать в
`docs/design/mockups/codex_redesign_2026_06/layout_map.md`.

### Фаза 3 — Пиксельные ассеты (9-slice, без растяжения)
Нарезать/сгенерировать новый набор рамок и фон под 9-slice:
- фон-бэкдроп (full-bleed, под viewport, без растяжения пикселей — корректный
  expand/cover, не stretch);
- панели Nav/List/Detail, карточка записи, кнопка категории, кнопка «Назад»,
  хедер — все как NinePatch (неискажаемые углы, тянущаяся середина);
- 6 иконок категорий — переиспользовать существующие, если годятся, иначе обновить.
Складывать в `assets/sprites/ui/frames/codex_pl/` (заменять in-place с
сохранением размеров → .import валиден; новые — рядом). Прозрачный фон, RGBA,
border-connected flood-fill alpha-cleanup если генератор запекает фон.

### Фаза 4 — Интеграция в код
Переписать секцию Кодекса в `scripts/ui_screens.gd`:
- **Фон**: всегда показывать backdrop, expand-mode = keep-aspect-covered (без
  растяжения), shade-оверлей убрать или снизить так, чтобы фон читался и текст
  оставался контрастным.
- **Растяжение**: все рамки через NinePatchRect/StyleBoxTexture с корректными
  margin'ами; задать минимальные размеры так, чтобы пиксели не тянулись;
  `texture_filter = NEAREST` сохранить.
- **Ресайз**: исправить баги — layout пересобирается корректно при любом
  изменении разрешения окна (тест в нескольких разрешениях, см. Acceptance).
  Предпочтительно — устойчивый anchor/Container-подход вместо ручного
  пересчёта rect'ов, либо починенный `_codex_v2_apply_layout`.
- **Текст**: поднять контраст — светлый текст по тёмным панелям, тёмный только
  по светлым плашкам; убрать нечитаемые тёмно-коричневые цвета на тёмном фоне.
- 6 секций и переходы List↔Detail остаются рабочими.

## Acceptance Criteria
- [ ] Мокап(ы) в `docs/design/mockups/codex_redesign_2026_06/` + `layout_map.md`.
- [ ] Фон экрана присутствует и читается; текст контрастен и к фону, и к
      картинкам/портретам во всех 6 секциях (визуальная проверка скриншотами).
- [ ] Нет растянутых/искажённых пикселей: все рамки 9-slice, углы не тянутся.
- [ ] Ресайз без багов: проверено в 1920×1080, 1280×720, 2560×1440 и при
      произвольном ресайзе окна — без обрезки/перекрытия/съезда. Скриншоты до/после
      в `build/qa/codex_redesign/`.
- [ ] Все 6 вкладок (персонажи/монстры/артефакты/статы/глоссарий/возвышения)
      и панель деталей работают; данные из `codex_data.gd` не потеряны.
- [ ] Каждая генерация арта шла через OpenAI gpt-image с приложенным
      стиль-референсом (команды/промпты зафиксировать в Result).
- [ ] Зелёные гейты: Godot `--import`, `runtime_smoke_test.gd`,
      `ui_no_overlap_matrix_test.gd`, `codex_data_smoke_test.gd`.

## Files / Assets / IDs
- Код: `scripts/ui_screens.gd` (секция Кодекса ~2619–3400).
- Данные (НЕ менять): `scripts/codex_data.gd`.
- Ассеты: `assets/sprites/ui/frames/codex_pl/` (+ `fit/`).
- Мокап/карта: `docs/design/mockups/codex_redesign_2026_06/`.
- Скриншоты QA: `build/qa/codex_redesign/`.
- Тесты: `tests/codex_data_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`,
  `tests/runtime_smoke_test.gd`.
- Locked paths (не трогать): `scripts/codex_data.gd`, контент-данные секций.

## Инструменты генерации
- Арт/мокап — скилл `fantasydisk-asset-generator` (OpenAI gpt-image), прозрачный
  фон, dark-fantasy пиксель-канон; референсы — текущий `codex_pl` + dark fantasy
  UI канон (`docs/design/systems/visual_style_assets.md`).
- Допустимо PixelLab MCP (`create_ui_asset`, омит elements для full-bleed 9-slice,
  «no text») для рамок/бэкдропа, если так быстрее под 9-slice.
- Alpha-cleanup при запечённом фоне — flood-fill (numpy+PIL), размер не менять.

## Самопроверка
Визуальный чек-лист по каждой секции в 3 разрешениях + headless-гейты;
контактный preview мокап↔финал в `docs/design/previews/`.

## Result — Codex UI worker 2026-07-02

Phase 3–4 implementation is present in the worktree:
- PixelLab MCP phase-3 source jobs completed for main/nav/list/detail/card/category/back/backdrop assets; source IDs and raw contact sheet are recorded in `docs/design/references/codex_redesign_2026_06/pixellab_sources/manifest.md` and `docs/design/previews/codex_redesign_2026_06_pixellab_contact.png`.
- Runtime PNGs were rebuilt through deterministic cleanup script `docs/design/references/codex_redesign_2026_06/build_scrum725_codex_assets.py` to remove baked labels/checker artifacts and keep textless 9-slice-safe margin bands. Runtime contact sheet: `docs/design/previews/codex_redesign_2026_06_runtime_contact.png`; audit: `docs/design/references/codex_redesign_2026_06/runtime_asset_audit.md`.
- `scripts/ui_screens.gd` Codex section now uses the SCRUM-725 layout map geometry, `codex_pl_backdrop` cover-crop with light shade, cream/gold dark-panel text, parchment-only dark detail body text, updated category/button metrics, and active-section rebuild on viewport resize.
- Codex-specific runtime smoke expectations were updated to the SCRUM-725 base rects in `tests/runtime_smoke_test.gd`.
- Documentation updated: `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, `docs/design/systems/visual_style_assets.md`.

Verification blocker:
- `python3 tools/godot_gate.py --headless --path . --import` was attempted twice from a clean/partial `.godot` cache. Both runs reached `[ DONE ] first_scan_filesystem` and then stayed silent until manually interrupted. After interruption, `.godot/imported/` contained `0` imported files and only `.godot/.gdignore` plus `.godot/global_script_class_cache.cfg` existed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd` also blocked at the gate's automatic import-cache step for the same reason.
- Required Godot gates (`--import`, `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`, `codex_data_smoke_test.gd`) are therefore **not claimed green** in this run.

Disk cleanup: removed partial `.godot` import cache and ignored `build/qa/codex_redesign_asset_audit.md` duplicate; no disposable clone/worktree created.
Thread cleanup: pending archive at worker finish.

## Verification Retry — Codex SCRUM-725 verification worker 2026-07-02

Статус: blocked
Thread/Worker: 019f1fbb-ac80-7013-90c6-5b8003afad49 / codex-scrum-725-verification-worker

Scope: verify/unblock the implementation already pushed to `origin/dev` at
`90b77eb2` (`fc2dd5e8` implementation, `28c4ead9` sync, `90b77eb2` cleanup note).

Result:
- Small SCRUM-725 defect fixed in `scripts/ui_screens.gd`: `CODEX_PL_LIST_CONTENT`
  and matching `CODEX_V2_LIST_PANEL_CONTENT` are now `Vector4(64, 72, 64, 64)`,
  so the Codex list panel content stays outside the 48px 9-slice ornament band.
- Non-Godot checks PASS: `git diff --check`; deterministic
  `docs/design/references/codex_redesign_2026_06/build_scrum725_codex_assets.py`
  rerun with no runtime asset diffs; Patch Notes still uses generic
  `_add_screen_background(root, "codex")`; Codex uses `_add_codex_pl_background`
  with `STRETCH_KEEP_ASPECT_COVERED`; Codex content-margin audit confirms every
  `CODEX_PL_*_CONTENT >= CODEX_PL_*_TEX`.
- Godot verification BLOCKED again: `python3 tools/godot_gate.py --headless
  --path . --import --quit` reached `[ DONE ] first_scan_filesystem` and then
  stayed silent for ~4 minutes. During the hang `.godot/` contained only
  `.godot/.gdignore` and `.godot/global_script_class_cache.cfg`,
  `.godot/imported` had `0` files, and `.godot` size was `8.0K`. The worker
  interrupted only its own gated import; no SCRUM-725 Godot smoke is claimed
  green.
- Not run/Not green because import cache never materialized:
  `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `codex_data_smoke_test.gd`, and 1280x720 / 1920x1080 / 2560x1440 screenshot
  evidence.

Next status: release back to Jira `К выполнению` / blocked evidence for a fresh
environment verification pass after Godot import unblocks. Do not move to
`Контроль качества` from this run.

Disk cleanup: pending removal of this worker's `.godot` cache and ignored
`build/qa/codex_redesign_asset_audit.md` after sync/commit.
Thread cleanup: pending archive at worker finish.
