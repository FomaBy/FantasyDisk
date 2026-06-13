# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈201) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked` | `done`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Feature Freeze

АКТИВЕН с 2026-06-13 для стабилизации `0.1.4`: добиваем уже начатые задачи,
баги, QA-дефекты, регрессии и release blockers. Всё новое (фичи/улучшения/арт/
контент) оформляется в backlog `0.1.5` и не dispatch'ится до релиза `v0.1.4`.
Фриз снимается сразу после релиза `0.1.4`.

## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 20 | 1 | 1 | 0 | 22 |
| SCRUM-213 Бой, враги, боссы, события | 33 | 1 | 0 | 1 | 35 |
| SCRUM-214 Баланс и экономика | 15 | 3 | 0 | 0 | 18 |
| SCRUM-215 Интерфейс, экраны, локализация | 22 | 0 | 0 | 0 | 22 |
| SCRUM-216 Арт и спрайты | 33 | 5 | 0 | 0 | 38 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 32 | 3 | 2 | 2 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **201** | **13** | **4** | **3** | **221** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_hero_select_radar_out_of_frame_description_left_task.md](../tasks/bug_hero_select_radar_out_of_frame_description_left_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-231. БАГ 0.1.4: роза ветров внутри рамки (регрессия SCRUM-224) — dispatch Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13, High/no-low; вынести в правый верхний угол вне рамки, описание слева, no-overlap |
| [backend_ascension_per_level_changes_near_start_task.md](../tasks/backend_ascension_per_level_changes_near_start_task.md) | Back-end (UI) | new (БЭКЛОГ 0.1.5) | Jira: SCRUM-230. ФРИЗ: у кнопки старта показывать ТОЛЬКО изменение выбранного уровня возвышения (дельта, не кумулятив); не dispatch до релиза 0.1.4 |
| [design_codex_interface_leather_gold_panels_restyle_task.md](../tasks/design_codex_interface_leather_gold_panels_restyle_task.md) | Design → Back-end | done | Jira: SCRUM-229. **QA: passed** (35b79e06) — 5 рамок RGBA8, прозрачные углы (без checkerboard), целевые UI + 4×smoke зелёные, визуал в `build/qa/scrum229/` (выбор героя/настройки/меню): leather+gold панели + золотой чекбокс + кнопки-пергамент согласованы, перекрытий нет. Физ.удаление legacy → safe-cleanup flow |
| [backend_parchment_button_seal_visible_height_task.md](../tasks/backend_parchment_button_seal_visible_height_task.md) | Back-end (UI) | done | Jira: SCRUM-227. **QA: passed** (35b79e06) — печать-кнопки 68-76px (≥64), тест `_test_parchment_button_seal_sizes` мерит 4 экрана + ассертит компактные no-seal, 4×smoke+no-overlap зелёные, визуал `build/qa/scrum227/` (меню печать не сжата, level-up чистый) |
| [backend_levelup_cards_text_field_style_task.md](../tasks/backend_levelup_cards_text_field_style_task.md) | Back-end (UI) | done | Jira: SCRUM-226. **QA: passed** (35b79e06) — карточки = text-field (мета+StyleBoxFlat, не button-тема), клик применяет усиление, «Позже»/Escape defer, тест мерит 3 карточки/иконку/описание, 4×smoke+no-overlap зелёные, визуал `build/qa/scrum227/level_up.png` |
| [backend_weapon_select_sprite_clean_layout_task.md](../tasks/backend_weapon_select_sprite_clean_layout_task.md) | Back-end (UI) | done | Jira: SCRUM-225. **QA: passed** (35b79e06) — спрайты оружия + русские статы + flat-карточки, клик ставит selected_weapon_id (тест ассертит), 4×smoke+no-overlap зелёные, визуал `build/qa/scrum225/weapon_select.png` |
| [backend_hero_select_description_left_of_radar_task.md](../tasks/backend_hero_select_description_left_of_radar_task.md) | Back-end (UI) | done | Jira: SCRUM-224. **QA: FAILED** (35b79e06) — описание-слева + автотесты OK, но визуальная регрессия: роза ВНУТРИ рамки (была плавающей в правом верхнем углу, урок SCRUM-206). Фикс → SCRUM-231 (уже in_progress). QA перепроверит после фикса |
| [codex_design_cursor_clawed_fire_task.md](../tasks/codex_design_cursor_clawed_fire_task.md) | Design (Codex) → Claude-Designer | done | Jira: SCRUM-223; synced to QA 2026-06-13 from recorded READY FOR QA result. Игровой курсор — 2-й вариант с референса: default/hover/attack заменены на dark steel dragon/clawed fire pointer, hotspot `(2, 2)`, preview `docs/design/previews/cursor_clawed_fire_before_after.png`; Godot import + focused UI/no-overlap + runtime smoke pass |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | done | Jira: SCRUM-156; implemented 2026-06-13. 3 boss + 6 mini-elite painterly D&D source sprites generated at stable `assets/sprites/bosses/` and `assets/sprites/elites/mini_*.png` paths, previews `new_bosses_mini_elites_contact.png` and scale sheet ready; PNG validation + Godot import + runtime/animation smoke pass; Back-end SCRUM-155 and Animator SCRUM-204 handoff notes updated | -> Design ПРИНЯТО 2026-06-13: 3 босса + 6 мини-элиток 512px, имозинг в каноне, читаются без тинта; cutout->Animator, вайринг->Back-end
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design | done | Jira: SCRUM-147; synced to QA from task-file `done` + Jira `Контроль качества`. User correction applied 2026-06-13: keep taller Parchment & Wax Seal buttons only, then SCRUM-229 replaces non-button paths with leather+gold panels; QA previews `ui_button_only_legacy_panels_contact.png` and `interface_leather_gold_panel_kit_contact.png`; Godot import + focused UI/no-overlap + runtime smoke pass |
| [backend_ui_dark_fantasy_theme_integration_task.md](../tasks/backend_ui_dark_fantasy_theme_integration_task.md) | Back-end (UI theme integration) | done | Jira: SCRUM-222. **QA: passed** (e9aa3d3a) — theme/no-overlap/runtime smoke зелёные; заявленное падение runtime_smoke на reward-offer (line 1042) НЕ воспроизводится на HEAD. Найдена НЕсвязанная флака `melee_weapon_targeting_test` (~17%) → заведён баг |
| [epic_full_project_quality_pass.md](../tasks/epic_full_project_quality_pass.md) | PM/Coordination | in_progress | Зонтик: 6 аудитов (Фаза 1) → волна исправлений (Фаза 2). Правила коллизий и «done=HEAD зелёный» |
| [backend_test_runtime_smoke_suite_split_task.md](../tasks/backend_test_runtime_smoke_suite_split_task.md) | Back-end | done | Jira: SCRUM-202. **QA: passed** (35b79e06) — 5 focused-сьютов (extends+override `_initialize` с реальными `_test_*`) + umbrella все зелёные headless; регрессия зелёная; нефатальный lambda-warning у umbrella (exit 0, латентный, отложен) |
| [backend_refactor_class_weapon_mode_registry_task.md](../tasks/backend_refactor_class_weapon_mode_registry_task.md) | Back-end | done | Jira: SCRUM-196. **QA: passed** (1fbc20c6) — registry+API, 83 executor/39 `_fire_*` сохранены, coverage-тест ассертит mode→executor по всему ростеру, weapon/animation/targeting/umbrella/meta зелёные |
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-198; unblocked/dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized queue item 3 after SCRUM-202/SCRUM-196. SCRUM-192 done and `scripts/progression_data.gd` clean; no balance changes; keep High/no low |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-199; unblocked/dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized queue item 4 after SCRUM-202/SCRUM-196/SCRUM-198. SCRUM-222/SCRUM-203 done and `scripts/ui_screens.gd` clean; no visual/design changes; keep High/no low |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | blocked | Jira: SCRUM-193; blocked 2026-06-13 until SCRUM-147/SCRUM-222 asset churn is clean enough for isolated backup-based cleanup |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | blocked | Jira: SCRUM-195; serialized 2026-06-13 until active content/UI blockers settle; task-local docs continue in implementation tasks |

## Баги от QA

| Баг | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_flaky_melee_targeting_hammer_aoe_cache_task.md](../tasks/bug_flaky_melee_targeting_hammer_aoe_cache_task.md) | Back-end | done | Jira: SCRUM-228. **QA: passed** (35b79e06) — анти-флака 25/25 PASS (было ~17%), `await process_frame` на месте, production-кэш `combat_target_query.gd` не тронут, регрессия 4×smoke зелёная |

## Архив

≈201 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
