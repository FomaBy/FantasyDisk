# Унификация UI под стиль «Атласа героев»: выбор персонажа, настройки, кодекс, релиз-ноты

- Jira: SCRUM-879
- Статус: done
- Контур: Claude
- Owner: Claude Fable 5 (интерактивный чат пользователя)
- Thread: claude-fable5-ui-unify-20260708
- Worktree: основной чекаут `dev` + 4 временных worktree `wt-ui-{hero,settings,codex,notes}`
- Branch: dev
- Locked paths: `scripts/ui_screens.gd`, `assets/sprites/ui/atlas_style/**`,
  `tools/generate_atlas_style_screens_openai.py`, `tools/capture_atlas_style_screens.gd`,
  `tests/hero_select_pixellab_layout_test.gd`, `tests/patch_notes_smoke_test.gd`,
  `tests/ui_no_overlap_matrix_test.gd` (блоки hero_select/settings/codex/patch_notes),
  `docs/design/previews/atlas_style_*`

## Source Request

Прямая директива пользователя (чат Claude, 2026-07-08): «Посмотри как сделан дизайн
на странице атласа персонажа и переделай интерфейсы выбора персонажа, настроек,
кодекса и релиз нотов. Проанализируй фреймы интерфейса, используй mcp pixellab +
openai image generation чтобы все было так же красиво и аккуратно. …полностью
автономно используя агентов для распараллеливания…»

- **Правило 1:** нельзя растягивать элементы интерфейса.
- **Правило 2:** все кнопки должны быть одинакового стиля (не касается выпадающих списков).

Генерация: PixelLab MCP (акценты/эмблемы) + OpenAI Images `gpt-image-2` (фоны
2560×1440). **OpenAI Images override** записан здесь по прямой директиве
пользователя и для консистентности с каноном кита meta40 (SCRUM-832) и settings_v6
(SCRUM-847), которые сгенерированы тем же пайплайном.

## Проблема

Экран «Атлас героев» (SCRUM-827/832, кит `assets/sprites/ui/meta40/`) задаёт
эталонный вид: полноэкранный тихий фон без растяжки (KEEP_ASPECT_COVERED), полая
орнаментная рама 9-slice (`draw_center=false`, контент строго в safe-зоне),
тёмно-кожаные панели с латунным кантом, глобальный кит кнопок
(text_buttons_unique + minimal_metal), пергаментно-золотая типографика.

Четыре экрана выбиваются из этого стиля:
1. **Выбор персонажа** (`_build_character_select_v4`) — «чёрный минимал» SCRUM-470:
   чистый ColorRect-фон, плоские StyleBoxFlat, собственная кнопочная тема
   `_apply_hs4_minimal_button_theme` (нарушение Правила 2).
2. **Настройки** (v6, SCRUM-847) — палитра уже атласная, но кнопки действий и табы
   на собственном арте `ui_settings_v6_btn_*`/`tab_*` (нарушение Правила 2), фон
   старый `ui_backdrop_settings`.
3. **Кодекс** — кит `codex_pl` (688×384 нативы, чанки при апскейле), собственная
   кнопочная тема `_apply_codex_pl_button_theme`, свой лоу-рез фон.
4. **Релиз-ноты** — панель `overhaul_2k/pn_panel` + чужой кодексовый фон.

## Решение

Общий фундамент в `ui_screens.gd`: константы `ATLAS_STYLE_*` и хелперы
`_unified_add_background` (фон COVERED без растяжки, fallback на `bg_sky`),
`_unified_add_frame` (полая рама `meta40/frame_border` поверх контента),
`_unified_make_safe_area` (MarginContainer по `_scaled_frame_margins_xy`,
контент только в пустой зоне рамы), `_unified_header_chip` (кожаный чип-заголовок
с эмблемой). Переиспользуются готовые `_atlas_chip_style`/`_atlas_frame_style` и
глобальный кит кнопок `_make_button`/`_set_action_button_size`.

Новые ассеты `assets/sprites/ui/atlas_style/`:
- OpenAI (пайплайн meta40: канвас 1536×1024 → crop 16:9 → LANCZOS 2560×1440):
  `bg_hero_hall.png`, `bg_codex_archive.png`, `bg_chronicle.png`, `bg_sanctum.png`.
- PixelLab MCP (map_object, прозрачный фон, целочисленный ×2 NEAREST):
  `pedestal_dais.png` (~760×240), `divider_ornament.png` (~800×64),
  `emblem_hero_hall.png`, `emblem_codex.png`, `emblem_chronicle.png` (128×128).

Per-экран (4 параллельных агента в изолированных worktree, непересекающиеся
диапазоны строк `ui_screens.gd`, merge оркестратором):
1. **Выбор персонажа:** bg_hero_hall + рама; досье/карусель/статы — кожаные
   чипы; все кнопки → глобальный кит; пьедестал под портретом; фокус-цепочки
   геймпада сохранить.
2. **Настройки:** фон → bg_sanctum; кнопки действий (`Apply/Revert/Back/Reset*`)
   и 3 таба → глобальный кит (актив таба — модуляция, как на атласе);
   OptionButton-поля, bind-поля, чекбоксы, слайдеры, чипы значений — остаются
   на ките v6 (поля = «выпадающие списки/поля ввода», исключение Правила 2).
3. **Кодекс:** шелл → фон bg_codex_archive + полая рама + три кожаные панели
   контейнерами в safe-зоне; табы разделов и «назад» → глобальный кит с
   эмблемами 160; карточки записей — кожаные чипы; object-first зоны SCRUM-850
   сохранить (имена узлов не менять).
4. **Релиз-ноты:** фон bg_chronicle + рама; контент — кожаная панель в
   safe-зоне; заголовки версий золотом + орнамент-разделители; кнопка назад —
   глобальный кит.

Тесты обновить под новый контракт стиля (matrix-блоки, hero_select layout-тест,
patch_notes smoke); прогнать runtime_smoke + ui_no_overlap_matrix + focused.

## Acceptance Criteria

- [ ] Все 4 экрана используют: фон atlas_style (COVERED, без растяжки осей),
      полую раму meta40 (кроме модалки настроек), контент в safe-зоне рамы,
      кожаные панели, золотую типографику.
- [ ] Правило 1: ни один элемент не растянут (только KEEP_ASPECT_* и 9-slice
      StyleBoxTexture с корректными texture/content margins).
- [ ] Правило 2: все Button-контролы 4 экранов на глобальном ките
      (text_buttons_unique/minimal_metal); исключения — только OptionButton,
      bind-поля, чекбоксы, слайдеры.
- [ ] Контент не наезжает на орнамент рамы (глобальное правило фреймов).
- [ ] Зелёные: `runtime_smoke_test`, `ui_no_overlap_matrix_test`,
      `hero_select_pixellab_layout_test`, `patch_notes_smoke_test`,
      `gamepad_settings_rebind_test`, `gamepad_menu_focus_test`.
- [ ] Превью 4 экранов в `docs/design/previews/atlas_style_*` (windowed capture).
- [ ] Всё влито в `origin/dev`, worktree убраны, Jira синхронна.

## Прогресс

- 2026-07-08: разведка (3 Explore-агента), спека, план параллелизации — Claude Fable 5.
- 2026-07-08: кит atlas_style сгенерирован (OpenAI 4 фона 2560×1440 + PixelLab пьедестал/
  разделитель/3 эмблемы, alpha-cleanup); фундамент `_unified_*` влит (b87bbaf8).
- 2026-07-08: 4 параллельных субагента в worktree; ветки влиты последовательно:
  релиз-ноты (31c25b64), выбор героя (8ea9f197+338ece20), настройки v1 (1c4d2a63+89e41ee1),
  кодекс (0eec5f12..e669fdf8; −700 строк мёртвого v2-движка).
- 2026-07-08: фидбек пользователя «настройки/кодекс не обновлены» → вторая итерация
  настроек (c248ab84): v6-модалка удалена целиком, полноэкранный атлас-шелл
  (safe-зона, кожаная контент-панель, шапка чип+Назад, ряд табов, футер Применить/
  Вернуть, полая рама поверх); кодекс был уже готов в ветке — влит.
- 2026-07-08: полный QA на объединённом dev + windowed-превью (build/qa/scrum879/,
  копии в docs/design/previews/atlas_style_*). Всё запушено в origin/dev.

## QA-Вердикт

- Статус: PASSED
- Дата: 2026-07-08, судья: Claude Fable 5 (оркестратор SCRUM-879)
- Прогоны на объединённом dev (все через tools/godot_gate.py, EXIT=0):
  runtime_smoke_test PASS; ui_no_overlap_matrix_test PASS (7 вьюпортов
  1152×648…3840×2160); hero_select_pixellab_layout_test PASS (5 вьюпортов,
  15 классов направленных превью); gamepad_settings_rebind_test PASS;
  patch_notes_smoke_test PASS; gamepad_menu_focus_test PASS;
  runtime_smoke_ui_test PASS; codex_data_smoke_test PASS. В ветках агентов
  дополнительно: video_settings_apply_test, game_settings_smoke_test,
  gamepad_full_flow_smoke_test — PASS.
- Визуальная приёмка скриншотов 2560×1440: рама не перекрыта контентом,
  растяжек нет (нативы кита/9-slice/KEEP_ASPECT), кнопки — единый глобальный
  кит, поля/бинды/чекбоксы/слайдеры v6 — санкционированное исключение.
- Превью: docs/design/previews/atlas_style_{hero_select,settings,codex,patch_notes}_2560x1440.png,
  ректы: build/qa/scrum879/atlas_style_rects.md.
- Disk cleanup: removed /private/tmp/fsd_wt_scrum879/{hero,settings,codex,notes,settings2}
  (worktree + ветки после влития), удалены 7 Finder-дублей « 2.*»; .godot-кэши
  worktree удалены вместе с ними.
