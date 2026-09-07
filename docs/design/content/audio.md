<!-- content-registry-section -->

# FantasyDisk Content Registry — Звуковые Ассеты

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Звуковые Ассеты

Бардовский пак SCRUM-966/967, интеграция SCRUM-968 (`scripts/audio_manager.gd`:
`SFX_PATHS`/`MUSIC_META`). Slot-id экранов: `menu`/`route_map`/`shop` — алиасы
на треки ниже; бой — `play_combat_music(kind, duration)`.

| ID | Файл | Использование |
| --- | --- | --- |
| `hit` | `assets/audio/sfx/sfx_hit.ogg` | Попадание по врагу (physical/true) |
| `hit_magic` | `assets/audio/sfx/sfx_hit_magic.ogg` | Попадание магией (`damage_type == "magic"`) |
| `hit_dot` | `assets/audio/sfx/sfx_hit_dot.ogg` | Тик DoT (`damage_type == "dot"`) |
| `player_hit` | `assets/audio/sfx/sfx_player_hit.ogg` | Урон по игроку |
| `dodge` | `assets/audio/sfx/sfx_dodge.ogg` | Уворот игрока |
| `pickup_xp` | `assets/audio/sfx/sfx_pickup_xp.ogg` | Подбор опыта |
| `pickup_money` | `assets/audio/sfx/sfx_pickup_money.ogg` | Подбор денег |
| `level_up` | `assets/audio/sfx/sfx_level_up.ogg` | Получение уровня |
| `purchase` | `assets/audio/sfx/sfx_purchase.ogg` | Успешная покупка (вызовы — ui_screens-хвост SCRUM-968) |
| `ui_click` | `assets/audio/sfx/sfx_ui_click.ogg` | Подтверждение кнопки (ui_screens-хвост) |
| `ui_back` | `assets/audio/sfx/sfx_ui_back.ogg` | Назад/отмена (ui_screens-хвост) |
| `ui_error` | `assets/audio/sfx/sfx_ui_error.ogg` | Отказ действия (ui_screens-хвост) |
| `artifact_reveal` | `assets/audio/sfx/sfx_artifact_reveal.ogg` | Показ артефакт-награды (ui_screens-хвост) |
| `boss_phase` | `assets/audio/sfx/sfx_boss_phase.ogg` | Смена фазы босса (boss.gd) |
| `low_hp_pulse` | `assets/audio/sfx/sfx_low_hp_pulse.ogg` | Луп при HP<30% (`set_sfx_loop`, player.gd) |
| `music_menu_tavern_warm` | `assets/audio/music/music_menu_tavern_warm.ogg` | Меню и мета-экраны (alias `menu`) |
| `music_route_map_bard_journey` | `assets/audio/music/music_route_map_bard_journey.ogg` | Карта маршрута (alias `route_map`) |
| `music_shop_campfire_inn` | `assets/audio/music/music_shop_campfire_inn.ogg` | Safe-узлы: магазин/костёр/событие/сундук (alias `shop`) |
| `music_combat_bardic_skirmish_a` | `assets/audio/music/music_combat_bardic_skirmish_a.ogg` | Обычный бой, ротация №1 |
| `music_combat_bardic_skirmish_b` | `assets/audio/music/music_combat_bardic_skirmish_b.ogg` | Обычный бой, ротация №2 |
| `music_combat_ruined_courtyard` | `assets/audio/music/music_combat_ruined_courtyard.ogg` | Обычный бой, ротация №3 (акт 2 приоритет) |
| `music_combat_fey_marsh` | `assets/audio/music/music_combat_fey_marsh.ogg` | Обычный бой, ротация №4 (без актового приоритета) |
| `music_elite_duel_300` | `assets/audio/music/music_elite_duel_300.ogg` | Элитный бой (300 c) |
| `music_boss_battle_300` | `assets/audio/music/music_boss_battle_300.ogg` | Промежуточный босс акта 1 (300 c) |
| `music_final_boss_crescendo_300` | `assets/audio/music/music_final_boss_crescendo_300.ogg` | Финальный босс акта 2 / секретный босс (300 c) |
| `music_sting_victory` | `assets/audio/music/music_sting_victory.ogg` | Стингер победы обычного боя |
| `music_sting_victory_epic` | `assets/audio/music/music_sting_victory_epic.ogg` | Стингер победы над элиткой/боссом |
| `music_sting_defeat` | `assets/audio/music/music_sting_defeat.ogg` | Стингер поражения |
