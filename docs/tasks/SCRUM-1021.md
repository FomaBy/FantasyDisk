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
