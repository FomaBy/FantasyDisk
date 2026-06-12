# Аудио FantasyDisk

Обновлено: 2026-06-13 (SCRUM-154 — струнный тавернный эмбиент).

## Музыка

| Слот | Файл | Трек | Автор | Лицензия | Источник | Луп |
| --- | --- | --- | --- | --- | --- | --- |
| Меню/мета | `assets/audio/music_menu_tavern.wav` | Medieval: The Old Tower Inn | RandomMind | CC0 | https://opengameart.org/content/medieval-the-old-tower-inn | Авторский loop-WAV; шов дополнительно сглажен микро-фейдом 23мс (скачок на стыке 9748 -> 0 сэмплов) |
| Бой | `assets/audio/music_combat_minstrel.wav` | Medieval: Minstrel Dance | RandomMind | CC0 | https://opengameart.org/content/medieval-minstrel-dance | Авторский loop-WAV (скачок на стыке 1436 — мягкий) |
| Босс | `assets/audio/music_boss_battle.mp3` | Medieval: Battle | RandomMind | CC0 | https://opengameart.org/content/medieval-battle | AudioStreamMP3.loop = true (стык 2 сэмпла — бесшовно) |

CC0 = атрибуция не обязательна; указана из уважения в кодексе («Об игре/Благодарности», если раздел есть) и здесь.

## Нормализация

Замеренный RMS (первая минута, PCM16): меню −19.8 dBFS, бой −14.6, босс −15.6.
Выравнивание к ~−17 dBFS per-track поправками `audio_manager.MUSIC_GAIN_DB`
(меню +2.8 дБ, бой −2.4, босс −1.4) поверх базовой `MUSIC_VOLUME_DB` −8 дБ —
слайдеры громкости работают как раньше.

## Кроссфейд

`audio_manager.play_music`: при смене трека текущий уезжает на второй плеер и
затухает (0.9с), новый нарастает с −28 дБ до целевой громкости. Без щелчков.
Босс-бой включает слот `boss` (combat_director._start_combat).

## Проверка лупов

Headless-окружение не воспроизводит звук — стыки проверены программно
(амплитудный скачок первый/последний сэмпл, см. таблицу). Прослушивание в
игре — за плейтестом.

## Бэкап

Старые `music_menu.wav` / `music_combat.wav` — в `build/cleanup_backup_2026_06_12/audio/`, из assets удалены (git rm).

## SFX

Без изменений: `sfx_*.wav` (см. `audio_manager.SFX_PATHS`).
