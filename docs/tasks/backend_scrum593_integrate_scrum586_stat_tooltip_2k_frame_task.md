# SCRUM-593: Integrate SCRUM-586 stat tooltip 2K frame

Jira: SCRUM-593
Статус: done
Роль: backend
Контур: Codex
Owner: Back-end / codex-background-backend-agent
Thread/Worker: codex-background-backend-agent
Locked paths: `scripts/ui/ui_theme_paths.gd`, `scripts/pause_stats_menu.gd`, `tests/ui_no_overlap_matrix_test.gd`, `docs/design/mockups/scrum586_stat_tooltip/spec.md`, `build/qa/scrum586_stat_tooltip/`
Source: SCRUM-586

## Context

Designer 2 completed the stat tooltip design-source package in SCRUM-586. This
task integrates the new visual asset into runtime and proves it with UI
verification.

## Inputs

- Spec: `docs/design/mockups/scrum586_stat_tooltip/spec.md`
- Runtime candidate: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`
- QA report: `build/qa/scrum586_stat_tooltip/scrum586_stat_tooltip_asset_report.json`
- Preview: `docs/design/previews/scrum586_stat_tooltip_safe_zones.png`

## Required Runtime Work

1. Register the new frame path and metadata through `scripts/ui/ui_theme_paths.gd`.
2. Wire `scripts/pause_stats_menu.gd::_make_custom_tooltip` to the new frame.
3. Replace the old `ST_LABEL_INSET_2K = 20` behavior with safe content padding:
   horizontal `44`, vertical `42` or stricter.
4. Preserve tooltip width `430`, auto height, autowrap and screen clamp behavior.
5. Keep all text inside the safe content zone. Do not place text over dragon
   corners, ruby pins, gold rails or center gems.

## Acceptance

- [x] New frame renders in `StatTooltipPanel`.
- [x] Tooltip text stays inside safe content zone at 1080p, 2K and 4K.
- [x] No `STRETCH_SCALE` on exact frame textures.
- [x] `tests/ui_no_overlap_matrix_test.gd` passes.
- [x] `tests/display_resolution_test.gd` passes.
- [x] UI smoke passes if runtime UI files changed.
- [x] Jira SCRUM-586 comment/result stays linked to this handoff.

## Result

Back-end integration complete. `StatTooltipPanel` now uses
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`, registered
through `UIThemePaths.OVERHAUL_2K_FRAME_*` as `stat_tooltip` with source size
`430x288`, texture margins `32/32/32/32`, and content margins `44/42/44/42`.
`_make_custom_tooltip` sizes `StatTooltipLabel` to the documented `342 px` safe
text width and the runtime smoke now asserts the exact frame path and safe
content margins.

Validation:

- `python3 tools/godot_gate.py --headless --path . --script res://tests/display_resolution_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Evidence: `build/qa/scrum586_stat_tooltip/scrum593_runtime_integration_evidence.md`.

## QA-Вердикт: PASSED

Статус: PASSED
Проверил: claude-qa (drift-repair), 2026-07-02, read-only на origin/dev 8d091d5e.
Причина правки .md: тикет с уже зафиксированным QA PASSED (см. историю комментов Jira + PM sprint audit) дрейфовал обратно в «Контроль качества». Корень — board_sync (tools/jira_board_sync.py:222-226): при «Статус: done» без секции «## QA-Вердикт» со строкой «Статус: PASSED» статус пересчитывается как done → «Контроль качества». Добавлен канонический блок, чтобы board_sync стабильно мапил тикет в «Готово».
Верификация: рантайм-интеграция на origin/dev — ui_theme_paths.gd регистрирует stat_tooltip (430x288, tex-margins 32, content 44/42), pause_stats_menu.gd подгружает STAT_TOOLTIP_FRAME_2K. Evidence: build/qa/scrum586_stat_tooltip/scrum593_runtime_integration_evidence.md.
