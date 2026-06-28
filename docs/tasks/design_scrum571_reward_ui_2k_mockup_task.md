# SCRUM-571: UI-redesign Reward Ordinary 2K Mockup

Статус: blocked
Контур: Codex
Owner: Design/Codex
Thread: codex-design-worker
Locked paths: docs/design/mockups/scrum571_reward_2k/, docs/design/references/scrum571_reward_2k/, docs/design/previews/scrum571_*, optional assets/sprites/ui/frames/overhaul_2k/reward*
Jira: SCRUM-571

## Autonomy / Approval

User pre-approved in-scope Design work. Work is limited to source mockup/spec/evidence assets for the ordinary reward screen. Runtime scripts and shared integration files are out of scope.

## Context

The task requests a 2K OpenAI-API-generated UI mockup/spec/source package for the ordinary reward screen. `fantasydisk-ui-director` and `content-zone-image-compositor` were used because the screen has fixed reward cards, choice buttons, and safe content zones.

## Result

Blocked by missing OpenAI Images API credentials on this machine:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, D:\FantasyDisk_worktrees\scrum-571-reward-ui\.env)
```

Per the UI skill, no manual/non-API fallback mockup was created. The layout planning artifacts are complete and ready for image generation once the key is available.

## Completed Evidence

- `docs/design/mockups/scrum571_reward_2k/ui_plan.json`
- `docs/design/mockups/scrum571_reward_2k/ui_plan_report.json` (`ok=true`, `decision=ready_for_image`)
- `docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout.json`
- `docs/design/mockups/scrum571_reward_2k/layout_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout_guide_report.json` (`ok=true`)
- `docs/design/previews/scrum571_reward_2k_ui_plan_guide.png`
- `docs/design/previews/scrum571_reward_2k_layout_guide.png`
- `docs/design/mockups/scrum571_reward_2k/spec.md`

## Pending Deliverables

- `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png`
- final compositor report for the generated mockup
- Jira transition to `Контроль качества` after the OpenAI mockup exists

## Validation

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output ... --report ...` passed.
- `render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output ... --report ...` passed.
- OpenAI asset generator attempted and blocked by missing `OPENAI_API_KEY`.

## Next Step

Restore/export `OPENAI_API_KEY` or add it to `C:/Users/FomaE/.codex/.env`, then rerun the generator command recorded in the Jira/comment history and continue from the existing plan/spec.
