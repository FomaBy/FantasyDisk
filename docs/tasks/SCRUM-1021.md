# SCRUM-1021 — exact Codex stat dependency matrix

Статус: done
Версия: 0.2.1
Jira: SCRUM-1021
Owner: Backend/Codex `/root`
Контур: Codex
Parent: SCRUM-955

## Причина

SCRUM-955 inferred related parameters by searching Russian formula/influence
prose for exact localized base-stat names. That lost generic dependencies such
as «все базовые характеристики» and could create lexical false positives such
as base `Сила` inside the derived phrase `Сила отталкивания`.

Independent QA caught the concrete failure:
`ultimate_multiplier.related == [energy]` while the runtime equation uses
Energy plus all seven remaining base characteristics.

## Решение

- `StatFormulas.DERIVED_BASE_DEPENDENCIES` is the canonical machine-readable
  26-row matrix, audited against `ProgressionData.derived_parameters()`.
- Every dependency row is stored in filtered `BASE_STAT_ORDER`; empty rows are
  explicit for derived values driven only by run modifiers.
- `CodexData._related_stats()` reads only that matrix. Derived rows project it
  directly and base rows invert it in `DERIVED_STAT_ORDER`; localized prose is
  presentation only.
- Player-facing formula/influence text was corrected where it contradicted the
  live equation: attack range, area radius/width, knockback distance,
  periodic damage and both vampiric values. Numeric gameplay code is unchanged.
- Focused tests assert the entire independent expected matrix and its inverse,
  not merely id type/membership. Regression anchors include all-eight
  `ultimate_multiplier`, `knockback_distance=[endurance, leadership]`, and
  empty direct dependencies for `range_multiplier`/`vampiric_*`.

## Verification

Passed on Godot 4.7 through `tools/godot_gate.py`:

- `tests/stat_formulas_smoke_test.gd` — all 26 rows exist, contain only unique
  canonical base ids and preserve `BASE_STAT_ORDER`;
- `tests/codex_data_smoke_test.gd` — exact full matrix + exact inverse, 8/26
  split and Russian-only projection;
- `tests/stat_formulas_derived_sync_test.gd` — 17 classes × 26 derived values;
- `tests/runtime_smoke_ui_test.gd` — six-tab runtime UI remains green;
- `tests/ui_no_overlap_matrix_test.gd` — Codex and the remaining responsive UI
  matrices keep their content inside safe frame zones;
- `tests/runtime_smoke_test.gd` — full project runtime smoke passed after the
  final rebase onto current `origin/dev`.

UI geometry, tabs, frame zones and scroll implementation are unchanged. The
pre-rebase display/theme/assets checks also passed; final focused,
no-overlap and full-runtime gates above were repeated after the rebase. This
implementation report is not the final QA verdict.

## QA-Вердикт (2026-07-10, `/root/audit_repo`) — FAILED

Статус: FAILED

Независимая регрессия выполнена в отдельном fresh worktree на
`origin/dev@db3094e1ca9eaa46ad51c264042a1823a7da2e8a`; production-код и тесты
не изменялись. Численный perturbation-probe реальных уравнений
`ProgressionData.derived_parameters()` подтвердил все 26 строк × 8 базовых
характеристик, точную обратную base→derived-проекцию, все восемь зависимостей
`ultimate_multiplier` и отсутствие ложной зависимости `strength` у
`knockback_distance`.

Зелёные проверки:

- compositor gates принятого SCRUM-1013: planning
  `ready_for_image/ok=true`, final layout/render `ok=true`, без warnings/errors;
- `stat_formulas_smoke_test`, `codex_data_smoke_test`,
  `stat_formulas_derived_sync_test`, `codex_discovery_contract_test`,
  `codex_unlock_tracking_test`, `runtime_smoke_ui_test`,
  `ui_no_overlap_matrix_test`, `display_resolution_test`,
  `dark_fantasy_ui_theme_test`, `asset_reference_integrity_test`;
- `gamepad_menu_focus_test`, `gamepad_core_input_test`,
  `gamepad_inrun_ui_test`, `gamepad_full_flow_smoke_test` 3/3 и полный
  `runtime_smoke_test` через `tools/godot_gate.py`.

Блокер найден оконной проверкой обоих split-разделов на 1280×720,
1920×1080, 2560×1080, 2560×1440 и 3840×2160. На всех размерах, кроме
1280×720, заголовок выбранного досье виден; safe frame zones, шесть русских
вкладок, related/detail scroll и восемь связанных элементов сохраняются.
На 1280×720 заголовки «Лидерство» и «Сила ульты» полностью не рисуются в двух
fresh-процессах даже после 120 settle-кадров:

- `CodexDetailTitle`: text корректен, `visible=true`, `in_tree=true`;
- rect `284×34`, `font_size=30`, рассчитанная высота glyph `42`;
- `line_count=1`, но `visible_lines=0`.

Скриншоты сохранены как
`docs/design/previews/scrum1023_codex_title_missing_1280x720_characteristics.png`
и `docs/design/previews/scrum1023_codex_title_missing_1280x720_attributes.png`.
Создан и связан blocking Bug **SCRUM-1023**. До его исправления и повторной
независимой QA SCRUM-1021 возвращён в `К выполнению`.

Disk cleanup: removed временные captures/logs/probes в `/tmp/scrum1021_qa`,
ignored `build/qa` и `.godot`; удаление QA-worktree после evidence push
фиксируется финальным Jira-комментарием.

Thread cleanup: collaboration subagent, не disposable top-level worker;
архивирование пользовательского task не требуется.

## Повторный независимый QA (2026-07-10, `/root/audit_repo`) — PASSED

После SCRUM-1023 независимый fresh-tree прогон подтвердил точную матрицу 26×8,
обратную base→derived-проекцию, `ultimate_multiplier` со всеми восемью
характеристиками и отсутствие false positive у `knockback_distance`. Оба
split-раздела прошли 720p/1080p/ultrawide/1440p/4K visual/content-zone matrix;
на 720p выбранный title имеет одну видимую строку. Все focused stat/Codex/UI,
display/theme/assets, gamepad и full-runtime гейты — PASS. Production/test
файлы QA не меняла; blocker SCRUM-1023 устранён и принят.
