# SCRUM-955 — split Codex Characteristics and Attributes

Статус: done
Версия: 0.2.1
Jira: SCRUM-955
Owner: Codex `/root`
Контур: Codex
Design source: SCRUM-1013 (independent QA PASSED)

## Решение

- `CodexData.characteristics()` projects exactly the eight canonical base
  characteristics in `BASE_STAT_ORDER`.
- `CodexData.attributes()` projects exactly the 26 current derived/build
  attributes in `DERIVED_STAT_ORDER`; `stats()` remains a compatibility
  concatenation for non-UI diagnostics.
- The live rail now has six Russian sections: Персонажи, Монстры, Артефакты,
  Характеристики, Атрибуты, Возвышение.
- Base and derived entries never cross sections. Each uses the canonical icon,
  Russian title/description/influence, semantic chip, structured formula/detail
  text and canonical related-parameter projection.
- The accepted SCRUM-1013 dossier zones are represented by a contained preview
  plus independent related-scroll rail on the left and title/chips/body scroll
  on the right. Both remain inside the empty dark panel interior.
- Raw ids were removed from player-facing character/monster/stat rows and
  chips. The canonical identifiers remain internal data keys only.

## Verification

Passed on Godot 4.7 through `tools/godot_gate.py`:

- `tests/codex_data_smoke_test.gd` — 31 monsters, 17 characters, 161
  artifact/shop rows, 5 ascensions, 8 characteristics, 26 attributes;
- `tests/stat_formulas_smoke_test.gd` — 34 definitions;
- `tests/stat_formulas_derived_sync_test.gd` — 17 classes × 26 attributes;
- `tests/codex_discovery_contract_test.gd`;
- `tests/codex_unlock_tracking_test.gd`;
- `tests/runtime_smoke_ui_test.gd` — six tabs, exact counts and related zones;
- `tests/ui_no_overlap_matrix_test.gd` — full matrix plus split-specific
  1280x720 / 1920x1080 / 2560x1440 gates.
- `tests/display_resolution_test.gd`;
- `tests/dark_fantasy_ui_theme_test.gd`;
- `tests/asset_reference_integrity_test.gd` — 195 files / 2424 references;
- `tests/runtime_smoke_test.gd` — PASSED (the known dummy-renderer null-texture
  screenshot warning remains non-fatal).

Windowed visual QA covered both split sections at 1280×720, 1920×1080 and
2560×1440. It found and fixed two real responsive defects before handoff: the
selected-entry title could collapse to one pixel and the semantic chip could
collapse to a sliver. The final captures show all six Russian tabs, both
independent scroll zones and the dossier rails inside the empty frame interior;
no raw ids or Latin player-facing formulas remain. Capture files were temporary
QA evidence and are intentionally not committed.

The final latest-`origin/dev` verification and commit hashes are recorded in
the Jira implementation handoff. This implementation report is not the final
independent QA verdict.
