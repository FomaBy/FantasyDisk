# Настройки: золотые рамки полей и кнопок → кожа с латунным кантом

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
самая яркая живая золотая рамка в игре — поля настроек v4.
Арт-дирекция SCRUM-806 reopen: тёмная кожа + тонкая латунная линия (референс
`assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`), либо без рамки.

Затронутые текстуры:

- `assets/sprites/ui/frames/settings_v4/ui_frame_settings_v4_field.png` —
  ярко-золотая орнаментальная рамка (bright 37.0%). Все поля-дропдауны и биндинги:
  SettingsScreenOption, SettingsResolutionOption, SettingsWindowModeOption,
  SettingsAimModeOption, BindingButton_*.
- `assets/sprites/ui/frames/settings_v4/ui_frame_settings_v4_action_button.png` —
  золотой кант + уголки (bright 18.4%). Кнопки SettingsApplyButton,
  SettingsRevertButton, SettingsBackButton, SettingsResetAudioButton,
  SettingsResetBindingsButton.
- `assets/sprites/ui/frames/settings_v3/ui_frame_settings_v3_tab_switcher.png` —
  тёплый золотисто-бронзовый рант арт-плашки за табами (bright 12.3%).

Код:

- `scripts/ui_screens.gd` `_settings_v3_button_style` (~8308): маршрутизация по ТОЧНЫМ
  именам нод на SETTINGS_V4_FIELD_PATH / SETTINGS_V4_ACTION_BUTTON_PATH
  (константы ~127–129: SETTINGS_V4_FRAME_DIR и пути; margins/content — SETTINGS_V4_*
  константы рядом), per-state тинты SETTINGS_V3_BTN_STATE_TINTS.
- `scripts/ui_screens.gd` ~4217: `_global_texture_style(SETTINGS_V3_TAB_SWITCHER_PATH, ...)`.
- История стиля: `docs/design/settings_v4_audit.md`, `settings_v4_concept.md`,
  `settings_v4_reference_principles.md` (SCRUM-805) — новый рестайл должен объяснить
  отход от v4-концепта ссылкой на PM-курс SCRUM-806/809.

## Что сделать

1. Скрин-капчи «до» экрана настроек (вкладки: экран/аудио/управление, состояние ховера
   поля) в `build/qa/` (Godot через `tools/godot_gate.py`).
2. Ассеты `settings_v4/ui_frame_settings_v4_field.png` и `..._action_button.png`
   перерисовать в кожу+латунь: тёмная кожаная подложка, тонкая латунная линия,
   БЕЗ орнаментальных золотых уголков. Варианты: (а) PIL-перекраска по hue-маске
   существующих PNG (предпочтительно, если рамка читаема после затемнения), (б) генерация новой
   пары через pixellab `create_ui_asset` (омить elements для full-bleed 9-slice,
   «no text») с последующим alpha-cleanup при запечённом фоне (memory
   alpha-flood-fill-fix-baked-bg). Размер PNG сохранить = margins/`.import` не трогаем;
   при новом размере — синхронно обновить SETTINGS_V4_*_MARGINS/CONTENT в ui_screens.gd.
3. `settings_v3_tab_switcher.png` — приглушить золотой рант в латунь (PIL hue-маска).
4. Проверить контраст: состояние hover/focus полей должно оставаться различимым
   (tint-стейты SETTINGS_V3_BTN_STATE_TINTS дают подсветку — латунный кант обязан
   читаться на тёмном фоне модалки).
5. Пиксель-скан bright < 5% по трём текстурам; капчи «после»; smoke UI-тестов
   (есть settings-тесты в `tests/` — прогнать через гейт).

## Acceptance Criteria

- [ ] Поля и action-кнопки настроек без ярко-золотой рамки: кожа + тонкая латунь,
      визуально в семье с cluster_bg (капча-сверка).
- [ ] Ховер/фокус полей различимы (капчи стейтов до/после).
- [ ] Контент (текст полей, стрелки дропдаунов) в safe-area, не на канте
      (frame-content-safe-area).
- [ ] Пиксель-скан bright < 5% на всех 3 текстурах.
- [ ] Капчи до/после в `build/qa/`.
- [ ] Settings smoke-тесты зелёные; margins/.import консистентны (без осиротевших правок).

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 3».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Контекст v4: SCRUM-805 (`docs/design/settings_v4_*.md`).

## Прогресс (2026-07-02)

- Перекраска tools/recolor_settings_brass.py (hue 25–70° sat≥0.25 val≥0.30 → латунь 34°,
  val 0.16–0.58): field 5966px, action_button 4018px, v3 tab_switcher 4853px;
  размеры/альфа/имена 1:1, .import/margins нетронуты.
- Скан методики аудита: bright 37.0→3.4% (field), 18.4→0.4% (action), 12.3→1.8% (tab) — AC <5%.
- Hover/focus: state-тинты 1.16/1.20 поверх латуни различимы (капчи вкладок).
- Капчи до/после: docs/design/previews/scrum819/ (до — старый локальный лейаут,
  после — актуальный 805-лейаут из origin с латунью; предупреждение: тёплый .godot-кэш
  основной папки маскирует замену PNG — «после» снималось в worktree после cold --import).
- Тесты в worktree от origin/dev + cherry-pick: game_settings_smoke PASSED,
  video_settings_apply PASSED, aim_mode_settings PASSED, ui_no_overlap_matrix PASSED.
- Коммит ассетов: e43c6465 (+ docs-коммит следом), оба в origin/dev.
