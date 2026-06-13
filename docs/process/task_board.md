# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈195) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked` | `done`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 20 | 1 | 0 | 0 | 21 |
| SCRUM-213 Бой, враги, боссы, события | 32 | 1 | 1 | 0 | 34 |
| SCRUM-214 Баланс и экономика | 14 | 4 | 0 | 0 | 18 |
| SCRUM-215 Интерфейс, экраны, локализация | 21 | 1 | 0 | 0 | 22 |
| SCRUM-216 Арт и спрайты | 31 | 7 | 0 | 0 | 38 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 31 | 2 | 0 | 6 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **195** | **16** | **2** | **6** | **219** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_codex_interface_leather_gold_panels_restyle_task.md](../tasks/design_codex_interface_leather_gold_panels_restyle_task.md) | Design → Back-end | done | Jira: SCRUM-229; synced to QA 2026-06-13 from recorded READY FOR QA result. Leather+gold panel/window/bar/check kit built from `docs/design/references/interface/`, source assets in `assets/sprites/ui/frames/leather_gold/`, live replacements applied in-place for non-button `dark_fantasy/global/escape/shop/system` PNG; `scripts/ui_screens.gd` not touched; Godot import + focused UI/no-overlap + runtime smoke pass |
| [backend_parchment_button_seal_visible_height_task.md](../tasks/backend_parchment_button_seal_visible_height_task.md) | Back-end (UI) | done | Jira: SCRUM-227; button min heights/left seal margin adjusted, compact no-seal utility/dropdown style added; runtime/no-overlap green; QA dump `build/qa/parchment_button_seal_sizes.md` |
| [backend_levelup_cards_text_field_style_task.md](../tasks/backend_levelup_cards_text_field_style_task.md) | Back-end (UI) | done | Jira: SCRUM-226; level-up cards changed to clickable text-field panels with rare accent; runtime/no-overlap green |
| [backend_weapon_select_sprite_clean_layout_task.md](../tasks/backend_weapon_select_sprite_clean_layout_task.md) | Back-end (UI) | done | Jira: SCRUM-225; weapon select cards now show weapon sprites, Russian stats and flat card style; runtime/no-overlap green; QA dump `build/qa/weapon_select_clean_layout.md` |
| [backend_hero_select_description_left_of_radar_task.md](../tasks/backend_hero_select_description_left_of_radar_task.md) | Back-end (UI) | done | Jira: SCRUM-224; hero dossier moved left of radar in right info panel; runtime/no-overlap green; QA dump `build/qa/hero_select_radar_rects.md` |
| [codex_design_cursor_clawed_fire_task.md](../tasks/codex_design_cursor_clawed_fire_task.md) | Design (Codex) → Claude-Designer | done | Jira: SCRUM-223; synced to QA 2026-06-13 from recorded READY FOR QA result. Игровой курсор — 2-й вариант с референса: default/hover/attack заменены на dark steel dragon/clawed fire pointer, hotspot `(2, 2)`, preview `docs/design/previews/cursor_clawed_fire_before_after.png`; Godot import + focused UI/no-overlap + runtime smoke pass |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | in_progress | Jira: SCRUM-156; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12. Спрайты по общему ростеру: 3 босса 512px + 6 мини-элиток, painterly D&D, cutout-нарезка, превью-лист масштаба; duplicate SCRUM-180/SCRUM-204 requirements folded in: stable source paths, transparent alpha, animation-friendly separable parts, contact sheet, Animator unblock note |
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design | done | Jira: SCRUM-147; synced to QA from task-file `done` + Jira `Контроль качества`. User correction applied 2026-06-13: keep taller Parchment & Wax Seal buttons only, then SCRUM-229 replaces non-button paths with leather+gold panels; QA previews `ui_button_only_legacy_panels_contact.png` and `interface_leather_gold_panel_kit_contact.png`; Godot import + focused UI/no-overlap + runtime smoke pass |
| [backend_ui_dark_fantasy_theme_integration_task.md](../tasks/backend_ui_dark_fantasy_theme_integration_task.md) | Back-end (UI theme integration) | done | Jira: SCRUM-222. **QA: passed** (e9aa3d3a) — theme/no-overlap/runtime smoke зелёные; заявленное падение runtime_smoke на reward-offer (line 1042) НЕ воспроизводится на HEAD. Найдена НЕсвязанная флака `melee_weapon_targeting_test` (~17%) → заведён баг |
| [epic_full_project_quality_pass.md](../tasks/epic_full_project_quality_pass.md) | PM/Coordination | in_progress | Зонтик: 6 аудитов (Фаза 1) → волна исправлений (Фаза 2). Правила коллизий и «done=HEAD зелёный» |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | blocked | Jira: SCRUM-199; serialized 2026-06-13 until SCRUM-147/SCRUM-222 UI dependency and active UI edits are stable |
| [backend_refactor_class_weapon_mode_registry_task.md](../tasks/backend_refactor_class_weapon_mode_registry_task.md) | Back-end | blocked | Jira: SCRUM-196; serialized 2026-06-13 until active class/weapon/content changes are stable |
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | blocked | Jira: SCRUM-198; serialized 2026-06-13 until active `ProgressionData` content/balance changes close |
| [backend_test_runtime_smoke_suite_split_task.md](../tasks/backend_test_runtime_smoke_suite_split_task.md) | Back-end | blocked | Jira: SCRUM-202; serialized 2026-06-13 until current focused smoke additions and UI/content checks stabilize; umbrella smoke remains required |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | blocked | Jira: SCRUM-193; blocked 2026-06-13 until SCRUM-147/SCRUM-222 asset churn is clean enough for isolated backup-based cleanup |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | blocked | Jira: SCRUM-195; serialized 2026-06-13 until active content/UI blockers settle; task-local docs continue in implementation tasks |

## Баги от QA

| Баг | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_flaky_melee_targeting_hammer_aoe_cache_task.md](../tasks/bug_flaky_melee_targeting_hammer_aoe_cache_task.md) | Back-end | done | Jira: SCRUM-228; `melee_weapon_targeting_test` hammer AoE flake fixed with one-frame wait after enemy group setup; production target cache unchanged; melee/runtime smoke green |

## Архив

≈197 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
