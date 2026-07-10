# BUG: Atlas windowed focused test оставляет ObjectDB/resources

Статус: done
Версия: 0.2.1
Jira: SCRUM-1031
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1031`
Приоритет: normal
Роль: Back-end / QA tooling
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

Claimed scope: `tests/atlas_scrum970_clickability_test.gd`, this mirror and the
windowed QA lifecycle protocol. Atlas production layout/semantics and
`scripts/ui_screens.gd` remain read-only. Diagnostics are verified from process
logs and are not suppressed.

## Reproduction

На production `origin/dev` `b243d6e26` и повторно после rebase на
`ee508d559`, с уникальным scratch `user://`:

```bash
HOME=<scratch> XDG_DATA_HOME=<scratch> \
  python3 tools/godot_gate.py --path . \
  --script res://tests/atlas_scrum970_clickability_test.gd -- \
  --user-data-dir=<scratch>
```

## Expected

Функциональный PASS завершается без ObjectDB/resource lifecycle diagnostics.

## Actual

Все четыре viewport и восемь windowed screenshots проходят, затем процесс
иногда сообщает:

```text
WARNING: 4 ObjectDB instances were leaked at exit
ERROR: 2 resources still in use at exit
```

Implementation pre-land также видел тот же diagnostic в одном windowed run.
Headless focused run чистый. Это non-blocking QA-tooling follow-up: визуальное и
интерактивное поведение SCRUM-1024 принято отдельно.

На свежем `origin/dev` перед правкой требуемая серия случайно прошла `5/5`, но
сразу после первого teardown-hardening run исходный diagnostic воспроизвёлся
`1/2`. Повтор с `--verbose` поймал его на седьмом запуске и дал точные типы:

```text
OggPacketSequence
AudioStreamOggVorbis
AudioStreamPlaybackOggVorbis
OggPacketSequencePlayback
music_menu_tavern_warm.ogg
```

Это доказало, что intermittent leak принадлежит не Atlas `SubViewportTexture`,
а меню-музыке глобального `AudioManager`, запущенной `Main` внутри windowed
fixture и остановленной только слишком поздно во время общего SceneTree quit.

## Implementation Result

- Teardown отключает новые обновления owned `SubViewport`, освобождает его
  `Main`/children первым и проверяет child + viewport lifetime через `WeakRef`
  barriers; UI/assertion paths не менялись.
- После всей четырёхразмерной матрицы windowed test явно вызывает публичный
  `AudioManager.stop_music()` и ждёт шесть кадров до `quit()`, чтобы audio thread
  отпустил Ogg playback handles до общего autoload/AudioServer shutdown.
- Headless path не трогает отключённый AudioManager; production audio/UI code,
  Atlas behavior and screenshots remain unchanged.

## Acceptance Criteria

- `SubViewport`/`Main` и связанные ресурсы освобождаются детерминированно;
- windowed focused matrix проходит 5/5 без ObjectDB/resource warning;
- headless focused matrix, viewport bounds, real pointer, preview-only, Buy,
  tooltip, dossier scroll и medallion focus assertions не ослаблены;
- полный runtime smoke остаётся зелёным;
- результат синхронизирован в Jira/docs и landed в `dev`.

## Verification

- exact pre-fix `--verbose` reproduction: leaked menu Ogg playback chain listed
  above;
- post-fix windowed matrix: `5/5` clean, no `ObjectDB instances were leaked`
  and no `resources still in use at exit`;
- final focused windowed run after rebase to `origin/dev` `daf427b15`: PASS,
  diagnostics clean;
- focused headless run: PASS;
- `tests/runtime_smoke_test.gd`: PASS;
- independent pre-land code/evidence review: PASS, no actionable findings.

Implementation landed in `origin/dev` as `365813dd8`; Jira routed to
`Контроль качества` for an independent runtime verdict.

Disk cleanup: pending removal of task-only `.godot/`, `build/qa/scrum1024`, and
the disposable worktree after push/QA handoff.
