# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈206) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked` | `done`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Feature Freeze

АКТИВЕН с 2026-06-13 для стабилизации `0.1.4`, но PM override пользователя:
**вся текущая board должна быть доделана в версии `0.1.4`**. Уже существующие
board-задачи раздаются/дожимаются до QA/release в текущем спринте. Новые
пожелания после этой директивы оформляются отдельно в backlog `0.1.5`, если PM
не решит иначе.

## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 22 | 0 | 0 | 0 | 22 |
| SCRUM-213 Бой, враги, боссы, события | 33 | 1 | 1 | 0 | 35 |
| SCRUM-214 Баланс и экономика | 15 | 3 | 0 | 0 | 18 |
| SCRUM-215 Интерфейс, экраны, локализация | 22 | 0 | 0 | 0 | 22 |
| SCRUM-216 Арт и спрайты | 35 | 3 | 0 | 0 | 38 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 33 | 2 | 4 | 0 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **206** | **9** | **6** | **0** | **221** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_hero_select_radar_out_of_frame_description_left_task.md](../tasks/bug_hero_select_radar_out_of_frame_description_left_task.md) | Back-end (UI) | done | Jira: SCRUM-231. **QA: passed** (f8f1409a) — радар = плавающий top-right виджет ВНЕ рамки досье (зазор 34px, тест ассертит parent=screen+anchor_right≥0.99), описание слева, no-overlap; визуал `build/qa/scrum231/hero_select_radar_fixed.png`. **Устраняет регрессию SCRUM-224** |
| [backend_ascension_per_level_changes_near_start_task.md](../tasks/backend_ascension_per_level_changes_near_start_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-230. PM override: текущая board закрывается в `0.1.4`; dispatch Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13, High/no-low. У кнопки старта показывать ТОЛЬКО изменение выбранного уровня возвышения (дельта, не кумулятив) |
| [design_codex_interface_leather_gold_panels_restyle_task.md](../tasks/design_codex_interface_leather_gold_panels_restyle_task.md) | Design → Back-end | done | Jira: SCRUM-229. **QA: passed** (35b79e06) — 5 рамок RGBA8, прозрачные углы (без checkerboard), целевые UI + 4×smoke зелёные, визуал в `build/qa/scrum229/` (выбор героя/настройки/меню): leather+gold панели + золотой чекбокс + кнопки-пергамент согласованы, перекрытий нет. Физ.удаление legacy → safe-cleanup flow |
| [backend_parchment_button_seal_visible_height_task.md](../tasks/backend_parchment_button_seal_visible_height_task.md) | Back-end (UI) | done | Jira: SCRUM-227. **QA: passed** (35b79e06) — печать-кнопки 68-76px (≥64), тест `_test_parchment_button_seal_sizes` мерит 4 экрана + ассертит компактные no-seal, 4×smoke+no-overlap зелёные, визуал `build/qa/scrum227/` (меню печать не сжата, level-up чистый) |
| [backend_levelup_cards_text_field_style_task.md](../tasks/backend_levelup_cards_text_field_style_task.md) | Back-end (UI) | done | Jira: SCRUM-226. **QA: passed** (35b79e06) — карточки = text-field (мета+StyleBoxFlat, не button-тема), клик применяет усиление, «Позже»/Escape defer, тест мерит 3 карточки/иконку/описание, 4×smoke+no-overlap зелёные, визуал `build/qa/scrum227/level_up.png` |
| [backend_weapon_select_sprite_clean_layout_task.md](../tasks/backend_weapon_select_sprite_clean_layout_task.md) | Back-end (UI) | done | Jira: SCRUM-225. **QA: passed** (35b79e06) — спрайты оружия + русские статы + flat-карточки, клик ставит selected_weapon_id (тест ассертит), 4×smoke+no-overlap зелёные, визуал `build/qa/scrum225/weapon_select.png` |
| [backend_hero_select_description_left_of_radar_task.md](../tasks/backend_hero_select_description_left_of_radar_task.md) | Back-end (UI) | done | Jira: SCRUM-224. **QA: FAILED** (35b79e06) → **устранено SCRUM-231** (QA passed f8f1409a). Исходно визуальная регрессия (роза внутри рамки); фикс вынес розу в top-right вне рамки — функционально закрыто |
| [codex_design_cursor_clawed_fire_task.md](../tasks/codex_design_cursor_clawed_fire_task.md) | Design (Codex) → Claude-Designer | done | Jira: SCRUM-223. **QA: passed** (1d772ee0) — 3 курсора 48×48 RGBA, hotspot (2,2) на остром кончике (alpha 0.63), мапинг arrow/hover/attack→3 PNG, превью 2-го варианта (когтистый огонь) подтверждён; UI-тесты+import зелёные |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | done | Jira: SCRUM-156. **QA: passed** (bb46e5b9, скоуп source-sprites) — 9 спрайтов 512×512 RGBA integral, прозрачный фон, канон/различимы (контакт-лист), animation+boss smoke зелёные. ⚠️ арт ещё НЕ в игре: мини-элитки на тинте сцен, новые PNG не подключены — нужен вайринг SCRUM-155 + cutout SCRUM-204 (QA перепроверит in-game после) |
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design | done | Jira: SCRUM-147. **QA: passed** (bb46e5b9) — финал button-only wax-seal: 12/12 button-состояний, primary 384×120 (печать помещается), 3 превью, theme/no-overlap зелёные; кросс-валидация 222/227/229. ChatGPT-сырьё — опц. follow-up, не блокер |
| [backend_ui_dark_fantasy_theme_integration_task.md](../tasks/backend_ui_dark_fantasy_theme_integration_task.md) | Back-end (UI theme integration) | done | Jira: SCRUM-222. **QA: passed** (e9aa3d3a) — theme/no-overlap/runtime smoke зелёные; заявленное падение runtime_smoke на reward-offer (line 1042) НЕ воспроизводится на HEAD. Найдена НЕсвязанная флака `melee_weapon_targeting_test` (~17%) → заведён баг |
| [epic_full_project_quality_pass.md](../tasks/epic_full_project_quality_pass.md) | PM/Coordination | in_progress | Зонтик: 6 аудитов (Фаза 1) → волна исправлений (Фаза 2). Правила коллизий и «done=HEAD зелёный» |
| [backend_test_runtime_smoke_suite_split_task.md](../tasks/backend_test_runtime_smoke_suite_split_task.md) | Back-end | done | Jira: SCRUM-202. **QA: passed** (35b79e06) — 5 focused-сьютов (extends+override `_initialize` с реальными `_test_*`) + umbrella все зелёные headless; регрессия зелёная; нефатальный lambda-warning у umbrella (exit 0, латентный, отложен) |
| [backend_refactor_class_weapon_mode_registry_task.md](../tasks/backend_refactor_class_weapon_mode_registry_task.md) | Back-end | done | Jira: SCRUM-196. **QA: passed** (1fbc20c6) — registry+API, 83 executor/39 `_fire_*` сохранены, coverage-тест ассертит mode→executor по всему ростеру, weapon/animation/targeting/umbrella/meta зелёные |
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-198. PM override: current board must finish in `0.1.4`; serialized Back-end queue after SCRUM-230, High/no-low; preserve balance/behavior and close Jira sync before next queued item |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-199. PM override: current board must finish in `0.1.4`; serialized Back-end queue after SCRUM-230 + SCRUM-198, High/no-low; no visual/gameplay changes, no animation scope |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | in_progress | Jira: SCRUM-193. PM override: current board must finish in `0.1.4`; serialized Back-end queue after SCRUM-230/198/199, High/no-low; safe cleanup only with backup/manifest checks |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | in_progress | Jira: SCRUM-195. PM override: current board must finish in `0.1.4`; final Back-end queue item after SCRUM-193 to refresh domain docs and close board/Jira sync |

## Баги от QA

| Баг | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_flaky_melee_targeting_hammer_aoe_cache_task.md](../tasks/bug_flaky_melee_targeting_hammer_aoe_cache_task.md) | Back-end | done | Jira: SCRUM-228. **QA: passed** (35b79e06) — анти-флака 25/25 PASS (было ~17%), `await process_frame` на месте, production-кэш `combat_target_query.gd` не тронут, регрессия 4×smoke зелёная |
| [bug_umbrella_runtime_smoke_intermittent_failure_task.md](../tasks/bug_umbrella_runtime_smoke_intermittent_failure_task.md) | Back-end | new | low. Umbrella `runtime_smoke_test` редко падает (1 из ~23, ~4%, не воспроизв. за 22 прогона); вероятно связано с `Lambda capture freed` warning. Рекомендация: логировать полный backtrace на падении + найти/починить freed-lambda `connect()`. Не блокер (>95% зелёный, focused-сьюты стабильны) |

## Бэклог 0.1.5 — патч «Бой и баланс» (PATCH-эпик SCRUM-232, под фризом)

Не dispatch до релиза 0.1.4. fixVersion 0.1.5.

| Задача | Роль | Статус | Тема |
| --- | --- | --- | --- |
| backend_global_balance_smoke_damage_survivability_task | Back-end | new(0.1.5) | ОПОРА: глобальные smoke урон+выживаемость (гейты патча) |
| backend_unique_class_mechanics_framework_main_attribute_task | Back-end | new(0.1.5) | Уникальные механики per класс в стиле основного атрибута (рамка) |
| backend_survivability_formulas_nerf_regen_vampirism_absorb_dodge_task | Back-end | new(0.1.5) | Нерф регена/вампиризма, баланс абсорба/уворота |
| backend_crit_formulas_rebalance_task | Back-end | new(0.1.5) | Баланс крита/силы крита |
| backend_attribute_weapon_universal_synergy_task | Back-end | new(0.1.5) | Все атрибуты × любое оружие |
| backend_melee_classes_strengthen_unique_attacks_task | Back-end | new(0.1.5) | Усиление милишников + уникальные ближние атаки |
| backend_summoner_classes_strengthen_task | Back-end | new(0.1.5) | Усиление призывателей |
| backend_auras_buffs_debuffs_system_task | Back-end | new(0.1.5) | Система аур/баффов/дебаффов |
| backend_aim_modes_cursor_and_nearest_task | Back-end | new(0.1.5) | Опции: прицел по курсору / на ближайшего |
| backend_remove_auto_movement_on_crit_dodge_task | Back-end | new(0.1.5) | Убрать авто-перемещение по криту/уклонению |
| animation_unique_attacks_all_classes_015_task | Back-end(rig) | new(0.1.5) | Анимации уникальных атак |
| design_codex_unique_weapons_vfx_all_classes_015_task | Design(Codex) | new(0.1.5) | Арт/VFX уникального оружия и атак |

## Архив

≈206 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
