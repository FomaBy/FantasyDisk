# Аудит жёлтых/золотых рамок UI — июль 2026 (SCRUM-809)

Дата: 2026-07-02
Тикет: SCRUM-809 (read-only аудит + план волны)
Арт-дирекция: SCRUM-806 reopen — вместо ярко-жёлтых рамок тёмная кожаная подложка
с тонкой латунной линией (`assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`,
применение — `_hud_v2_cluster_style`/`_timer_panel_style` в `scripts/ui_screens.gd`),
либо вовсе без рамки (референс — голый ряд эмблем возвышения AscensionHudRow).

## Методика

1. Инвентаризация текстур: `assets/sprites/ui/**` (649 PNG), карта путей
   `scripts/ui/ui_theme_paths.gd`, прямые константы в `scripts/ui_screens.gd`,
   `scripts/pause_stats_menu.gd`, `scripts/route_map_screen.gd`, `scripts/ui/shop_ui_constants.gd`.
2. Пиксельный скан (python3+PIL): доля ярко-жёлтых пикселей (hue 30–68°, sat ≥ 0.42,
   val ≥ 0.52) среди непрозрачных пикселей краевой полосы (внешние 15% каждой стороны) —
   там живёт кольцо рамки. Отдельно считалась «латунная» доля (та же hue, val 0.28–0.52).
3. Калибровка метрики: одобренная кожаная подложка `ui_hud_v2_cluster_bg.png` = **0.0%**
   ярко-жёлтого; известный жёлтый референс `ui_frame_2k_chud_timer.png` (уже выведен из
   HUD в SCRUM-806) = **28.9%**. Порог «жёлтая рамка» ≥ ~10–15% с обязательной визуальной
   верификацией каждого кандидата (все ключевые текстуры просмотрены глазами).
4. Трассировка использования: grep стилевых хелперов (`_overhaul_2k_frame_style`,
   `_global_texture_style`, `_minimal_frame_style`, `_button_state_style`,
   `_apply_overhaul_2k_button_theme` и др.) до конкретных экранов/нод.

⚠️ Осознанное отступление от AC: скрин-капчи «до» по экранам НЕ сняты — Godot-гейт на
момент аудита занят исполнителем SCRUM-808 (запуск параллельного headless Godot душит
чужие прогоны, см. memory godot-single-instance-exit144). Капча «до/после» перенесена
в каждую задачу волны как обязательный шаг.

## Главный вывод

Жёлтые рамки в игре — это не отдельные ассеты, а **три системные семьи + две локальные**:

1. **Семья minimal_metal** (`frames/minimal_metal/`): тёмный уголь с тонким
   ярко-жёлто-оранжевым кантом. Скан занижает её (кант тонкий: 3.7–11.1%), но визуально
   кант ярко-жёлтый на всех 6 фреймах. Это самая массовая семья: экономика, награды,
   пауза-досье, боевой чип-худ персонажа, межбоевой ресурс-HUD.
2. **Семья overhaul_2k «жёлтая линия + уголки»** (`frames/overhaul_2k/`, рисуются
   генератором `tools/build_ui_2k_frame_kit.py`): тёмное тело + яркая жёлтая линия по
   периметру с угловыми скобками (11–45%). Живые: ws_card, ctb_big, vbn_frame, gt_panel,
   chud_resource_panel. Большие панели той же семьи (pm/result/evt/ws/pd/pn/attr/upgrade)
   уже тёмные (3–7%) — их не трогаем.
3. **Семья skill_tree «оранжевое дерево + золото»** (`skill_tree/`): рамки панелей путей,
   селектор класса, попап бонусов, плашка «ОЧКИ» — тёплый оранжево-золотой стиль (10–18%).
4. **Settings v4** (`frames/settings_v4/`): ярко-золотая орнаментальная рамка полей (37%)
   и золотой кант action-кнопок (18%) — самые «золотые» живые рамки в игре.
5. **Жёлтые кнопки**: FAB докачки и utility-кнопки (`frames/minimal_metal_buttons/`,
   100% жёлтая обводка), кнопка «Позже» level-up (`frames/level_up_scrum682/`, 40%).

## Таблица живых жёлтых рамок: текстура → хелпер → экраны → решение

Решения: (а) = заменить на кожаную подложку/латунный кант в стиле combat_hud_v2,
(б) = убрать рамку, (в) = оставить (с обоснованием).
«bright%» — доля ярко-жёлтых пикселей в краевой полосе по скану.

### Семья minimal_metal (жёлтый кант) — волна 1

| Текстура | bright% | Хелпер/константа (scripts/ui_screens.gd) | Экраны/ноды | Решение |
|---|---|---|---|---|
| `minimal_metal/ui_frame_minimal_metal_card.png` | 7.6 (кант жёлтый) | `_reward_card_style` (REWARD_*_CARD_PATH), `_economy_choice_style` (ECONOMY_CHOICE_CARD_PATH), `_card_hover_style`, `_character_card_style` | карты наград (обычные+элитные), карты выбора экономики (событие/отдых/докачка/атрибуты AttributeOffer_*) | (а) перекрасить кант в латунь |
| `minimal_metal/ui_frame_minimal_metal_panel.png` | 3.7 (кант жёлтый) | `_panel_style`, `_economy_panel_style`, `_minimal_frame_style("panel")`, ECONOMY_PANEL_PATH; preload в `pause_stats_menu.gd` (ESCAPE_PANEL_FRAME, STAT_GROUP_FRAME) | генерик-панели меню (`_create_menu_box`), панели экономики, группы статов в паузе-досье | (а) |
| `minimal_metal/ui_frame_minimal_metal_field.png` | 10.6 | `_hud_card_style` (COMBAT_HUD_CARD_PATHS hp/xp/money/ult), `_character_stats_hud_style`, ECONOMY_PRICE_BADGE_PATH, CODEX_PORTRAIT_SLOT_PATH (`_codex_portrait_slot_style`); preload в `pause_stats_menu.gd` (STAT_BASIC_ROW_FRAME, STAT_CHIP_FRAME) | чипы CharacterStatsHud (БОЙ!), карточки межбоевого ресурс-HUD, ценники экономики, слот портрета кодекса, строки/чипы статов паузы | (а) — приоритет: единственный жёлтый остаток в боевом HUD |
| `minimal_metal/ui_frame_minimal_metal_tooltip.png` | 11.1 | ECONOMY_TOOLTIP_PATH, CODEX_TOOLTIP_PATH, GLOBAL_TOOLTIP_FRAME_PATH | тултипы экономики/кодекса | (а) |
| `minimal_metal/ui_frame_minimal_metal_modal.png` | 3.5 (кант жёлтый) | `_minimal_frame_style("modal")`; preload PAUSE_END_MODAL_FRAME в `pause_stats_menu.gd` (fallback) | модалка конца забега (fallback, основная — result_panel 2k) | (а) заодно с семьёй |
| `minimal_metal/ui_frame_minimal_metal_hud_strip.png` | 8.6 | только запись в карте `_minimal_frame_style` ("hud_strip"), живых вызовов нет | — | (б)/не трогать — де-факто мёртвая |

### Семья overhaul_2k «жёлтая линия + уголки» — волна 2

| Текстура | bright% | Хелпер | Экраны/ноды | Решение |
|---|---|---|---|---|
| `overhaul_2k/ui_frame_2k_ctb_big.png` | 37.5 | `_show_combat_title_banner` → `_overhaul_2k_frame_style("ctb_big")` | боевой интро-баннер босса (CombatIntroBanner) | (а) тонкая латунная линия вместо жёлтой |
| `overhaul_2k/ui_frame_2k_ctb_small.png` | 1.0 (латунь 43.2) | там же ("ctb_small") | интро-баннер элитки | (в)/выровнять заодно — линия уже латунная, но выровнять палитру с ctb_big |
| `overhaul_2k/ui_frame_2k_vbn_frame.png` | 11.1 | `_overhaul_2k_frame_style("vbn_frame")` | баннер победы (VictoryBanner) | (а) |
| `overhaul_2k/ui_frame_2k_ws_card.png` | 15.0 | `_overhaul_2k_frame_style("ws_card")` ×5 стейтов | строки-карточки выбора оружия | (а) |
| `overhaul_2k/ui_frame_2k_gt_panel.png` | 22.0 | `_overhaul_2k_frame_style("gt_panel")` | тултип глоссария (кодекс) | (а) |
| `overhaul_2k/ui_frame_2k_chud_resource_panel.png` | 22.4 | `_hud_panel_style` | межбоевой ресурс-HUD (`_create_menu_run_hud`), шапка route map (`route_map_screen.gd:96`) | (а) — предпочтительно вообще перевести на `_hud_v2_cluster_style` (унификация с боевым HUD, ассет уже есть) |

### Settings — волна 3

| Текстура | bright% | Хелпер | Экраны/ноды | Решение |
|---|---|---|---|---|
| `settings_v4/ui_frame_settings_v4_field.png` | 37.0 | `_settings_v3_button_style` (is_field: SettingsScreenOption/SettingsResolutionOption/SettingsWindowModeOption/SettingsAimModeOption/BindingButton_*) | ВСЕ поля-дропдауны и кнопки биндингов настроек | (а) — самая яркая золотая рамка в живом UI |
| `settings_v4/ui_frame_settings_v4_action_button.png` | 18.4 | `_settings_v3_button_style` (is_action: Apply/Revert/Back/ResetAudio/ResetBindings) | action-кнопки настроек | (а) |
| `settings_v3/ui_frame_settings_v3_tab_switcher.png` | 12.3 | прямой вызов `_global_texture_style(SETTINGS_V3_TAB_SWITCHER_PATH, ...)` (арт-плашка за табами) | переключатель вкладок настроек | (а) приглушить рант в латунь |

### Skill tree (оранжево-золотая семья) — волна 4

| Текстура | bright% | Хелпер | Экраны/ноды | Решение |
|---|---|---|---|---|
| `skill_tree/ui_frame_skill_tree_class_select.png` | 14.5 | `_skill_tree_class_select_style` | селектор класса «КЛАСС» | (а) |
| `skill_tree/ui_frame_skill_tree_class_popup.png` | 12.2 | `_skill_tree_class_popup_style` | попап «БОНУСЫ КЛАССА» | (а) |
| `skill_tree/ui_btn_skill_points.png` | 18.3 | `_skill_tree_points_button_style` | плашка «ОЧКИ» | (а) |
| `skill_tree/ui_frame_skill_tree_path_wealth/lore/might/endure.png` | 9.8–17.7 | SKILL_TREE_PATH_* | панели путей дерева | (а) приглушить рамы в тёмное дерево/латунь |
| `skill_tree/ui_frame_skill_tree_main.png` | 10.1 | `_skill_tree_main_panel_style` | главная панель дерева | (а) заодно |
| `skill_tree/node_keystone_allocated.png` | 37.0 | PROGRESSION_NODE_TEXTURES ("keystone"/"purchased") | медальон купленного кистоуна | **(в) оставить** — золото здесь семантика «вложенных очков» (стейт-фидбек, не рамка); эмблема в пиксель-стиле эмблем возвышения |

### Кнопки и level-up — волна 5

| Текстура | bright% | Хелпер | Экраны/ноды | Решение |
|---|---|---|---|---|
| `minimal_metal_buttons/ui_btn_minimal_metal_fab*.png` (4 стейта) | 95–100 | `_button_state_style` → `_button_asset_type`="fab" (UpgradeFabButton) | FAB «⬆» докачки в забеге | (а) тёмная кожа + латунь; жёлтым оставить только иконку-стрелку при желании |
| `minimal_metal_buttons/ui_btn_minimal_metal_utility*.png` (4 стейта) | 100 | `_button_state_style` → "utility" (кнопки ≤64px: SkillTreeZoomIn/OutButton и любые мелкие фоллбеки) | зум «+»/«−» скилл-три и мелкие кнопки | (а) |
| `level_up_scrum682/ui_btn_lu682_later.png` (+`_hover`/`_pressed`) | 40.3/40.9 | `_apply_level_up_later_button_theme` | кнопка «Позже» на level-up | (а) перекрасить золотой кант в латунь |
| `level_up_scrum682/ui_frame_lu682_portrait.png` | 24.1 | `_level_up_portrait_style` | кольцо портрета level-up | (а) кольцо в тёмную латунь |
| `level_up_scrum682/ui_frame_lu682_card_hover.png` | 17.3 | `_level_up_scrum682_style` (hover карты) | ховер карты level-up | (в)/приглушить — ховер-фидбек допустим, но светло-кремовый ореол лучше свести к латуни; решить в задаче |
| `frames/combat_hud/ui_btn_combat_level_up_plus*.png` | 11.2–11.4 | `_button_state_style` → "combat_level_up_plus" (LevelUpPlusButton) | кнопка «+» уровня в боевом HUD | (в)/пограничная — рамка тёмно-золотая тонкая; включить в задачу как опцию |

### Оставить как есть (не рамки / семантика золота)

| Ассет | Причина |
|---|---|
| `hud/combat_hud_v2/ui_hud_v2_icon_money.png`, `ui_hud_v2_icon_ascension.png`, `ui_hud_v2_icon_timer.png` | пиксель-иконки, золото = валюта/возвышение, принято в SCRUM-806 |
| `hud/combat_hud/ui_hud_bar_fill_gold.png`, `ui_hud_gold_medallion.png` | заливка полосы золота и медальон-монета: золото = валюта |
| `shop/ui_shop_caption_plate.png` | тёмная латунь + пергамент — уже соответствует направлению |
| `skill_tree/node_keystone_allocated.png` и золотые стейты узлов | семантика «куплено/доступно», не рамка |
| `result_crests/ui_crest_victory.png`, `menu_title/*`, `cursor/game_cursor*` | арт-объекты (гербы, тайтлы, курсор), не UI-рамки |
| `icons/shop/*`, `icons/artifacts/*` | иконки товаров/артефактов |
| `frames/text_buttons_unique/*` | тёмные плиты с латунным рантом (0–1.2%) — уже в стиле |
| `frames/hero_select_pixellab/*`, `frames/codex_pl/*` | новые pixel-art паки, тёмные (0–9%) |

### Мёртвые жёлтые ассеты (кодом не используются — в волну НЕ входят)

Найдены жёлтыми, но без живых ссылок; кандидаты на отдельную задачу-чистку каталогов,
перерисовка не нужна: `overhaul_2k/ui_frame_2k_chud_timer.png` (28.9, выведен SCRUM-806),
`chud_artifact_row` (25.7), `hs4_asc_btn`/`hs4_choose_btn` (28.0/25.7, HS4 переехал на
hero_select_pixellab), `fb_btn_send`/`fb_btn_cancel` (43.7/45.2), `pm_btn`/`pd_btn`/
`ws_btn_back` (42.3), `qc_btn` (40.3), `cr_btn`/`rc_btn` (39.2) — все эти btn-слоты
перехватываются `_apply_overhaul_2k_button_theme` → text_buttons_unique и фактически не
рендерятся; `mm_btn` (23.8), `codex_entry_card` (24.5) и весь codex_* 2k-набор (кодекс на
codex_pl), `st_panel` (14.6), `lut_toast` (0 живых ссылок — сам ассет тёмный);
каталоги целиком без ссылок из кода: `frames/red_gold/` (весь, вкл. hover 29.5),
`frames/ornate/` (pause_stat_chip 28.1), `frames/dark_fantasy/` (divider 79.5,
stat_row 38.9), `buttons_minimalist/` (btn_hover 39.1), `frames/codex_glossary/` (кнопки
cg_*), `hud/timer_frame*.png` (24.9), `frames/hero_select*/` (v1/v2/v3),
`icons/system/ui_scrollbar_grabber.png` (56.7)/`ui_slider_track.png` (44.8) — константа
объявлена, вызовов нет; неиспользуемые типы `minimal_metal_buttons/*` (fab/utility живые —
см. волну 5, остальные типы достижимы только редким фоллбеком `_button_state_style` у
кнопок без unique-id — фоллбек чинится в волне 5).

## Волна задач (спеки созданы этим аудитом)

| # | Спека | Объём |
|---|---|---|
| 1 | `docs/tasks/minimal_metal_recolor_leather_brass_task.md` | перекраска канта семьи minimal_metal (5 текстур) — экономика/награды/пауза/чип-HUD |
| 2 | `docs/tasks/overhaul_2k_kit_brass_line_task.md` | палитра генератора build_ui_2k_frame_kit.py + перегенерация 6 живых слотов; перевод межбоевого HUD на cluster-стиль |
| 3 | `docs/tasks/settings_gold_frames_restyle_task.md` | settings v4 field/action + v3 tab_switcher → кожа+латунь |
| 4 | `docs/tasks/skill_tree_warm_frames_restyle_task.md` | скилл-три: селектор/попап/ОЧКИ/панели путей/главная рама |
| 5 | `docs/tasks/yellow_buttons_levelup_accents_task.md` | FAB+utility кнопки, «Позже»/портрет/ховер level-up, опц. «+» боевого HUD |

Порядок: 1 и 2 — наибольшая площадь (экономика+боевые баннеры+HUD), потом 3 (самая яркая
золотая рамка), 4–5 — добивка. Все задачи независимы по файлам и параллелизуемы, кроме
пересечения волны 2 и 5 по `scripts/ui_screens.gd` (разные функции, но один файл — мерджить
аккуратно или последовательно).

## Замечания по safe-area

Все замены обязаны сохранять существующие 9-slice margins и content-инсеты
(`UIThemePaths.*_MARGINS/_CONTENT`, `OVERHAUL_2K_FRAME_TEXTURE_MARGINS/CONTENT`) либо
обновлять их синхронно с ассетом: контент должен оставаться в пустой зоне фрейма, не на
орнаменте (глобальное правило frame-content-safe-area, AGENTS.md + qa_protocol).
Перекраска БЕЗ изменения размера PNG не требует переимпорта-миграций (.import остаются
валидными) — предпочтительный метод для волн 1, 4, 5.
