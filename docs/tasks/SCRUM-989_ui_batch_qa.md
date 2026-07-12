# SCRUM-989 — QA Level Up, Victory, Attribute Upgrade и Atlas

Статус: done
Jira: SCRUM-989
Версия: 0.2.1
Контур: Codex
Owner: QA/Codex `/root/qa_berserk_895_1043`
Роль: QA
Production scope: read-only
Блокер: снят — SCRUM-1045 QA PASSED / Готово

## Acceptance Matrix

- Level Up: gold local cards, no outer `LevelUpFrame`, badge/socket/icon
  disjoint, content outside ornament at `1280x720`, `1920x1080`, `2560x1440`.
- Victory transient banner and full result panel: exact centered and viewport/
  gold-shell safe at all three sizes plus live resize.
- Attribute Shop: one hollow final mouse-ignore frame, no redundant inner panel,
  complete stat-effect lines and two/three Atlas offers in one horizontal row.
- Mouse, keyboard and gamepad focus/activation remain functional.

## QA-Вердикт (2026-07-11)

Статус: FAILED

Функциональный и визуальный результат: PASS на clean-cache `origin/dev`
`76789a9dd`.

- PixelLab/UI Director evidence: SCRUM-985 source
  `d3e5030c-b61d-4899-83ba-04fd6ccafaa9`; Attribute Shop source
  `bf62b298-1df4-40d7-baeb-8fd30ac071d3`; planning gates
  `ready_for_image`, errors/warnings `0/0`, compositor reports `ok=true`.
- Fresh Metal 4.0 / Apple M4 Pro matrices `1280x720`, `1920x1080`,
  `2560x1440` manually inspected: no content-on-ornament overlap; Level Up
  badge/socket/icon disjoint; Victory centered; Attribute effects complete and
  three offers stay L→R in one row.
- PASS: Level capture oracle; SCRUM-986 centering/live resize;
  SCRUM-982/987/988 semantics; UI no-overlap; dark-fantasy theme; runtime UI;
  level-up advisor; meta skill tree; progression/economy; gamepad in-run/menu/
  core; gamepad full-flow `2/2`; clean-userdata full runtime.
- QA-only physical input probe: mouse, keyboard and gamepad each activate
  Level Up, Attribute Shop purchase and Victory banner exactly once.

Блокирующий lifecycle-дефект: SCRUM-1045. Windowed Metal runs of
`capture_scrum985_level_up.gd`, `capture_scrum982_987_988_attribute_shop.gd`
и `capture_scrum981_gold_menu_shell.gd` функционально завершаются exit `0`, но
каждый оставляет `4 ObjectDB` instances и `2 resources still in use`. Verbose
диагностика: `OggPacketSequence`, `AudioStreamOggVorbis`,
`AudioStreamPlaybackOggVorbis`, `OggPacketSequencePlayback`,
`music_menu_tavern_warm.ogg`.

По обязательному Windowed lifecycle gate SCRUM-1031 задача возвращена в Jira
`К выполнению` с label `blocked` до исправления SCRUM-1045 и чистого повтора
трёх Metal captures. Production UI не изменялся.

## Re-QA-вердикт (2026-07-11)

Статус: **PASSED** на актуальном `origin/dev` `7085e0dcb`.

- Исправление SCRUM-1045 принято независимым QA. Оригинальный verbose Apple
  Metal oracle повторён для всех трёх capture tools: Level Up, Attribute Shop и
  Gold Menu Shell/Victory прошли матрицы 1280×720, 1920×1080 и 2560×1440 с
  success markers и без `ObjectDB`, resource-still-in-use, Ogg/AudioStream,
  script-error или engine-error diagnostics.
- Повторно прошли Level Up geometry, Victory centering/live resize,
  Attribute/Atlas 2/3-offer semantics, UI no-overlap, dark-fantasy theme,
  runtime UI, level-up advisor, meta tree и progression/economy gates.
- Gamepad in-run/menu/core и два независимых full-flow прогона прошли; ранее
  принятый physical mouse/keyboard/gamepad probe остаётся применимым, поскольку
  после исходного QA production UI не менялся, а SCRUM-1045 затронул только
  QA-capture teardown.
- Полный isolated-userdata `runtime_smoke_test.gd` прошёл. Production UI/audio
  оставались read-only, локальный production diff отсутствует.

Label `blocked` снят; SCRUM-989 переведён из `Контроль качества` в `Готово`.
