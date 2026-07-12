# SCRUM-1090 — Atlas detailed upgrade descriptions UI mockup

Статус: done
Версия: 0.2.1
Jira: SCRUM-1090
Контур: Codex
Owner: Design / current Codex task
Thread/Worker: current user-facing Codex task
Branch: `dev`
Worktree: `/Users/sergeyfomin/Documents/AI Agent`

## Locked scope

- `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/`;
- `docs/design/references/scrum1090_atlas_upgrade_descriptions/`;
- `docs/design/previews/scrum1090_atlas_upgrade_descriptions/`;
- this task mirror and task-scoped Jira sync metadata.

Excluded: runtime UI, constellation manifest/data, balance values and tests owned
by SCRUM-1088/SCRUM-1089. Back-end implementation is a separate linked Jira
handoff.

## Source request

The Atlas must explain exactly what each invested point improves. The final
point of every weapon path must read as a unique, sufficiently strong reward
worth reaching.

## Design acceptance

- retain the accepted Atlas page hierarchy and existing production art;
- provide a PixelLab MCP source-only reference for the detailed dossier state;
- show exact-effect, scope, path progress and next-point result as separate
  semantic blocks;
- give a final node a clearly named `УНИКАЛЬНЫЙ ФИНАЛ` callout with trigger,
  numeric result and weapon-only scope;
- reserve a scrollable information viewport instead of shrinking long copy or
  covering ornament;
- keep every runtime label and action inside the calm dossier interior at
  1280×720, 1920×1080 and 2560×1440;
- create a linked Back-end handoff for runtime descriptions/final-node strength.

## Evidence

- PixelLab MCP config smoke: PASS (`get_balance`, no secrets printed).
- Planning contract: `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/ui_plan.json`.
- Render contract: `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/layout.json`.
- PixelLab source ID: `b6693906-f259-4b43-a1b5-4283ff88bec3`.

## Result

- PixelLab source-only page reference generated as
  `b6693906-f259-4b43-a1b5-4283ff88bec3` (688×384, 40 generations); no fallback
  and no runtime promotion.
- Planning gate: `ready_for_image`, 0 errors/warnings.
- Compositor fit: 13/13 content zones PASS. The final-node preview explicitly
  shows a 3-hit trigger, 35% execute threshold, +24% boss cap and +20% strength
  floor over node 5.
- Responsive reference: 3/3 PASS at 1280×720, 1920×1080 and 2560×1440.
- Preview/debug/contact sheet:
  `docs/design/previews/scrum1090_atlas_upgrade_descriptions/`.
- Back-end/data/balance handoff created as linked SCRUM-1091 and left blocked
  until independent Design QA plus release of SCRUM-1088/SCRUM-1089 locks.
- Runtime/data files changed: none.

Disk cleanup: temporary responsive render directory auto-removed; no Godot
cache, disposable clone or worktree created.

Thread cleanup: not a disposable worker thread.

## QA-Вердикт (2026-07-12)

Статус: FAILED

Независимо проверено в чистом worktree от `origin/dev` `ff4c37b63`:

- PixelLab MCP подтвердил completed source
  `b6693906-f259-4b43-a1b5-4283ff88bec3`; удалённый PNG и repository source
  совпадают по SHA-256
  `a8d05d4bbc33bb078239b4722ded71fac5640bde869ed62240ba6190e82b9f6f`;
- planning gate: `ready_for_image`, 19 элементов, 0 ошибок/предупреждений;
- compositor: 13/13 зон PASS; responsive matrix: 3/3 PASS;
- task commit не меняет `assets/`, `scripts/`, `scenes/` или `tests/`;
- SCRUM-1091 существует и корректно остаётся не взятым, пока SCRUM-1088 и
  SCRUM-1089 держат overlapping `scripts/ui_screens.gd` locks.

Найдены два приёмочных дефекта:

1. обязательная callout-надпись `УНИКАЛЬНЫЙ ФИНАЛ` отсутствует: макет использует
   `ФИНАЛ · SOLO`;
2. PixelLab base содержит запечённый символ `$` в верхнем header, вопреки
   no-text/no-pseudo-text контракту frame layer.

Linked blocking Bug: SCRUM-1092. Исправления дизайна/runtime QA не выполнял;
SCRUM-1090 возвращён в Jira `К выполнению` до fix + re-QA.

## Design rework result — SCRUM-1092 (2026-07-12)

- PixelLab base полностью перегенерирован через MCP: новый source
  `cccfc9a1-e067-4507-a178-9dd6d54bfce4`, SHA-256
  `3c2583453bd3d03612df9345676b9a91d465c3ca889481a93473f4a299d429be`.
- Base больше не содержит `$`, другого текста, цифр, валютных/semantic glyphs,
  рун или pseudo-writing. Original-size audit сохранён в
  `docs/design/references/scrum1090_atlas_upgrade_descriptions/glyph_audit.json`.
- Обязательная видимая callout теперь compositor-owned и записана точно как
  `УНИКАЛЬНЫЙ ФИНАЛ`; сокращение `ФИНАЛ · SOLO` удалено из plan/layout.
- Повторные gates: planning 20 элементов / 0 errors / 0 warnings; compositor
  13/13 PASS; responsive 3/3 PASS; debug visual подтверждает content-only
  placement внутри пустых секций dossier.
- Runtime/data/assets не менялись. Linked SCRUM-1092 готов к независимому re-QA;
  SCRUM-1091 остаётся blocked.

## Independent re-QA (2026-07-12)

Статус: PASSED

Связанный SCRUM-1092 принят независимым QA: новый PixelLab source подтверждён
API и SHA, original-size glyph audit чистый, callout ровно
`УНИКАЛЬНЫЙ ФИНАЛ`, planning `20/20`, compositor `13/13`, responsive `3/3`,
source-only scope соблюдён. Предыдущий QA-вердикт FAILED superseded этим
re-QA PASS; SCRUM-1090 закрыт в Jira как `Готово`.
