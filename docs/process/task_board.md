# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈197) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 20 | 0 | 1 | 0 | 21 |
| SCRUM-213 Бой, враги, боссы, события | 32 | 0 | 1 | 0 | 33 |
| SCRUM-214 Баланс и экономика | 14 | 3 | 1 | 0 | 18 |
| SCRUM-215 Интерфейс, экраны, локализация | 21 | 0 | 1 | 0 | 22 |
| SCRUM-216 Арт и спрайты | 31 | 4 | 2 | 0 | 37 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 31 | 2 | 0 | 6 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **195** | **9** | **7** | **6** | **217** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_codex_interface_leather_gold_panels_restyle_task.md](../tasks/design_codex_interface_leather_gold_panels_restyle_task.md) | Design → Back-end | new | Переделать интерфейс: кит панелей/окон «кожа+золото» (5 PNG в references/interface) — 9-slice, карта замены всех панелей/тултипов/чекбоксов; согласовать с кнопками-пергаментом |
| [backend_parchment_button_seal_visible_height_task.md](../tasks/backend_parchment_button_seal_visible_height_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-227; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch addition with SCRUM-224/SCRUM-225/SCRUM-226. Печать на кнопках должна быть видна; keep High/no low; Jira sync required |
| [backend_levelup_cards_text_field_style_task.md](../tasks/backend_levelup_cards_text_field_style_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-226; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-225. Карточки повышения уровня — стиль поля с текстом, не кнопки; keep High/no low; Jira sync required |
| [backend_weapon_select_sprite_clean_layout_task.md](../tasks/backend_weapon_select_sprite_clean_layout_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-225; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-226. Выбор оружия: спрайт, убрать тяжёлый button-style, статы по-русски; keep High/no low; Jira sync required |
| [backend_hero_select_description_left_of_radar_task.md](../tasks/backend_hero_select_description_left_of_radar_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-224; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-225/SCRUM-226. Описание героя слева от розы ветров; keep High/no low; Jira sync required |
| [codex_design_cursor_clawed_fire_task.md](../tasks/codex_design_cursor_clawed_fire_task.md) | Design (Codex) → Claude-Designer | in_progress | Jira: SCRUM-223; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-13. Игровой курсор — 2-й вариант с референса (когтистый наконечник + огонь), заменить `game_cursor.png`, выверить hotspot; duplicate audit: prior cursor pack SCRUM-79/SCRUM-55 is done and superseded by this specific rework |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | in_progress | Jira: SCRUM-156; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12. Спрайты по общему ростеру: 3 босса 512px + 6 мини-элиток, painterly D&D, cutout-нарезка, превью-лист масштаба; duplicate SCRUM-180/SCRUM-204 requirements folded in: stable source paths, transparent alpha, animation-friendly separable parts, contact sheet, Animator unblock note |
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design | review | Jira: SCRUM-147; user correction applied 2026-06-13: keep taller Parchment & Wax Seal buttons only, restore old/legacy interface panels across `global/escape/shop` and non-button `dark_fantasy` paths; QA preview `ui_button_only_legacy_panels_contact.png`; Godot import + focused UI tests pass, full runtime smoke currently fails on unrelated post-battle attribute offers |
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
| [bug_flaky_melee_targeting_hammer_aoe_cache_task.md](../tasks/bug_flaky_melee_targeting_hammer_aoe_cache_task.md) | Back-end | blocked | Undispatched: missing Jira key/issue; PM/QA-owner must sync Jira first. Флака `melee_weapon_targeting_test` (~17%, hammer AoE Берсерка); фикс в тесте (await/`set_process(false)`), production не трогать. Найдено при QA SCRUM-222 |

## Архив

≈197 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
