# Зачистка осиротевших UI-фреймов и тулов после атлас-миграции

Jira: SCRUM-891
Статус: done
Контур: Claude
Owner: claude-busy-taussig-7e019f (user-directed chat)
Thread: current Claude worker
Worktree: .claude/worktrees/busy-taussig-7e019f
Branch: claude/suspicious-tu-f7448c
Locked paths: assets/sprites/ui/frames/{overhaul_2k,level_up_scrum682,settings_v6,codex_pl}; scripts/ui/ui_theme_paths.gd; scripts/ui_screens.gd (только мёртвые *_2K константы); tests/ui_theme_paths_existence_test.gd; tests/ui_no_overlap_matrix_test.gd (только мёртвые константы); tools/capture_settings_v6.gd; tools/build_ui_2k_frame_kit.py; tools/generate_settings_v6_openai.py; tools/recolor_yellow_buttons_brass.py

## Что/Зачем

После перевода всех экранов на атлас-стиль (SCRUM-879..888, влито в origin/dev)
в репозитории остались осиротевшие ассеты старых UI-китов и их записи в коде.
Задача: удалить их вместе с `.import`-сайдкарами, проверив КАЖДЫЙ файл grep-ом
на 0 ссылок в `scripts/ tests/ tools/`, и вычистить мёртвые записи словарей,
констант и генераторов. Живые ассеты не трогать.

## Текущее состояние (аудит 2026-07-08)

- Экраны level-up/settings/codex/hero-select/меню/магазины на атласе
  (`_atlas_chip_style` и родня); старые киты держатся только словарями
  `UIThemePaths`, оффлайн-генераторами в `tools/` и мёртвыми константами.
- Живые исключения проверены grep-ом: `pd_panel`+`stat_tooltip`
  (pause_stats_menu.gd + runtime_smoke), `lut_toast` (level_up_toast.gd),
  `chud_resource_panel/chud_timer/chud_artifact_row` (route_map_screen.gd +
  dark_fantasy_ui_theme_test читает словарь по этим ключам), `cr_panel/cr_btn`,
  `rc_panel/rc_btn`, `fb_panel`, `ctb_big/ctb_small` (ui_screens.gd),
  фоны `ui_backdrop_settings.png` и `codex_pl_backdrop.png`
  (SCREEN_BACKGROUND_PATHS в scripts/main.gd:90-91), иконки `codex_pl_icon_*`
  и полевые элементы settings_v6 (поля/чекбоксы/слайдеры/медальон/стрелка/чипы).

## Шаги

1. Удалить осиротевшие png+`.png.import`:
   - `overhaul_2k` (36): attr_panel, codex_back_btn, codex_detail,
     codex_entry_card, codex_list, codex_main, codex_nav, codex_tab_btn,
     evt_card, evt_panel, fb_btn_cancel, fb_btn_send, gt_panel, hs4_asc_btn,
     hs4_carousel_panel, hs4_choose_btn, hs4_dossier_panel, hs4_portrait_panel,
     hs4_radar_panel, level_up_card, level_up_panel, mm_btn, pd_btn, pm_btn,
     pm_panel, pn_panel, qc_btn, qc_modal, qc_panel, result_panel, st_panel,
     upgrade_panel, vbn_frame, ws_btn_back, ws_card, ws_panel.
   - `level_up_scrum682` (12, каталог целиком): ui_frame_lu682_*,
     ui_btn_lu682_later*, ui_badge_lu_best_*.
   - `settings_v6` (12): modal_frame, content_inset, tab_active/hover/inactive,
     btn_neutral_normal/hover/pressed/disabled,
     btn_primary_normal/hover/pressed/disabled.
   - `codex_pl` (14): панельные main_shell/nav_panel/grid_panel/detail_panel/
     entry_card/category_button/back_button в корне и весь каталог `fit/`.
   - `tools/capture_settings_v6.gd` + `.uid` (ссылается на удалённые узлы
     SettingsV2Modal).
2. Вычистить мёртвые записи кода:
   - `ui_theme_paths.gd`: LEVEL_UP_SCRUM682_FRAME_DIR/_PATHS целиком; из
     OVERHAUL_2K_FRAME_PATHS/_SOURCE_SIZE/_TEXTURE_MARGINS/_CONTENT — слоты
     удаляемых фреймов (27 ключей).
   - `tests/ui_theme_paths_existence_test.gd`: проверку
     LEVEL_UP_SCRUM682_FRAME_PATHS.
   - `tests/ui_no_overlap_matrix_test.gd`: мёртвые константы
     EVT_CARD_2K_FRAME_PATH, PN_PANEL_2K_FRAME_PATH.
   - `scripts/ui_screens.gd`: мёртвые Rect2-константы *_2K (аудит .gd-only,
     объявление = единственное упоминание) + рудименты "pm_btn"/"ws_btn_back"
     в списке уникальных кнопок.
   - `tools/build_ui_2k_frame_kit.py`: SLOTS-записи удаляемых slug-ов.
   - `tools/generate_settings_v6_openai.py`: SPEC/derive-записи удаляемых
     элементов.
   - `tools/recolor_yellow_buttons_brass.py`: lu682-пути.
3. Контроль: повторный grep каждого удалённого стема по scripts/ tests/ tools/
   = 0 ссылок.
4. Тесты (godot_gate, последовательно): ui_theme_paths_existence,
   runtime_smoke_test, ui_no_overlap_matrix_test — зелёные.
5. Коммит явным git add, push в origin/dev, Jira → Контроль качества
   с evidence (список удалённого + освобождённое место).

## Acceptance Criteria

- [x] Каждый удалённый файл имел 0 ссылок в scripts/ tests/ tools/ на момент
      удаления (после вычистки словарей/генераторов); `.import` удалены парно.
- [x] Живые ассеты не тронуты: pd_panel, stat_tooltip, lut_toast, chud_*,
      cr_*, rc_*, fb_panel, ctb_*, фоны settings/codex, иконки codex_pl,
      полевые элементы settings_v6.
- [x] `runtime_smoke_test.gd` PASSED, `ui_no_overlap_matrix_test.gd` PASSED
      (+ `ui_theme_paths_existence_test.gd` PASSED,
      `dark_fantasy_ui_theme_test.gd` PASSED).
- [x] Изменения влиты в origin/dev, Jira-тикет в «Контроль качества»
      с evidence и размером освобождённого места.

## Result

Done 2026-07-08 by claude-busy-taussig-7e019f (ожидает QA-вердикта).
Удалено 152 файла (76 ассетов/тулов + 76 сайдкаров `.import`/`.uid`), ~3.5 MB:
- overhaul_2k: 36 png (attr/codex_×7/evt_×2/fb_btn_×2/gt/hs4_×6/level_up_×2/
  mm/pd_btn/pm_×2/pn/qc_×3/result/st/upgrade/vbn/ws_×3); живые 13 остались.
- level_up_scrum682: каталог целиком (12 png).
- settings_v6: 12 png (modal_frame/content_inset/tab_×3/btn_neutral_×4/btn_primary_×4);
  полевые элементы живы.
- codex_pl: 7 панельных png в корне + весь fit/ (7 png); иконки и backdrop живы.
- tools/capture_settings_v6.gd (+.uid).
Код: ui_theme_paths.gd −138 строк (словарь lu682 + 32 мёртвых слота @2K),
ui_screens.gd −106 мёртвых *_2K констант + рудимент "pm_btn"/"ws_btn_back",
pause_stats_menu.gd −PD_BTN_2K, existence-тест без lu682-проверки, матрица без
мёртвых EVT_CARD/PN_PANEL констант, build_ui_2k_frame_kit.py −34 SLOTS-записи
(4 живых слота переведены на "const": None), generate_settings_v6_openai.py
−5 SPEC/derive-блоков, recolor_yellow_buttons_brass.py −4 lu682-цели.
Контроль: per-stem grep по scripts/ tests/ tools/ = 0 для всех 76 файлов.
Tests: ui_theme_paths_existence PASSED, runtime_smoke PASSED,
ui_no_overlap_matrix PASSED, dark_fantasy_ui_theme PASSED (godot_gate, 4.7).

## Files

assets/sprites/ui/frames/overhaul_2k/*, assets/sprites/ui/frames/level_up_scrum682/*,
assets/sprites/ui/frames/settings_v6/*, assets/sprites/ui/frames/codex_pl/*,
scripts/ui/ui_theme_paths.gd, scripts/ui_screens.gd,
tests/ui_theme_paths_existence_test.gd, tests/ui_no_overlap_matrix_test.gd,
tools/capture_settings_v6.gd(.uid), tools/build_ui_2k_frame_kit.py,
tools/generate_settings_v6_openai.py, tools/recolor_yellow_buttons_brass.py
