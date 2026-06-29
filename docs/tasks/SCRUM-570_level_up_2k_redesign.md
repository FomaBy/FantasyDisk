# SCRUM-570: UI Redesign - Level-Up Overlay @2K

Status: done
Contour: Codex
Owner: Design/Codex design-loop-2
Thread: design-loop-2
Locked paths: docs/design/mockups/scrum570_levelup_2k_redesign/, docs/design/references/scrum570_levelup_2k_redesign/, docs/design/previews/scrum570_*
Jira: SCRUM-570

## Scope

Design-only stage for the level-up overlay redesign. Required deliverables: an OpenAI-API-generated 2K mockup PNG, source references, preview/evidence, and a geometry spec for safe zones/frame margins/responsive behavior. Runtime integration files are out of scope for this stage.

## Work Performed

- Checked Jira SCRUM-570 status/comments and confirmed the latest dispatch is for Codex Design, design-only, no runtime file edits.
- Recovered the prior blocked geometry/spec package from `codex/scrum-570-level-up-ui`.
- Added `ui_plan.json`, ran the content-zone planning validator, and saved `ui_plan_report.json` plus `ui_plan_guide.png`.
- Generated two OpenAI Images API mockups. The first pass is retained as rejected geometry evidence; the second pass is accepted as the visual style/mockup source.
- Created safe-zone and contact previews under `docs/design/previews/`.

## Result

OpenAI Images API generation is now unblocked and complete. The design package is ready for QA / Back-end integration handoff.

Important caveat: the accepted v2 mockup is a visual source, not a slice-ready runtime atlas. The model preserved the hierarchy and material direction but is not exact enough to cut directly into runtime frames. The implementation contract is `ui_plan.json` and the element/safe-zone table in `spec.md`.

## Deliverables

- Mockup PNG: `docs/design/references/scrum570_levelup_2k_redesign/levelup_overlay_2k_mockup_v2.png`
- Rejected first pass: `docs/design/references/scrum570_levelup_2k_redesign/levelup_overlay_2k_mockup.png`
- Spec: `docs/design/mockups/scrum570_levelup_2k_redesign/spec.md`
- UI plan: `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan.json`
- Planning report: `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan_report.json`
- Planning guide: `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan_guide.png`
- Safe-zone preview: `docs/design/previews/scrum570_levelup_2k_safe_zones_v2.png`
- Contact sheet: `docs/design/previews/scrum570_levelup_2k_contact.png`

## Validation

- PASS: content-zone planning validator, `decision: ready_for_image`.
- PASS: OpenAI Images API generation through `fantasydisk-asset-generator`.
- PASS: safe-zone preview/contact sheet generated.
- Runtime tests: not run; no Godot runtime files, scenes, scripts, or runtime assets were changed in this Design-only stage.

## Next Step

Back-end integration should follow `spec.md` and `ui_plan.json`, not slice the mockup directly. Runtime content must stay inside the declared safe zones and off frame ornament.

## Disk Cleanup

Removed transient `tools/__pycache__/`. No `.godot/` cache or disposable QA clone was created.
