# ART/UX: Настройки — единообразные 3 вкладки, красивый переключатель, единый стиль рамок/кнопок

Статус: review
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Связано: SCRUM-341 (свитчер 3 вкладки), SCRUM-329 (UI Overhaul меню/настройки), SCRUM-384 (единый фрейм), SCRUM-273 (базовые кнопки), SCRUM-318 (hover), SCRUM-275 (скролл «Управление»), SCRUM-324 (скилл)
Jira: SCRUM-391

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Изменить меню настроек: там 3 вкладки — все 3 должны быть ЕДИНООБРАЗНЫ; вкладки
переключаются через КРАСИВЫЙ интерфейс по референсу проекта; все рамки и кнопки
в настройках — в ЕДИНОМ стиле, исходящем из БАЗОВЫХ кнопок игры».

Настройки: ui_screens.gd `_show_settings_menu`, 3 вкладки `_make_settings_tab`
(«Экран»/«Звук»/«Управление»), переключатель `_make_settings_tab_switcher`
(SETTINGS_TAB_SWITCHER, чинится в SCRUM-341 до 3 слотов). Контролы: чекбоксы
(_style_checkbox), OptionButton (_apply_compact_button_theme), слайдеры (HSlider),
ряды ребайнда, кнопки сброса (_make_button). Скролл «Управление» — SCRUM-275.

## ОБЯЗАТЕЛЬНО — скилл + базовые кнопки/единый фрейм
Графику генерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG,
прозрачный фон) по референсам проекта. Стиль кнопок/рамок — **из БАЗОВЫХ кнопок
игры** (red_gold кит SCRUM-273) и единого фрейма (SCRUM-384, тонкий металл). Старое
— в бэкап. Биллинг OK.

## Требования
1. **3 вкладки единообразны**: одинаковая компоновка/отступы/типографика/выравнивание
   во всех трёх («Экран»/«Звук»/«Управление») — единый шаблон вкладки, ничего не
   «разъезжается» между ними.
2. **Красивый переключатель вкладок** по референсу проекта (координация с SCRUM-341:
   3 слота, без пустого 4-го): аккуратные таб-кнопки, читаемые состояния
   selected/hover/pressed (hover без жёлтого свечения, SCRUM-318); активная вкладка
   явно выделена.
3. **Единый стиль рамок и кнопок настроек, исходящий из базовых кнопок игры**:
   все кнопки (сброс, OptionButton, таб-кнопки, «Назад») и рамки/панели вкладок —
   на базовом button-ките (SCRUM-273) и едином фрейме (SCRUM-384). Чекбоксы/слайдеры
   стилизовать согласованно (единая палитра/металл).
4. Контент в content-зоне рамок (глоб. правило), no-overlap; скролл «Управление»
   (SCRUM-275) не сломать; настройки сохраняются/применяются как раньше.
5. Читаемость и единообразие на 1280×720 / 1920×1080 / 2560×1440.
6. Тест (smoke + no-overlap): настройки строятся; 3 единообразные вкладки;
   переключатель работает (selected/hover); кнопки/рамки в едином стиле; no-overlap.
   Скрин всех 3 вкладок в build/qa/.
7. CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_settings_menu; _make_settings_tab; _make_settings_tab_switcher;
  SETTINGS_TAB_SWITCHER_*; _settings_tab_button_style; _style_checkbox;
  _apply_compact_button_theme; _make_button; _unified_frame_style)
- assets/sprites/ui/ (таб-кнопки/рамки настроек, скиллом) + бэкап
- docs/design/references/ (база — Buttons/единый фрейм)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] 3 вкладки настроек единообразны (общий шаблон компоновки/типографики).
- [ ] Красивый переключатель вкладок по референсу (3 слота, selected/hover без жёлтого); активная вкладка выделена.
- [ ] Все рамки и кнопки настроек в едином стиле из базовых кнопок игры (SCRUM-273) + единый фрейм (SCRUM-384).
- [ ] Контент в content-зоне; no-overlap на 3 разрешениях; скролл/сохранение настроек целы; smoke зелёные; скрины 3 вкладок.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Progress Log
- 2026-06-14 — Took task in Design/Codex thread after SCRUM-369 review. Starting settings menu asset/style inventory; Design scope only, Back-end runtime layout/theme changes will be handed off if needed.
- 2026-06-14 — Generated a new 3-slot Settings tab switcher reference through
  `fantasydisk-asset-generator`:
  `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_reference.png`.
  The raw reference used a baked checkerboard background, so it was alpha-cleaned
  into `settings_tab_switcher_3slot_reference_alpha_clean.png`.
- 2026-06-14 — Created production candidate
  `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
  (`1280x256`, RGBA). Current active 4-slot asset was backed up to
  `build/qa/scrum391/ui_frame_settings_tab_switcher_4slot_backup.png`.
- 2026-06-14 — Recorded Design safe rects in
  `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_metadata.json`:
  `Rect2(160,88,270,82)`, `Rect2(506,88,270,82)`,
  `Rect2(852,88,270,82)`. Preview/contact:
  `docs/design/previews/settings_menu_3slot_switcher_safe_zone.png`,
  `docs/design/previews/settings_menu_unified_restyle_contact.png`.
- 2026-06-14 — Verification PASS: PNG RGBA/alpha validation and Godot import.
  Runtime settings integration needs Back-end because current
  `SETTINGS_TAB_SWITCHER_SAFE_RECTS` still contains four source rects.
- 2026-06-14 — Created Back-end handoff
  `docs/tasks/backend_settings_menu_unified_restyle_integration_task.md` with
  exact asset path, source size, safe rects and runtime acceptance criteria.

## Result
Design side готов к review. Новый production candidate решает визуальную часть:
переключатель настроек теперь имеет ровно 3 выразительные вкладки в red-gold /
dark steel D&D стиле, без пустого четвертого слота. Live runtime path не заменен
напрямую, потому что это требовало бы изменения `scripts/ui_screens.gd`; точный
Back-end handoff создан. До Back-end интеграции активная игра продолжает
использовать старый 4-slot switcher.
