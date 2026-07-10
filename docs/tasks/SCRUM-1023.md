# SCRUM-1023 — Codex selected stat title is invisible at 1280×720

Статус: done
Версия: 0.2.1
Jira: SCRUM-1023
Owner: Backend/Codex `/root`
Контур: Codex
Parents: SCRUM-1021, SCRUM-955

## Причина

Независимая QA обнаружила, что в разрешении 1280×720 выбранный заголовок
досье разделов «Характеристики» и «Атрибуты» не рисуется. Данные и rect
существуют, но доступная высота строки меньше высоты glyph:

- `CodexDetailTitle`: rect `284×34`, `font_size=30`, glyph height `42`;
- `visible=true`, `line_count=1`, `visible_lines=0`;
- воспроизводится для «Лидерство» и «Сила ульты» в fresh windowed-процессах
  после 120 settle-кадров;
- 1920×1080, 2560×1080, 2560×1440 и 3840×2160 отображают заголовок.

Evidence:

- `docs/design/previews/scrum1023_codex_title_missing_1280x720_characteristics.png`;
- `docs/design/previews/scrum1023_codex_title_missing_1280x720_attributes.png`.

## Scope

Узкое responsive-исправление в `scripts/ui_screens.gd` и focused regression
tests. Не объединять с будущим redesign SCRUM-954. Locked paths отсутствуют до
claim; после claim — только Codex title sizing/visibility и связанные тесты.

## Acceptance

- Выбранный русский заголовок досье виден на 1280×720 и всех больших целевых
  разрешениях без перекрытия чипа/тела/рамки.
- Добавлен runtime regression assertion `visible_lines >= 1` на 1280×720;
  проверки одной только высоты rect недостаточно.
- Related/detail scroll остаются разными контролами; title, chip, body и обе
  rail-зоны остаются внутри пустой тёмной content-zone frame.
- Сохранены шесть русских вкладок, матрица 8/26 и все восемь связанных
  характеристик для `ultimate_multiplier`.
- Зелёные focused stat/Codex/UI/no-overlap/display/theme/assets/gamepad и full
  runtime gates через `tools/godot_gate.py`, затем независимая windowed QA.

Disk cleanup: none created by the unclaimed remediation task.

Thread cleanup: task mirror created by collaboration QA subagent; no
disposable remediation worker thread exists yet.

## Реализация

- `CodexDetailTitle` использует отдельную mockup-native шкалу от базы
  1920×1080: `15 / 22 / 29 / 30px` на 720p / 1080p / 1440p / 4K.
- Геометрия title/chip/body, обе rail-зоны и scroll-контролы не менялись.
- Responsive-гейт теперь проверяет `get_visible_line_count() >= 1` для обоих
  stat-разделов, поэтому существующий rect без реально нарисованной строки
  больше не считается зелёным.

## Проверка реализации

После final-tree импорта через `tools/godot_gate.py` прошли:

- `ui_no_overlap_matrix_test.gd` (включая 720p/1080p/1440p и фактическую
  видимую строку обоих stat-разделов);
- `runtime_smoke_ui_test.gd`, `codex_data_smoke_test.gd`;
- `display_resolution_test.gd`, `dark_fantasy_ui_theme_test.gd`,
  `asset_reference_integrity_test.gd`;
- `codex_discovery_contract_test.gd`, `codex_unlock_tracking_test.gd`;
- `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`;
- `stat_formulas_derived_sync_test.gd`, полный `runtime_smoke_test.gd`.

Это implementation handoff, не независимый QA-вердикт. SCRUM-1023 и
родительские SCRUM-1021/955 закрываются только после отдельной повторной QA.
