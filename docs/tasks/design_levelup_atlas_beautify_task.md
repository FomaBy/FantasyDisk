# Level-up: довести визуал до языка Атласа (рама, сокеты, орнаменты)

- Jira: SCRUM-892
- Статус: in_progress
- Контур: Claude
- Owner: Claude Fable 5 (интерактивный чат пользователя)
- Thread: claude-fable5-ui-unify-20260708
- Worktree: /private/tmp/fsd_wt_levelup2 (ветка levelup-beauty)
- Branch: dev
- Locked paths: scripts/ui_screens.gd (level-up зона), tests/ui_no_overlap_matrix_test.gd
  (level_up ветка), tests/runtime_smoke_test.gd (level-up ассерты)

## Source Request

Прямая директива пользователя (чат, 2026-07-08, скриншот): «экран поднятия
уровня… выглядит коряво и некрасиво (возьми за пример дизайн атласа)».
Первая итерация (чипы SCRUM-883) принята как недостаточная — нужен визуальный
язык Атласа: золотая рама, сокеты, орнаменты, торжественность.

## Решение

Поверх дима 0.82 — полая рама meta40 на весь экран; титул с орнаментом-
разделителем; портрет героя в кольце keystone; иконки наград в сокет-колодцах
meta40 (socket_notable); карточки плотнее (без пустых зон); бейджи и кит-кнопка
«Позже» остаются. Ассеты — существующие meta40/atlas_style, без новой генерации.

## Acceptance Criteria

- [ ] Рама, сокеты, орнамент, кольцо портрета — язык Атласа читается сразу.
- [ ] Карточки без больших пустот, кегль ≥12, viewport-fit ×7 зелёный.
- [ ] Зелёные: matrix, runtime_smoke, gamepad_inrun_ui, level_up_advisor.

## Прогресс

- 2026-07-08: спека — Claude Fable 5.
