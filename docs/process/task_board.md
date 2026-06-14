# Task Board — FantasyDisk (живой дашборд)

Обновлено: 2026-06-14
Ведёт: PM. Доска показывает ТОЛЬКО активную работу. Завершённые задачи (≈222) не
дублируются здесь — они в Jira (эпики SCRUM-212..221, статус «Готово») и git-истории.
Статусы: `new` | `in_progress` | `review` | `blocked` | `done`. Источник истины по деталям —
файлы `docs/tasks/*.md`; управление и отчётность — Jira.

## Спринт 0.1.5 — патч «Бой и баланс» (АКТИВЕН, фриз снят 2026-06-13)

Релиз v0.1.4 выпущен. Активен Спринт 0.1.5 (эпик SCRUM-232). Очередь патча
сериализована по зависимостям/общим файлам:
- СТАРТ: SCRUM-256 framework механик — done; SCRUM-260 монстры/размеры —
  done/QA; SCRUM-253 авто-движение — done; SCRUM-259 скилы элиток/боссов —
  done/QA; SCRUM-255 формулы выживаемости — done; SCRUM-247/243
  формулы — done; SCRUM-241 прицел — done. Гейты 249 и анимации 239 —
  done (ждут/прошли QA по Jira).
- SCRUM-256 framework завершен; 251/254/245 сняты с framework-блокера и снова
  доступны как backend-задачи. SCRUM-258 разблокирован и отправлен Design после
  готовности 256/251/254/245. SCRUM-262 финальная сверка AoE разблокирована и
  отправлена Back-end после готовности всех balance/mechanics gates.
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

(КК = Контроль качества, ждёт QA; Кв = К выполнению/current sprint todo.)

## Активные задачи

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [backend_quit_confirmation_dialog_and_escape_task.md](../tasks/backend_quit_confirmation_dialog_and_escape_task.md) | Back-end (UI) | blocked | Jira: SCRUM-319. UX 0.1.5: диалог подтверждения выхода + Escape в главном меню; hold until active SCRUM-281 UI changes in `scripts/ui_screens.gd` / `tests/runtime_smoke_test.gd` are finished/QA or PM override |
| [bug_button_hover_remove_yellow_glow_task.md](../tasks/bug_button_hover_remove_yellow_glow_task.md) | Back-end (UI) | blocked | Jira: SCRUM-318. Hold until active SCRUM-281 Design Hero Select frame/safe-area pass stops editing `scripts/ui_screens.gd`; then dispatch Back-end hover/focus pass if still актуально |
| [design_main_menu_background_new_bosses_battle_task.md](../tasks/design_main_menu_background_new_bosses_battle_task.md) | Designer (Codex) | new | Jira: SCRUM-316. ART 0.1.6: новый фон главного меню 2560×1440 — 3 новых босса + пара героев в бою, более гладкие текстуры; UI читаем, старый в бэкап; future-scope, не dispatch в 0.1.5 |
| [art_unified_character_style_anim_spec_task.md](../tasks/art_unified_character_style_anim_spec_task.md) | Designer+Back-end | new | Jira: SCRUM-298. ART 0.2.0 ОПОРНАЯ: единый стиль персонажей + система анимаций (5 walk/5 attack, без оружия), эталон=берсерк; блокирует 16 пер-персонажных |
| [art_char_redraw_anim_berserk_task.md](../tasks/art_char_redraw_anim_berserk_task.md) | Designer (Codex) | blocked | Jira: SCRUM-283. ART 0.2.0: перерисовать «Берсерк» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_dark_mage_task.md](../tasks/art_char_redraw_anim_dark_mage_task.md) | Designer (Codex) | blocked | Jira: SCRUM-286. ART 0.2.0: перерисовать «Тёмный маг» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_guitarist_task.md](../tasks/art_char_redraw_anim_guitarist_task.md) | Designer (Codex) | blocked | Jira: SCRUM-291. ART 0.2.0: перерисовать «Гитарист» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_assassin_task.md](../tasks/art_char_redraw_anim_assassin_task.md) | Designer (Codex) | blocked | Jira: SCRUM-282. ART 0.2.0: перерисовать «Ассасин» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_thief_task.md](../tasks/art_char_redraw_anim_thief_task.md) | Designer (Codex) | blocked | Jira: SCRUM-297. ART 0.2.0: перерисовать «Вор» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_elementalist_task.md](../tasks/art_char_redraw_anim_elementalist_task.md) | Designer (Codex) | blocked | Jira: SCRUM-289. ART 0.2.0: перерисовать «Элементалист» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_sniper_task.md](../tasks/art_char_redraw_anim_sniper_task.md) | Designer (Codex) | blocked | Jira: SCRUM-296. ART 0.2.0: перерисовать «Снайпер» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_priest_task.md](../tasks/art_char_redraw_anim_priest_task.md) | Designer (Codex) | blocked | Jira: SCRUM-293. ART 0.2.0: перерисовать «Священник» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_biologist_task.md](../tasks/art_char_redraw_anim_biologist_task.md) | Designer (Codex) | blocked | Jira: SCRUM-284. ART 0.2.0: перерисовать «Биолог» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_robot_task.md](../tasks/art_char_redraw_anim_robot_task.md) | Designer (Codex) | blocked | Jira: SCRUM-295. ART 0.2.0: перерисовать «Робот» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_engineer_task.md](../tasks/art_char_redraw_anim_engineer_task.md) | Designer (Codex) | blocked | Jira: SCRUM-290. ART 0.2.0: перерисовать «Инженер» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_ranger_task.md](../tasks/art_char_redraw_anim_ranger_task.md) | Designer (Codex) | blocked | Jira: SCRUM-294. ART 0.2.0: перерисовать «Рейнджер» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_doctor_task.md](../tasks/art_char_redraw_anim_doctor_task.md) | Designer (Codex) | blocked | Jira: SCRUM-287. ART 0.2.0: перерисовать «Доктор» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_chemist_task.md](../tasks/art_char_redraw_anim_chemist_task.md) | Designer (Codex) | blocked | Jira: SCRUM-285. ART 0.2.0: перерисовать «Химик» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_knight_task.md](../tasks/art_char_redraw_anim_knight_task.md) | Designer (Codex) | blocked | Jira: SCRUM-292. ART 0.2.0: перерисовать «Рыцарь» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [art_char_redraw_anim_druid_task.md](../tasks/art_char_redraw_anim_druid_task.md) | Designer (Codex) | blocked | Jira: SCRUM-288. ART 0.2.0: перерисовать «Друид» в едином стиле, 5 walk/5 attack, без оружия; ждёт опорную |
| [design_hero_select_replace_frames_herouiframe_task.md](../tasks/design_hero_select_replace_frames_herouiframe_task.md) | Designer (Codex) | review | Jira: SCRUM-281. Hero Select herouiframe kit applied: 8 dedicated frames in `assets/sprites/ui/frames/hero_select/`, 720p safe-area fixed (Back button visible, thumbnails inside viewport), screenshots `build/qa/scrum281/hero_select_*.png`, UI/no-overlap/runtime smokes PASS. Закрывает SCRUM-276 pending QA |
| [design_druid_wolf_summon_animation_slice_task.md](../tasks/design_druid_wolf_summon_animation_slice_task.md) | Designer (Codex) | review | Jira: SCRUM-280. Wolf source sheets sliced into `ally_druid_wolf_spriteframes.tres`: move 8f/12fps loop, attack 6f/14fps no-loop, 256x224 bottom-center pivot, QA preview/gifs in `build/qa/druid_wolf_summon_animation/`; SCRUM-279 unblocked |
| [backend_druid_wolf_summon_animation_integrate_task.md](../tasks/backend_druid_wolf_summon_animation_integrate_task.md) | Back-end (анимации) | in_progress | Jira: SCRUM-279. Dispatched 2026-06-14 to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`; integrate `ally_druid_wolf_spriteframes.tres` into `AllyMinion` for `druid_beast` move/attack/flip; motion polish/pivot retiming -> Animator handoff if needed |
| [bug_all_characters_weapon_integrity_audit_task.md](../tasks/bug_all_characters_weapon_integrity_audit_task.md) | Back-end (геймплей) | done | Jira: SCRUM-277. Fixed 18 stale proxy weapon textures incl. PriestChime→priest_chime.png, aligned axe/doctor scene defaults, added 17×3 weapon integrity test; 6 smokes PASS |
| [bug_combat_level_up_button_reposition_opaque_task.md](../tasks/bug_combat_level_up_button_reposition_opaque_task.md) | Back-end (UI) | done | Jira: SCRUM-278. `LevelUpPlusButton` перенесена в правый нижний угол, alpha=1, normal/hover/focus используют один opaque stylebox; runtime smoke PASS, dump `build/qa/combat_level_up_button.md` |
| [bug_hero_select_description_overlaps_frame_task.md](../tasks/bug_hero_select_description_overlaps_frame_task.md) | Back-end (UI) | blocked | Jira: SCRUM-276. Hold for active SCRUM-281 Design Hero Select frame/safe-area pass; do not dispatch Back-end in parallel until SCRUM-281 result/QA decides if residual layout fix remains |
| [bug_settings_controls_tab_overflow_scroll_task.md](../tasks/bug_settings_controls_tab_overflow_scroll_task.md) | Back-end (UI) | done | Jira: SCRUM-275. Controls tab fixed with vertical `ControlsScroll` + `follow_focus`; reset bindings stays inside scroll, Back remains outside; runtime/UI/no-overlap/aim settings smokes PASS |
| [design_codex_apply_red_gold_button_kit_task.md](../tasks/design_codex_apply_red_gold_button_kit_task.md) | Design → Back-end | done | Jira: SCRUM-273. Red&Gold Dragon button kit applied: 15 types × 4 states in `assets/sprites/ui/frames/red_gold/`, runtime type mapping in `ui_screens.gd`, preview/docs updated, dark theme/UI no-overlap/runtime smokes PASS |
| [design_codex_apply_ornate_frame_kit_task.md](../tasks/design_codex_apply_ornate_frame_kit_task.md) | Design → Back-end | review | Jira: SCRUM-274. QA-ready after Design result in thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`; focused UI checks passed, umbrella caveat tracked by Back-end weapon-integrity work |
| [backend_unify_button_size_main_menu_standard_task.md](../tasks/backend_unify_button_size_main_menu_standard_task.md) | Back-end (UI) | done | Jira: SCRUM-264. Единая высота action-кнопок 104px, главное меню 380x104, стандарт применен к обычным action-кнопкам; служебные/card controls оставлены исключениями; UI/no-overlap/umbrella+focused smokes green |
| [backend_button_stretch_discipline_text_frame_task.md](../tasks/backend_button_stretch_discipline_text_frame_task.md) | Back-end (UI) | done | Jira: SCRUM-263. Широкие action-кнопки capped до 560px; text-heavy rewards/rest/upgrade/events используют info frame над короткой стандартной кнопкой; UI/no-overlap/umbrella+focused smokes green |
| [backend_unique_class_mechanics_framework_main_attribute_task.md](../tasks/backend_unique_class_mechanics_framework_main_attribute_task.md) | Back-end | done | Jira: SCRUM-256. Framework готов: `CLASS_MECHANIC_IDENTITIES` + ProgressionData API, 17 class main attributes, 51 weapon identities, docs + progression API/weapon/full smoke + global balance gates green |
| [backend_survivability_formulas_nerf_regen_vampirism_absorb_dodge_task.md](../tasks/backend_survivability_formulas_nerf_regen_vampirism_absorb_dodge_task.md) | Back-end | done | Jira: SCRUM-255. Regen/vampirism strongly nerfed; defense/dodge/absorb now diminishing with lower caps; tank/contact_swarm synthetic TTD 321.0s→38.5s; stat/survivability/API/global balance/runtime smokes green |
| [backend_crit_formulas_rebalance_task.md](../tasks/backend_crit_formulas_rebalance_task.md) | Back-end | done | Jira: SCRUM-247. Crit chance/power rebalanced with shared constants, diminishing chance cap 55%, crit damage cap 2.75; stat/API/balance/runtime smokes green |
| [backend_attribute_weapon_universal_synergy_task.md](../tasks/backend_attribute_weapon_universal_synergy_task.md) | Back-end | done | Jira: SCRUM-243. Universal 8×6 attribute×weapon archetype synergy map + soft cross-scaling in derived parameters; stat/API/progression/balance/full runtime smokes green |
| [backend_melee_classes_strengthen_unique_attacks_task.md](../tasks/backend_melee_classes_strengthen_unique_attacks_task.md) | Back-end | done | Jira: SCRUM-251. **QA: passed** (2981acf8, ре-QA) — изначально FAILED (флака proof-теста), фикс SCRUM-272 (`await`) устранил → `melee_unique_mechanics_test` 16/16 PASS; фича (execute/cleave/stagger/sustain) + баланс (51-пара коридор) зелёные |
| [backend_summoner_classes_strengthen_task.md](../tasks/backend_summoner_classes_strengthen_task.md) | Back-end | done | Jira: SCRUM-254. Разблокировано SCRUM-256; summon/leadership identities должны использовать class mechanic framework |
| [backend_auras_buffs_debuffs_system_task.md](../tasks/backend_auras_buffs_debuffs_system_task.md) | Back-end | done | Jira: SCRUM-245. Разблокировано SCRUM-256; aura/buff/debuff назначения должны использовать class mechanic framework |
| [backend_aim_modes_cursor_and_nearest_task.md](../tasks/backend_aim_modes_cursor_and_nearest_task.md) | Back-end | done | Jira: SCRUM-241. Aim mode selector added to Settings/Controls; nearest keeps auto-targeting, cursor routes melee/projectiles/beams/deploy/point-AoE through Player aim API; focused/UI/weapon/global balance/full runtime smokes green |
| [backend_remove_auto_movement_on_crit_dodge_task.md](../tasks/backend_remove_auto_movement_on_crit_dodge_task.md) | Back-end | done | Jira: SCRUM-253. Player-body crit dash заменен на неподвижный shadow burst, `shadow_backstab` Вора больше не телепортирует героя; runtime weapon/full smoke + API + global balance gates green |
| [backend_monster_elite_size_balance_rework_task.md](../tasks/backend_monster_elite_size_balance_rework_task.md) | Back-end | done | Jira: SCRUM-260. Enemy size profiles data-driven: mini_elite 1.05, route elite 1.68, boss 1.90; card elites slightly buffed HP/damage; hitbox/contact/HP-bar coherency tested; API/boss-elite/full smoke + global balance gates green |
| [backend_elites_bosses_unique_skills_mechanics_task.md](../tasks/backend_elites_bosses_unique_skills_mechanics_task.md) | Back-end | done | Jira: SCRUM-259. Data-driven mechanic catalog + unique patterns for 4 elites/5 bosses; boss-specific telegraph mechanics wired; codex/docs/tests updated; SCRUM-261 Design VFX handoff unblocked |
| [design_codex_unique_weapons_vfx_all_classes_015_task.md](../tasks/design_codex_unique_weapons_vfx_all_classes_015_task.md) | Design | done | Jira: SCRUM-258. **QA: passed** (2026-06-14) — 51 per-weapon D&D/painterly VFX plates `vfx_weapon_<weapon_id>.png` generated/imported for all class weapon identities; `AttackVfx.weapon_signature()` + `ClassWeapon` visual-only routing added; previews `scrum258_unique_weapon_vfx_contact/readability`; unique weapon/attack/hazard/status/melee/summoner/runtime smokes PASS |
| [backend_final_balance_audit_aoe_crowd_clear_task.md](../tasks/backend_final_balance_audit_aoe_crowd_clear_task.md) | Back-end | done | Jira: SCRUM-262. **QA: passed** (2f78c734) — финальный 0.1.5 balance/AoE audit PASS: 51 class×weapon пар в коридоре (solo ±20%, CCT ±30%, worst +22% doctor/plague_syringe/20), API+harness+отчёт+damage/survivability smoke зелёные, 0 FAIL |
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
| [bug_flaky_melee_unique_mechanics_arc_followup_task.md](../tasks/bug_flaky_melee_unique_mechanics_arc_followup_task.md) | Back-end | done | Jira: SCRUM-272. **QA: passed** (2026-06-14) — Berserk arc follow-up flake stabilized with same-frame CombatTargetQuery cache wait; 16/16 focused PASS + runtime smoke PASS; production code unchanged |
| [bug_umbrella_runtime_smoke_intermittent_failure_task.md](../tasks/bug_umbrella_runtime_smoke_intermittent_failure_task.md) | Back-end | done | Jira: SCRUM-257. **QA: passed** (5d7c2337) — freed-lambda warning eliminated; hero-radar/header umbrella flake fixed; 32/32 isolated umbrella PASS with 0 warnings; weapon/melee/UI/animation/meta regressions green |

## 0.1.5 — blocked / dependency-gated

Feature freeze снят. Эти задачи остаются `blocked` до указанных предпосылок и
не dispatch'ятся, пока blocker не будет снят исполнителем/PM.

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_codex_elite_boss_new_skills_vfx_task.md](../tasks/design_codex_elite_boss_new_skills_vfx_task.md) | Design | done | Jira: SCRUM-261. **QA: passed** (2026-06-14) — 13 boss/enemy VFX assets integrated VFX-only; hazard/attack/boss-elite/full runtime smokes PASS after duplicate cleanup; no bugs |

## CLEANUP — рефакторинг и чистка v2 (эпик SCRUM-266, запрос 2026-06-14)

ФАЗА 1 read-only аудиты идут сейчас (безопасно во время патча 0.1.5 — только
читают+отчёты). ФАЗА 2 (удаления/рефакторинг) сериализуется ПОСЛЕ балансового
патча на общих файлах. «done = чистый HEAD зелёный».

| Задача | Роль | Статус | Тема |
| --- | --- | --- | --- |
| cleanup_audit_code_deadcode_duplication_warnings_task | Back-end | done | Jira: SCRUM-267. Read-only code/deadcode/duplication audit complete; report `docs/design/reviews/cleanup_code_audit_2026_06.md`; spawned P1 duplicate-artifact cleanup SCRUM-270 |
| cleanup_remove_duplicate_artifact_files_task | Back-end | done | Jira: SCRUM-270. **QA: passed** (2026-06-14) — QA confirmed 275 duplicate ` N.` artifacts removed with backup; runtime/animation/content_registry smokes passed; not redispatched |
| cleanup_audit_unused_sprites_images_task | Design→Back-end | done | Jira: SCRUM-269. **QA: passed** (2026-06-14) — read-only asset/image audit complete; report `docs/design/reviews/cleanup_assets_audit_2026_06.md`; no dead gameplay art found; spawned orphan sidecar cleanup SCRUM-271 |
| cleanup_remove_orphan_import_sidecars_task | Back-end | done | Jira: SCRUM-271. File-isolated cleanup from SCRUM-269: removed 110 orphan double-extension sidecars from already-deleted duplicates; real assets not touched; audit/content_registry/unique_vfx/runtime smoke PASS |
| cleanup_audit_docs_full_update_task | Back-end | done | Jira: SCRUM-268. Docs-only audit/update complete; report `docs/design/reviews/cleanup_docs_audit_2026_06.md`, key docs aligned to 0.1.5/17 classes/51 weapons/5 bosses |

## Архив

≈222 завершённых задач не показываются на доске. Полный список и история —
в Jira (фильтр по эпику, статус «Готово») и в `docs/tasks/*.md` (Статус: done +
блок «## QA-Вердикт»). Прежняя длинная доска — в git-истории до 2026-06-13.
