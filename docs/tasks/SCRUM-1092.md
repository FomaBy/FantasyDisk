# SCRUM-1092 — Atlas mockup: отсутствует «УНИКАЛЬНЫЙ ФИНАЛ» и запечён символ $

Статус: done
Тип: bug
Приоритет: normal
Версия: 0.2.1
Jira: SCRUM-1092
Контур: Codex
Роль: Design
Найдено QA при тестировании: SCRUM-1090
Owner: Design/current Codex rework
Thread/Worker: current user-facing Codex task
Branch: `codex/scrum-1092-atlas-final-callout`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/SCRUM-1092`
Locked paths: `docs/design/{mockups,references,previews}/scrum1090_atlas_upgrade_descriptions/`,
`docs/tasks/SCRUM-1090.md`, `docs/tasks/SCRUM-1092.md`

Runtime/data scope is explicitly excluded. SCRUM-1088/SCRUM-1089 files and
locks are not touched.

## Воспроизведение

1. Открыть
   `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/ui_plan.json` и
   compositor preview.
2. Проверить semantic callout финального узла: используется `ФИНАЛ · SOLO`,
   точная обязательная надпись `УНИКАЛЬНЫЙ ФИНАЛ` отсутствует.
3. Открыть PixelLab source PNG и верхний header около `x=270, y=27`:
   в frame layer запечён символ `$`, остающийся в preview/responsive evidence.

## Ожидание / Реальность

Ожидание: явно названная callout `УНИКАЛЬНЫЙ ФИНАЛ`; PixelLab frame/layout
layer без текста, цифр, валютных символов и pseudo-text.

Реальность: required callout отсутствует, а base содержит `$` вопреки recorded
no-text prompt.

## Acceptance

- callout `УНИКАЛЬНЫЙ ФИНАЛ` присутствует и помещается в dossier safe zone;
- PixelLab base исправлен через PixelLab MCP без fallback и не содержит text,
  numbers, currency glyphs или pseudo-text;
- provenance/source ID + SHA обновлены;
- planning gate остаётся `ready_for_image` с 0 errors/warnings;
- compositor и responsive matrix 1280×720 / 1920×1080 / 2560×1440 зелёные;
- runtime code/data/assets не меняются в Design fix.

## QA evidence

- origin/dev tested: `ff4c37b63`;
- source ID: `b6693906-f259-4b43-a1b5-4283ff88bec3`;
- source SHA-256:
  `a8d05d4bbc33bb078239b4722ded71fac5640bde869ed62240ba6190e82b9f6f`;
- independent gates: planning 19/19; compositor 13/13; responsive 3/3;
- linked Jira Bug SCRUM-1092 blocks SCRUM-1090.

## Result

- Новый PixelLab MCP source:
  `cccfc9a1-e067-4507-a178-9dd6d54bfce4`, 688×384 RGBA, SHA-256
  `3c2583453bd3d03612df9345676b9a91d465c3ca889481a93473f4a299d429be`.
- Старый source `b6693906-f259-4b43-a1b5-4283ff88bec3` явно записан в
  provenance как rejected/superseded из-за запечённого `$`.
- Новый base просмотрен в original size: текст, цифры, валютные glyphs,
  semantic icons, руны и pseudo-writing отсутствуют; defect-region header
  пуст. Audit: `docs/design/references/scrum1090_atlas_upgrade_descriptions/glyph_audit.json`.
- Видимая compositor-callout теперь ровно `УНИКАЛЬНЫЙ ФИНАЛ`; она не запечена
  в base и помещается в `Rect2(510,69,143,12)`.
- Planning gate: `ready_for_image`, 20 элементов, 0 errors, 0 warnings.
- Compositor: 13/13 zones PASS; responsive: 3/3 PASS на 1280×720,
  1920×1080, 2560×1440; debug visual обновлён.
- Runtime/data/assets SCRUM-1088/SCRUM-1089 не менялись. SCRUM-1091 остаётся
  blocked до независимого re-QA и освобождения overlapping Back-end locks.

Disk cleanup: task не создавал `.godot`, user-data или build caches; isolated
worktree/branch удаляются сразу после push и Jira sync.

Thread cleanup: not a disposable worker thread.
