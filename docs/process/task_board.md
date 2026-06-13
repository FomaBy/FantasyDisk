# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈197) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 20 | 0 | 0 | 0 | 20 |
| SCRUM-213 Бой, враги, боссы, события | 32 | 0 | 1 | 0 | 33 |
| SCRUM-214 Баланс и экономика | 14 | 3 | 0 | 0 | 17 |
| SCRUM-215 Интерфейс, экраны, локализация | 20 | 1 | 0 | 0 | 21 |
| SCRUM-216 Арт и спрайты | 31 | 4 | 1 | 0 | 36 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 31 | 2 | 0 | 6 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **194** | **10** | **3** | **6** | **213** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [backend_parchment_button_seal_visible_height_task.md](../tasks/backend_parchment_button_seal_visible_height_task.md) | Back-end (UI) | new | Кнопка пергамент+печать: печать сплющивается при низкой высоте — поднять мин-высоту кнопок (≥64-72px), проверить 9-slice/поля, текст не на печать; везде где стиль применяется |
| [backend_levelup_cards_text_field_style_task.md](../tasks/backend_levelup_cards_text_field_style_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-226; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-225. Карточки повышения уровня — стиль поля с текстом, не кнопки; keep High/no low; Jira sync required |
| [backend_weapon_select_sprite_clean_layout_task.md](../tasks/backend_weapon_select_sprite_clean_layout_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-225; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-226. Выбор оружия: спрайт, убрать тяжёлый button-style, статы по-русски; keep High/no low; Jira sync required |
| [backend_hero_select_description_left_of_radar_task.md](../tasks/backend_hero_select_description_left_of_radar_task.md) | Back-end (UI) | in_progress | Jira: SCRUM-224; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13 as serialized `scripts/ui_screens.gd` UI batch with SCRUM-225/SCRUM-226. Описание героя слева от розы ветров; keep High/no low; Jira sync required |
| [codex_design_cursor_clawed_fire_task.md](../tasks/codex_design_cursor_clawed_fire_task.md) | Design (Codex) → Claude-Designer | in_progress | Jira: SCRUM-223; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-13. Игровой курсор — 2-й вариант с референса (когтистый наконечник + огонь), заменить `game_cursor.png`, выверить hotspot; duplicate audit: prior cursor pack SCRUM-79/SCRUM-55 is done and superseded by this specific rework |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | in_progress | Jira: SCRUM-156; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12. Спрайты по общему ростеру: 3 босса 512px + 6 мини-элиток, painterly D&D, cutout-нарезка, превью-лист масштаба; duplicate SCRUM-180/SCRUM-204 requirements folded in: stable source paths, transparent alpha, animation-friendly separable parts, contact sheet, Animator unblock note |
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design | review | Jira: SCRUM-147; user correction applied 2026-06-13: keep taller Parchment & Wax Seal buttons only, restore old/legacy interface panels across `global/escape/shop` and non-button `dark_fantasy` paths; QA preview `ui_button_only_legacy_panels_contact.png`; Godot import + focused UI tests pass, full runtime smoke currently fails on unrelated post-battle attribute offers |
| [backend_ui_dark_fantasy_theme_integration_task.md](../tasks/backend_ui_dark_fantasy_theme_integration_task.md) | Back-end (UI theme integration) | review | Jira: SCRUM-222; done 2026-06-13 by Back-end, awaiting QA. Runtime style layer keeps primary/secondary/danger 4-state wax-seal buttons; non-button `dark_fantasy` frame paths now visually mirror old interface after SCRUM-147 correction; post-correction UI tests pass, full runtime smoke now points to reward-offer logic follow-up |
| [epic_full_project_quality_pass.md](../tasks/epic_full_project_quality_pass.md) | PM/Coordination | in_progress | Зонтик: 6 аудитов (Фаза 1) → волна исправлений (Фаза 2). Правила коллизий и «done=HEAD зелёный» |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | blocked | Jira: SCRUM-199; serialized 2026-06-13 until SCRUM-147/SCRUM-222 UI dependency and active UI edits are stable |
| [backend_refactor_class_weapon_mode_registry_task.md](../tasks/backend_refactor_class_weapon_mode_registry_task.md) | Back-end | blocked | Jira: SCRUM-196; serialized 2026-06-13 until active class/weapon/content changes are stable |
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | blocked | Jira: SCRUM-198; serialized 2026-06-13 until active `ProgressionData` content/balance changes close |
| [backend_test_runtime_smoke_suite_split_task.md](../tasks/backend_test_runtime_smoke_suite_split_task.md) | Back-end | blocked | Jira: SCRUM-202; serialized 2026-06-13 until current focused smoke additions and UI/content checks stabilize; umbrella smoke remains required |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | blocked | Jira: SCRUM-193; blocked 2026-06-13 until SCRUM-147/SCRUM-222 asset churn is clean enough for isolated backup-based cleanup |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | blocked | Jira: SCRUM-195; serialized 2026-06-13 until active content/UI blockers settle; task-local docs continue in implementation tasks |

## Архив

≈197 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
