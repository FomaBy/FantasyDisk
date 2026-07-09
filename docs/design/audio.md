# Аудио FantasyDisk

Обновлено: 2026-07-10 (SCRUM-968 — пак подключён в рантайм: `MUSIC_META`,
ротация боевых тем, round-timed outro, стингеры, `set_sfx_loop`; легаси
wav/mp3 удалены). Предыдущие ревизии: 2026-07-09 (SCRUM-966/967 — бардовский
пак), 2026-06-13 (SCRUM-154).

## Текущий пак (SCRUM-966 музыка / SCRUM-967 SFX / SCRUM-968 интеграция)

Файлы: `assets/audio/music/*.ogg` (13) и `assets/audio/sfx/*.ogg` (15) по спеке
`docs/design/systems/audio.md` (§2/§5/§7). Формат: OGG Vorbis 44.1 kHz
(музыка стерео q≈6, SFX моно q≈4). Подключение — `scripts/audio_manager.gd`:
`MUSIC_META` (loop/loop_offset проставляются кодом на загруженном
`AudioStreamOggVorbis`, .import не правится), shuffle-bag ротация боя,
`play_combat_music`/`begin_music_outro`/`play_music_stinger`/`set_sfx_loop`.

Полная таблица источников/лицензий/правок каждого файла:
`docs/design/references/audio_sources/SOURCES.md`. Сводка:

| Группа | Файлы | Источники | Лицензии |
| --- | --- | --- | --- |
| Музыка safe (меню/карта/магазин) | music_menu_tavern_warm, music_route_map_bard_journey, music_shop_campfire_inn | RandomMind (The Bard's Tale, Exploration), Kevin MacLeod (Suonatore di Liuto) | CC0 / CC BY 4.0 |
| Музыка боя (ротация ×4) | music_combat_bardic_skirmish_a/b, music_combat_ruined_courtyard, music_combat_fey_marsh | RandomMind (Minstrel Dance), MacLeod (Master of the Feast, Lord of the Land, Celtic Impulse) | CC0 / CC BY 4.0 |
| Элитка/боссы | music_elite_duel_300, music_boss_battle_300, music_final_boss_crescendo_300 | RandomMind (Battle), MacLeod (Drums of the Deep, The Escalation) | CC0 / CC BY 4.0 |
| Стингеры | music_sting_victory, music_sting_victory_epic, music_sting_defeat | RandomMind (Victory/Defeat Theme) | CC0 |
| SFX (15 id) | sfx_hit, sfx_hit_magic, sfx_hit_dot, sfx_player_hit, sfx_dodge, sfx_pickup_xp, sfx_pickup_money, sfx_level_up, sfx_purchase, sfx_ui_click, sfx_ui_back, sfx_ui_error, sfx_artifact_reveal, sfx_boss_phase, sfx_low_hp_pulse | Kenney (Impact Sounds, RPG Audio), artisticdude (RPG Sound Pack), bart (Heartbeat), qubodup (Ghost breath), AntumDeluge (Fire Crackling) + вырезки RandomMind/MacLeod | CC0 (+CC BY 4.0 у 2 вырезок) |

**CC BY-атрибуции обязательны** — канонический player-facing файл
`docs/CREDITS.md` (6 треков Kevin MacLeod, incompetech.com, CC BY 4.0; источник
блока — SOURCES.md). Игровой экран «Об игре/Благодарности» — хвост
`docs/tasks/SCRUM-968_ui_screens_tail.md` (ui_screens.gd был залочен).

### Нормализация и лупы (замеры 2026-07-09)

- Музыка: integrated **−16 LUFS ±0.3**, true peak ≤ −1.0 dBTP, LRA 1.6–5.7 LU;
  `gain_trim_db` для нового пака = 0 (§6 спеки выполняется файлами).
- Стингеры: −14 LUFS momentary-max, TP ≤ −2.0 dBTP.
- SFX: иерархия громкости группами через TP-потолки (hits −3 dBTP; dodge −4.5;
  пикапы/UI −6; hit_dot −8; low_hp_pulse −24 LUFS-S при TP −6.8) — короткие
  транзиенты не достигают буквенных LUFS-S-таргетов §6, отклонение
  задокументировано в SOURCES.md.
- Лупы: intro+loop (loop_offset в сек. — в SOURCES.md и манифесте мастеринга),
  швы EOF→loop_offset с равномощным кроссфейдом, амплитудный скачок ≤ 0.030 FS
  (методика SCRUM-154). `music_menu_tavern_warm` — авторский луп ×2
  (loop_offset 57.73 c); `music_combat_bardic_skirmish_a` (56.3 c) и
  `music_elite_duel_300` (78.9 c) — авторские лупы целиком, loop_offset 0
  (без отдельного интро — зафиксированное отклонение; вход маскируется
  кроссфейдом 0.9 c плеера).
- Пайплайн воспроизводим: `tools/audio_master.py` +
  `tools/audio_master_manifest.json` (нужны numpy+soundfile; scipy/pyloudnorm
  опциональны). ffmpeg в пайплайне не используется (libsndfile пишет ogg).

### Известные отклонения от спеки (на добор/плейтест)

- `music_elite_duel_300`: файл/луп 78.9 c при целевых 100–130/90–120 (−15% почти
  впритык). На 300 c — 3.8 прохода вместо 2.5–3. Кандидат на замену при находке
  более длинного CC-материала той же стилистики.
- В `music_combat_ruined_courtyard` нет hurdy-gurdy (перкуссия+лютня+флейта);
  в boss/final «хоровые гласные» отсутствуют/минимальны — CC-материал точного
  состава не найден, стилевые гардрейлы соблюдены.
- Тональная сверка соседних треков (меню→карта→магазин, §1) — за плейтестом:
  программная оценка лада не выполнялась.

## Легаси (удалено в SCRUM-968)

Плоские `assets/audio/*.wav|mp3` (3 трека RandomMind CC0 из SCRUM-154:
The Old Tower Inn / Minstrel Dance / Battle + 6 процедурных SFX генератора
`tools/generate_audio_assets.py`) удалены из репо после переключения всех id
на ogg-пак: рантайм-ссылок не осталось (grep по scripts/scenes/tests), история
— в git до коммита SCRUM-968. Прежние slot-id экранов живут как алиасы
(`menu`/`route_map`/`shop` → записи `MUSIC_META`), легаси `combat`/`boss` в
`play_music` роутятся в `play_combat_music` (AC «старые id замаплены»).
`MUSIC_GAIN_DB` заменён полем `gain_db` в `MUSIC_META` (пак −16 LUFS → трим 0).

## Кроссфейд и round-timed playback

`audio_manager.play_music`: при смене трека текущий уезжает на второй плеер и
затухает (0.9с), новый нарастает с −28 дБ до целевой громкости. Без щелчков.
Бой: `combat_director._start_combat` → `play_combat_music(kind, длительность
раунда)`; за 6 c (8 c у элиток/боссов) до конца таймера `main._process`
запускает идемпотентный `begin_music_outro` (ease-out до −40 dB на
PAUSABLE-якоре — фейд замирает вместе с паузой). Ранний конец боя (босс убит /
смерть) — fast-outro 1.2 c; поверх тишины — стингер результата
(`play_music_stinger`), затем экран/карта меняют трек штатным кроссфейдом.

## Проверка лупов

Headless-окружение не воспроизводит звук — стыки нового пака проверены
программно (`tools/audio_master.py`: скачок EOF→loop_offset ≤ 0.030 FS).
Прослушивание в игре — за плейтестом после SCRUM-968.
