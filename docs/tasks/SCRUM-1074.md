# SCRUM-1074 — Atlas focused Metal test lifecycle leak

Статус: new
Версия: 0.2.1
Jira: SCRUM-1074
Контур: Codex
Owner: unassigned
Parent: SCRUM-220
Source QA: SCRUM-1070
Related precedent: SCRUM-1031

## Scope

- test-only lifecycle fix in `tests/atlas_scrum1070_respec_button_test.gd`;
- child-first owned `SubViewport`/`Main` teardown with frame barriers and
  `WeakRef` verification;
- pre-quit public `AudioManager.stop_music()` barrier for windowed fixtures;
- this mirror and QA evidence.

Production `scripts/ui_screens.gd`, Atlas geometry/semantics, runtime audio and
button assets are excluded.

## Reproduction

On fresh `origin/dev` `0b17c754a`, run the SCRUM-1070 focused test with an
isolated `HOME`/`XDG_DATA_HOME`/test `--user-data-dir` under macOS Metal:

```text
tools/godot_gate.py --verbose --display-driver macos \
  --rendering-method mobile --rendering-driver metal \
  --script res://tests/atlas_scrum1070_respec_button_test.gd
```

The functional success marker is printed, then process exit reports four
leaked ObjectDB instances and two resources: the Ogg packet/stream/playback
chain for `music_menu_tavern_warm.ogg`.

## Expected

The windowed focused gate must exit `0` without `WARNING`, `ERROR`,
`SCRIPT ERROR`, `ObjectDB instances were leaked` or
`resources still in use at exit`, matching the QA protocol and SCRUM-1031.

## Acceptance

- five consecutive isolated Metal runs are functionally PASS and lifecycle
  clean;
- headless focused geometry/live-resize/reset assertions remain unchanged;
- semantic, Meta40, clickability, button family/theme, gamepad, no-overlap,
  runtime UI and full runtime gates remain PASS;
- no production UI/audio/schema/balance edits;
- SCRUM-1070 receives a clean independent QA rerun and may then move to Done.

## QA evidence

- reproduced `2/2` on Apple M4 Pro, Godot 4.7, Metal 4.0 Forward Mobile;
- verbose types: `OggPacketSequence`, `AudioStreamOggVorbis`,
  `AudioStreamPlaybackOggVorbis`, `OggPacketSequencePlayback`;
- linked Jira issues: SCRUM-1070 and SCRUM-1031.
