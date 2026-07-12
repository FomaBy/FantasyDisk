# SCRUM-1095 — Main Menu visible Gratitude icon remains more than 20 px from version glyphs

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1095
Тип: bug
Контур: Codex
Роль: Back-end / UI
Найдено QA: SCRUM-1093
Owner: `/root/scrum1095_visible_icon_gap`

## Воспроизведение

1. Открыть Main Menu на 1280×720, 1920×1080, 2048×1152 и 2560×1440.
2. Измерить от rightmost non-transparent pixel Gratitude PNG после
   runtime scale до first visible version glyph.
3. Повторить с `application/config/version=0.2.10-beta` и live resize.

## Ожидание / реальность

Ожидание: actual visible alpha-to-glyph gap `0..20 px`.

Реальность: `33.75 / 37.47 / 37.47 / 42.91 px`; existing tests
показывают 18px, потому что меряют transparent Button hitbox.

## Acceptance

- actual alpha-bbox-to-glyph gap `0..20 px` во всей матрице + resize;
- future version полностью visible/dynamic;
- exact 8px frame-safe reserve и ornament safety сохранены;
- callback/focus/tooltip/accessibility/SFX не изменены;
- independent visible-gap oracle и full UI/runtime gates PASS.

QA evidence: `tests/scrum1093_independent_visible_gap_test.gd`.
