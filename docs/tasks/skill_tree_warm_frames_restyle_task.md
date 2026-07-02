# Скилл-три: оранжево-золотые рамки → тёмная кожа с латунью (селектор, попап, ОЧКИ, панели путей)

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.1.8
Создано: 2026-07-02
Автор: SCRUM-809 аудит
Labels: foma, backend, claude

## Контекст

Аудит жёлтых рамок (SCRUM-809, `docs/design/audits/yellow_frames_audit_2026_07.md`):
экран мета-прогрессии (скилл-три) выдержан в тёплой оранжево-золотой «деревянной» семье,
выбивающейся из принятого курса. Арт-дирекция SCRUM-806 reopen: тёмная кожа + тонкая
латунная линия (референс `assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`).

Затронутые текстуры (все в `assets/sprites/ui/skill_tree/`, bright% из аудита):

- `ui_frame_skill_tree_class_select.png` (14.5) — селектор «КЛАСС» с оранжевой рамкой
  и оранжевым боксом стрелки.
- `ui_frame_skill_tree_class_popup.png` (12.2) — попап «БОНУСЫ КЛАССА», толстая
  оранжево-деревянная рама.
- `ui_btn_skill_points.png` (18.3) — плашка «ОЧКИ» с золотисто-оранжевой рамой
  (текст «ОЧКИ» запечён в текстуру).
- `ui_frame_skill_tree_path_wealth.png` / `_lore` / `_might` / `_endure.png` (9.8–17.7) —
  панели четырёх путей дерева (шапка с эмблемой запечена).
- `ui_frame_skill_tree_main.png` (10.1) — главная рама экрана.

НЕ трогать (решение аудита «оставить»): `node_keystone_allocated.png` и прочие золотые
стейты узлов (`node_*`) — золото там семантика «куплено/вложено», эмблемы в пиксель-стиле
эмблем возвышения, не рамки. Зум-кнопки «+»/«−» (SkillTreeZoomIn/OutButton) чинятся
волной 5 (текстура utility из `minimal_metal_buttons/`) — здесь не трогать.

Код (менять НЕ требуется при in-place перекраске; ориентиры в `scripts/ui_screens.gd`):

- Константы ~422–470: SKILL_TREE_FRAME_DIR, SKILL_TREE_CLASS_SELECT_PATH,
  SKILL_TREE_CLASS_POPUP_PATH, SKILL_TREE_POINTS_BTN_PATH, SKILL_TREE_PATH_*
  (wealth/lore/might/endure), SKILL_TREE_MAIN_FRAME_PATH, SKILL_TREE_POINTS_BADGE_PATH.
- Стили: `_skill_tree_class_select_style`, `_skill_tree_class_popup_style`,
  `_skill_tree_points_button_style`, `_skill_tree_main_panel_style`,
  `_skill_tree_points_badge_style`, `_make_skill_tree_popup` (~9106–9177,
  искать по именам функций).

## Что сделать

1. Скрин-капчи «до» экрана скилл-три в `build/qa/` (селектор класса раскрыт,
   попап бонусов, обе колонки путей видны; Godot через `tools/godot_gate.py`).
2. PIL-перекраска по hue-маске (hue 20–68°, sat≥0.35, val≥0.45 — у этой семьи рамы
   темнее и оранжевее, чем у minimal_metal, подобрать селектор по факту): свести
   оранжево-золотые рамы к тёмной коже/тёмному дереву с латунным кантом. Тело панелей
   (тёмный пергамент/фиолетовый фон) не трогать. Размер PNG сохранить → margins и
   `.import` не меняются.
3. Следить за запечёнными элементами: текст «ОЧКИ», заголовки путей («БОГАТСТВО» и др.),
   эмблемы в шапках панелей — золото ТЕКСТА/эмблем оставить (семантика/читаемость),
   перекрашивать только рамы. Если hue-маска цепляет запечённый текст — маскировать
   зоны текста прямоугольником-исключением.
4. Пиксель-скан краевой полосы: bright < 5% по всем перекрашенным текстурам.
5. Капчи «после», сверка с cluster_bg-референсом; smoke-тесты
   (скилл-три тесты в `tests/`, гонять через гейт).

## Acceptance Criteria

- [ ] 8 текстур (class_select, class_popup, points_btn, 4 path-панели, main) без
      оранжево-золотых рам: тёмная кожа/дерево + латунный кант.
- [ ] Золотые узлы дерева и запечённые тексты/эмблемы НЕ изменены.
- [ ] Размеры PNG/margins/.import не изменены.
- [ ] Пиксель-скан bright < 5% (краевая полоса) по перекрашенным текстурам.
- [ ] Капчи до/после в `build/qa/`; контент в safe-area (frame-content-safe-area).
- [ ] Smoke-тесты скилл-три зелёные.

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 4».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Зависимость: зум-кнопки этого экрана — волна 5
  (`docs/tasks/yellow_buttons_levelup_accents_task.md`).

## Реализация (Back-end, Claude — SCRUM-820)

Инструмент: `tools/recolor_skill_tree_brass.py` (in-place PIL-перекраска, тот же
brass-remap, что и семья minimal_metal SCRUM-817 — единая латунная линия по UI).

Метод отделения рамы от запечённого золота: рама (кант, угловые бобышки, канты
картушей, бокс стрелки селектора, разделители) касается прозрачного поля и берётся
flood-fill'ом «наружной» не-золотой области от края внутрь; запечённый ТЕКСТ (тайтлы,
имена путей, «ОЧКИ», «КЛАСС») и ЭМБЛЕМЫ (монета, эмблемы путей) — замкнутые острова
внутри тёмного тела, по умолчанию защищены и НЕ перекрашиваются. Декоративные острова
(нижний ромб `main`, разделитель шапки `class_popup`) возвращены в перекраску точечными
прямоугольниками — это канты, не текст/эмблемы.

Результат (8 текстур, размеры/alpha/`.import` не изменены):
- bright-orange на раме = 0 px по всем 8; краевая полоса (frame-only) 0.0% < 5%.
- запечённые тексты и эмблемы сохранены (bright-gold только в защищённых зонах).
- превью до/после: `docs/design/previews/scrum820/*_before_after.png`.

AC: все пункты выполнены (рамы → тёмная латунь; золото узлов/текстов/эмблем не тронуто;
размеры/margins/.import неизменны; edge bright < 5%; превью; smoke-тесты скилл-три).

## QA-Вердикт
Статус: PASSED (2026-07-02, claude-qa/оркестратор)

- Ancestry: c56bccec — merge-base ancestor origin/dev OK.
- Независимый bright-скан origin-блобов (методика аудита SCRUM-809): WORST 1.92%
  (ui_btn_skill_points), остальные 0.00–1.58% — AC <5% на всех 8 текстурах.
- Визуальная сверка превью class_select: ярко-золотой кант → тёмная латунь,
  читаемость сохранена, в арт-дирекции SCRUM-806/809.
- Worktree от origin/dev, cold --import: meta_skill_tree_smoke_test PASSED,
  ui_no_overlap_matrix_test PASSED.
