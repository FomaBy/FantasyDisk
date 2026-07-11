# UI: унифицировать весь интерфейс игры и добавить icon-only кнопку благодарностей

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1049
Контур: Codex
Owner: coordinator/root
Thread: /root
Locked paths: `docs/tasks/SCRUM-1049.md`, Jira coordination; implementation split into SCRUM-1050/1051/1052

## Цель

Сделать весь FantasyDisk UI единым визуальным семейством D&D + Dark Fantasy Dragon без механического копирования одного вида на все экраны. Отдельно привести Кодекс к общему UI-kit и заменить текстовый вход в благодарности на icon-only кнопку в правом верхнем углу главного меню.

## Декомпозиция

- `SCRUM-1050` — Design main: PixelLab reference sheet, layout/spec, gratitude icon.
- `SCRUM-1051` — Back-end: runtime inventory, shared UI-kit integration, tests/docs.
- `SCRUM-1052` — QA: независимая responsive/state/frame-safety приёмка.

## Acceptance criteria

- Все runtime-кнопки входят в одно FantasyDisk visual family с допустимыми screen-specific accents.
- Default/hover/pressed/disabled/focus/selected состояния согласованы и не сдвигают layout.
- Кодекс использует shared kit, сохраняя parchment/library accent.
- Main menu содержит icon-only кнопку благодарностей без face text; она открывает существующий Credits screen.
- Контент не пересекает орнамент рамок на 1280x720, 1920x1080 и 2560x1440.
- PixelLab provenance, mockup/spec, implementation evidence и QA verdict записаны в дочерних задачах.
