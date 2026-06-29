# SCRUM-572 - UI Redesign: Elite Artifact Reward 2K

Статус: done
Контур: Codex
Owner: Design/Codex design-loop
Thread: design-loop
Locked paths: `docs/design/mockups/scrum572_elite_artifact_reward_2k/`, `docs/design/references/scrum572_elite_artifact_reward_2k/`, `docs/design/previews/scrum572_*`, local SCRUM-572 evidence docs
Jira: SCRUM-572

## Scope

Design-only stage for the elite artifact reward screen: create an OpenAI-API-generated 2K mockup/spec/source package for the reward screen that presents 3 artifact choices after an elite victory. Runtime files such as `scripts/ui_screens.gd` are out of scope and were not edited.

## Result

Completed the elite artifact reward 2K mockup package. The OpenAI Images API base layer was generated after loading `OPENAI_API_KEY` from the Windows User environment, then runtime sample content was composited strictly inside declared content zones. No manual or non-API substitute was used.

## Completed Evidence

- `docs/design/mockups/scrum572_elite_artifact_reward_2k/spec.md`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/ui_plan.json`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/ui_plan_report.json` (`ok=true`, `decision=ready_for_image`)
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/ui_plan_guide.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/layout.json`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/layout_guide.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/layout_guide_report.json` (`ok=true`)
- `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_base.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_debug.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_report.json` (`ok=true`, 18 zones)
- `docs/design/previews/scrum572_elite_artifact_reward_2k_ui_plan_guide.png`
- `docs/design/previews/scrum572_elite_artifact_reward_2k_layout_guide.png`
- `docs/design/previews/scrum572_elite_artifact_reward_2k_base.png`
- `docs/design/previews/scrum572_elite_artifact_reward_2k_mockup.png`
- `docs/design/previews/scrum572_elite_artifact_reward_2k_mockup_debug.png`

## Validation

- Read required dispatcher/UI skills: `fantasydisk-agent-dispatcher`, `fantasydisk-ui-director`, `fantasydisk-asset-generator`, and `content-zone-image-compositor`.
- `validate_ui_layout_plan.py` passed for `ui_plan.json` with `ok=true`, `decision=ready_for_image`.
- `render_content_zones.py` layout guide passed with `ok=true`.
- OpenAI asset generator produced the 2560x1440 base layer.
- Final compositor report passed with `ok=true` for 18 zones.
- PNG audit confirmed base, mockup, debug, and preview images are 2560x1440.
- No runtime scripts, scenes, gameplay, balance, or integration files were edited.

## Pending Deliverables

Runtime Godot integration is out of scope for this Design-only ticket. Create a separate Back-end/UI integration task if the elite reward screen should consume this package in-game.

## Rationale / Notes

The base image is a full-screen UI mockup/reference layer, so RGB is acceptable for this Design package. Future isolated runtime frame assets must be exported separately as alpha-ready PNGs with measured texture/content margins before Godot wiring.
