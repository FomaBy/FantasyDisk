# Level-up: довести визуал до языка Атласа (рама, сокеты, орнаменты)

- Jira: SCRUM-892
- Статус: done
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
- 2026-07-08: доп-директива пользователя (скриншот live): убрать иконку класса
  с level-up полностью — keystone-кольцо портрета ОТМЕНЕНО, узлы не создаются.
- 2026-07-08: субагент levelup-beauty влит (7583e018, мерж ce93494e→): полая рама
  meta40 поверх дима 0.82, титул + divider_ornament, панель от safe-зоны рамы,
  сокеты notable за иконками наград / keystone+star_alloc у карточки советника,
  hover подсвечивает сокет; карточки контентной высоты (probe реального шрифта,
  ступенчатая деградация на компактах). Пойманный агентом баг: probe-Label вне
  дерева игнорирует override кегля + Label с боксом ниже строки не рисует её
  (lines_visible=0) — высоты меряются Font.get_height напрямую.

## QA-Вердикт

- Статус: PASSED
- Дата: 2026-07-08, судья: Claude Fable 5 (оркестратор)
- Гейты в worktree (агент, EXIT=0): level_up_advisor, gamepad_inrun_ui,
  ui_no_overlap_matrix ×7 (новые ассерты: рама, панель в safe ±2px, сокеты,
  divider, отсутствие иконки класса), полный runtime_smoke.
- Гейты на слитом dev (оркестратор, EXIT=0): ui_no_overlap_matrix ×7 + полный
  runtime_smoke.
- Визуальная сверка капчеров 2560×1440 и 1152×648 — оркестратором лично
  (build/qa/scrum892/, локально).
- Известный вне-скоуп: меню-HUD (ОЗ/Опыт) и «+1» поверх банда рамы —
  pre-existing слой, кандидат на отдельный тикет.
- Disk cleanup: removed /private/tmp/fsd_wt_levelup2 (+ .godot-кэш), ветка
  levelup-beauty удалена после влития.
