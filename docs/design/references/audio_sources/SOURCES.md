# Источники и лицензии аудио-пака SCRUM-966/967

Обновлено: 2026-07-09. Все файлы `assets/audio/music/*.ogg` и `assets/audio/sfx/*.ogg`
собраны из курируемых CC0/CC-BY источников и обработаны `tools/audio_master.py`
(рецепт: `tools/audio_master_manifest.json`; LUFS-нормализация, true-peak лимит,
loop-edit с кроссфейдом шва, конверсия в OGG Vorbis 44.1 kHz, метаданные очищены —
vorbis-комменты содержат только `ENCODER=libsndfile`).

Лицензии: **CC0 1.0** — атрибуция не обязательна (указана из уважения).
**CC BY 3.0/4.0** — атрибуция ОБЯЗАТЕЛЬНА: строки из раздела «Обязательные
атрибуции» должны попасть в игровые credits (экран «Об игре/Благодарности» —
интеграция SCRUM-968+) и сопровождать дистрибуцию.
D&D-референсов в именах файлов и метаданных нет (гардрейл спеки §1.4).

## Музыка (assets/audio/music/)

| Файл | Исходный трек | Автор | Лицензия | Источник (URL) | Что изменено |
| --- | --- | --- | --- | --- | --- |
| music_menu_tavern_warm.ogg | Medieval: The Bard's Tale (loop version) | RandomMind | CC0 | https://opengameart.org/content/medieval-the-bards-tale | авторский луп ×2 (интро = 1-й проход, loop_offset 57.73 c), −16 LUFS, ogg q≈6 |
| music_route_map_bard_journey.ogg | Medieval: Exploration | RandomMind | CC0 | https://opengameart.org/content/medieval-exploration | вырезан intro 2.76 c + луп 84.5 c (39 тактов @110.5 BPM), кроссфейд шва 0.4 c, −16 LUFS |
| music_shop_campfire_inn.ogg | Suonatore di Liuto | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/Suonatore%20di%20Liuto.mp3 | intro 2.15 c + луп 75.8 c (22 такта @69.5 BPM), кроссфейд 0.5 c, −16 LUFS |
| music_combat_bardic_skirmish_a.ogg | Medieval: Minstrel Dance (loop version) | RandomMind | CC0 | https://opengameart.org/content/medieval-minstrel-dance | авторский луп без изменений структуры (loop_offset 0), −16 LUFS |
| music_combat_bardic_skirmish_b.ogg | Master of the Feast | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/Master%20of%20the%20Feast.mp3 | intro 2.96 c + луп 65.4 c (33 такта @121.5 BPM), кроссфейд 0.35 c, −16 LUFS |
| music_combat_ruined_courtyard.ogg | Lord of the Land | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lord%20of%20the%20Land.mp3 | intro 2.69 c + луп 62.7 c (29 тактов @110.5 BPM), кроссфейд 0.4 c, −16 LUFS |
| music_combat_fey_marsh.ogg | Celtic Impulse | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/Celtic%20Impulse.mp3 | ресемпл 48→44.1 kHz, intro 2.38 c + луп 64.2 c (38 тактов @141.5 BPM), кроссфейд 0.35 c, −16 LUFS |
| music_elite_duel_300.ogg | Medieval: Battle | RandomMind | CC0 | https://opengameart.org/content/medieval-battle | полная (лупящаяся) версия целиком, loop_offset 0, −16 LUFS |
| music_boss_battle_300.ogg | Drums of the Deep | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/Drums%20of%20the%20Deep.mp3 | intro 5.31 c + луп 128.8 c (41 такт @76.5 BPM), кроссфейд 0.8 c, −16 LUFS |
| music_final_boss_crescendo_300.ogg | The Escalation | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/mp3-royaltyfree/The%20Escalation.mp3 | intro 4.87 c + луп 138.7 c (@119 BPM), кроссфейд 1.2 c, −16 LUFS |
| music_sting_victory.ogg | Medieval: Victory Theme | RandomMind | CC0 | https://opengameart.org/content/medieval-victory-theme | вырез открывающей фразы 3.2 c + фейд 0.6 c, −14 LUFS (momentary max) |
| music_sting_victory_epic.ogg | Medieval: Victory Theme | RandomMind | CC0 | https://opengameart.org/content/medieval-victory-theme | вырез поздней кульминации (20.6 c) 5.6 c + фейд 1.1 c, −14 LUFS |
| music_sting_defeat.ogg | Medieval: Defeat Theme | RandomMind | CC0 | https://opengameart.org/content/medieval-defeat-theme | вырез первой фразы 4.3 c + фейд 0.9 c, −14 LUFS |

## SFX (assets/audio/sfx/)

Все SFX — фоли-слоение/трим/питч (ресемпл)/фильтры из источников ниже; моно
44.1 kHz (кроме stereo `sfx_artifact_reveal`, `sfx_low_hp_pulse`), ogg q≈4.

Источники-паки:

- **Kenney — Impact Sounds** (CC0): https://kenney.nl/assets/impact-sounds
- **Kenney — RPG Audio** (CC0): https://kenney.nl/assets/rpg-audio
- **artisticdude — RPG Sound Pack** (CC0): https://opengameart.org/content/rpg-sound-pack
- **bart (OGA) — Heartbeat sounds** (CC0): https://opengameart.org/content/heartbeat-sounds
- **qubodup — Ghost breath** (CC0): https://opengameart.org/content/ghost-breath
- **AntumDeluge — Fire Crackling** (CC0): https://opengameart.org/content/fire-crackling
- RandomMind — Medieval: Victory Theme (CC0, см. выше) — музыкальные вырезки
- Kevin MacLeod — Suonatore di Liuto / Drums of the Deep (CC BY 4.0, см. выше) — микро-вырезки

| Файл | Слои (источник → правки) | Лицензии |
| --- | --- | --- |
| sfx_hit.ogg | Kenney impactPunch_medium_000 (трим 0.13 c) + impactWood_light_000 (−7 dB) | CC0 |
| sfx_hit_magic.ogg | Kenney RPG cloth2 (HP 500 Hz) + impactSoft_medium_000 (LP 2.5 kHz, −6 dB) | CC0 |
| sfx_hit_dot.ogg | Fire Crackling fire-1.wav (вырез 1.20–1.29 c, HP 400 Hz, тихий потолок −8 dBTP) | CC0 |
| sfx_player_hit.ogg | Kenney impactPunch_heavy_000 (питч 0.88) + RPG clothBelt (−8 dB) | CC0 |
| sfx_dodge.ogg | RPG Sound Pack battle/swing.wav (LP 3.2 kHz, питч 0.95) + Kenney cloth1 (−5 dB) + footstep_carpet_000 (LP 2 kHz, −12 dB) | CC0 |
| sfx_pickup_xp.ogg | Suonatore di Liuto — одиночный щипок лютни (0.43–0.57 c) | CC BY 4.0 (MacLeod) |
| sfx_pickup_money.ogg | Kenney RPG handleCoins (вырез 0.41–0.57 c, LP 6 kHz) | CC0 |
| sfx_level_up.ogg | Medieval: Victory Theme — открывающий флориш 0.75 c | CC0 |
| sfx_purchase.ogg | Kenney RPG handleCoins2 + handleSmallLeather (−2 dB, смещение 0.10 c) | CC0 |
| sfx_ui_click.ogg | Kenney impactWood_light_001 (трим 0.075 c) | CC0 |
| sfx_ui_back.ogg | Kenney impactWood_light_001 (питч 0.84 — ниже тоном) | CC0 |
| sfx_ui_error.ogg | Kenney impactWood_medium_000 (питч 0.75, LP 2.2 kHz) | CC0 |
| sfx_artifact_reveal.ogg | Victory Theme — аккордовый расцвет 20.5–21.45 c + Kenney impactSoft_heavy_000 (питч 0.7, −5 dB — удар ручного барабана) | CC0 |
| sfx_boss_phase.ogg | Kenney impactSoft_heavy_000 (питч 0.62 — war drum) + Drums of the Deep 0–0.9 c (LP 550 Hz, −7 dB — низкий «рог»-дрон) | CC0 + CC BY 4.0 (MacLeod) |
| sfx_low_hp_pulse.ogg | Heartbeat sounds heartbeat_slow ×3 (LP 900 Hz, ~66 BPM, луп 5.4 c) + Ghost breath ×2 (питч 1.267, LP 1.5 kHz, −6 dB) — лупится, шов кроссфейд 0.12 c | CC0 |

## Обязательные атрибуции (CC BY)

В credits игры и дистрибутивные материалы включить:

```
"Suonatore di Liuto", "Master of the Feast", "Lord of the Land",
"Celtic Impulse", "Drums of the Deep", "The Escalation"
Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
http://creativecommons.org/licenses/by/4.0/
```

CC0-авторы (атрибуция добровольная, указываем из уважения): RandomMind
(opengameart.org/users/randommind), Kenney (kenney.nl), artisticdude, bart,
qubodup, AntumDeluge — все OpenGameArt.org / kenney.nl, CC0 1.0.

## Замеры мастеринга (2026-07-09, tools/audio_master.py)

Музыка: integrated −16.0…−16.3 LUFS (допуск ±0.5), true peak ≤ −1.0 dBTP,
LRA 1.6–5.7 LU (норма ≤9), швы лупов ≤ 0.030 FS (уровень «мягкого» стыка по
методике SCRUM-154). Стингеры: −14 LUFS (momentary max), TP ≤ −2.0 dBTP.
SFX: иерархия групп через TP-потолки — hits/праздничные −3 dBTP, dodge −4.5,
пикапы/UI −6, hit_dot −8, low_hp_pulse −6.8 dBTP при −24 LUFS-S(max)
(короткие транзиенты физически не достигают LUFS-таргетов §6 при заданных
потолках — выравнивание внутри группы по пикам, отклонение зафиксировано).
Полный лог: tools/audio_master.py --manifest tools/audio_master_manifest.json.
