# Скилл-три: оранжево-золотые рамки → тёмная кожа с латунью (селектор, попап, ОЧКИ, панели путей)

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
