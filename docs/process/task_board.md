# Task Board — FantasyDisk

Обновлено: 2026-06-11
Ведет: PM-чат. Статусы: `new` | `in_progress` | `review` | `done` | `blocked` | `unknown`.

`unknown` — задача создана до введения доски, статус в файле не указан; уточняется при следующем контакте с исполнителем.

## Новые (выданы PM 2026-06-11, пакет «2K фоны + усиление элиток + боевой фидбек»)

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_arena_backgrounds_2k_native_task.md](../tasks/design_arena_backgrounds_2k_native_task.md) | Design | in_progress | 4 фона арены в нативном 2560x1440. В работе у Designer с 2026-06-11 |
| [design_elite_sprites_upsize_attack_vfx_task.md](../tasks/design_elite_sprites_upsize_attack_vfx_task.md) | Design | in_progress | Спрайты элиток 256x256 + 5 VFX атак. В работе у Designer с 2026-06-11, приоритет |
| [backend_elite_overhaul_size_unique_attacks_task.md](../tasks/backend_elite_overhaul_size_unique_attacks_task.md) | Back-end | in_progress | Размер элиток x1.35 + уникальные атаки с telegraph. В работе у Backend с 2026-06-11 |
| [animation_elite_unique_attacks_task.md](../tasks/animation_elite_unique_attacks_task.md) | Animator | blocked | Анимации фаз атак элиток. Не отправлена: чата Animator нет; ждет фаз атак от Backend |
| [backend_combat_feedback_hp_bars_hitbox_hammer_nerf_task.md](../tasks/backend_combat_feedback_hp_bars_hitbox_hammer_nerf_task.md) | Back-end | in_progress | HP-бары мобов, ревизия contact-хитбоксов, красная виньетка урона, молот 200→100. В работе у Backend с 2026-06-11 |

## Новые (выданы PM 2026-06-11, пакет «идентичность оружия + баланс классов + прицеливание»)

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [backend_berserk_weapon_identity_rebalance_task.md](../tasks/backend_berserk_weapon_identity_rebalance_task.md) | Back-end | in_progress | Меч — узкая полоса/быстро/урон; топор — широкая дуга слабее; молот — слабый старт, мощный рост. В работе с 2026-06-11 |
| [backend_attack_aim_nearest_enemy_fix_task.md](../tasks/backend_attack_aim_nearest_enemy_fix_task.md) | Back-end | in_progress | Баг: атака по направлению движения → целиться в ближайшего врага. В работе с 2026-06-11 |
| [backend_mage_buff_guitarist_rework_task.md](../tasks/backend_mage_buff_guitarist_rework_task.md) | Back-end | in_progress | Маг: 2 луча/2 взрыва; бас — мин. урон + скорость; амп — живет на земле, лимит от Лидерства. В работе с 2026-06-11 |
| [design_sprite_quality_audit_cleanup_task.md](../tasks/design_sprite_quality_audit_cleanup_task.md) | Design | new | Перевыдана 2026-06-11: лишние куски текстур на краях спрайтов по всей игре |

## Новые (выданы PM 2026-06-11, пакет «артефакты + таймер + чистка ассетов и кода»)

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [design_artifact_icons_fantasy_restyle_task.md](../tasks/design_artifact_icons_fantasy_restyle_task.md) | Design | new | 46 иконок артефактов в фэнтези-мультяшном стиле + ассеты таймера |
| [codex_design_route_map_background_task.md](../tasks/codex_design_route_map_background_task.md) | Design owner + Codex image executor | done | Закрыта 2026-06-11: `assets/backgrounds/route_map_backdrop.png` готов, 2560x1440, low-contrast center; интеграция — через готовый Backend hook |
| [backend_artifact_ui_timer_shop_wall_task.md](../tasks/backend_artifact_ui_timer_shop_wall_task.md) | Back-end | new | Артефакты иконками в HUD/паузе, магазин на «стене», таймер сверху по центру, красный при <=5с |
| [backend_unused_assets_cleanup_task.md](../tasks/backend_unused_assets_cleanup_task.md) | Back-end | new | Карта использования ассетов, неиспользуемые — в backup с отчетом |
| [backend_performance_code_quality_review_task.md](../tasks/backend_performance_code_quality_review_task.md) | Back-end | new | Перевыдана с расширением: + закрыть все debug-ошибки, удалить мертвый код. Выполнять последней |
| [animation_player_motion_smoothness_task.md](../tasks/animation_player_motion_smoothness_task.md) | Animator | blocked | Плавность движения, замахи под новые формы, walk мага. Чата Animator нет; зависит от backend/design |

## Активные / Неподтвержденные

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [animation_movement_overhaul_task.md](../tasks/animation_movement_overhaul_task.md) | Animator | unknown | Статус в файле не указан |
| [animation_natural_motion_current_sprites_task.md](../tasks/animation_natural_motion_current_sprites_task.md) | Animator | unknown | Статус в файле не указан |
| [animator_fix_cutout_rig_parse_errors_task.md](../tasks/animator_fix_cutout_rig_parse_errors_task.md) | Animator | unknown | Статус в файле не указан |
| [backend_dark_mage_guitarist_balance_amp_cleanup_task.md](../tasks/backend_dark_mage_guitarist_balance_amp_cleanup_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_escape_stats_compact_grouped_layout_task.md](../tasks/backend_escape_stats_compact_grouped_layout_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_event_node_click_and_screen_art_integration_task.md](../tasks/backend_event_node_click_and_screen_art_integration_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_integrate_stat_icons_hud_remove_obstacles_task.md](../tasks/backend_integrate_stat_icons_hud_remove_obstacles_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_map_2k_camera_zoom_task.md](../tasks/backend_map_2k_camera_zoom_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_performance_code_quality_review_task.md](../tasks/backend_performance_code_quality_review_task.md) | Back-end | unknown | Статус в файле не указан |
| [backend_route_map_start_selection_scroll_task.md](../tasks/backend_route_map_start_selection_scroll_task.md) | Back-end | unknown | Статус в файле не указан |
| [design_escape_stats_fantasy_frames_task.md](../tasks/design_escape_stats_fantasy_frames_task.md) | Design | unknown | Статус в файле не указан |
| [design_event_shop_campfire_backgrounds_style_unification_task.md](../tasks/design_event_shop_campfire_backgrounds_style_unification_task.md) | Design | unknown | Статус в файле не указан |
| [design_sprite_quality_audit_cleanup_task.md](../tasks/design_sprite_quality_audit_cleanup_task.md) | Design | unknown | Статус в файле не указан |
| [design_stat_icons_hud_visual_task.md](../tasks/design_stat_icons_hud_visual_task.md) | Design | unknown | Статус в файле не указан |
| [design_visual_redesign_after_animation_task.md](../tasks/design_visual_redesign_after_animation_task.md) | Design | unknown | Статус в файле не указан |
| [documentation_post_changes_domain_split_task.md](../tasks/documentation_post_changes_domain_split_task.md) | Back-end (docs) | unknown | Повторяемая задача после крупных пакетов изменений |
| [elite_boss_wave_balance_camera_task.md](../tasks/elite_boss_wave_balance_camera_task.md) | Back-end | unknown | Статус в файле не указан |

## Закрытые

| Задача | Роль | Статус | Примечание |
| --- | --- | --- | --- |
| [animation_smoke_test_sliced_rig_update_task.md](../tasks/animation_smoke_test_sliced_rig_update_task.md) | Animator | done | Закрыта 2026-06-10 |
| [backend_main_gd_module_split_task.md](../tasks/backend_main_gd_module_split_task.md) | Back-end | done | Выполнена 2026-06-10 |
| [backend_meta_ascension_levels_task.md](../tasks/backend_meta_ascension_levels_task.md) | Back-end | done | Выполнена 2026-06-10 |
| [design_cartoon_character_style_fix_task.md](../tasks/design_cartoon_character_style_fix_task.md) | Design | done | Реализовано 2026-06-10 + усиление по уточнению |
| [design_dark_mage_sprite_legs_rework_task.md](../tasks/design_dark_mage_sprite_legs_rework_task.md) | Design | done | Закрыта 2026-06-11: нейтральная стойка, ноги читаемы, rig-части пересобраны, registry обновлен |
