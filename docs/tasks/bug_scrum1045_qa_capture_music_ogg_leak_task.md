# BUG: QA capture tools leak menu-music Ogg resources on Metal

Статус: new
Jira: SCRUM-1045
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Роль: Back-end / QA tooling
Найдено QA при тестировании: SCRUM-989
Locked paths: `tools/capture_scrum985_level_up.gd`,
`tools/capture_scrum982_987_988_attribute_shop.gd`,
`tools/capture_scrum981_gold_menu_shell.gd`, optional shared test-only teardown
helper; production audio/UI paths are read-only.

## Воспроизведение

На свежем `origin/dev` `76789a9dd` запустить любой из трёх capture tools
windowed через `tools/godot_gate.py` с Metal и уникальным `user-data-dir`.
Функциональный capture завершается, но процесс сообщает:

```text
WARNING: 4 ObjectDB instances were leaked at exit
ERROR: 2 resources still in use at exit
```

Повтор `capture_scrum985_level_up.gd` с `--verbose` показывает:

```text
OggPacketSequence
AudioStreamOggVorbis
AudioStreamPlaybackOggVorbis
OggPacketSequencePlayback
music_menu_tavern_warm.ogg
```

## Ожидание / Реальность

Ожидание: каждый windowed capture проходит обязательный lifecycle gate из
`docs/process/qa_protocol.md`: owned `Main`/`SubViewport` освобождены
child-first, глобальная музыка остановлена до `SceneTree.quit()`, после stop
есть frame barrier для audio thread, stderr чист от lifecycle diagnostics.

Реальность: все три fixture завершаются exit `0`, но оставляют одинаковую
Ogg playback chain. Функциональная геометрия и Metal screenshots Level Up,
Victory и Attribute Shop на `1280x720`, `1920x1080`, `2560x1440` визуально
зелёные. Предыдущий SCRUM-1031 исправил только
`tests/atlas_scrum970_clickability_test.gd`, поэтому это не дубль его scope.

## Acceptance Criteria

- Все три capture tools завершаются windowed Metal без ObjectDB/resource leak.
- Teardown не скрывает diagnostics и не меняет production `AudioManager`.
- Headless focused/geometry gates остаются зелёными.
- Metal-матрица трёх разрешений сохраняет текущий UI/content-zone contract.
- Полный `tests/runtime_smoke_test.gd` проходит.

SCRUM-1045 блокирует umbrella QA SCRUM-989 до чистого windowed lifecycle gate.
