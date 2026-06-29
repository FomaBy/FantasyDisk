# SCRUM-586: UI-редизайн тултипа статов @2K

Jira: SCRUM-586
Статус: done
Роль: design
Контур: Codex
Owner: Design / design-codex-SCRUM-586
Thread/Worker: design-codex-SCRUM-586
Locked paths: assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png, docs/design/mockups/scrum586_stat_tooltip/, docs/design/previews/scrum586_stat_tooltip_*, docs/design/references/scrum586_stat_tooltip/, scripts/pause_stats_menu.gd stat tooltip section, scripts/ui/ui_theme_paths.gd, tests/runtime_smoke_test.gd, tests/runtime_smoke_ui_test.gd, tests/ui_no_overlap_matrix_test.gd, tests/display_resolution_test.gd, build/qa/scrum586_stat_tooltip/
Handoff: SCRUM-593

## Задача

Подготовить дизайн-source пакет для свежего `StatTooltipPanel` в рамках UI
Overhaul 2K. База: `2560x1440`; runtime slot остается компактным
`430 x auto`, но новый frame требует большего content inset, чем старый
`ST_LABEL_INSET_2K = 20`.

## Результат Design

- OpenAI source: `docs/design/references/scrum586_stat_tooltip/stat_tooltip_frame_source.png`.
- 2K mockup composite: `docs/design/mockups/scrum586_stat_tooltip/mockup_2k.png`.
- Spec: `docs/design/mockups/scrum586_stat_tooltip/spec.md`.
- Runtime candidate asset: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`.
- Candidate copy: `docs/design/references/scrum586_stat_tooltip/ui_frame_2k_stat_tooltip_candidate.png`.
- Preview/contact: `docs/design/previews/scrum586_stat_tooltip_contact.png`.
- Safe-zone preview: `docs/design/previews/scrum586_stat_tooltip_safe_zones.png`.
- QA report: `build/qa/scrum586_stat_tooltip/scrum586_stat_tooltip_asset_report.json`.

Asset metrics:

```text
source_size: 430x288
texture_margins_ltrb: 32,32,32,32
content_margins_ltrb: 44,42,44,42
content_safe_rect_xywh: 44,42,342,204
edge_alpha_max: 0
```

## Handoff To Back-end

Created Jira handoff `SCRUM-593` for runtime integration and verifier runs.
Designer did not edit `scripts/pause_stats_menu.gd` or
`scripts/ui/ui_theme_paths.gd` by role boundary.

Back-end must:

- register the new frame path/metadata through `scripts/ui/ui_theme_paths.gd`;
- wire `scripts/pause_stats_menu.gd::_make_custom_tooltip` to the new frame;
- replace old 20 px text inset with the safe content margins above or equivalent;
- preserve fixed width `430`, auto height and tooltip clamp behavior;
- run `tests/ui_no_overlap_matrix_test.gd`, `tests/display_resolution_test.gd`
  and UI smoke as applicable.

## Validation

- OpenAI generation via `fantasydisk-asset-generator`: PASS.
- PNG audit: `430x288 RGBA`, `edge_alpha_max=0`, no baked text/icons.
- Safe-zone preview confirms runtime content must use `44/42` inset, not the old
  `20` px inset.
- Full runtime verifier is intentionally not run in this Design-only task;
  integration belongs to SCRUM-593.

## Notes

The Jira description mentions `scripts/ui_screens.gd`, but current inventory and
runtime code locate `StatTooltipPanel` / `_make_custom_tooltip` in
`scripts/pause_stats_menu.gd`.

## Final Verification 2026-06-28

- Owner/thread refreshed to `design-codex-SCRUM-586` per user directive; Designer 2 blocker ignored.
- Existing 2K stat tooltip package and runtime integration on `origin/dev` were re-verified instead of regenerated because the accepted generated frame, mockup, and SCRUM-593 integration are already present.
- Runtime target: `scripts/pause_stats_menu.gd::_make_custom_tooltip`; Jira text still mentions `scripts/ui_screens.gd`, but current code owns the stat tooltip builder in `scripts/pause_stats_menu.gd`.
- Safe zone confirmed: 430 x 288 frame, 32 px texture margins, content margins `Vector4(44, 42, 44, 42)`, label width 342 px, content never placed on frame ornament.
- Evidence: `build/qa/scrum586_stat_tooltip/scrum593_runtime_integration_evidence.md`.
- Tests passed: `tests/display_resolution_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_test.gd`.
- `tools/godot_gate.py` was not usable on Windows due `ModuleNotFoundError: No module named 'fcntl'`; target Godot scripts were run directly through Godot 4.7 console.
- Disposable Godot import/cache output is not part of the deliverable and was cleaned before finish.
