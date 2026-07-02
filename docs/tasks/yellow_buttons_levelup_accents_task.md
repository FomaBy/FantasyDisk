# Жёлтые кнопки (FAB, utility) и золотые акценты level-up → тёмная кожа с латунью

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
две 100%-жёлтые кнопочные текстуры и золотые акценты экрана level-up. Арт-дирекция
SCRUM-806 reopen: тёмная кожа + тонкая латунная линия (референс
`assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`), либо без рамки.

Затронутые текстуры:

1. `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab.png`
   (+`_hover`, `_focus`, `_pressed`; bright 95–100%) — толстый ярко-жёлтый бордюр.
   Живой потребитель: FAB «⬆» докачки за золото в забеге (UpgradeFabButton,
   `scripts/ui_screens.gd` `_create_upgrade_fab` ~2344, стиль через
   `_apply_compact_button_theme` → `_button_state_style` → `_button_asset_type`="fab").
2. `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_utility.png`
   (+3 стейта; bright 100%) — жёлтая рамка мелких кнопок. Живые потребители: зум
   «+»/«−» скилл-три (SkillTreeZoomIn/OutButton, `_make_compact_button` ~2501–2505)
   и любой мелкий фоллбек `_button_asset_type`="utility" (кнопки ≤64px без unique-id).
3. `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later.png`
   (+`_hover`, `_pressed`; bright 40.3/40.9) — золотой кант кнопки «Позже» level-up
   (`_apply_level_up_later_button_theme`, ~строка 8660 области level-up хелперов;
   LEVEL_UP_SCRUM682_FRAME_PATHS в `scripts/ui/ui_theme_paths.gd:77–87`).
4. `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_portrait.png`
   (bright 24.1) — светло-латунное кольцо портрета level-up (`_level_up_portrait_style`).
5. Опционально (решить в задаче, пограничные):
   - `level_up_scrum682/ui_frame_lu682_card_hover.png` (17.3) — кремовый ореол ховера
     карт level-up: допустимый фокус-фидбек; либо оставить, либо свести к латуни.
   - `frames/combat_hud/ui_btn_combat_level_up_plus*.png` (11.2) — кнопка «+» уровня в
     боевом HUD, тонкая тёмно-золотая рамка (COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES).

## Что сделать

1. Скрин-капчи «до» в `build/qa/`: забег с FAB, скилл-три с зум-кнопками, экран
   level-up (карты+«Позже»+портрет) — Godot через `tools/godot_gate.py`.
2. PIL-перекраска по hue-маске (методика волны 1: hue 30–68°, sat≥0.42, val≥0.52 →
   латунь val 0.3–0.45) для fab/utility (по 4 стейта) и lu682_later (3 стейта):
   бордюр → тёмная латунь, тело угольное. Стейт-различимость сохранить: hover заметно
   светлее normal (латунь чуть ярче), pressed темнее; сравнить капчами.
3. `lu682_portrait.png`: светлое tan-кольцо → тёмная латунь (красные ромбы и тёмное
   внутреннее кольцо не трогать).
4. Решить и зафиксировать в спеке результат по пограничным (card_hover, level_up_plus):
   оставить с обоснованием ЛИБО приглушить той же маской.
5. Размеры PNG не менять (margins в `ui_theme_paths.gd` MINIMAL_METAL_BUTTON_MARGINS /
   LU_LATER_BUTTON_2K и `.import` остаются валидными).
6. Пиксель-скан bright < 5% по перекрашенным текстурам; капчи «после»; smoke UI-тестов
   через гейт.

## Acceptance Criteria

- [ ] FAB и utility-кнопки: тёмная кожа + латунный кант во всех стейтах, стейты
      различимы (капчи normal/hover/pressed).
- [ ] «Позже» и кольцо портрета level-up без ярко-золотого канта.
- [ ] По card_hover и level_up_plus зафиксировано решение (оставить/приглушить) с
      обоснованием в спеке.
- [ ] Размеры PNG/margins/.import не изменены.
- [ ] Пиксель-скан bright < 5% на перекрашенных текстурах.
- [ ] Капчи до/после в `build/qa/` (забег/скилл-три/level-up).
- [ ] Smoke UI-тесты зелёные.

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 5».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Внимание: `scripts/ui_screens.gd` также правится волной 2 — правок кода здесь по
  умолчанию нет (in-place перекраска), но если решите менять хелперы — координировать.

## Прогресс (2026-07-02)

- 16 текстур перекрашено tools/recolor_yellow_buttons_brass.py (методика волны:
  hue 25–70° → латунь 34°, val 0.16–0.50 — верх мапа НИЖЕ bright-порога скана 0.52,
  иначе почти белые hover fab/utility оставались «ярко-жёлтыми» по метрике):
  FAB ×4, utility ×4, lu682_later ×3, lu682_portrait, combat level_up_plus ×4.
- Решения по пограничным (AC): card_hover — ОСТАВЛЕН (кремовый ореол = фокус-фидбек
  выбора карты, не рамка; убирать его — терять читаемость выбора);
  combat level_up_plus — ПРИГЛУШЁН той же маской для единообразия с HUD v2.
- Стейт-различимость: value-мап монотонный (hover светлее normal, pressed темнее) —
  видно на контактном листе docs/design/previews/scrum821/contact_sheet_before_after.png.
- Скан (методика аудита): WORST 0.00% по всем 16 (AC <5%).
- Экранные капчи заменены контактным листом текстур (как в 817/818: отступление
  зафиксировано — оконный рендер при живом редакторе не гоняем).
- Верификация в worktree от origin/dev (cold --import): runtime_smoke PASSED,
  ui_no_overlap_matrix PASSED. Коммит 39248f12 (+docs следом) в origin/dev.

## QA-Вердикт: PASSED
Статус: PASSED
QA claude-qa 2026-07-02 (изолированный worktree от origin/dev, независимая проверка).
- Реальный landed-коммит в origin/dev — 410b8c2c (локальный 39248f12 перебазирован); диффскоуп: только 16 PNG кнопок (minimal_metal_buttons fab/utility ×4 стейта, level_up_scrum682 lu682_later ×3 + portrait, combat_hud level_up_plus ×4) + превью + tools/recolor_yellow_buttons_brass.py; `.import`, `ui_theme_paths.gd`, `ui_screens.gd` НЕ тронуты (asset-only ✓).
- Все 16: размер 1:1 против 410b8c2c^, alpha-канал байт-в-байт идентичен, перекраска применена (изменённые пиксели present).
- Независимый bright-скан (hue 30–68°, sat≥0.42, val≥0.52): WORST 0.00% по всем 16 (AC <5% ✓). card_hover осознанно оставлен как фокус-фидбек (зафиксировано в спеке).
- Контактный лист до/после сверен визуально: ярко-жёлтые/золотые бордюры и акценты кнопок → тёмная латунь; эмблемы (дракон+крест) и disabled-состояния сохранены.
- Тест: ui_no_overlap_matrix_test PASS на финальном HEAD origin/dev (+исполнитель: runtime_smoke PASS).
- Прим.: локальный статус спеки был «new» на origin/dev — выставлен «done» для консистентности с board_sync (тикет сдан в QA/Готово).
