# Перекраска семьи minimal_metal: жёлтый кант → тёмная латунь (экономика, награды, пауза, чип-HUD)

Статус: new
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.1.8
Создано: 2026-07-02
Автор: SCRUM-809 аудит
Labels: foma, backend, claude

## Контекст

Аудит жёлтых рамок (SCRUM-809, `docs/design/audits/yellow_frames_audit_2026_07.md`):
семья `assets/sprites/ui/frames/minimal_metal/` — тёмный уголь с тонким
ярко-жёлто-оранжевым кантом — самая массовая жёлтая рамка в игре. Арт-дирекция
(SCRUM-806 reopen, `docs/tasks/combat_hud_compact_redesign_task.md`, раздел «Доработка
по фидбеку PM»): вместо ярко-жёлтых рамок — тёмная кожа + тонкая латунная линия
(референс `assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`), либо без рамки.

Затронутые текстуры (все в `assets/sprites/ui/frames/minimal_metal/`):

- `ui_frame_minimal_metal_card.png` (426×486) — карты наград (обычные+элитные),
  карты выбора экономики (событие/отдых/докачка/атрибуты).
- `ui_frame_minimal_metal_panel.png` (782×716) — генерик-панели `_create_menu_box`,
  панели экономики, группы статов паузы-досье.
- `ui_frame_minimal_metal_field.png` (616×286) — чипы CharacterStatsHud (В БОЮ —
  единственный жёлтый остаток боевого HUD), карточки межбоевого ресурс-HUD,
  ценники экономики, слот портрета кодекса, строки/чипы статов паузы.
- `ui_frame_minimal_metal_tooltip.png` (760×242) — тултипы экономики/кодекса.
- `ui_frame_minimal_metal_modal.png` (986×900) — fallback-модалка конца забега.

Код, который их применяет (менять НЕ требуется, если перекраска in-place):

- `scripts/ui/ui_theme_paths.gd` — MINIMAL_METAL_FRAME_PATHS/MARGINS/CONTENT (строки 10–64).
- `scripts/ui_screens.gd` — `_minimal_frame_style`, `_minimal_metal_frame_style`,
  `_reward_card_style`, `_economy_choice_style`, `_hud_card_style`,
  `_character_stats_hud_style`, `_codex_portrait_slot_style`, `_panel_style`,
  `_economy_panel_style` (искать по именам функций; константы ECONOMY_*/REWARD_*/
  COMBAT_HUD_CARD_PATHS/CODEX_PORTRAIT_SLOT_PATH в шапке файла, строки ~31–35, 160–170,
  370–380, 470–485, 575–585).
- `scripts/pause_stats_menu.gd:10–24` — preload'ы ESCAPE_PANEL_FRAME, STAT_BASIC_ROW_FRAME,
  STAT_GROUP_FRAME, STAT_CHIP_FRAME, STAT_TOOLTIP_FRAME, PAUSE_END_MODAL_FRAME.

## Что сделать

1. Скрин-капчи «до» затронутых экранов (экономика-выбор, награда, пауза-досье, бой с
   CharacterStatsHud, кодекс-портрет) в `build/qa/` — capture-тулзы в `tools/`
   (см. `tools/capture_*`; Godot 4.6.3, гонять через `tools/godot_gate.py`).
2. Перекрасить кант всех 5 текстур из ярко-жёлтого (#E8A33D-семейство, hue 30–68°,
   sat>0.42, val>0.52) в тёмную латунь как у `ui_hud_v2_cluster_bg.png` (пипеткой снять
   цвет линии: тёмный золотисто-коричневый, val ~0.3–0.45). Метод — python3+PIL
   таргет-перекраска по hue-маске (селектор: hue 30–68°, sat≥0.42, val≥0.52 → сдвиг
   val/sat вниз до латуни), РАЗМЕР PNG НЕ МЕНЯТЬ — тогда .import остаются валидными
   и 9-slice margins в `ui_theme_paths.gd` не трогаются.
3. Прогнать пиксель-скан краевой полосы (методика аудита): bright-доля каждой текстуры
   после перекраски < 5%.
4. Скрин-капчи «после» тех же экранов, глазами сверить с референсом cluster_bg.
5. Smoke-тесты UI (`tests/` через `tools/godot_gate.py`, один инстанс Godot).

## Acceptance Criteria

- [ ] Все 5 текстур перекрашены: кант тёмно-латунный, тело угольное без изменений.
- [ ] Размеры PNG и 9-slice margins НЕ изменены (git diff только по содержимому PNG,
      без правок .import/ui_theme_paths.gd).
- [ ] Пиксель-скан: bright-доля краевой полосы < 5% у каждой текстуры.
- [ ] Капчи до/после в `build/qa/` по 5 экранам (экономика, награда, пауза-досье,
      бой с чип-HUD, кодекс).
- [ ] Контент остаётся в safe-area фреймов (frame-content-safe-area правило).
- [ ] Smoke UI-тесты зелёные.

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 1».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Паттерн безопасной правки альфы/цвета без смены размера: memory
  alpha-flood-fill-fix-baked-bg (не менять размер → .import валиден).
