# SCRUM-571: UI-redesign Reward Ordinary 2K Mockup

Статус: done
Lane: Codex
Owner: Design/Codex design-loop
Thread: design-loop
Locked paths: docs/design/mockups/scrum571_reward_2k/, docs/design/references/scrum571_reward_2k/, docs/design/previews/scrum571_*, optional assets/sprites/ui/frames/overhaul_2k/reward*
Jira: SCRUM-571

## Autonomy / Approval

User pre-approved in-scope Design work. Work is limited to source mockup/spec/evidence assets for the ordinary reward screen. Runtime scripts and shared integration files are out of scope.

## Context

The task requests a 2K OpenAI-API-generated UI mockup/spec/source package for the ordinary reward screen. `fantasydisk-ui-director` and `content-zone-image-compositor` were used because the screen has fixed reward cards, choice buttons, and strict safe content zones.

## Result

Completed the Design-only SCRUM-571 2K ordinary reward mockup package. The OpenAI Images API base layer was generated after loading `OPENAI_API_KEY` from the Windows User environment, then runtime sample content was composited strictly inside declared content zones. No manual/non-API substitute was used.

## Completed Evidence

- `docs/design/mockups/scrum571_reward_2k/ui_plan.json`
- `docs/design/mockups/scrum571_reward_2k/ui_plan_report.json` (`ok=true`, `decision=ready_for_image`)
- `docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout.json`
- `docs/design/mockups/scrum571_reward_2k/layout_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout_guide_report.json` (`ok=true`)
- `docs/design/mockups/scrum571_reward_2k/spec.md`
- `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json` (`ok=true`, 15 zones)
- `docs/design/previews/scrum571_reward_2k_ui_plan_guide.png`
- `docs/design/previews/scrum571_reward_2k_layout_guide.png`
- `docs/design/previews/scrum571_reward_2k_base.png`
- `docs/design/previews/scrum571_reward_2k_mockup.png`
- `docs/design/previews/scrum571_reward_2k_mockup_debug.png`

## Validation

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output ... --report ...` passed.
- `render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output ... --report ...` passed.
- OpenAI asset generator passed: `reward_ordinary_2k_base.png` saved under `docs/design/references/scrum571_reward_2k/`.
- Final compositor passed: `reward_ordinary_2k_mockup_report.json` has `ok=true` for all 15 zones.
- PNG audit passed: base/mockup/debug/preview images are `2560x1440`.

## Pending Deliverables

- Runtime Godot integration is intentionally out of scope for this Design stage and should be handled by a separate Back-end/UI integration task if needed.

## Rationale / Notes

The base image is a full-screen UI mockup/reference layer, so RGB is acceptable for this Design package. Future isolated runtime frame assets must be exported separately as alpha-ready PNGs with freshly measured texture/content margins before Godot wiring.
