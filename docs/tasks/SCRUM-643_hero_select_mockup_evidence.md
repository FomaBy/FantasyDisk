# SCRUM-643: SCRUM-561 QA - Missing Mandatory Hero Select Mockup Evidence

Статус: done
Contour: Codex
Owner: QA-evidence/design worker / codex-scrum-643-hero-select-evidence
Thread: codex-scrum-643-hero-select-evidence
Locked paths: docs/design/mockups/scrum561_hero_select_2k_redesign/**; docs/design/references/scrum561_hero_select_2k_redesign/**; docs/design/previews/scrum561_hero_select_2k_*
Jira: SCRUM-643

## Scope

Fix the SCRUM-561 QA failure where the live Hero Select 2K pass had runtime
frame assets and tests, but lacked the mandatory UI-director/OpenAI mockup
evidence package.

No runtime scripts, combat HUD files, or text-button runtime wiring are in
scope.

## Result

Added the missing Hero Select 2K evidence package:

- `docs/design/references/scrum561_hero_select_2k_redesign/hero_select_2k_mockup.png`
- `docs/design/mockups/scrum561_hero_select_2k_redesign/ui_plan.json`
- `docs/design/mockups/scrum561_hero_select_2k_redesign/ui_plan.report.json`
- `docs/design/mockups/scrum561_hero_select_2k_redesign/layout.json`
- `docs/design/mockups/scrum561_hero_select_2k_redesign/layout.guide.report.json`
- `docs/design/mockups/scrum561_hero_select_2k_redesign/mockup_render.report.json`
- `docs/design/previews/scrum561_hero_select_2k_ui_plan_guide.png`
- `docs/design/previews/scrum561_hero_select_2k_layout_guide.png`
- `docs/design/previews/scrum561_hero_select_2k_mockup_labeled_preview.png`
- `docs/design/previews/scrum561_hero_select_2k_mockup_debug_overlay.png`

Updated `docs/design/mockups/scrum561_hero_select_2k_redesign/spec.md` to link
the source mockup, content-zone plans, safe-zone previews and validation reports.

## Checks

- PASS: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\validate_ui_layout_plan.py --plan docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.json --guide-output docs\design\previews\scrum561_hero_select_2k_ui_plan_guide.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.report.json`
- PASS: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\render_content_zones.py --layout docs\design\mockups\scrum561_hero_select_2k_redesign\layout.json --guide-output docs\design\previews\scrum561_hero_select_2k_layout_guide.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\layout.guide.report.json`
- PASS: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\render_content_zones.py --input docs\design\references\scrum561_hero_select_2k_redesign\hero_select_2k_mockup.png --layout docs\design\mockups\scrum561_hero_select_2k_redesign\layout.json --output docs\design\previews\scrum561_hero_select_2k_mockup_labeled_preview.png --debug-output docs\design\previews\scrum561_hero_select_2k_mockup_debug_overlay.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\mockup_render.report.json`

Godot runtime tests were not rerun because this task changed only mockup/evidence
documentation and did not touch runtime UI code or assets used by Godot.

## Jira Final Note

Result: done / QA-ready.
Branch/commit/PR: `codex/SCRUM-643-hero-select-evidence`; commit/push recorded in Jira final comment.
Tests/evidence: content-zone planning and render reports pass; OpenAI mockup path
recorded above.
Docs/mirrors: this file and SCRUM-561 mockup spec updated.
Next owner/status: QA can re-check SCRUM-643 against the new evidence paths.
Disk cleanup: worktree cleanup recorded in Jira final comment.
