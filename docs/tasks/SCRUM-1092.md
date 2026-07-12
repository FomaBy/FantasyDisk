# SCRUM-1092 — Atlas mockup: отсутствует «УНИКАЛЬНЫЙ ФИНАЛ» и запечён символ $

Статус: new
Тип: bug
Приоритет: normal
Версия: 0.2.1
Jira: SCRUM-1092
Контур: Codex
Роль: Design
Найдено QA при тестировании: SCRUM-1090

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
