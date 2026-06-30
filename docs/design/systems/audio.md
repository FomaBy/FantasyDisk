# Audio

Обновлено: 2026-06-13

Этот файл описывает аудиосистему `dev` / sprint target 0.1.5. Snapshot полного состояния: `docs/design/current_game_state.md`. Канонические ID: `docs/design/content_registry.md`. Музыкальная подсистема введена в SCRUM-154; отчёты ревью — `docs/design/reviews/`.

Источник истины — autoload `scripts/audio_manager.gd` (`AudioManager`). Этот документ — обзор для дизайна, не дублирует код построчно.

## Архитектура

- `AudioManager` — autoload-узел с `process_mode = PROCESS_MODE_ALWAYS` (звук идёт и на паузе).
- В headless (`DisplayServer.get_name() == "headless"`, smoke-тесты) аудио полностью отключается (`_disabled = true`): микшера нет, иначе остаются висячие `AudioStreamPlayback` при выходе.
- Шины создаются программно поверх дефолтного layout (в нём только `Master`): `Music` и `SFX` добавляются в `_ensure_audio_buses` и шлются в `Master`.
- При выходе/закрытии (`_exit_tree`, `NOTIFICATION_WM_CLOSE_REQUEST`, `NOTIFICATION_PREDELETE`) стримы останавливаются и отвязываются (`_release_audio_refs`), чтобы AudioServer не ругался «resources still in use at exit».

## SFX

- Пул из `SFX_POOL_SIZE = 8` плееров `AudioStreamPlayer` на шине `SFX`, базовая громкость `SFX_VOLUME_DB = -4.0`.
- `play_sfx(id)` берёт первый свободный плеер пула; если все заняты — звук пропускается (без очереди).
- Троттлинг: один и тот же `id` не повторяется чаще `SFX_MIN_REPEAT_INTERVAL = 0.05` с — толпа врагов не спамит идентичный звук.
- Текущие звуки (`SFX_PATHS`): `hit`, `player_hit`, `dodge`, `pickup_xp`, `pickup_money`, `level_up`.

## Музыка

- Один основной плеер `_music_player` + второй `_music_player_fade` для кроссфейда, оба на шине `Music`, база `MUSIC_VOLUME_DB = -8.0`.
- Треки (`MUSIC_PATHS`): `menu` (`music_menu_tavern.wav`), `combat` (`music_combat_minstrel.wav`), `boss` (`music_boss_battle.mp3`).
- Луп: WAV выставляют `LOOP_FORWARD` (`loop_begin = 0`, `loop_end` по размеру данных), MP3 — `loop = true`.
- Источник треков (SCRUM-154): RandomMind, CC0 (OpenGameArt) — струнный тавернный эмбиент. `menu` = «The Old Tower Inn» (шов лупа сглажен микро-фейдом ~23 мс), `combat` = «Minstrel Dance», `boss` = «Battle».
- Нормализация громкости: `MUSIC_GAIN_DB` (`menu +2.8`, `combat -2.4`, `boss -1.4` dB) к ~−17 dBFS по замеренному RMS; целевая громкость трека = `MUSIC_VOLUME_DB + MUSIC_GAIN_DB[id]`.

### Кроссфейд

`play_music(id)` при смене трека (`MUSIC_CROSSFADE_SEC = 0.9`):

1. Уходящий трек переносится на `_music_player_fade` (с текущей позиции воспроизведения) и затухает до −40 dB.
2. Новый трек стартует на `_music_player` и нарастает от −28 dB до целевой громкости.
3. По завершении tween fade-плеер останавливается.

Повторный вызов с тем же `id` на играющем плеере только обновляет громкость (без перезапуска). Неизвестный `id` → `stop_music()`.

## Источники переключения музыки

- Меню/карта маршрута: `ui_screens.gd` и `route_map_screen.gd` → `_play_music("menu")`.
- Бой: `combat_director.gd` → `_play_music("boss" if is_boss_fight else "combat")`.
- Маршрутизация идёт через `main.gd` (`_play_music` → `AudioManager.play_music`).

## Настройки громкости

- `apply_volume_settings(settings)` применяется мгновенно к уже играющим стримам (меняет громкость шин).
- Ключи (см. `scripts/game_settings.gd`): `master_volume`, `music_volume`, `sfx_volume` (линейные 0..1) и флаги `music_enabled`, `sfx_enabled`.
- Линейная громкость переводится в dB через `linear_to_db(max(volume, 0.0001))`; выключенная категория мьютит шину (`set_bus_mute`).
- Применяется из `main.gd` при старте/смене настроек.

### Аудит (SCRUM-720)

`audio_manager.gd` пересмотрен, поведение не менялось:

- Шины `Music`/`SFX` создаются программно (`_ensure_audio_buses`) поверх дефолтного
  Master-лэйаута; `apply_volume_settings` меняет громкость/мьют уже играющих шин —
  мгновенное применение сохранено.
- Headless (smoke) полностью отключает аудио (`_disabled`), а `_release_audio_refs`
  на `_exit_tree`/закрытии окна снимает playback-хэндлы — нет «resources still in
  use at exit».
- Луп WAV считается в КАДРАХ с учётом каналов/битности (SCRUM-646), MP3 — `loop=true`;
  кроссфейд меню↔бой идёт через второй плеер. Регрессий не найдено.

## Связанные документы

- Меню звука и регуляторы: `docs/design/systems/menus_ui.md`.
- Боевой контекст переключения треков: `docs/design/systems/combat.md`.
- Полный снимок состояния: `docs/design/current_game_state.md`.
