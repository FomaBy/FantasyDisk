# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-13
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈222) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked` | `done`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Спринт 0.1.5 — патч «Бой и баланс» (АКТИВЕН, фриз снят 2026-06-13)

Релиз v0.1.4 выпущен. Активен Спринт 0.1.5 (эпик SCRUM-232). Очередь патча
сериализована по зависимостям/общим файлам:
- СТАРТ (new): SCRUM-256 framework механик, 255/247/243 формулы (выживаемость/
  крит/синергия), 241 прицел, 253 авто-движение, 260 монстры/размеры, 259
  скилы элиток/боссов. Гейты 249 и анимации 239 — done (ждут QA).
- BLOCKED до предпосылок: 251/254/245 (классы — после 256), 258/261 (арт —
  после механик), 262 финальная сверка AoE (после ВСЕХ правок).
Анти-коллизия воркеров сериализует общие файлы (stat_formulas/progression_data/
class_weapon). «done = чистый HEAD зелёный».


## Прогресс по эпикам (снимок Jira, 2026-06-13)

| Эпик | Готово | КК | В работе | Кв | Всего |
| --- | ---: | ---: | ---: | ---: | ---: |
| SCRUM-212 Персонажи и классы | 22 | 0 | 0 | 0 | 22 |
| SCRUM-213 Бой, враги, боссы, события | 35 | 0 | 0 | 0 | 35 |
| SCRUM-214 Баланс и экономика | 16 | 2 | 0 | 0 | 18 |
| SCRUM-215 Интерфейс, экраны, локализация | 22 | 0 | 0 | 0 | 22 |
| SCRUM-216 Арт и спрайты | 35 | 3 | 0 | 0 | 38 |
| SCRUM-217 Анимация и риги | 30 | 0 | 1 | 0 | 31 |
| SCRUM-218 Звук и музыка | 5 | 0 | 0 | 0 | 5 |
| SCRUM-219 Мета-прогрессия | 6 | 0 | 0 | 0 | 6 |
| SCRUM-220 Качество кода, тесты, аудиты | 33 | 3 | 4 | 0 | 40 |
| SCRUM-221 Релиз и процессы | 5 | 0 | 0 | 0 | 5 |
| SCRUM-232 Backlog 0.1.5: бой и баланс | 13 | 1 | 0 | 15 | 29 |
| **ИТОГО** | **222** | **9** | **5** | **15** | **251** |

(КК = Контроль качества, ждёт QA; Кв = К выполнению. Для `SCRUM-232` колонка
«Кв» сейчас означает backlog `0.1.5` вне active sprint.)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_hero_select_radar_out_of_frame_description_left_task.md](../tasks/bug_hero_select_radar_out_of_frame_description_left_task.md) | Back-end (UI) | done | Jira: SCRUM-231. **QA: passed** (f8f1409a) — радар = плавающий top-right виджет ВНЕ рамки досье (зазор 34px, тест ассертит parent=screen+anchor_right≥0.99), описание слева, no-overlap; визуал `build/qa/scrum231/hero_select_radar_fixed.png`. **Устраняет регрессию SCRUM-224** |
| [backend_ascension_per_level_changes_near_start_task.md](../tasks/backend_ascension_per_level_changes_near_start_task.md) | Back-end (UI) | done | Jira: SCRUM-230. **QA: passed** (6b56d592) — `ascension_level_change_line`: L3=только ур.3 (не 1-2), L0=«без усложнений», кумулятив сохранён для тултипа; тест ассертит «есть N, нет 1..N-1»; UI/no-overlap/регрессия зелёные; CHANGELOG+doc |
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
| [backend_refactor_progression_data_domain_split_task.md](../tasks/backend_refactor_progression_data_domain_split_task.md) | Back-end | done | Jira: SCRUM-198. **QA: passed** — ProgressionData compatibility facade + domain split verified; API surface, content registry, progression economy, weapon/boss/meta/melee smokes and balance harness green |
| [backend_refactor_ui_screens_domain_split_task.md](../tasks/backend_refactor_ui_screens_domain_split_task.md) | Back-end | done | Jira: SCRUM-199. UI screens facade preserved; hero radar control/theme paths/shop constants/hero select constants split into scripts/ui modules; UI, animation, meta, melee, VFX and umbrella smokes passed |
| [backend_content_safe_cleanup_followup_task.md](../tasks/backend_content_safe_cleanup_followup_task.md) | Back-end | done | Jira: SCRUM-193. Done 2026-06-13 (Claude): удалено 10 legacy-прототипных спрайтов +.import +5 .DS_Store с бэкапом (commit 88304f41). Codex follow-up: old character placeholders verified absent with backup, audit updated/verified for split `progression_data_*`, runtime+animation smoke green; live enemies/new bosses/icons not removed |
| [backend_docs_domain_consistency_update_task.md](../tasks/backend_docs_domain_consistency_update_task.md) | Back-end | done | Jira: SCRUM-195. Done 2026-06-13 (Claude): combat.md+progression_balance.md рефреш под 0.1.4. Codex follow-up: fixed stale 0.2/version/doc-name drift, refreshed boss/mini-elite cleanup notes, runtime smoke green |
| [animation_unique_attacks_all_classes_015_task.md](../tasks/animation_unique_attacks_all_classes_015_task.md) | Animator | done | Jira: SCRUM-239. **QA: passed** (168c3fad) — weapon phase variants reach cutout rig without gameplay changes; animation + runtime smoke passed ×2 after Back-end ProgressionData unblock; no bugs |

## Баги от QA

| Баг | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [bug_flaky_melee_targeting_hammer_aoe_cache_task.md](../tasks/bug_flaky_melee_targeting_hammer_aoe_cache_task.md) | Back-end | done | Jira: SCRUM-228. **QA: passed** (35b79e06) — анти-флака 25/25 PASS (было ~17%), `await process_frame` на месте, production-кэш `combat_target_query.gd` не тронут, регрессия 4×smoke зелёная |
| [bug_umbrella_runtime_smoke_intermittent_failure_task.md](../tasks/bug_umbrella_runtime_smoke_intermittent_failure_task.md) | Back-end | done | Jira: SCRUM-257. **QA: passed** (5d7c2337) — freed-lambda warning eliminated; hero-radar/header umbrella flake fixed; 32/32 isolated umbrella PASS with 0 warnings; weapon/melee/UI/animation/meta regressions green |

## Backlog 0.1.5 — не dispatch во время feature freeze

PATCH-эпик `SCRUM-232` содержит 15 незавершённых задач `Версия: 0.1.5` в backlog и 13 закрытых duplicate/superseded Jira issues. Эти backlog-задачи не показываются как active rows и не отправляются исполнителям до релиза `v0.1.4` или явного PM override. `SCRUM-239` уже прошёл QA как активная 0.1.4 work item, потому что по нему был записан Animator result.

Новые запросы во время freeze можно оформлять как backlog-задачи `0.1.5`
(`Статус: new`, `Версия: 0.1.5`, Jira fixVersion `0.1.5`, вне active sprint).
Codex Documentation dispatcher может создавать такие task/Jira entries, но не
dispatch'ит их и не переводит в `in_progress` до релиза `v0.1.4` или явного PM
override.

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [backend_final_balance_audit_aoe_crowd_clear_task.md](../tasks/backend_final_balance_audit_aoe_crowd_clear_task.md) | Back-end | new (0.1.5 backlog) | Jira: SCRUM-262. ФИНАЛ патча: сверка цифр урона + фокус crowd-clear (пачки 5/10), выправить классы со слабым AoE; после всех балансовых правок. Не dispatch во время freeze |

## Архив

≈222 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
