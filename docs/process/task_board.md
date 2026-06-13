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
| SCRUM-215 Интерфейс, экраны, локализация | 19 | 0 | 2 | 0 | 21 |
| SCRUM-216 Арт и спрайты | 30 | 3 | 2 | 0 | 35 |
| SCRUM-217 Анимация и риги | 26 | 4 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 28 | 3 | 8 | 0 | 39 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| **ИТОГО** | **185** | **13** | **14** | **0** | **212** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению, ждёт взятия)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_codex_new_bosses_mini_elites_sprites_task.md](../tasks/design_codex_new_bosses_mini_elites_sprites_task.md) | Design (Codex генерация) → Claude-Designer | in_progress | Jira: SCRUM-156; dispatched Design `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12. Спрайты по общему ростеру: 3 босса 512px + 6 мини-элиток, painterly D&D, cutout-нарезка, превью-лист масштаба; duplicate SCRUM-180/SCRUM-204 requirements folded in: stable source paths, transparent alpha, animation-friendly separable parts, contact sheet, Animator unblock note |
| [design_codex_ui_dark_fantasy_restyle_task.md](../tasks/design_codex_ui_dark_fantasy_restyle_task.md) | Design (Claude арт-дирекшен/ревью; генерация Codex) → handoff Back-end | in_progress | Jira: SCRUM-147; 2026-06-13 Design asset slice complete: canonical `assets/sprites/ui/frames/dark_fantasy/` kit added, unified Parchment & Wax Seal 4-state buttons generated for primary/secondary/danger, live `global/escape/shop` frame PNGs replaced in-place, preview `ui_dark_fantasy_restyle_kit_contact.png`, docs updated, Back-end handoff `backend_ui_dark_fantasy_theme_integration_task.md`; import + runtime smoke passed | -> Design ОТКЛОНЕНО 2026-06-13: арт не соответствует эталону Parchment & Wax Seal (плоские прямоугольники вместо пергамент+сургуч+кованый металл); перегенерировать Codex с приложенным button_parchment_wax_seal.png
| [backend_ui_dark_fantasy_theme_integration_task.md](../tasks/backend_ui_dark_fantasy_theme_integration_task.md) | Back-end (UI theme integration) | in_progress | Jira: SCRUM-222; dispatched Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13. Dependency update: SCRUM-147 Design review rejected the current frame set, so do not wire rejected dark_fantasy/global/escape assets as final; wait for accepted Parchment & Wax Seal regeneration or keep work to swappable scaffolding; animation scope none |
| [epic_full_project_quality_pass.md](../tasks/epic_full_project_quality_pass.md) | PM/Coordination | in_progress | Зонтик: 6 аудитов (Фаза 1) → волна исправлений (Фаза 2). Правила коллизий и «done=HEAD зелёный» |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-199; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13; serialize after active UI tasks. Split shared `ui_screens.gd` |
| [backend_refactor_class_weapon_mode_registry_task.md](../tasks/backend_refactor_class_weapon_mode_registry_task.md) | Back-end | in_progress | Jira: SCRUM-196; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13; high-conflict serialization. Split shared `class_weapon.gd` |
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | in_progress | Jira: SCRUM-198; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13; high-conflict serialization. Split shared `progression_data.gd` |
| [backend_test_runtime_smoke_suite_split_task.md](../tasks/backend_test_runtime_smoke_suite_split_task.md) | Back-end | in_progress | Jira: SCRUM-202; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13. Split mega-smoke into focused suites |
| [backend_content_character_sprite_registry_alignment_task.md](../tasks/backend_content_character_sprite_registry_alignment_task.md) | Back-end | in_progress | Jira: SCRUM-192; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13. Align new class sprite paths with registry |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | in_progress | Jira: SCRUM-193; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13; sequence after SCRUM-194. Backup-based cleanup after manifest |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | in_progress | Jira: SCRUM-195; restarted Back-end `019eabd9-780b-78a2-9f4b-e7203d659ef2` 2026-06-13. Domain docs refresh |

## Архив

≈197 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
