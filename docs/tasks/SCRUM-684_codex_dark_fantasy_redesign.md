# SCRUM-684 — Полный редизайн экрана Кодекса (Dark Fantasy, пиксель-арт через Pixel Lab)

Статус: done
Lane: claude
Labels: foma, design, claude

## Что и зачем
Полный редизайн экрана Кодекса (Codex / Глоссарий) внутри игры. Сейчас экран выглядит
технически; нужен уютный, качественный Dark Fantasy / D&D вид в высоком разрешении,
в единой стилистике игры. Все новые UI-ассеты — пиксель-арт, сгенерированный через
Pixel Lab MCP.

## Стилистика
- Dark Fantasy, Dungeons & Dragons: старый гримуар/манускрипт, тёмное дерево,
  кованый металл, золотой орнамент, тиснёная кожа, пергамент.
- Высокое разрешение (вьюпорт игры 2560x1440), чётко и читабельно.
- Контент строго в безопасной зоне фрейма (не на орнаменте рамки) — см. правило
  frame-content-safe-area-rule.
- Единый язык с принятыми UI-паками (level-up SCRUM-682/683, codex design pack
  SCRUM-678): те же шрифты, кнопки, палитра.

## Шаги
1. Разведка: текущий codex-код в `scripts/ui_screens.gd`, ассеты SCRUM-678, общий UI-стиль.
2. Сгенерировать через Pixel Lab набор ассетов: фон-панель гримуара, рамка контента,
   табы/иконки разделов, скролл/декор, кнопка Назад.
3. Импортировать ассеты в `assets/sprites/ui/` (+ `.import` сайдкары), привязать в коде.
4. Переверстать codex-экран под новый арт: панель, разделы, список записей, область чтения.
5. QA: headless smoke, безопасная зона фрейма, читабельность, отсутствие регрессий.

## Acceptance
- Экран Кодекса открывается без ошибок (headless smoke зелёный).
- Новый Dark Fantasy вид: пиксель-арт панели/рамки/иконки, высокое разрешение,
  контент в безопасной зоне.
- Стиль согласован с остальными UI-экранами игры.
- Все новые ассеты с `.import` сайдкарами, влиты в origin/dev.

## Files
- `scripts/ui_screens.gd` (codex-экран) — lane: claude
- `scripts/main.gd` (codex-задник)
- `assets/sprites/ui/frames/codex_pl/**` (новые пиксель-арт ассеты)
- `tests/runtime_smoke_test.gd` (codex frame-path ассерты)

## QA-Вердикт
Статус: PASSED (исходный редизайн f5064705) — затем REOPEN, исправлено ниже.

- Все 16 ассетов сгенерированы через Pixel Lab MCP, скачаны в
  `assets/sprites/ui/frames/codex_pl/` с `.import` сайдкарами (21 PNG / 21 import,
  включая обрезанные 9-slice копии в `fit/`).
- Интеграция: задник, фикс-margin 9-slice фреймы, nearest-фильтр, эмблемы разделов
  в nav, тёмный текст на пергаменте, screen-inset (фрейм не обрезается).
- Визуальная верификация GPU-скриншотов (characters/monsters/artifacts): орнамент
  не клиппится, контент в безопасной зоне, читабельно, единый Dark Fantasy стиль.
- `project.godot` (случайное удаление `window/stretch/aspect="keep"`) откатан.
- Коммит `f5064705`, влит в origin/dev.

## Reopen-фикс (2026-06-30, claude-designer) — коммит `4372692c`
QA-reopen вскрыл регрессию общего UI-гейта `ui_no_overlap_matrix_test.gd` (все
разрешения 1152…3840):
1. **CodexBackButton ∩ CodexDetailPanel.** Причина: фикс (немасштабируемые) 60px
   content-margins + шрифт 28 давали intrinsic-min высоту ≈99px, которая на малых
   вьюпортах превышала масштабированный layout-rect → кнопка раздувалась вниз на
   detail-панель. Фикс: `_codex_v2_apply_back_button_metrics()` масштабирует
   content-margins и шрифт кнопки по codex-scale (как табы), а safe-rect поднят и
   ужат (`CODEX_V2_BACK_BUTTON_SAFE` y 104→100, h 84→66) — нижняя кромка (base
   166) теперь чисто над верхом detail-панели (base 170) на всех scale.
2. **'expected CodexMainPanel to use its Codex @2K frame'.** `ui_no_overlap_matrix_test`
   всё ещё ассертил снятые `overhaul_2k` codex-фреймы; f5064705 обновил только
   `runtime_smoke_test`. Перенацелил matrix-ассерты на `codex_pl/fit` (совпадают с
   redesign + runtime_smoke). `runtime_smoke_test` expected back-button rect тоже
   синхронизирован с новым safe-rect.
- `ui_no_overlap_matrix_test.gd` зелёный: «UI no-overlap matrix test passed.»
  (codex no-overlap + frame-asserts на всех 6 разрешениях).
- Коммит `4372692c`, влит в origin/dev.

## QA-Вердикт (reopen fix, 2026-06-30)
Статус: PASSED

Проверено на `dev == origin/dev` после коммитов `4372692c` и `82352f1c`.
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.

Подтверждено: `CodexBackButton` больше не пересекает `CodexDetailPanel`,
`CodexMainPanel` проверяется на актуальный `codex_pl/fit` frame. Дефектов не
найдено. Disk cleanup: none created; чужой untracked WIP не трогался.
